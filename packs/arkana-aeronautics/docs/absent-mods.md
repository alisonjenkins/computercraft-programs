# Absent mods — what we can't do here

**Status in this pack:** Reference. These are mods CC programs *commonly* assume but that are **not** in this pack. Each lists the workaround.

## Plethora Peripherals

Status: **Not present.** No 1.21.x release exists. The Fabric port stops at 1.20.1.

Replacement in this pack: most Plethora features re-implemented by **Advanced Peripherals**:

| Plethora module | AP equivalent |
|---|---|
| Block scanner | `block_reader` + `geo_scanner` |
| Sensor (entities) | `environment_detector.scanEntities(range)` |
| Manipulator chat | `chat_box` |
| Player introspection | `player_detector` + `inventory_manager` |
| Laser / kinetic | (no replacement) |

## Computronics

Status: **Not present.** Only goes up to 1.12.2.

Replacement: AP smart turtles + UnlimitedPeripheralWorks would have covered most uses, but UPW is also absent in 1.21.1 (see below).

## UnlimitedPeripheralWorks (SirEdvin)

Status: **Not present** for 1.21.1. Last release is 1.20.1.

What we'd lose: vanilla-block-as-peripheral wraps (Beacon, Jukebox, Note Block, Lectern, Powered Rail), and integrations with Tom's Simple Storage / Lifts / Easy Villagers / Integrated Dynamics.

Replacement: the generic `inventory` / `fluid_storage` / `energy_storage` auto-wrap covers the bulk of "interact with a vanilla/modded block" use cases. For Lectern / Note Block / Jukebox specifically — no clean replacement; use a redstone-driven pulse via `redstone_relay` + a vanilla noteblock if you want sound.

## Turtlematic

Status: **Not present** for 1.21.1.

What we'd lose: extra turtle upgrades (combat, sweeping, magnet). Replacement: AP smart turtles + standard turtle inventory ops.

## Create: Computing (SaschaT)

Status: **Not present.** Last release is 1.18.2 Forge.

What we'd lose: Train Network Observer (graph of tracks, signals, ETAs).

Replacement: build it yourself. Each Train Station exposes the train present at it via Create's native CC integration; aggregate over all stations on a wired modem network with rednet.

## AE2 — Applied Energistics 2

Status: **Not in pack.**

What we'd lose: AP's `me_bridge` peripheral (craftItem, listItems, exportItem, etc.) is dead weight here.

Replacement: **Sophisticated Storage** + a CC controller program. Less polished than AE2 autocrafting but workable for simple "ensure ≥ N of X" stocking.

## Refined Storage

Status: **Not in pack.** AP's `rs_bridge` is inert.

Replacement: same as AE2 — Sophisticated Storage + custom logistics.

## Mekanism

Status: **Not in pack.** AP's Mekanism telemetry is inert. `environment_detector.getRadiation()` returns `nil`.

What we'd lose: the entire `cc-mek-scada` reactor SCADA program family.

Replacement: for fission-style power, **Create: New Age** is the in-pack equivalent (FE generation). Read its FE output with the AP `energy_detector`.

## MineColonies

Status: **Not in pack.** AP's `colony_integrator` is inert.

Replacement: none. If you want a settler-management UI, do it manually with `chat_box` + `player_detector`.

## Quick check before assuming a peripheral exists

```lua
print(peripheral.getNames())                 -- list all attached
print(peripheral.find("the_type_string"))    -- nil if absent
```

If a tutorial says "place an X next to the modem and `peripheral.find("y")`," and `find` returns `nil`, that mod is absent — re-route via this doc's tables.
