# computercraft-programs

Lua programs for ComputerCraft (CC: Tweaked) computers and turtles, targeted at specific Minecraft modpacks.

## Per-pack reference docs

The peripheral surface available to a CC program depends on which mods the server has loaded. We track that surface per pack under `packs/<pack-name>/docs/`. Before writing or modifying a program, **read the relevant pack's `docs/index.md` first** — it routes you to the right page (CC:T core, addons, storage, etc.) and flags which peripherals are inert in that pack.

Currently tracked packs:

- **`packs/arkana-aeronautics/`** — Arkana Aeronautics (Create-focused), MC 1.21.1 NeoForge. See `packs/arkana-aeronautics/README.md` for versions and `packs/arkana-aeronautics/docs/index.md` for the API surface.

## Pack source of truth

Pack contents are not vendored here. They live in `../nix-config/pkgs/create-arkana-aeronautics-server/` (paths are relative to this repo's parent dir). When the pack bumps, update:

1. `packs/<pack>/README.md` — version table.
2. Any doc that pins a version-sensitive detail (e.g. AP type-string casing changed in 1.21.1).

A diff against the upstream `overlays.nix` and `arkana-mods.nix` is the fastest way to spot what changed.

## Programs

Each program lives in its own directory with a `README.md` and entry-point Lua file. Bootstrap any program onto a CC computer with `install.lua` (see below).

- **`smelter.lua`** (root) — vanilla furnace auto-feeder. Original worked example.
- **`treefarm/`** — `monitor.lua` watches a Create-saw farm, alerts on jam / low saplings via chat box.
- **`storage/`** — `controller.lua` indexes a chest network, serves chat-driven `!give` / `!find` / `!list`.
- **`builder/`** — `builder.lua` runs on a plain turtle, places blocks layer-by-layer from `schemas/*.lua`.
- **`mining/`** — three turtle programs sharing `pos.lua` / `state.lua` / `filter.lua`:
  - `miner.lua` — branch mining (smart 1×1 default, `--tall` for 1×3 walkable), auto-refuel, vein follow, resume across reboots.
  - `digdown.lua` — vertical 1×1 ladder shaft, lava/water aware (plug + dig).
  - `room.lua` — layer-by-layer rectangular-room excavator. State tagged `program="room"` so it can't collide with `miner.lua` saves.
- **`lib/`** — shared helpers: `inv.lua` (inventory ops), `log.lua` (chat + monitor + term sink).

Each program's `README.md` lists the exact peripherals it expects (by type string, snake_case for 1.21.1) and the in-game wiring required.

When writing a new program: target a specific pack; declare in a header comment which peripherals you wrap; mirror the directory layout when copying onto the in-game computer (`/lib/inv.lua`, `/<program>/<entry>.lua`).

## Installer (`install.lua`)

`install.lua` is a single-file bootstrap that fetches a program's files from an HTTP source (default: this repo on GitHub raw) and writes them to the correct paths on the CC computer. Re-runs are idempotent — files are overwritten.

```text
# in-game on the CC computer:
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua storage
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua --autostart storage

# or, if hosted on pastebin:
pastebin run <id> storage
```

Programs known to the installer: `storage`, `treefarm`, `builder`, `smelter`, `mining` (bundles `miner.lua` + `digdown.lua` + `room.lua` + the shared `mining/{pos,state,filter}.lua`). Manifest of files per program lives in the `PROGRAMS` table at the top of `install.lua` — when adding a new program, add an entry there.

`--autostart <program>` writes a `/startup.lua` so the program runs on every boot.

When adding a new program directory: update `install.lua`'s `PROGRAMS` and `AUTOSTART_ENTRY` tables, then push the change so `wget` sees the new files.

## Style

Reference docs in `packs/*/docs/` are quick-reference cards, not tutorials. Each page leads with a one-line **Status in this pack:** tag and links upstream for the full story. Method signatures live in fenced `lua` blocks. Peripheral type strings are always quoted (`"player_detector"`).

## Methodology

`docs/methodology.md` documents the pack-agnostic workflow used to build `packs/<pack>/docs/`: identifying mods from `nix-config`, extracting recipes directly from mod JARs (`unzip -p <jar> data/<modid>/recipe/<name>.json`), discovering peripheral surfaces from upstream docs vs in-game `peripheral.getMethods`, and refreshing when a pack bumps. Read this before adding a new pack or refreshing a stale one.
