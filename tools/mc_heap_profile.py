#!/usr/bin/env python3
"""
Profile the actual heap usage of the Arkana Aeronautics modded Minecraft
client at a given -Xmx so you can find the empirical floor.

Workflow:

    # 1. Inject GC logging into PrismLauncher's instance.cfg + pin -Xmx.
    python3 tools/mc_heap_profile.py prepare --xmx 6G --label run-6g

    # 2. Launch MC via PrismLauncher as normal. Play in a "representative"
    #    area for 10+ minutes: base, ship contraption, world traversal.
    #    Quit cleanly via the in-game menu.

    # 3. Analyse the GC log for peak used / committed heap. Also restores
    #    the original instance.cfg.
    python3 tools/mc_heap_profile.py analyze --label run-6g

    # 4. Or restore the cfg without analysing (cancel a run):
    python3 tools/mc_heap_profile.py restore

Try a few -Xmx values (e.g. 4G, 5G, 6G, 7G, 8G). The empirical floor is
the smallest -Xmx where peak used-heap stays comfortably below committed
(say 80%) and where you didn't notice frametime hitches.

Notes:
- The script preserves your existing JVM args (Shenandoah + tuning) and
  only ADDS the -Xlog argument plus -Xmx / -Xms / Override toggles.
- A state file at tools/.mc_heap_profile.state.json holds the backup
  bits so `restore` can put cfg back exactly as it was.
- Default instance.cfg path is derived automatically; override with
  --instance-cfg PATH if you have multiple instances.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import sys
from pathlib import Path

PRISMS_INSTANCES = (
    Path.home()
    / "Library/Application Support/PrismLauncher/instances"
)

# Persisted backup of mutated fields.
STATE_PATH = Path(__file__).parent / ".mc_heap_profile.state.json"


# ──────────────────────────────────────────────────────────────────────────
# instance.cfg parsing — flat key=value, with quoted-string values for
# fields containing spaces. We preserve all other lines verbatim.

def find_instance_cfg() -> Path:
    if not PRISMS_INSTANCES.exists():
        sys.exit(f"PrismLauncher instances dir not found at {PRISMS_INSTANCES}")
    candidates = [
        p / "instance.cfg"
        for p in PRISMS_INSTANCES.iterdir()
        if (p / "instance.cfg").exists() and "arkana" in p.name.lower()
    ]
    if not candidates:
        sys.exit(
            "No PrismLauncher instance matching '*arkana*' found. "
            "Pass --instance-cfg PATH explicitly."
        )
    if len(candidates) > 1:
        sys.stderr.write(
            f"warning: multiple arkana instances; using {candidates[0]}\n"
        )
    return candidates[0]


def read_cfg(path: Path) -> dict[str, str]:
    """Return key→value with quotes stripped. Used for read-only inspection.
    For mutation we re-write lines in place rather than reformat."""
    out: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if "=" not in line or line.startswith("["):
            continue
        k, v = line.split("=", 1)
        v = v.strip()
        if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
            v = v[1:-1]
        out[k.strip()] = v
    return out


def mutate_cfg(path: Path, updates: dict[str, str]) -> dict[str, str]:
    """Apply key=value updates in place. Returns the OLD values for each
    mutated key so the caller can persist them for restore. Keys that
    didn't exist before are recorded with value ``<MISSING>``."""
    lines = path.read_text().splitlines(keepends=True)
    old_values: dict[str, str] = {}
    seen: set[str] = set()

    def encode(v: str) -> str:
        # Mirror PrismLauncher's convention: quote if the value contains
        # whitespace; leave plain otherwise.
        if any(c.isspace() for c in v) or v == "":
            return f'"{v}"'
        return v

    for idx, raw in enumerate(lines):
        if "=" not in raw or raw.lstrip().startswith("["):
            continue
        k, _, _ = raw.partition("=")
        k = k.strip()
        if k in updates:
            stripped_v = raw.split("=", 1)[1].rstrip("\n")
            stripped_v = stripped_v.strip()
            if len(stripped_v) >= 2 and stripped_v[0] == '"' and stripped_v[-1] == '"':
                stripped_v = stripped_v[1:-1]
            old_values[k] = stripped_v
            new_v = updates[k]
            lines[idx] = f"{k}={encode(new_v)}\n"
            seen.add(k)

    # Append any keys we didn't find.
    for k, v in updates.items():
        if k not in seen:
            old_values[k] = "<MISSING>"
            lines.append(f"{k}={encode(v)}\n")

    path.write_text("".join(lines))
    return old_values


