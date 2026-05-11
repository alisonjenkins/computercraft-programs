#!/usr/bin/env python3
"""
Convert a Minecraft/Create .nbt schematic (vanilla structure format) into a
Lua schema consumable by builder.lua.

Vanilla structure NBT layout (gzipped TAG_Compound):
    size      -> [W, H, L]  (int_array or list of 3 ints)
    palette   -> [{ Name: str, Properties: optional compound }, ...]
    blocks    -> [{ state: int, pos: [x, y, z], nbt: optional }, ...]
    entities  -> ignored
    DataVersion -> ignored

Create's exported `.nbt` schematics use this same layout, so files dropped
into `<world>/schematics/<player>/foo.nbt` round-trip through this script.

Output: a Lua file shaped like

    return {
        size    = { width = W, height = H, length = L },
        palette = { [1] = "minecraft:stone", [2] = "minecraft:oak_planks", ... },
        layers  = {
            -- y = 0
            { { 1, 1, 2, ... }, ... },   -- rows along Z, each row is a list of cell indices
            -- y = 1
            { ... },
        },
    }

Where `0` (or missing) cells = air. Block properties (stair facing, slab top
half, etc.) are dropped — turtle.placeDown can't honour them, and the
resulting build will be solid-blocks-only for stairs/slabs/etc.

Install dep:
    pip install nbtlib

Usage:
    python3 tools/schematic_to_lua.py path/to/schematic.nbt [output.lua] [--orient N]

--orient rotates the schematic around the vertical axis (looking down) in 90°
clockwise steps. N ∈ {0, 90, 180, 270} or equivalently {0, 1, 2, 3}. Rotation
is applied to block positions and the size header; block properties are
dropped already, so stair facings etc. won't be re-mapped (a known limit).
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import nbtlib
except ImportError:
    sys.stderr.write("error: nbtlib not installed. Run: pip install nbtlib\n")
    sys.exit(2)


def lua_string(s: str) -> str:
    """Format a Python string as a Lua string literal."""
    escaped = s.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


# 90° CW rotation table for horizontal cardinal directions.
_FACING_CW = {"north": "east", "east": "south", "south": "west", "west": "north"}


def rotate_facing(value: str, steps: int) -> str:
    """Rotate a `facing` property value `steps × 90°` clockwise (top-down).
    Pass-through for any value that isn't a cardinal direction."""
    if value not in _FACING_CW:
        return value
    for _ in range(steps % 4):
        value = _FACING_CW[value]
    return value


# Axis-based blocks (logs, pillars, chains) rotate differently — swap x ↔ z
# on 90/270, identity on 0/180.
_AXIS_CW = {"x": "z", "z": "x"}


def rotate_axis(value: str, steps: int) -> str:
    if (steps % 2 == 1) and value in _AXIS_CW:
        return _AXIS_CW[value]
    return value


# Which property keys we actually rotate when --orient is used. Other props
# (half, shape, waterlogged, …) are pass-through.
_ROTATABLE_PROPS = {
    "facing": rotate_facing,
    "axis": rotate_axis,
    # door / chest "hinge" doesn't rotate cleanly because the meaning flips with
    # facing; leave alone — half-broken for doors is the existing limitation.
}


def transform_properties(props: dict[str, str], steps: int) -> dict[str, str]:
    out = {}
    for k, v in props.items():
        fn = _ROTATABLE_PROPS.get(k)
        out[k] = fn(v, steps) if fn else v
    return out


def parse_orient(value: str) -> int:
    """Normalise an --orient value to a 90° step count in [0, 3]."""
    try:
        n = int(value)
    except ValueError:
        raise SystemExit(f"--orient must be 0/90/180/270, got {value!r}")
    if n in (0, 90, 180, 270):
        return n // 90
    if n in (0, 1, 2, 3):
        return n
    raise SystemExit(f"--orient must be 0/90/180/270, got {value!r}")


def rotate(x: int, z: int, W: int, L: int, steps: int) -> tuple[int, int, int, int]:
    """Rotate a (x, z) cell `steps` × 90° clockwise (viewed from above) inside
    a W×L footprint. Returns (new_x, new_z, new_W, new_L). Y is unchanged.

    Step transforms:
      0 → identity                         : size W×L
      1 → 90° CW : (x, z) → (L-1-z, x)     : size L×W
      2 → 180°   : (x, z) → (W-1-x, L-1-z) : size W×L
      3 → 270° CW: (x, z) → (z, W-1-x)     : size L×W
    """
    steps %= 4
    if steps == 0:
        return x, z, W, L
    if steps == 1:
        return L - 1 - z, x, L, W
    if steps == 2:
        return W - 1 - x, L - 1 - z, W, L
    return z, W - 1 - x, L, W


