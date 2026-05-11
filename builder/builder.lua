-- Pack: arkana-aeronautics
-- Computer: plain turtle (no upgrade required)
-- Hardware: a supply chest one block above the turtle's start position.
-- Usage: builder/builder.lua <schema-path>
--   e.g. builder/builder.lua builder/schemas/5x5x3-shed.lua
--
-- Two schema formats accepted:
--
-- 1. Hand-written "char palette + string rows" (legacy):
--      return {
--          palette = { [" "] = nil, ["C"] = "minecraft:cobblestone", ... },
--          layers  = {
--              { "CCCCC", "C   C", ... },   -- layer y=0: rows of chars
--              ...
--          },
--      }
--
-- 2. Auto-generated from a vanilla .nbt schematic via tools/schematic_to_lua.py:
--      return {
--          size    = { width = W, height = H, length = L },
--          palette = { [1] = "minecraft:stone", [2] = "minecraft:oak_planks", ... },
--          layers  = {
--              { { 1, 1, 2, ... }, { ... }, ... },  -- layer y=0: rows of palette indices
--              ...
--          },
--      }
--
-- The two are distinguished by whether `s.layers[1][1]` is a string (legacy)
-- or a table (NBT-derived).

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local args = { ... }
local schemaPath = args[1] or "builder/schemas/5x5x3-shed.lua"

local function loadSchema(path)
    local fn, err = loadfile(path)
    assert(fn, "schema load failed: " .. tostring(err))
    local s = fn()
    assert(type(s) == "table", "schema must return a table")
    assert(s.layers and s.palette, "schema needs .layers and .palette")
    return s
end

-- Returns a function (x, z) → entry (or nil for air) for the given layer
-- index. `entry` is one of:
--   nil                                       — leave air
--   string "minecraft:foo"                    — plain block, place flat
--   { name = "minecraft:foo",                 — block with orientation
--     properties = { facing = "north", ... } }
-- Hides the difference between the two schema formats.
local function layerLookup(s, layerIdx)
    local layer = s.layers[layerIdx]
    local firstRow = layer[1]
    if type(firstRow) == "string" then
        -- legacy char-grid format
        return function(x, z)
            local row = layer[z]
            if not row then return nil end
            local ch = row:sub(x, x)
            return s.palette[ch]
        end, #layer, function(z) return #layer[z] end
    else
        -- NBT-derived: each row is { idx, idx, ... }
        return function(x, z)
            local row = layer[z]
            if not row then return nil end
            local idx = row[x]
            if not idx or idx == 0 then return nil end
            local entry = s.palette[idx]
            if entry == nil then return nil end
            if type(entry) == "string" then
                if entry == "minecraft:air" then return nil end
                return entry
            end
            -- table entry
            if entry.name == "minecraft:air" then return nil end
            return entry
        end, #layer, function(z) return #layer[z] end
    end
end

local function turtleSelectByName(name)
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == name then turtle.select(slot) ; return slot end
    end
    return nil
end

