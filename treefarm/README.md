# Tree farm monitor

CC computer that watches a Create-saw tree farm and alerts on jam / low saplings via Advanced Peripherals chat box.

## Hardware

| Block | Purpose | Source mod |
|---|---|---|
| Computer (basic) | Runs `monitor.lua`. Advanced only if pairing with a coloured monitor. | CC: Tweaked |
| Wired Modem (×4–5) | One on each peripheral block + one on the computer | CC: Tweaked |
| Network Cable | Connects everything (≥6 cable craft = 6 segments) | CC: Tweaked |
| Sophisticated Storage Chest | Output buffer (logs + saplings drop here) | Sophisticated Storage |
| Chat Box | Alerts | Advanced Peripherals |
| Redstone Relay (optional) | Jam-recovery clutch pulse | CC: Tweaked |
| Monitor (optional) | Status display | CC: Tweaked |
| Mechanical Saw | Cuts the tree | Create |
| Mechanical Bearing OR Rope Pulley | Drives the saw vertically | Create |
| Andesite Funnel (×2) | Pulls items into buffer chest | Create |
| Water Wheel | Power source | Create |
| Andesite Casing, Cogwheels, Shaft | Power transmission | Create |

See `packs/arkana-aeronautics/docs/recipes.md` for every recipe.

## Layout (one of the simpler patterns)

```
       [saw moves up/down on rope pulley or contraption]
       │
       │
       ▼
       ┌──────────┐
       │ tree     │
       │ (oak/    │   ← saplings 2x2
       │  spruce) │
       └──────────┘
            │ items fall
            ▼
   ┌─────────────────┐
   │ andesite funnel │ ← pulls items
   └─────────────────┘
            │
            ▼
   ┌─────────────────────────┐    ┌──────────┐
   │ Sophisticated Chest     │────│ wmodem   │── cable ── computer + chat_box (+relay) (+monitor)
   └─────────────────────────┘    └──────────┘
```

The exact saw-on-bearing pattern varies. Two common approaches:

1. **Rope pulley + saw** — saw mounted on the rope pulley's contraption arm; pulley descends + ascends on a redstone clock.
2. **Mechanical Bearing windmill saw** — saw on a bearing-driven horizontal arm that sweeps the tree.

Either way, the **CC computer doesn't drive the farm** — it observes the output chest. The Create rotation is just plumbing.

## Setup

1. Build the Create farm. Confirm logs + saplings end up in the buffer chest.
2. Place wired modems on:
   - the computer
   - the Sophisticated chest
   - the chat box
   - (optional) the redstone relay
   - (optional) the monitor
3. Right-click each modem to attach (red ring lights up).
4. Connect with network cable.
5. On the computer:
   - Copy `lib/inv.lua`, `lib/log.lua`, `treefarm/monitor.lua` to the computer's filesystem (via floppy disk, `wget`, or `pastebin`).
   - Mirror the directory layout: `lib/` and `treefarm/` at root.
   - Run `treefarm/monitor.lua`.
6. To auto-run on reboot, save a `startup.lua` with:
   ```lua
   shell.run("treefarm/monitor.lua")
   ```

## Tunables (in `monitor.lua`'s `CONFIG`)

| Key | Default | Effect |
|---|---|---|
| `buffer_name` | `nil` (auto) | Force a specific chest network name |
| `sample_period_s` | `1` | How often to poll buffer |
| `jam_threshold_s` | `300` | Seconds idle before "jammed" alert |
| `sapling_min` | `8` | Below this → "low saplings" alert |
| `relay_side` | `"front"` | Which side of the relay pulses the clutch |
| `relay_pulse_s` | `1.0` | Pulse duration |

## What it does NOT do

- Doesn't restock saplings — the farm's funnel/dispenser logic should keep itself fed (or drop saplings into the buffer; the farm pulls them back in).
- Doesn't break the contraption to fix a jam. The relay pulse just disengages a clutch; you still need to walk over and check on serious failures.
- No automatic crafting of charcoal — pair with `smelter.lua` (slot the buffer's logs into the smelter's input chest) for fuel production.