# ──────────────────────────────────────────────────────────────────────────
# Xmx mutation. JvmArgs is one giant quoted string of JVM flags. We splice
# in or replace -Xmx, -Xms, and a -Xlog line.

GC_LOG_FLAG_TPL = "-Xlog:gc,gc+heap=info:file={path}::filecount=1,filesize=20M"


def update_jvm_args(existing: str, xmx: str, xms: str, log_path: Path) -> str:
    tokens = shlex.split(existing)
    # Strip any pre-existing -Xmx / -Xms / -Xlog:gc* so a repeat prepare
    # is idempotent.
    keep = []
    for t in tokens:
        if t.startswith("-Xmx") or t.startswith("-Xms"):
            continue
        if t.startswith("-Xlog:gc"):
            continue
        keep.append(t)
    keep.append(f"-Xms{xms}")
    keep.append(f"-Xmx{xmx}")
    keep.append(GC_LOG_FLAG_TPL.format(path=log_path))
    return " ".join(keep)


# ──────────────────────────────────────────────────────────────────────────
# GC log parsing. Shenandoah `-Xlog:gc:info` emits lines like:
#
#   [12.345s][info][gc] Concurrent reset 1234M->1024M(8192M) 1.234ms
#
# and heap header lines:
#
#   [12.345s][info][gc,heap] Heap: 1024M(8192M) used(committed)
#
# We extract numbers that look like "USED->USED(COMMITTED)" or
# "USED(COMMITTED)" and report the running maxima.

SIZE_RE = re.compile(r"(\d+)([KMG])")
MIGRATION_RE = re.compile(
    r"(\d+[KMG])->(\d+[KMG])\((\d+[KMG])\)"
)
SINGLE_RE = re.compile(
    r"\b(\d+[KMG])\(([0-9]+[KMG])\)"
)


def to_mb(token: str) -> float:
    """Convert '1024M' / '2G' / '500K' to megabytes (float)."""
    m = SIZE_RE.fullmatch(token)
    if not m:
        return 0.0
    n = float(m.group(1))
    unit = m.group(2)
    if unit == "K":
        return n / 1024.0
    if unit == "M":
        return n
    if unit == "G":
        return n * 1024.0
    return 0.0


def analyze_log(path: Path) -> tuple[float, float, int]:
    if not path.exists():
        sys.exit(f"GC log not found at {path} — did MC actually run?")
    peak_used = 0.0
    peak_committed = 0.0
    n_samples = 0
    with path.open() as f:
        for line in f:
            for m in MIGRATION_RE.finditer(line):
                used_after = to_mb(m.group(2))
                committed = to_mb(m.group(3))
                if used_after > peak_used:
                    peak_used = used_after
                if committed > peak_committed:
                    peak_committed = committed
                n_samples += 1
            # Also try the single USED(COMMITTED) pattern, but only on lines
            # where MIGRATION_RE didn't already match.
            if MIGRATION_RE.search(line):
                continue
            for m in SINGLE_RE.finditer(line):
                used = to_mb(m.group(1))
                committed = to_mb(m.group(2))
                if used > peak_used:
                    peak_used = used
                if committed > peak_committed:
                    peak_committed = committed
                n_samples += 1
    return peak_used, peak_committed, n_samples


# ──────────────────────────────────────────────────────────────────────────
# State persistence (for restore).

def save_state(state: dict) -> None:
    STATE_PATH.write_text(json.dumps(state, indent=2))


def load_state() -> dict | None:
    if not STATE_PATH.exists():
        return None
    return json.loads(STATE_PATH.read_text())


def clear_state() -> None:
    if STATE_PATH.exists():
        STATE_PATH.unlink()


# ──────────────────────────────────────────────────────────────────────────
# Subcommands.

