-- Pack: arkana-aeronautics
-- Computer: mining turtle (or any turtle with a pickaxe equipped)
-- Hardware: stack of ladders + a stack of "plug" blocks (cobblestone, dirt,
--           gravel, deepslate, netherrack, stone) + fuel.
--
-- Usage:
--   mining/digdown.lua <depth> [--no-ladders] [--seal-water]
-- Example: from surface Y=64 to Y=-58 → depth = 122
--   mining/digdown.lua 122
--
-- Behaviour:
--   - Digs straight down 1x1 for <depth> blocks.
--   - Lava-aware: if `inspectDown` finds lava, places a plug block to
--     replace it before digging. After each descent, checks all four
--     side walls for lava and plugs them too. Without a plug block the
--     turtle stops rather than diving into lava.
--   - Water-aware (passive): digs through water normally (water doesn't
--     damage the turtle). With `--seal-water`, also plugs water on sides
--     to keep the shaft dry and lets ladders place reliably.
--   - After each descent, placeUp's a ladder into the cell the turtle
--     just vacated. Vanilla ladder auto-attaches to one of the 4
--     surrounding walls.
--   - Mid-descent refuels from any fuel-burnable item in inventory.
--   - On out-of-ladders, out-of-plugs, or bedrock, stops with the depth
--     reached so you can refill + re-run for the remainder.

local argv = { ... }

local depth = tonumber(argv[1])
local placeLadders = true
local sealWater    = false
for i = 2, #argv do
    if     argv[i] == "--no-ladders" then placeLadders = false
    elseif argv[i] == "--seal-water" then sealWater = true end
end

if not depth or depth < 1 then
    print("usage: mining/digdown.lua <depth> [--no-ladders] [--seal-water]")
    return
end

local LADDER_NAMES = { ["minecraft:ladder"] = true }

local PLUG_NAMES = {
    ["minecraft:cobblestone"]       = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:stone"]             = true,
    ["minecraft:deepslate"]         = true,
    ["minecraft:dirt"]              = true,
    ["minecraft:gravel"]            = true,
    ["minecraft:netherrack"]        = true,
    ["minecraft:tuff"]              = true,
    ["minecraft:granite"]           = true,
    ["minecraft:diorite"]           = true,
    ["minecraft:andesite"]          = true,
    ["minecraft:basalt"]            = true,
    ["minecraft:blackstone"]        = true,
}

local FLUID_KIND = {
    ["minecraft:lava"]          = "lava",
    ["minecraft:flowing_lava"]  = "lava",
    ["minecraft:water"]         = "water",
    ["minecraft:flowing_water"] = "water",
}

local function findItem(predicate)
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and predicate(d.name) then turtle.select(slot) ; return slot end
    end
    return nil
end

local function selectLadder() return findItem(function(n) return LADDER_NAMES[n] end) end
local function selectPlug()   return findItem(function(n) return PLUG_NAMES[n]   end) end

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
end

local function fluidKind(blockData)
    return blockData and FLUID_KIND[blockData.name] or nil
end

local function shouldSeal(kind)
    if kind == "lava" then return true end
    if kind == "water" and sealWater then return true end
    return false
end

local function plugDown()
    if not selectPlug() then return false end
    return turtle.placeDown()
end

local function plugForward()
    if not selectPlug() then return false end
    return turtle.place()
end

-- Check the 4 side walls. For each fluid we want to seal, plug it.
local function sealSides()
    for _ = 1, 4 do
        local ok, b = turtle.inspect()
        if ok and shouldSeal(fluidKind(b)) then
            -- Replace the fluid: dig it out then place a plug forward.
            turtle.dig()                                      -- removes fluid block
            if not plugForward() then
                printError("warn: out of plug blocks while sealing side fluid")
            end
        end
        turtle.turnRight()
    end
end

print(("digdown: depth=%d ladders=%s seal-water=%s")
    :format(depth, tostring(placeLadders), tostring(sealWater)))

for i = 1, depth do
    refuelIfNeeded(64 + (depth - i))

    -- Inspect the cell directly below before doing anything to it.
    local okBelow, blockBelow = turtle.inspectDown()
    if okBelow then
        local kind = fluidKind(blockBelow)
        if kind == "lava" then
            if not plugDown() then
                printError(("lava directly below at depth %d, no plug — stopping"):format(i))
                return
            end
        end
        -- water below: just digDown, no special handling
    end

    -- Dig down (handles solid blocks, water, and just-placed plug).
    while turtle.detectDown() do
        if not turtle.digDown() then
            printError(("can't dig down at depth %d (bedrock?)"):format(i))
            return
        end
    end

    -- Defensive double-check in case lava poured back in.
    do
        local ok, b = turtle.inspectDown()
        if ok and fluidKind(b) == "lava" then
            if not plugDown() then
                printError(("lava re-flowed below at depth %d, no plug"):format(i))
                return
            end
            turtle.digDown()
        end
    end

    if not turtle.down() then
        printError(("blocked moving down at depth %d"):format(i))
        return
    end

    -- Now plug any side lava (and side water if --seal-water).
    sealSides()

    if placeLadders then
        if not selectLadder() then
            printError(("out of ladders at depth %d — stopping"):format(i))
            return
        end
        if not turtle.placeUp() then
            print(("warn: ladder placeUp failed at depth %d"):format(i))
        end
    end

    if i % 16 == 0 then print(("  ... %d / %d"):format(i, depth)) end
end

print(("done: descended %d blocks. turtle is now %d below start."):format(depth, depth))
