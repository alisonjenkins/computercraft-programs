-- Pack: arkana-aeronautics
-- Computer: basic computer with wired modem
-- Peripherals expected (over wired modem):
--   1× inventory          (input/output chest — set CONFIG.chest)
--   N× minecraft:furnace        (general smelting fallback)
--   N× minecraft:smoker         (food, 2× speed)
--   N× minecraft:blast_furnace  (ores + raw metals, 2× speed)
--
-- Slot convention (all three machine types): 1 = input, 2 = fuel, 3 = output.
--
-- Behaviour:
--   - Discovers machines automatically every cycle.
--   - Classifies items in the input chest: food → smoker, ores/raw → blast,
--     other smeltables → furnace. Falls back to regular furnace if the
--     preferred machine type isn't connected.
--   - Pulls outputs to chest, refuels machines from chest, tops up inputs.

settings.define("smelter_chest", {
    description = "Network name of the input/output chest",
    type        = "string",
})
settings.load()

local CONFIG = {
    chest         = settings.get("smelter_chest"),
    refuel_below  = 8,    -- refill fuel slot when count drops below this
    refuel_amount = 8,    -- push this many fuel items per refill
    sleep_s       = 1,
}

if not CONFIG.chest or CONFIG.chest == "" then
    error("set smelter_chest in shell: set smelter_chest sophisticatedstorage:chest_0")
end

local FUELS = {
    ["minecraft:coal"]       = true,
    ["minecraft:charcoal"]   = true,
    ["minecraft:coal_block"] = true,
    ["minecraft:blaze_rod"]  = true,
}

-- Items that are themselves smelting/cooking outputs. Never re-smelt these,
-- even if their name contains a substring that would otherwise match an
-- input pattern (e.g. "cooked_beef" contains "beef", "dried_kelp" contains
-- "kelp", "smooth_stone" contains "stone", "iron_ingot" comes from raw_iron).
local SMELTED_OUTPUTS = {
    -- Cooked food (smoker / furnace outputs)
    ["minecraft:cooked_beef"]     = true,
    ["minecraft:cooked_chicken"]  = true,
    ["minecraft:cooked_mutton"]   = true,
    ["minecraft:cooked_porkchop"] = true,
    ["minecraft:cooked_rabbit"]   = true,
    ["minecraft:cooked_cod"]      = true,
    ["minecraft:cooked_salmon"]   = true,
    ["minecraft:baked_potato"]    = true,
    ["minecraft:dried_kelp"]      = true,
    ["minecraft:popped_chorus_fruit"] = true,
    -- Smelted blocks
    ["minecraft:glass"]           = true,
    ["minecraft:stone"]           = true,   -- output of smelting cobblestone
    ["minecraft:smooth_stone"]    = true,
    ["minecraft:smooth_basalt"]   = true,
    ["minecraft:smooth_sandstone"] = true,
    ["minecraft:smooth_red_sandstone"] = true,
    ["minecraft:smooth_quartz"]   = true,
    ["minecraft:terracotta"]      = true,
    ["minecraft:nether_brick"]    = true,
    ["minecraft:cracked_stone_bricks"] = true,
    ["minecraft:cracked_nether_bricks"] = true,
    ["minecraft:sponge"]          = true,
    ["minecraft:deepslate"]       = true,   -- smelted from cobbled_deepslate
    -- Smelted metals
    ["minecraft:iron_ingot"]      = true,
    ["minecraft:gold_ingot"]      = true,
    ["minecraft:copper_ingot"]    = true,
    ["minecraft:netherite_scrap"] = true,
    -- Other
    ["minecraft:charcoal"]        = true,
    ["minecraft:green_dye"]       = true,   -- cactus → green dye
}

-- Item-name patterns. Each item is checked against SMELTED_OUTPUTS first
-- (early return nil), then categorised food → blast → smelt.
local function classify(name)
    if SMELTED_OUTPUTS[name] then return nil end
    local n = name:lower()
    -- Food (smoker). Substring is OK now because cooked outputs are blocked above.
    if n:find("beef",      1, true) or n:find("chicken",    1, true)
    or n:find("mutton",    1, true) or n:find("porkchop",   1, true)
    or n:find("rabbit",    1, true) or n:find("cod",        1, true)
    or n:find("salmon",    1, true) or n:find("potato",     1, true)
    or n:find("kelp",      1, true) or n:find("chorus_fruit", 1, true)
    then return "food" end
    -- Ore / raw metal (blast furnace)
    if n:find("_ore", 1, true)
    or n:find("raw_", 1, true)
    or n == "minecraft:ancient_debris"
    or n == "minecraft:gilded_blackstone"
    then return "blast" end
    -- General smeltables (regular furnace).
    -- Note: don't include "stone" — it'd auto-convert to smooth_stone, which
    -- the user may not want. Logs → charcoal. Cobblestone → stone (one step).
    if n:find("cobblestone", 1, true) or n:find("sand",      1, true)
    or n:find("log",         1, true) or n:find("netherrack", 1, true)
    or n == "minecraft:clay"          or n == "minecraft:wet_sponge"
    or n == "minecraft:cactus"
    or n == "minecraft:basalt"        or n == "minecraft:cobbled_deepslate"
    then return "smelt" end
    return nil