def cmd_prepare(args: argparse.Namespace) -> None:
    if load_state() is not None:
        sys.exit(
            "Existing profile state found — `restore` or `analyze` first."
        )
    cfg_path = Path(args.instance_cfg) if args.instance_cfg else find_instance_cfg()
    cfg = read_cfg(cfg_path)
    xmx = args.xmx
    xms = args.xms or xmx
    label = args.label or f"run-{xmx.lower()}"
    log_path = Path("/tmp") / f"mc-heap-{label}.log"
    if log_path.exists():
        log_path.unlink()

    existing_args = cfg.get("JvmArgs", "")
    new_args = update_jvm_args(existing_args, xmx=xmx, xms=xms, log_path=log_path)

    # Force PrismLauncher to honour our pinned -Xmx via OverrideMemory=true
    # so its own MinMem/MaxMem doesn't fight our JvmArgs. We also pin its
    # MinMemAlloc / MaxMemAlloc to match — belt and braces.
    xmx_mb = int(round(to_mb(xmx)))
    updates = {
        "JvmArgs": new_args,
        "OverrideJavaArgs": "true",
        "OverrideMemory": "true",
        "MinMemAlloc": str(xmx_mb),
        "MaxMemAlloc": str(xmx_mb),
    }
    old = mutate_cfg(cfg_path, updates)
    save_state({
        "cfg_path": str(cfg_path),
        "label": label,
        "log_path": str(log_path),
        "xmx": xmx,
        "old_values": old,
    })
    print(f"prepared instance.cfg with -Xmx={xmx} -Xms={xms} (label={label})")
    print(f"  GC log will be written to {log_path}")
    print("now: launch MC via PrismLauncher, play >=10 min, quit cleanly")
    print(f"then: python3 {Path(__file__).name} analyze")


def cmd_analyze(args: argparse.Namespace) -> None:
    state = load_state()
    if state is None:
        sys.exit("no active profile — run `prepare` first.")
    label = state["label"]
    log_path = Path(state["log_path"])
    print(f"analyzing label={label} log={log_path}")
    peak_used, peak_committed, n = analyze_log(log_path)
    if n == 0:
        sys.exit(
            "log parsed 0 heap samples — make sure MC actually ran and quit "
            "cleanly. Run again or `restore`."
        )
    print(f"  samples:        {n}")
    print(f"  peak used:      {peak_used:.0f} MB")
    print(f"  peak committed: {peak_committed:.0f} MB")
    # Heuristic recommendation: minimum = peak_used × 1.25 (working set +
    # 25% headroom for GC + spikes), rounded to nearest 256 MB.
    rec = int(round(peak_used * 1.25 / 256.0)) * 256
    if rec < 1024:
        rec = 1024
    print(f"  recommended -Xmx (peak_used × 1.25, rounded to 256MB): {rec} MB")
    # Restore unless --keep was passed.
    if not args.keep:
        _do_restore(state)
    else:
        print("(--keep set: instance.cfg NOT restored; rerun analyze without --keep, or `restore`)")


def cmd_restore(args: argparse.Namespace) -> None:
    state = load_state()
    if state is None:
        sys.exit("nothing to restore — no active profile state.")
    _do_restore(state)


def _do_restore(state: dict) -> None:
    cfg_path = Path(state["cfg_path"])
    old = state["old_values"]
    # Restore each previously-mutated key; for keys that didn't exist
    # before, drop them by setting to <MISSING> and we'll filter.
    real_updates = {k: v for k, v in old.items() if v != "<MISSING>"}
    if real_updates:
        mutate_cfg(cfg_path, real_updates)
    # For keys we ADDED, strip them out.
    keys_to_strip = [k for k, v in old.items() if v == "<MISSING>"]
    if keys_to_strip:
        keep_lines = []
        for line in cfg_path.read_text().splitlines(keepends=True):
            k = line.split("=", 1)[0].strip()
            if k in keys_to_strip:
                continue
            keep_lines.append(line)
        cfg_path.write_text("".join(keep_lines))
    clear_state()
    print(f"restored {cfg_path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_prep = sub.add_parser("prepare", help="inject GC logging + pin -Xmx")
    p_prep.add_argument("--xmx", required=True, help="target heap, e.g. 6G or 5120M")
    p_prep.add_argument("--xms", default=None, help="initial heap (default: same as xmx)")
    p_prep.add_argument("--label", default=None, help="run label (default: run-<xmx>)")
    p_prep.add_argument("--instance-cfg", default=None, help="explicit path to instance.cfg")
    p_prep.set_defaults(fn=cmd_prepare)

    p_an = sub.add_parser("analyze", help="parse GC log + report peaks")
    p_an.add_argument("--keep", action="store_true", help="don't restore instance.cfg")
    p_an.set_defaults(fn=cmd_analyze)

    p_rest = sub.add_parser("restore", help="restore instance.cfg")
    p_rest.set_defaults(fn=cmd_restore)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
