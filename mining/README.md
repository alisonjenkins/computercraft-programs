# Mining turtle

Branch-mining turtle with auto-refuel, auto-return, vein follow, and resume across reboots.

## Hardware

| Item | Qty | Recipe |
|---|---|---|
| Mining Turtle | 1 | plain turtle (7 iron + chest + computer) → equip diamond pickaxe via crafting grid (1 turtle + 1 diamond pickaxe shapeless = mining turtle) |
| Diamond Pickaxe | 1 | 3 diamonds + 2 sticks (vanilla) |
| Sophisticated Storage Chest (or vanilla) ×2 | 2 | for dump (above) + fuel (below) |

Diamonds: **3** (the diamond pickaxe). Leaves you 1 spare diamond if you started with 4.

## Base layout

```
   ┌───────────────┐
   │  dump chest   │   ← items go here (dropUp)
   │   (above)     │
   └───────────────┘
          │
   ┌───────────────┐
   │   TURTLE      │   ← starts here, facing into the mine
   └───────────────┘
          │
   ┌───────────────┐
   │  fuel chest   │   ← coal / charcoal / logs (suckDown)
   │   (below)     │
   └───────────────┘
```

The turtle's *forward* direction at start = the direction the mine extends into. After it digs into the wall, that's the **main shaft** (north in turtle-relative coords).

## Mining pattern (branch mining)

```
plan view, looking down. T = turtle home. → = main shaft. ↑↓ = branches.
S = block-spaced spine.

         ↑↑↑↑↑↑↑↑   (branch left, length B)
         |
T → S → S → S → →→→→→→→→→→→→→→→  (main shaft, length L)
         |
         ↓↓↓↓↓↓↓↓   (branch right, length B)

         (next branch pair every 3 forward steps)
```

CLI:

```
mining/miner.lua <shaft_length> <branch_length> --start [--tall]
```

Example:

```
mining/miner.lua 64 8 --start
```

Mines a 64-block main shaft, with 8-block branches every 3 blocks (L+R). Total ≈ 64 + 22×8×2 = ~416 blocks dug per shaft.

**Corridor height** (flag at first run):

| Flag | Corridor | Fuel per advance | Ore-detection coverage | Use when |
|---|---|---|---|---|
| (default) | 1×1 | 2 (dig forward + move) | 4 perpendicular faces inspected per step | Pure ore-mining. Walking through afterwards means ducking; preferred for the turtle's own work. |
| `--tall`  | 1×3 | 4 (dig forward + dig up + dig down + move) | Same 4 faces (inspect runs before clear-out) | You want to walk through later — caves explore, run gear, lay rails. |

`--smart` is the default explicit alias.

**Mode swap mid-run:** running with `--tall` (or `--smart`) on a resume command overrides the saved mode without losing position or `shaft_progress`. Example: started in 1×1 default, change your mind, want walkable for the rest:

```
mining/miner.lua --tall
```

Continues from where it left off, but every subsequent advance is 1×3. No flag = keep the saved mode.

To **resume** after a reboot or interruption, omit `--start`:

```
mining/miner.lua
```

Saved state in `/.miner_state` carries `pos`, `facing`, `shaft_progress`, and the original `--start` args.

## Behaviour

- **Auto-refuel mid-mine.** When fuel ≤ 256, the turtle scans its inventory for any `refuel`-burnable item (coal, charcoal, log, lava bucket) and burns it.
- **Trash dump.** Every step, drops cobblestone, dirt, gravel, andesite/diorite/granite/tuff, netherrack, basalt, blackstone, end stone, smooth basalt, cobbled deepslate. Keeps stone, deepslate (block form), all `_ore` variants, raw metals, ancient debris, gilded blackstone, redstone, lapis, coal, diamonds, etc.
- **Vein mining.** When `inspect()` finds an ore on a wall / floor / ceiling, the turtle digs into the vein and follows it (DFS bounded to depth 16) before returning to the corridor.
- **Auto-return.** Goes home when:
  - Inventory is full AND no trash to dump, OR
  - Fuel level ≤ Manhattan-distance home + 64 (safety margin)
- **Dump + refuel at home.**
  - `dropUp()` everything that isn't fuel-burnable into the dump chest.
  - `suckDown()` from the fuel chest until fuel level ≥ 2048.
- **Resume.** Walks back to the last known shaft position and continues mining.
- **Stop.** When the shaft is complete, dumps a final time and clears state. Also stops if fuel chest empty + insufficient fuel for another round-trip.

## Recovery

If you break or move the turtle mid-run, the state file persists at `<world>/computercraft/computer/<id>/.miner_state`. Edit or delete to reset:

```
delete /.miner_state    # at the turtle's shell — forces fresh-start
```

If the turtle lost track of position (broken mid-move, world rollback), do **NOT** resume — you risk it walking into walls or skipping the corridor. Manually carry it back to start, run `delete /.miner_state`, then `mining/miner.lua <shaft> <branch> --start`.

## Companion: `room.lua` — flat-room excavator

Carves a rectangular room. Useful for bases, mob farms, storage halls.

### Hardware

Same chest layout as `miner.lua`: dump chest above the turtle, fuel chest below. Turtle starts at "home" — one block back from the room's near face. The room extends FORWARD from the turtle.

