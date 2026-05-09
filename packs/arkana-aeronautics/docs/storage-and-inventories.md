# Storage & inventories in this pack

**Status in this pack:** Active. All storage in this pack is reachable via CC:T's generic `inventory` peripheral (see `cc-tweaked-generic.md` for the full method list).

## Mods present

- **Sophisticated Storage** — chests, barrels, shulker boxes, controllers
- **Sophisticated Backpacks** — primarily player-worn / entity-bound
- **Sophisticated Storage Create Integration** — bridges into Create funnels/pipes
- **Sophisticated Backpacks Create Integration**
- **EnderStorage** — frequency-paired chests (works cross-dimension)
- **Vanilla** — chest, barrel, hopper, dropper, shulker, furnace family

## Sophisticated Storage

Block names show as `sophisticatedstorage:chest_<n>`, `sophisticatedstorage:barrel_<n>`, `sophisticatedstorage:limited_chest_<n>`, etc. Wrap as `inventory`:

```lua
local chest = peripheral.wrap("sophisticatedstorage:chest_0")
chest.list()
chest.pushItems(targetName, slot, count, targetSlot)
```

This is exactly how `smelter.lua` in the repo root works.

Sophisticated Storage's *upgrades* (compaction, hopper, magnet, smelting, etc.) are NBT-only; they don't affect the CC interface — your `pushItems` just sees the resulting items.

## Sophisticated Backpacks

Backpacks are mostly **on-entity** (player) or in-slot — not addressable as block peripherals. Use the **Inventory Manager** (`advanced-peripherals.md`) to move items in/out of a wearer's inventory rather than addressing the backpack directly.

A backpack placed as a block (right-click on ground) does become a regular inventory peripheral, but this is an unusual setup.

## EnderStorage

Frequency-paired. `peripheral.wrap("enderstorage:ender_chest_<n>")` exposes `inventory` like any other chest. **Both ends share contents** — a `pushItems` from one end into "itself" (the same frequency in another dimension) is essentially a no-op.

Useful for bridging long distances or dimensions in turtle programs without a wired modem network.

## Vanilla furnace family

Vanilla furnaces / blast furnaces / smokers have **3 slots**:

| Slot | Role |
|---|---|
| 1 | Input (ingredient) |
| 2 | Fuel |
| 3 | Output |

`smelter.lua` uses this convention — `inv[1]` is the ingredient, `inv[2]` is fuel, `inv[3]` is output.

## Create blocks as inventories

Many Create blocks expose an item handler and therefore wrap as `inventory`:

- **Item Vault** — bulk storage, shows as one big slot pool
- **Mechanical Crafter** — input/result slots
- **Basin** — input slots; mixing/compacting happens between basin and machine
- **Funnel** (when buffered) — small intermediate inventory
- **Mechanical Mixer** — does NOT itself have an inventory; pair with a Basin
- **Belt** — items on a belt are entities, NOT in any inventory; you can't `pushItems` directly to a belt

Treat Create's belts/funnels as flow, and chests/vaults/basins as buffers you address from CC.

## Fluid handlers

Same idea, different capability:

```lua
local tank = peripheral.find("fluid_storage")
for _, t in ipairs(tank.tanks()) do
  print(t.name, t.amount)
end
```

Create fluid tanks, fluid pipes (when buffered), drains, and spouts expose this.

## Energy handlers

```lua
local fe = peripheral.find("energy_storage")
print(fe.getEnergy(), "/", fe.getEnergyCapacity())
```

Read-only. To watch flow, splice an Advanced Peripherals **Energy Detector** into the cable line and call `getTransferRate()`.

## Patterns specific to this pack

**Smelter-style auto-feeder** — see `smelter.lua`. The pattern: pull `chest.list()`, classify items, push into machine slots. Generalises to Create Mechanical Crafters, Basins, Drains.

**Funnel-buffered logistics** — Create funnels with internal buffers behave as inventories. Pair a CC computer + Sophisticated Storage chest + Create funnel to programmatically gate flow.

**Cross-dimension item bridge** — EnderStorage chest at each end + a CC computer at one end watching `chest.list()` and pulling on demand.
