# Create — native CC:T integration

**Status in this pack:** Active. Comes with Create itself (6.0.10 in this pack) — no addon needed.

Upstream docs: https://wiki.createmod.net/ (search "ComputerCraft"). The legacy GitHub wiki has been migrated; expect the wiki URL to be the live source.

## Caveat for this card

Create 6.x slightly renamed some things vs 5.x and the new wiki rendering occasionally hides the API pages from scrapers. **Use `peripheral.getMethods(name)` in-game to confirm exact signatures.** Method names listed below match the historical Create wiki and known references; treat them as a starting point.

## Train Station

The flagship Create-CC integration. Lets you read trains, dispatch schedules, and read live train state.

Common methods (verify in-game):

```lua
isInAssemblyMode() -> bool
getStationName() -> string  setStationName(name)
hasTrain() -> bool
getTrainName() -> string|nil   setTrainName(name)
getTrainOwner() -> uuid|nil
getSchedule() -> table|nil  setSchedule(schedule)
                                          -- schedule shape mirrors the in-game schedule item NBT
assemble()                                -- assemble a stationary train
disassemble()
```

For the schedule format, dump an existing one with `textutils.serialiseJSON(getSchedule())` and use it as a template.

## Display Link

Bridges Create *information sources* (Stressometer, Speedometer, Steam Engine, fluid gauge, …) to display targets. Without CC, it's a passive bridge. With CC, you can drive it programmatically — but in this pack **CC:C Bridge's `create_source` block is usually nicer** because it gives you direct terminal-like writes.

If you do want the Display Link directly: `peripheral.getMethods` it; the API is small (it's basically a write target).

## Rotation Speed Controller

Sets / reads the configured rotation speed of the kinetic network it sits on.

```lua
getTargetSpeed() -> int                  -- RPM
setTargetSpeed(rpm)                       -- -256..256
```

Useful for spinning up gantries / mechanical arms on demand.

## Sequenced Gearshift

Programmable gear with a queue of timed rotation steps.

```lua
rotate(angle, modifier)                   -- angle in degrees, modifier scales speed
move(distance, modifier)                  -- in blocks (for translation contraptions)
isRunning() -> bool
```

Behaviour mirrors the in-game scroll-configurable instructions; consult the wiki for the exact instruction set in 6.x.

## Speedometer

Read-only kinetic-RPM probe.

```lua
getSpeed() -> int                         -- RPM, signed
```

## Stressometer

Read-only stress-units probe — useful for dashboards.

```lua
getStress() -> number                     -- current SU usage
getStressCapacity() -> number             -- network capacity
```

## Patterns

**SU dashboard via Stressometer + Display Link:**

```lua
local sm = peripheral.wrap("create:stressometer_0")
local src = peripheral.find("create_source")
while true do
  local pct = sm.getStress() / sm.getStressCapacity() * 100
  src.clear(); src.setCursorPos(1,1)
  src.write(("SU %d%%"):format(pct))
  sleep(1)
end
```

**Auto-dispatch a train when a player is on the platform:**

```lua
local pd = peripheral.find("player_detector")
local st = peripheral.find("Create:track_station") -- name varies; check getNames()
while true do
  if st.hasTrain() and pd.isPlayersInRange(3) then
    -- assemble a "depart" schedule, or release the brake redstone
  end
  sleep(0.5)
end
```