-- Facing tracker. 0 = north (turtle's start heading), 1 = east, 2 = south, 3 = west.
-- placeDown() inherits the turtle's heading for blockstate orientation: the
-- placed block's `facing` property ends up opposite of the turtle's heading.
-- So to materialise a block with `facing = X` we turn the turtle to face the
-- opposite cardinal, placeDown, and rotate back.
local FACING_INDEX = { north = 0, east = 1, south = 2, west = 3 }
local OPPOSITE_FACING = {
    north = "south", south = "north", east = "west", west = "east",
}

local turtleHeading = 0

local function turnLeftTracked()  turtle.turnLeft()  ; turtleHeading = (turtleHeading - 1) % 4 end
local function turnRightTracked() turtle.turnRight() ; turtleHeading = (turtleHeading + 1) % 4 end

-- Rotate to absolute heading `targetIdx`. Returns the signed number of
-- right-turns taken so the caller can undo with the inverse.
local function rotateToHeading(targetIdx)
    local delta = (targetIdx - turtleHeading) % 4
    if     delta == 0 then return 0
    elseif delta == 1 then turnRightTracked() ; return 1
    elseif delta == 2 then turnRightTracked() ; turnRightTracked() ; return 2
    elseif delta == 3 then turnLeftTracked()  ; return -1 end
    return 0
end

local function rotateByDelta(delta)
    if     delta ==  1 then turnRightTracked()
    elseif delta == -1 then turnLeftTracked()
    elseif delta ==  2 then turnRightTracked() ; turnRightTracked()
    elseif delta == -2 then turnLeftTracked()  ; turnLeftTracked() end
end

local function ensureFuel(min)
    local f = turtle.getFuelLevel()
    if f == "unlimited" then return true end
    if f >= min then return true end
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then turtle.refuel() end
        if turtle.getFuelLevel() == "unlimited" or turtle.getFuelLevel() >= min then
            return true
        end
    end
    return false
end

local function restockFromSupply()
    -- Supply chest is directly above the turtle's start position.
    -- Turtle assumed to be back at origin when this is called.
    while not turtle.suckUp() do
        sleep(2)
    end
end

local function placeBlock(entry)
    if not entry then return true end                -- air → skip
    local name, props
    if type(entry) == "string" then
        name = entry
    else
        name  = entry.name
        props = entry.properties
    end
    if not turtleSelectByName(name) then
        return false, "missing material: " .. name
    end

    -- Pre-rotate to materialise a directional block. `facing = X` on the
    -- placed block requires the turtle to face the OPPOSITE cardinal at
    -- placeDown time.
    local restoreDelta = 0
    if props and props.facing and OPPOSITE_FACING[props.facing] then
        local targetHeading = FACING_INDEX[OPPOSITE_FACING[props.facing]]
        local pre = turtleHeading
        rotateToHeading(targetHeading)
        restoreDelta = (pre - turtleHeading) % 4
        if restoreDelta == 3 then restoreDelta = -1 end
    end

    local ok = turtle.placeDown()

    if restoreDelta ~= 0 then rotateByDelta(restoreDelta) end

    if not ok then return false, "place failed" end
    return true
end

local function safeMove(dir)
    local fn = turtle[dir]
    while not fn() do
        if dir == "forward" then
            if turtle.detect() then turtle.dig() end
        elseif dir == "up" then
            if turtle.detectUp() then turtle.digUp() end
        elseif dir == "down" then
            if turtle.detectDown() then turtle.digDown() end
        end
        sleep(0.2)
    end
end

local function buildLayer(s, layerIdx)
    local lookup, rows, rowLen = layerLookup(s, layerIdx)
    for z = 1, rows do
        local cols = rowLen(z)
        for x = 1, cols do
            local name    = lookup(x, z)
            local ok, err = placeBlock(name)
            if not ok then
                print(("layer %d row %d col %d: %s"):format(layerIdx, z, x, err))
                restockFromSupply()
                ok = placeBlock(name)
                assert(ok, "still missing material after restock")
            end
            if x < cols then safeMove("forward") end
        end
        if z < rows then
            -- snake: alternate forward/back across rows. Use tracked turns
            -- so placeBlock's facing-aware pre-rotation knows our heading.
            if z % 2 == 1 then
                turnRightTracked() ; safeMove("forward") ; turnRightTracked()
            else
                turnLeftTracked()  ; safeMove("forward") ; turnLeftTracked()
            end
        end
    end
end

local function paletteSize(s)
    local n = 0
    for _ in pairs(s.palette) do n = n + 1 end
    return n
end

local function run()
    local s = loadSchema(schemaPath)
    if s.size then
        print(("schema: %d × %d × %d  layers=%d  palette=%d  (NBT-derived)")
            :format(s.size.width, s.size.height, s.size.length,
                    #s.layers, paletteSize(s)))
    else
        print(("schema: %d layers, palette size %d  (legacy)")
            :format(#s.layers, paletteSize(s)))
    end

    -- Top up materials before starting.
    restockFromSupply()
    if not ensureFuel(64) then error("not enough fuel") end

    for i = 1, #s.layers do
        print(("layer %d/%d"):format(i, #s.layers))
        if i > 1 then safeMove("up") end
        buildLayer(s, i)
        -- After buildLayer, turtle is at the far corner of the layer; we don't reset XZ here.
        -- For a v1 schema the layers must be the same shape so the turtle's drift across rows
        -- is consistent layer-to-layer. Caller can re-home the turtle manually if needed.
    end

    print("done")
end

run()
