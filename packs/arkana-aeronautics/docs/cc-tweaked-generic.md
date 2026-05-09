# CC: Tweaked — generic peripherals (auto-wrap)

**Status in this pack:** Active. The single most important integration in this pack — it makes Sophisticated Storage chests, vanilla furnaces, and most Create item/fluid/energy blocks work without an addon.

Upstream: https://tweaked.cc/generic_peripheral/

## How it works

Any block that exposes Forge/NeoForge capabilities (item handler, fluid handler, FE energy handler) is auto-wrapped by CC:T. A single block can be all three types simultaneously. The block name shows up as the peripheral name; the methods come from the capabilities it exposes.

Detect by capability, not by mod-specific name:

```lua
local chest = peripheral.find("inventory")
peripheral.hasType("sophisticatedstorage:chest_0", "inventory") -- true
local types = peripheral.getType("minecraft:furnace_0")
-- e.g. { "minecraft:furnace", "inventory" }
```

## `inventory`

```lua
size() -> int
list() -> { [slot]: { name, count, ... } }            -- sparse table
getItemDetail(slot) -> table|nil                       -- name, count, displayName, tags, nbt, durability, …
getItemLimit(slot) -> int
pushItems(toName, fromSlot[, limit[, toSlot]]) -> int  -- moved
pullItems(fromName, fromSlot[, limit[, toSlot]]) -> int
```

`toName` / `fromName` are network names obtainable via `peripheral.getName(p)`. Both ends must be reachable on the same wired-modem network for cross-block transfer.

`smelter.lua` in this repo is a worked example — it uses `peripheral.wrap("sophisticatedstorage:chest_0")`, `chest.list()`, and `chest.pushItems(furnace_name, slot, count, target_slot)`.

## `fluid_storage`

```lua
tanks() -> { { name, amount, ...nbt } }                -- amount in mB
pushFluid(toName[, limit[, fluidName]]) -> int         -- mB moved
pullFluid(fromName[, limit[, fluidName]]) -> int
```

Works on Create fluid tanks, fluid pipes, sinks, etc.

## `energy_storage`

```lua
getEnergy() -> int            -- FE
getEnergyCapacity() -> int
```

Read-only — energy moves via cables, not Lua. For *flow-rate* monitoring use Advanced Peripherals' `energy_detector` block as a resistor in the cable line.

## Worked patterns

**Find every chest on the network:**

```lua
for _, p in ipairs({ peripheral.find("inventory") }) do
  print(peripheral.getName(p), p.size())
end
```

**Move all items of a name from chest to chest:**

```lua
local from, to = peripheral.wrap("a"), peripheral.wrap("b")
local toName = peripheral.getName(to)
for slot, item in pairs(from.list()) do
  if item.name == "minecraft:iron_ingot" then
    from.pushItems(toName, slot)
  end
end
```

**Filter by tag** (CC:T exposes tags via `getItemDetail`):

```lua
local detail = chest.getItemDetail(1)
if detail and detail.tags["c:ores"] then ... end
```

## Caveats

- `list()` is sparse — iterate with `pairs`, not `ipairs`.
- `pushItems` returns 0 if the destination is full; check the return value.
- Generic methods do NOT include slot reservations / locks; two computers hitting the same chest can race.
- Some Create blocks have multiple item handlers (e.g. ingredient + result); the generic wrap exposes the *primary* one. Use a Create-specific wrapper or a dedicated buffer chest if you need a specific handler.
