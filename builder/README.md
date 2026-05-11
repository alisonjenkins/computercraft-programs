# Builder turtle

Plain turtle places blocks layer-by-layer from a Lua schema. No diamond tools required.

## Hardware

| Item | Qty | Note |
|---|---|---|
| Plain Turtle | 1 | No upgrades needed for placing |
| Sophisticated Storage Chest | 1 | Supply chest, ABOVE the turtle's start position |
| (optional) Floppy Disk + Disk Drive | 1 | Easier to load schemas |

## Layout

```
   ┌──────────┐
   │  supply  │   ← chest with all build materials inside
   │   chest  │
   └──────────┘
        │ above turtle
   ┌──────────┐
   │  TURTLE  │   ← spawn point, facing the build direction
   └──────────┘
        ▼
   build region — turtle moves into XZ plane and lays blocks face-down
```

The turtle's facing at start = the row direction of layer rows. Layers are laid bottom-first; the turtle moves UP between layers and places blocks DOWNWARD onto the layer below.

## Schema format

`builder.lua` accepts **two formats**. The legacy hand-written format is easier to author; the NBT-derived format is what you get when converting a Create / Minecraft `.nbt` schematic.

### Format 1 — hand-written char-palette (legacy)

```lua
return {
    palette = {
        [" "] = nil,                       -- air
        ["C"] = "minecraft:cobblestone",
        ["P"] = "minecraft:oak_planks",
    },
    layers = {
        { "CCCCC", "CPPPC", "CPPPC", "CPPPC", "CCCCC" },  -- y = 0
        { "CCCCC", "C   C", "C   C", "C   C", "CCCCC" },  -- y = 1
        -- ...
    },
}
```

Rules:

- Each layer is a list of rows; each row is a string. Row count and row length must match across layers.
- A character in `palette` maps to a Minecraft item ID. `nil` = leave air.

### Format 2 — NBT-derived (from `.nbt` schematics)

```lua
return {
    size = { width = W, height = H, length = L },
    palette = {
        [1] = "minecraft:stone",
        [2] = "minecraft:oak_planks",
        -- ...
    },
    layers = {
        { { 1, 1, 2, 1 }, { 1, 0, 0, 1 }, ... },  -- y = 0, rows of palette indices
        -- ...
    },
}
```

Rules:

- `s.layers[y][z]` is a list of palette indices (1-based). `0` or out-of-palette = air.
- Schema files live in `builder/schemas/`. Either format works.

### Converting a `.nbt` schematic

`tools/schematic_to_lua.py` (on your Mac, not on the turtle) reads vanilla / Create schematic files and emits the format-2 Lua. Use this for builds you sketched out in-game with the schematic-and-quill or exported from a Create Schematic Table.

```
# one-time setup
pip install nbtlib

# convert a schematic
python3 tools/schematic_to_lua.py path/to/mywall.nbt builder/schemas/mywall.lua

# rotate around Y axis before emit (looking down, clockwise). Useful when the
# in-game placement direction doesn't match the turtle's facing at start.
python3 tools/schematic_to_lua.py mywall.nbt builder/schemas/mywall.lua --orient 90
```

Then push the resulting `.lua` to GitHub (the installer fetches files from raw GitHub) or copy directly onto the turtle's `builder/schemas/` directory via `wget` / floppy disk.

**What's preserved:**

- **Horizontal `facing`** for stairs, doors (lower half), repeaters, comparators, observers, chests, furnaces, hoppers pointed at a cardinal direction. The converter records the property in the palette entry; the builder turns the turtle to the opposite cardinal before `placeDown` so the placed block ends up with the right facing.
- Other blockstate fields (`shape`, `waterlogged`, `power`, etc.) are recorded but the turtle has no way to honour them — `shape` for stairs ("inner/outer corner") auto-resolves from neighbour blocks once placed.

**Still dropped / broken:**

- **Axis-based blocks** (logs / pillars / chains with `axis = x` or `axis = z`) — the turtle places from above with `placeDown`, which always gives `axis = y`. Use placeable filler blocks if axis matters.
- **Top half slabs** (`half = top`) — `placeDown` always produces bottom half. The whole geometry would need to flip (place from below with `placeUp`).
- **Tile entities** (chest contents, sign text, banner patterns) — block placed, contents empty.
- **Double-block placements** (beds, doors, tall flowers, pistons-with-arm-out) — only the lower half is placed.
- **Entities** in the schematic — skipped.

For complex builds, the schematic is best treated as a structural skeleton — fire the turtle for walls / floors / ceilings / stair runs, then decorate by hand or fire the rest with a Create Schematicannon (which preserves everything but eats more materials per tick).

## Setup

1. Build a chest one block above the turtle. Stock it with all required materials in any slot order. Include enough fuel (coal / planks / logs) to refuel mid-build.
2. Copy files to the turtle:
   ```
   /lib/inv.lua
   /lib/log.lua
   /builder/builder.lua
   /builder/schemas/<your-schema>.lua
   ```
3. From the turtle's shell:
   ```
   builder/builder.lua builder/schemas/5x5x3-shed.lua
   ```

The turtle will:

1. `suckUp` from the supply chest to top up materials.
2. Refuel if below 64 fuel.
3. Walk through each layer placing blocks face-down. Snake pattern: row 1 left→right, row 2 right→left, etc.
4. Move UP between layers.
5. Print progress and stop with `done`.

If a material runs out mid-layer, the turtle prints an error and tries to `restockFromSupply` (calls `suckUp` again — which only works if the turtle happens to be under the chest). For now, **stage all materials in the supply chest before starting** to avoid mid-build restocks. A future version will return to the start position before restocking.

## Limits / known gaps

- No GPS — schemas are placed relative to the turtle's start position.
- No diagonal moves.
- Mid-build restock only works at the start position; for now ensure enough materials up-front.
- No `place` (forward) — only `placeDown`. Schemas are read top-down.
- No undo — if you stop mid-build, the turtle leaves the half-built structure in place.
- No backtrack-to-start orientation on completion.
