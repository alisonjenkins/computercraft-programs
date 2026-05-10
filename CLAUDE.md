# computercraft-programs

Lua programs for ComputerCraft (CC: Tweaked) computers and turtles, target specific Minecraft modpacks.

## Per-pack reference docs

Peripheral surface depends on mods loaded. Tracked per pack under `packs/<pack-name>/docs/`. Before writing/modifying program, **read pack's `docs/index.md` first** — routes to right page (CC:T core, addons, storage, etc.) and flags inert peripherals.

Tracked packs:

- **`packs/arkana-aeronautics/`** — Arkana Aeronautics (Create-focused), MC 1.21.1 NeoForge. See `packs/arkana-aeronautics/README.md` for versions, `packs/arkana-aeronautics/docs/index.md` for API surface.

## Pack source of truth

Pack contents not vendored here. Live at `../nix-config/pkgs/create-arkana-aeronautics-server/` (paths relative to parent dir). On pack bump, update:

1. `packs/<pack>/README.md` — version table.
2. Any doc pinning version-sensitive detail (e.g. AP type-string casing changed in 1.21.1).

Diff against upstream `overlays.nix` and `arkana-mods.nix` = fastest way spot changes.

## Programs

Each program own directory with `README.md` + entry-point Lua file. Bootstrap onto CC computer with `install.lua` (below).

- **`smelter.lua`** (root) — vanilla furnace auto-feeder. Original worked example.
- **`treefarm/`** — `monitor.lua` watches Create-saw farm, alerts on jam / low saplings via chat box.
- **`storage/`** — `controller.lua` indexes chest network, serves chat-driven `!give` / `!find` / `!list`.
- **`builder/`** — `builder.lua` runs on plain turtle, places blocks layer-by-layer from `schemas/*.lua`.
- **`mining/`** — three turtle programs sharing `pos.lua` / `state.lua` / `filter.lua`:
  - `miner.lua` — branch mining (smart 1×1 default, `--tall` for 1×3 walkable), auto-refuel, vein follow, resume across reboots.
  - `digdown.lua` — vertical 1×1 ladder shaft, lava/water aware (plug + dig).
  - `room.lua` — layer-by-layer rectangular-room excavator. State tagged `program="room"` so can't collide with `miner.lua` saves.
- **`lib/`** — shared helpers: `inv.lua` (inventory ops), `log.lua` (chat + monitor + term sink).

Each program's `README.md` lists exact peripherals expected (by type string, snake_case for 1.21.1) and in-game wiring required.

New program: target specific pack; declare in header comment which peripherals wrapped; mirror directory layout when copying onto in-game computer (`/lib/inv.lua`, `/<program>/<entry>.lua`).

## Installer (`install.lua`)

`install.lua` = single-file bootstrap. Fetches program files from HTTP source (default: this repo on GitHub raw), writes to correct paths on CC computer. Re-runs idempotent — files overwritten.

```text
# in-game on the CC computer:
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua storage
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua --autostart storage

# or, if hosted on pastebin:
pastebin run <id> storage
```

Installer-known programs: `storage`, `treefarm`, `builder`, `smelter`, `mining` (bundles `miner.lua` + `digdown.lua` + `room.lua` + shared `mining/{pos,state,filter}.lua`). File manifest per program in `PROGRAMS` table at top of `install.lua` — adding new program, add entry there.

`--autostart <program>` writes `/startup.lua` so program runs every boot.

Adding new program directory: update `install.lua`'s `PROGRAMS` and `AUTOSTART_ENTRY` tables, push change so `wget` sees new files.

## Style

Reference docs in `packs/*/docs/` = quick-reference cards, not tutorials. Each page leads with one-line **Status in this pack:** tag, links upstream for full story. Method signatures in fenced `lua` blocks. Peripheral type strings always quoted (`"player_detector"`).

## Methodology

`docs/methodology.md` documents pack-agnostic workflow for building `packs/<pack>/docs/`: identify mods from `nix-config`, extract recipes from mod JARs (`unzip -p <jar> data/<modid>/recipe/<name>.json`), discover peripheral surfaces from upstream docs vs in-game `peripheral.getMethods`, refresh on pack bump. Read before adding new pack or refreshing stale one.