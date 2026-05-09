# Program ideas — Arkana Aeronautics

Pack-specific programs that exploit the active peripherals. Each entry lists required peripherals, key APIs, and a rough sketch — no full code.

## 1. Smelter v2

Generalise `smelter.lua` to multiple machine families and route status to a Create display.

- Peripherals: vanilla `furnace` / `blast_furnace` / `smoker` (`inventory`), one Sophisticated Storage chest as the input pool, one **CC:C Bridge `create_source`** for status output.
- APIs: `inventory.list/getItemDetail/pushItems`, `create_source.write`.
- Key change vs v1: auto-detect smeltables by **inspecting** what came out of slot 3 after one cycle and caching `input_name → smelts_to`. Drop the regex heuristic.
- Status line: `"SMELT: 3/4 active · 1248 done · queue 642"` on a Flap Display.

## 2. Train control panel

Monitor + chat-driven train dispatch.

- Peripherals: one or more Create **Train Station** peripherals (over wired modem), `monitor` (4×3+ tile), `chat_box`, `player_detector` for auth.
- APIs: `Station.getSchedule/setSchedule/hasTrain/getTrainName`, `chat_box.sendMessage` + `chat` event, `player_detector.isPlayerInRange`.
- UI: list of stations with current train + ETA; chat command `!dispatch <station> <train>` gated by player whitelist; broadcast on `chat_box` when a train arrives.

## 3. Cannon battery fire-control

Big Cannons assembly plus targeting.

- Peripherals: `redstone_relay` for fire trigger + reload pulses, `block_reader` aimed at the elevation/yaw indicator, `geo_scanner` for terrain inspection at the target, `monitor` + `Scroller Pane` for gunner UI.
- APIs: `redstone_relay.setOutput`, `block_reader.getBlockStates`, `geo_scanner.scan`.
- UI: scroll wheel adjusts elevation; dial in target coords; computer solves a parabolic ballistic, drives elevation servos via `redstone_relay`, fires.

## 4. Airship status HUD

For a Sable / Aeronautics contraption — onboard CC computer + AR HUD.

- Peripherals: `ar_controller` (with AR Goggles), `environment_detector`, `geo_scanner`, Create `Speedometer` and `Stressometer` if mounted on the contraption.
- APIs: `ar_controller.drawString/drawCircle/setRelativeMode`, `environment_detector.getDimension/getBlockLightLevel`, `Speedometer.getSpeed`, `Stressometer.getStress`.
- HUD: altimeter, heading (Y if airship), nearby entities (`environment_detector.scanEntities`), SU draw, RPM.

## 5. Chat-driven storage pull

Voice-of-god item retrieval from a Sophisticated Storage network.

- Peripherals: `chat_box`, `inventory_manager` (with a Memory Card linked to the requesting player), one or more `inventory`-wrapped storage chests on the same network.
- APIs: `chat` event, `chat_box.sendMessageToPlayer`, `inventory_manager.addItemToPlayer`.
- Protocol: chat `!give <item> <count>` → search storage chests for matching `name` (use `getItemDetail` for tags / `c:ingots`-style filters) → `pushItems` into a buffer chest adjacent to the inventory manager → `addItemToPlayer("up", { name=…, count=… })`.

## 6. Geo prospector turtle

Geoscanning Turtle that maps ore hot-spots.

- Peripherals (on-turtle): `geo_scanner` upgrade.
- Peripherals (offboard): `nbt_storage` to record finds, GPS host array (≥4 wireless modems running `gps host …`).
- APIs: `gps.locate`, `geo_scanner.scan(8)`, `nbt_storage.writeTable`, `turtle.forward/up/down`.
- Pattern: serpentine grid with periodic `gps.locate()` resync; for each scan, count ores by `tags["c:ores"]`; dump `{x,y,z, counts}` rows to NBT Storage. A separate computer polls the storage and renders a heatmap on a monitor.

## 7. Factory dashboard

Wall-of-flap-displays for the Create base.

- Peripherals: 1+ `energy_detector` per relevant FE line (Create: New Age generators, machine clusters), 1+ `Stressometer` per kinetic axis, multiple **CC:C Bridge `create_source`** blocks pointing at Flap Display arrays.
- APIs: `energy_detector.getTransferRate`, `Stressometer.getStress`, `create_source.write`.
- Layout: top row FE in/out and net; middle row SU per axis; bottom row ticker of recent crafts pulled from a side-channel rednet topic.

## 8. Door / lock system

Whitelisted door with audit log.

- Peripherals: `player_detector` (range covers approach), `redstone_relay` (drives the door), `chat_box` (broadcast denials + log), `nbt_storage` (whitelist persistence).
- APIs: `playerClick` event, `player_detector.getPlayer`, `redstone_relay.setOutput`, `chat_box.sendMessage`, `nbt_storage.read/writeTable`.
- Flow: on `playerClick`, check whitelist in NBT Storage → if allowed, pulse `redstone_relay` to open; else `chat_box.sendMessage` "Denied: <user>" and log to the storage.

## 9. GPS constellation

Boilerplate but pack-relevant for any of the above.

- 4+ Advanced Computers on tall towers, each with a wireless modem, each running `gps host <x> <y> <z>` with their actual coordinates.
- Hosts must be non-coplanar — vary altitudes and horizontal positions.
- Use ender modem GPS hosts to extend cross-dimension coverage if needed.

## 10. Big Cannons munition autoloader

Pair an autoloader controller with cannon (#3) for a sustained-fire battery.

- Peripherals: `inventory`-wrapped Sophisticated Storage barrel (powder + projectile), `redstone_relay` for ramming/loading sequence, `chat_box` for low-ammo alerts.
- APIs: `inventory.pushItems` to a Big Cannons loader block, `redstone_relay.setOutput` with timed pulses for ram strokes, `chat_box.sendMessage` on `<5%` ammo.
