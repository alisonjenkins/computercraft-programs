-- Pack: arkana-aeronautics
-- Computer: mining turtle (or any turtle with a pickaxe equipped)
-- Hardware: stack of ladders in turtle inventory + fuel.
--
-- Usage:
--   mining/digdown.lua <depth> [--no-ladders]
-- Example: from surface Y=64 to Y=-58 → depth = 122
--   mining/digdown.lua 122
--
-- Behaviour:
--   - Digs straight down 1x1 for <depth> blocks.
--   - After each descent, placeUp's a ladder into the cell the turtle just
--     vacated (vanilla ladder auto-attaches to one of the 4 surrounding
--     stone walls — should work for any descent through solid material).
--   - If a ladder placement fails (e.g. the cell above is in open air with
--     no walls), prints a warning and continues. Manually place those
--     ladders later if you want a continuous climb.
--   - Mid-descent refuels from any fuel-burnable item in inventory.
--   - On out-of-ladders, stops with the depth reached so you can refill +
--     re-run for the remainder.

local argv = { ... }

local depth = tonumber(argv[1])
local placeLadders = true
for i = 2, #argv do
    if argv[i] == "--no-ladders" then placeLadders = false end
end

if not depth or depth < 1 then
    print("usage: mining/digdown.lua <depth> [--no-ladders]")
    return
end

local LADDER_NAMES = {
    ["minecraft:ladder"] = true,
}

local function findItem(predicate)
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and predicate(d.name) then turtle.select(slot) ; return slot end
    end
    return nil
end

local function refuelIfNeeded(target)
    target = target or 256
    if turtle.getFuelLevel() == "unlimited" then return end
    if turtle.getFuelLevel() >= target then return end
    for slot = 1, 16 do
        if turtle.getFuelLevel() ~= "unlimited"
           and turtle.getFuelLevel() >= target then break end
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if turtle.refuel(0) then turtle.refuel() end
        end
    end
    turtle.select(1)
end

local function selectLadder()
    return findItem(function(name) return LADDER_NAMES[name] end)
end

print(("digdown: depth=%d ladders=%s"):format(depth, tostring(placeLadders)))

for i = 1, depth do
    refuelIfNeeded(64 + (depth - i))   -- want enough fuel for remaining descent

    while turtle.detectDown() do
        if not turtle.digDown() then
            printError(("can't dig down at depth %d (bedrock?)"):format(i))
            return
        end
    end

    if not turtle.down() then
        printError(("blocked moving down at depth %d"):format(i))
        return
    end

    if placeLadders then
        if not selectLadder() then
            printError(("out of ladders at depth %d — stopping"):format(i))
            return
        end
        if not turtle.placeUp() then
            print(("warn: ladder placeUp failed at depth %d"):format(i))
        end
    end

    if i % 16 == 0 then
        print(("  ... %d / %d"):format(i, depth))
    end
end

print(("done: descended %d blocks. turtle is now %d below start."):format(depth, depth))