### CLI

```
mining/room.lua <length> <width> <height> --start [--left] [--up]
mining/room.lua                              # resume from saved state
```

Axes are turtle-relative at start:

- `length`: blocks **forward** (the direction the turtle faces).
- `width`: blocks **right** of the turtle. Use `--left` to sweep left instead.
- `height`: blocks **down** from start. Use `--up` to dig upward instead (room above the turtle).

So with no flags, the room sits forward + right + below. The turtle starts at the **front-top-left** corner (from the player's POV looking into the room). Place the turtle anywhere relative to the room you want; pick `--left` / `--up` to match.

Example — a 16×16×4 storage hall:

```
mining/room.lua 16 16 4 --start
```

### Behaviour

- **Layer-by-layer serpentine.** Mines the top layer first (length × width), then digs down (or up) one block, mines the next layer, etc.
- **Auto-refuel mid-excavation.** Same trigger as `miner.lua`: when fuel ≤ 256, refuels from any burnable in inventory.
- **Auto-return.** Returns home when inventory is full or fuel is too low to safely complete a return trip.
- **Dump + refuel at home.** dropUp's everything that isn't fuel-burnable, suckDown's from the fuel chest below.
- **Low-fuel polling.** If the fuel chest is empty AND the turtle's own inventory has no burnables, the turtle **pauses and polls** every 5 seconds. Drop coal/charcoal/logs into the turtle's GUI (right-click it) or top up the fuel chest below; the turtle resumes automatically once fuel ≥ 4096.
- **Lava-aware.** Like `digdown.lua`: places a plug block (cobblestone, dirt, etc. from inventory) before digging into a lava cell. Without a plug it stops rather than diving in.
- **Resume.** State persists at `/.miner_state` (tagged `program = "room"` so it can't be confused with the branch miner). Saved fields: `pos`, `args` (length/width/height/sweep_left/dig_up), `layer`, `col`, `col_progress`, `col_dir`. After a reboot, `mining/room.lua` (no args) walks back to the saved mining position and continues.
- **Stop.** When the final layer is done, dumps a final time and clears state.

### Limits

- **No vein-follow.** Rooms by definition mine every block — vein DFS would be wasted work. If you want ore yield, run `miner.lua` first; use `room.lua` for clearing space.
- **No mid-run dimension change.** Unlike `miner.lua`'s `--tall` swap, you can't resize the room mid-excavation. Delete `/.miner_state` and re-`--start` to change dimensions.
- **No GPS.** Same dead-reckoning caveats as `miner.lua`.

## Companion: `digdown.lua`

Sinks a 1×1 ladder shaft straight down. Useful for getting a turtle (or yourself) down to Y=-58 efficiently.

```
mining/digdown.lua <depth> [--no-ladders] [--seal-water]
```

- `<depth>` = blocks to descend. From surface Y=64 to Y=-58 → **depth = 122**.
- Default places one ladder per descent step (via `turtle.placeUp` into the cell the turtle just vacated). Vanilla auto-attaches the ladder to one of the four surrounding stone walls.
- `--no-ladders` skips ladder placement (just digs the shaft).
- `--seal-water` also plugs water on the side walls (off by default — water doesn't damage the turtle, but plugging keeps the shaft dry and reliable for ladders).
- **Lava-aware (always on):** if `inspectDown` finds lava, places a plug block (cobble / stone / dirt / gravel / deepslate / etc.) to replace it before digging. After each descent, checks all four side walls and plugs any lava found. Without a plug block in inventory the turtle stops rather than diving into lava.
- Mid-descent refuels from any burnable item in inventory.
- Pre-flight: stack of ladders + ~1 stack of plug blocks (any cheap stone) + fuel. From the storage system: `!give ladder 128` and `!give cobblestone 64`.
- Open-air sections (e.g. starting on a hill with no walls) → ladder placement fails for those blocks. Walk back up + manually fill the gap, or run the program from a 1×1 starter hole.

After it finishes, the turtle is at the bottom. Move it into your branch-mine starter chamber (carve a 3×3 room around the bottom of the shaft), set up the dump+fuel chests, then run `mining/miner.lua 64 8 --start`.

## Limits / known gaps

- **No GPS.** Position is dead-reckoning. If the turtle gets unloaded mid-step (rare on a dedicated server but possible during chunk reload), saved position can drift one block.
- **No obstacle pathing.** Return path assumes the branches and shaft remain clear after mining. If you backfill or a creeper blows up the corridor, the turtle digs through whatever's in the way (it has a pickaxe) but on big detours it may get confused.
- **Single Y level.** No vertical stairs / quarry mode. Branch mines at the Y you start at — pick Y=-58 for diamond yield.
- **Single turtle.** No fleet coordination.
- **One direction.** Doesn't pivot the spine — pick the right facing before `--start`.
- **Fuel chest must be a single chest.** Doesn't traverse a network.

## Install

After you've crafted the mining turtle, run on the turtle:

```
wget run "https://raw.githubusercontent.com/alisonjenkins/computercraft-programs/master/install.lua?cb=mining" mining
```

Then start mining:

```
mining/miner.lua 64 8 --start
```
