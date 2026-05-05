-- Peripherals from your setup in image_cbdbb2.png
local chest = peripheral.wrap("minecraft:chest_0")
local furnaces = {
    peripheral.wrap("minecraft:furnace_1"),
    peripheral.wrap("minecraft:furnace_2")
}

-- Simple fuel list (Removed blaze rods)
local FUELS = { ["minecraft:coal"] = true, ["minecraft:charcoal"] = true, ["minecraft:coal_block"] = true }

-- Pattern matching for smeltables to avoid typing 100+ item names
local function isSmeltable(name)
    local n = name:lower()
    -- Matches: ores, raw metals, sand, cobble, debris, kelp, logs, and food
    return n:find("ore") or n:find("raw_") or n:find("sand") or
        n:find("cobblestone") or n:find("ancient_debris") or
        n:find("kelp") or n:find("log") or n:find("beef") or n:find("chicken")
end

local function manage(f)
    local f_name = peripheral.getName(f)
    local c_name = peripheral.getName(chest)
    local inv = f.list()

    -- 1. Grab Output
    if inv[3] then f.pushItems(c_name, 3) end

    -- 2. Refuel (Slot 2)
    if not inv[2] or inv[2].count < 8 then
        for slot, item in pairs(chest.list()) do
            if FUELS[item.name] then
                chest.pushItems(f_name, slot, 8, 2)
                break
            end
        end
    end

    -- 3. Load Input (Slot 1)
    if not inv[1] then
        for slot, item in pairs(chest.list()) do
            if not FUELS[item.name] and isSmeltable(item.name) then
                chest.pushItems(f_name, slot, 64, 1)
                break
            end
        end
    elseif inv[1].count < 64 then
        -- Top off existing stack
        for slot, item in pairs(chest.list()) do
            if item.name == inv[1].name then
                chest.pushItems(f_name, slot, 64 - inv[1].count, 1)
            end
        end
    end
end

print("Smelter Online. Monitoring furnaces...")
while true do
    for _, f in ipairs(furnaces) do
        if f then manage(f) end
    end
    sleep(1) -- Check every 20 ticks
end