end

local function discoverMachines()
    local pools = { food = {}, blast = {}, smelt = {} }
    for _, p in ipairs({ peripheral.find("minecraft:smoker") }) do
        pools.food[#pools.food + 1] = p
    end
    for _, p in ipairs({ peripheral.find("minecraft:blast_furnace") }) do
        pools.blast[#pools.blast + 1] = p
    end
    for _, p in ipairs({ peripheral.find("minecraft:furnace") }) do
        pools.smelt[#pools.smelt + 1] = p
    end
    return pools
end

-- Pick a machine for `category`. Falls back to regular furnace if the
-- preferred pool is empty. Returns nil if no machine of any type exists.
local function pickMachine(category, pools)
    local order = ({
        food  = { "food",  "smelt" },
        blast = { "blast", "smelt" },
        smelt = { "smelt" },
    })[category] or { "smelt" }
    for _, kind in ipairs(order) do
        if #pools[kind] > 0 then
            return pools[kind][1]   -- naive: always first; could load-balance later
        end
    end
    return nil
end

-- Manage one machine: pull output, refuel if low, top up input if empty.
local function manage(machine, chest, chestName)
    local mName = peripheral.getName(machine)
    local inv   = machine.list()

    -- 1. Output → chest
    if inv[3] then machine.pushItems(chestName, 3) end

    -- 2. Refuel slot 2 if low
    if not inv[2] or inv[2].count < CONFIG.refuel_below then
        for slot, item in pairs(chest.list()) do
            if FUELS[item.name] then
                chest.pushItems(mName, slot, CONFIG.refuel_amount, 2)
                break
            end
        end
    end

    -- 3. Top up input slot 1
    if not inv[1] then
        -- Find an item from the chest that this machine accepts.
        local mType = peripheral.getType(mName)
        local wantCategory =
            (mType == "minecraft:smoker") and "food" or
            (mType == "minecraft:blast_furnace") and "blast" or
            "smelt"
        for slot, item in pairs(chest.list()) do
            if not FUELS[item.name] then
                local cat = classify(item.name)
                if cat == wantCategory or (wantCategory == "smelt" and cat) then
                    chest.pushItems(mName, slot, 64, 1)
                    break
                end
            end
        end
    elseif inv[1].count < 64 then
        -- Top off existing stack
        for slot, item in pairs(chest.list()) do
            if item.name == inv[1].name then
                chest.pushItems(mName, slot, 64 - inv[1].count, 1)
            end
        end
    end
end

-- Distribute fresh items from the chest into idle machines of the right
-- category (respecting "smelt" fallback).
local function distribute(chest, chestName, pools)
    local fed = {}  -- mark machines we already touched this round
    for slot, item in pairs(chest.list()) do
        if FUELS[item.name] then
            -- skip; refuel is handled per-machine in manage()
        else
            local cat = classify(item.name)
            if cat then
                local m = pickMachine(cat, pools)
                if m and not fed[peripheral.getName(m)] then
                    -- Manage will pick it up on the per-machine pass; this
                    -- function exists mainly so future logic (e.g. multi-
                    -- target round-robin) has a hook. For v1 we no-op here
                    -- and rely on manage() per machine.
                    fed[peripheral.getName(m)] = true
                end
            end
        end
    end
end

print("Smelter online. chest=" .. CONFIG.chest)

while true do
    local chest = peripheral.wrap(CONFIG.chest)
    if not chest then
        print("warn: chest " .. CONFIG.chest .. " not on network — retrying")
        sleep(5)
    else
        local pools = discoverMachines()
        if (#pools.food + #pools.blast + #pools.smelt) == 0 then
            print("warn: no smoker / blast_furnace / furnace on network — retrying")
            sleep(5)
        else
            distribute(chest, CONFIG.chest, pools)
            for _, kind in ipairs({ "food", "blast", "smelt" }) do
                for _, m in ipairs(pools[kind]) do
                    manage(m, chest, CONFIG.chest)
                end
            end
            sleep(CONFIG.sleep_s)
        end
    end
end
