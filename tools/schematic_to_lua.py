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
    python3 tools/schematic_to_lua.py path/to/schematic.nbt [output.lua]
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


def convert(src: Path, dst: Path) -> None:
    nbt = nbtlib.load(str(src))
    root = nbt.root if hasattr(nbt, "root") else nbt

    # `size` may be either an int_array or a list — coerce.
    size = list(root["size"])
    if len(size) != 3:
        raise ValueError(f"expected size to have 3 entries, got {len(size)}")
    W, H, L = int(size[0]), int(size[1]), int(size[2])

    palette_raw = list(root["palette"])
    palette_names: list[str] = []
    for entry in palette_raw:
        name = str(entry["Name"])
        palette_names.append(name)

    # Dense grid: grid[x][y][z] = 1-based palette index. 0 = empty (air).
    grid = [[[0] * L for _ in range(H)] for _ in range(W)]

    for b in root["blocks"]:
        state = int(b["state"])  # 0-indexed into palette
        pos = list(b["pos"])
        x, y, z = int(pos[0]), int(pos[1]), int(pos[2])
        if not (0 <= x < W and 0 <= y < H and 0 <= z < L):
            sys.stderr.write(
                f"warning: block at ({x},{y},{z}) outside size ({W},{H},{L}) — skipping\n"
            )
            continue
        grid[x][y][z] = state + 1  # Lua 1-based

    # Lua emit
    with dst.open("w", encoding="utf-8") as f:
        f.write(f"-- Auto-generated from {src.name} by tools/schematic_to_lua.py\n")
        f.write(f"-- Size: {W} (W) × {H} (H) × {L} (L)\n")
        f.write(f"-- Palette entries: {len(palette_names)}\n")
        f.write("return {\n")
        f.write(f"    size = {{ width = {W}, height = {H}, length = {L} }},\n")
        f.write("    palette = {\n")
        for i, name in enumerate(palette_names, start=1):
            f.write(f"        [{i}] = {lua_string(name)},\n")
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

    print(
        f"wrote {dst} — {W}×{H}×{L} = {W*H*L} cells, {len(palette_names)} palette entries"
    )


def main() -> None:
    if len(sys.argv) < 2:
        sys.stderr.write(
            "usage: schematic_to_lua.py <input.nbt> [output.lua]\n"
        )
        sys.exit(1)
    src = Path(sys.argv[1])
    if not src.exists():
        sys.stderr.write(f"error: {src} not found\n")
        sys.exit(1)
    dst = Path(sys.argv[2]) if len(sys.argv) >= 3 else src.with_suffix(".lua")
    convert(src, dst)


if __name__ == "__main__":
    main()
