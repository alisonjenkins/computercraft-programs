# CC: Tweaked — turtle API

**Status in this pack:** Active. Standard CC:T turtle. Smart turtle variants (Chatty / Chunky / Geoscanning / etc.) come from Advanced Peripherals — see `advanced-peripherals.md`.

Upstream: https://tweaked.cc/module/turtle.html

## Movement

```lua
turtle.forward() -> bool, err
turtle.back()    turtle.up()    turtle.down()
turtle.turnLeft()    turtle.turnRight()
```

Movement consumes 1 fuel per block. `back` does not turn around — it moves opposite to facing.

## Detect / inspect / compare

```lua
turtle.detect()  turtle.detectUp()  turtle.detectDown()           -- bool
turtle.inspect() -> bool, blockData                                -- {name, state, tags, ...}
turtle.inspectUp()  turtle.inspectDown()
turtle.compare()  turtle.compareUp()  turtle.compareDown()        -- vs selected slot
turtle.compareTo(slot) -> bool                                     -- vs another slot in inventory
```

## Dig / place / attack

```lua
turtle.dig([side])  turtle.digUp()  turtle.digDown()              -- side: "left"|"right"
turtle.place([text])  turtle.placeUp()  turtle.placeDown()         -- text: optional sign text
turtle.attack([side])  turtle.attackUp()  turtle.attackDown()
```

## Inventory

```lua
turtle.select(slot)  turtle.getSelectedSlot() -> slot
turtle.getItemCount([slot]) -> int
turtle.getItemSpace([slot]) -> int
turtle.getItemDetail([slot[, detailed]]) -> table|nil
turtle.transferTo(slot[, count]) -> bool
turtle.drop([count])  turtle.dropUp()  turtle.dropDown()
turtle.suck([count])  turtle.suckUp()  turtle.suckDown()
```

Slots 1..16. `getItemDetail(slot, true)` returns the same level of detail as `inventory.getItemDetail`.

## Fuel

```lua
turtle.getFuelLevel() -> int|"unlimited"
turtle.getFuelLimit() -> int|"unlimited"
turtle.refuel([count]) -> bool                                    -- consumes selected slot
```

Fuel limit is server-config (default 100k). Coal = 80, charcoal = 80, log = 15, lava bucket = 1000.

## Equipment (upgrades)

```lua
turtle.equipLeft()  turtle.equipRight()
turtle.getEquippedLeft() -> table|nil
turtle.getEquippedRight() -> table|nil
```

Crafty Turtle (with crafting upgrade equipped):

```lua
turtle.craft([limit]) -> bool, err
```

The mining/woodaxe/sword/hoe/shovel are also "tools" — equipping them changes which blocks `dig` will mine.

## Events

`turtle_inventory` — fires whenever the turtle's inventory changes.

## Pattern: safe move

```lua
local function go(dir)
  while not turtle[dir]() do
    turtle["dig" .. (dir == "forward" and "" or dir:sub(1,1):upper()..dir:sub(2))]()
    sleep(0.1)
  end
end
```

Or the `cc.expect` pattern with detection:

```lua
if turtle.detect() then turtle.dig() end
turtle.forward()
```

## Patterns common to this pack

- **GPS-aware turtle** — pair with `gps.locate()` (needs ≥4 GPS hosts). See `cc-tweaked-networking.md`.
- **Fuelled by Create** — Create item conveyors can drop fuel into a turtle's slot; `refuel()` on a timer.
- **Geoscanning Turtle** (AP) — equip the Geo Scanner upgrade, then `peripheral.find("geo_scanner")` from inside the turtle.
