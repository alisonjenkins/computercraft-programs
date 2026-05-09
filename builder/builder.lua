-- Pack: arkana-aeronautics
-- Computer: plain turtle (no upgrade required)
-- Hardware: a supply chest one block above the turtle's start position.
-- Usage: builder/builder.lua <schema-path>
--   e.g. builder/builder.lua builder/schemas/5x5x3-shed.lua

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

local function paletteOf(s, ch)
    if ch == nil then return nil end
    return s.palette[ch]
end

local function turtleSelectByName(name)
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and d.name == name then turtle.select(slot) ; return slot end
    end
    return nil
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

local function placeBlock(name)
    if not name then return true end
    if not turtleSelectByName(name) then
        return false, "missing material: " .. name
    end
    local ok = turtle.placeDown()
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
    local layer = s.layers[layerIdx]
    local rows  = #layer
    for z = 1, rows do
        local row = layer[z]
        for x = 1, #row do
            local ch    = row:sub(x, x)
            local name  = paletteOf(s, ch)
            local ok, err = placeBlock(name)
            if not ok then
                print(("layer %d row %d col %d: %s"):format(layerIdx, z, x, err))
                restockFromSupply()
                ok = placeBlock(name)
                assert(ok, "still missing material after restock")
            end
            if x < #row then safeMove("forward") end
        end
        if z < rows then
            -- snake: alternate forward/back across rows
            if z % 2 == 1 then
                turtle.turnRight() ; safeMove("forward") ; turtle.turnRight()
            else
                turtle.turnLeft()  ; safeMove("forward") ; turtle.turnLeft()
            end
        end
    end
end

local function run()
    local s = loadSchema(schemaPath)
    print(("schema: %d layers, palette size %d")
        :format(#s.layers, (function() local n=0; for _ in pairs(s.palette) do n=n+1 end; return n end)()))

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