def convert(src: Path, dst: Path, orient: int = 0) -> None:
    nbt = nbtlib.load(str(src))
    root = nbt.root if hasattr(nbt, "root") else nbt

    # `size` may be either an int_array or a list — coerce.
    size = list(root["size"])
    if len(size) != 3:
        raise ValueError(f"expected size to have 3 entries, got {len(size)}")
    W, H, L = int(size[0]), int(size[1]), int(size[2])

    palette_raw = list(root["palette"])
    palette_entries: list[tuple[str, dict[str, str]]] = []
    for entry in palette_raw:
        name = str(entry["Name"])
        props: dict[str, str] = {}
        if "Properties" in entry:
            for k, v in entry["Properties"].items():
                props[str(k)] = str(v)
        if orient:
            props = transform_properties(props, orient)
        palette_entries.append((name, props))

    # Apply rotation to size; cells are rotated as they're placed below.
    _, _, rotW, rotL = rotate(0, 0, W, L, orient)

    # Dense grid sized to the *rotated* footprint.
    grid = [[[0] * rotL for _ in range(H)] for _ in range(rotW)]

    for b in root["blocks"]:
        state = int(b["state"])  # 0-indexed into palette
        pos = list(b["pos"])
        x, y, z = int(pos[0]), int(pos[1]), int(pos[2])
        if not (0 <= x < W and 0 <= y < H and 0 <= z < L):
            sys.stderr.write(
                f"warning: block at ({x},{y},{z}) outside size ({W},{H},{L}) — skipping\n"
            )
            continue
        rx, rz, _, _ = rotate(x, z, W, L, orient)
        grid[rx][y][rz] = state + 1  # Lua 1-based

    # Use the rotated dimensions for emit.
    W, L = rotW, rotL

    # Lua emit
    with dst.open("w", encoding="utf-8") as f:
        f.write(f"-- Auto-generated from {src.name} by tools/schematic_to_lua.py\n")
        f.write(f"-- Size: {W} (W) × {H} (H) × {L} (L)\n")
        f.write(f"-- Palette entries: {len(palette_entries)}\n")
        f.write("return {\n")
        f.write(f"    size = {{ width = {W}, height = {H}, length = {L} }},\n")
        f.write("    palette = {\n")
        for i, (name, props) in enumerate(palette_entries, start=1):
            if not props:
                f.write(f"        [{i}] = {lua_string(name)},\n")
            else:
                prop_pairs = ", ".join(
                    f"{k} = {lua_string(v)}" for k, v in props.items()
                )
                f.write(
                    f"        [{i}] = {{ name = {lua_string(name)}, "
                    f"properties = {{ {prop_pairs} }} }},\n"
                )
        f.write("    },\n")
        f.write("    layers = {\n")
        for y in range(H):
            f.write(f"        -- y = {y}\n")
            f.write("        {\n")
            for z in range(L):
                row = [grid[x][y][z] for x in range(W)]
                f.write(f"            {{ {', '.join(str(c) for c in row)} }},\n")
            f.write("        },\n")
        f.write("    },\n")
        f.write("}\n")

    orient_label = orient * 90
    n_oriented = sum(1 for _, p in palette_entries if p)
    print(
        f"wrote {dst} — {W}×{H}×{L} = {W*H*L} cells, "
        f"{len(palette_entries)} palette entries "
        f"({n_oriented} with properties), rotated {orient_label}° CW"
    )


def main() -> None:
    argv = sys.argv[1:]
    positional: list[str] = []
    orient_steps = 0
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--orient":
            i += 1
            if i >= len(argv):
                sys.stderr.write("error: --orient requires a value (0/90/180/270)\n")
                sys.exit(1)
            orient_steps = parse_orient(argv[i])
        elif a.startswith("--orient="):
            orient_steps = parse_orient(a.split("=", 1)[1])
        elif a in ("-h", "--help"):
            sys.stdout.write(__doc__ or "")
            return
        else:
            positional.append(a)
        i += 1

    if len(positional) < 1:
        sys.stderr.write(
            "usage: schematic_to_lua.py <input.nbt> [output.lua] [--orient 0|90|180|270]\n"
        )
        sys.exit(1)
    src = Path(positional[0])
    if not src.exists():
        sys.stderr.write(f"error: {src} not found\n")
        sys.exit(1)
    dst = Path(positional[1]) if len(positional) >= 2 else src.with_suffix(".lua")
    convert(src, dst, orient=orient_steps)


if __name__ == "__main__":
    main()
