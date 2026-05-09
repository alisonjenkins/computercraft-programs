# Arkana Aeronautics — CC reference index

**Status in this pack:** Active. CC: Tweaked 1.118.0 + Advanced Peripherals 0.7.61b + CC:C Bridge 1.7.2 on MC 1.21.1 NeoForge.

## What's the surface?

Programs in this pack can use:

- **CC: Tweaked core** — full standard Lua API (`fs`, `peripheral`, `redstone`, `rednet`, `http`, `term`, `parallel`, `textutils`, `gps`, `vector`, `settings`, `os`, …) plus the `cc.*` require'd libs.
- **Built-in CC:T peripherals** — computer, monitor, modem (wired/wireless/ender), drive, printer, speaker, command, and the new **redstone_relay**.
- **Generic auto-wrapped peripherals** — most modded blocks expose `inventory` / `fluid_storage` / `energy_storage` types automatically. This is how Sophisticated Storage chests, vanilla furnaces, and most Create blocks become callable from Lua without a dedicated integration.
- **Advanced Peripherals** — block peripherals (`player_detector`, `chat_box`, `energy_detector`, `block_reader`, `geo_scanner`, `environment_detector`, `inventory_manager`, `nbt_storage`, `ar_controller`) plus smart turtle upgrades.
- **CC:C Bridge** — Create ↔ CC blocks (`create_source`, `create_target`, RedRouter, Scroller Pane, Animatronic) and Create-side display targets (Flap Display, Nixie Tubes, Lectern, Sign).
- **Create native CC integration** — Train Station, Display Link, Rotation Speed Controller, Sequenced Gearshift, Speedometer, Stressometer.

## Naming-convention note

Advanced Peripherals switched type strings from camelCase to snake_case **at MC 1.21.1**. This pack is 1.21.1 → use `"player_detector"`, not `"playerDetector"`. Tutorials online from before 2025 may use the old names.

## Routing — "I want to…"

| Intent | File |
|---|---|
| Read/write items in a chest, barrel, vault, drawer | `cc-tweaked-generic.md`, `storage-and-inventories.md` |
| List the standard Lua APIs / which `cc.*` libs exist | `cc-tweaked.md` |
| Drive a monitor, speaker, printer, drive, modem | `cc-tweaked-peripherals.md` |
| Run redstone over a wired modem network | `cc-tweaked-peripherals.md` (redstone_relay) |
| Use rednet, websockets, http, GPS | `cc-tweaked-networking.md` |
| Move/dig/place/inspect with a turtle | `cc-tweaked-turtle.md` |
| Detect a player or react to chat | `advanced-peripherals.md` (player_detector, chat_box) |
| Measure FE flow, scan blocks, scan ores, read environment | `advanced-peripherals.md` |
| Persist data across reboots in NBT | `advanced-peripherals.md` (nbt_storage) |
| Draw a HUD onto AR Goggles | `advanced-peripherals.md` (ar_controller) |
| Move items from/to the wearer's inventory | `advanced-peripherals.md` (inventory_manager) |
| Output redstone on more sides | `cc-tweaked-peripherals.md` (redstone_relay — Redstone Integrator was removed in AP 0.7.50b) |
| Push text onto a Create flip-display / nixie / sign | `cccbridge.md` (create_source) |
| Read live data from a Create stressometer/steam engine | `cccbridge.md` (create_target) or `create-native-cc.md` (Stressometer) |
| Scroll-wheel HID input | `cccbridge.md` (Scroller Pane) |
| Control a Create train | `create-native-cc.md` (Train Station) |
| Read SU / RPM | `create-native-cc.md` (Stressometer, Speedometer) |
| Drive a Display Link from CC | `create-native-cc.md` (Display Link) — note CC:C Bridge's create_source is usually nicer |
| Find out a peripheral I expected isn't here | `absent-mods.md` |
| Get program ideas for this pack | `program-ideas.md` |
| Look up a recipe (CC:T / AP / CC:C Bridge / Create / SS) | `recipes.md` |
| Set up rotational power (early game) | `power.md` |

## Upstream docs (linked, not mirrored)

- CC: Tweaked — https://tweaked.cc/
- Advanced Peripherals — https://docs.advanced-peripherals.de/latest/
- CC:C Bridge — https://cccbridge.kleinbox.dev/
- Create CC integration — https://wiki.createmod.net/ (search "ComputerCraft")
