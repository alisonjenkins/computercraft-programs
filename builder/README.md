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

Each schema is a Lua table:

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
- A character in `palette` maps to a Minecraft item ID (`minecraft:` or modded). `nil` = leave air.
- Schema files live in `builder/schemas/`. Example: `5x5x3-shed.lua`.

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
