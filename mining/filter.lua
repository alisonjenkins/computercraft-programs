-- Trash filter + inventory helpers. Pure on the trash list; touches turtle.* on
-- the action helpers.

local M = {}

M.TRASH = {
    ["minecraft:cobblestone"]       = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:dirt"]              = true,
    ["minecraft:gravel"]            = true,
    ["minecraft:flint"]             = false,  -- keep — useful
    ["minecraft:andesite"]          = true,
    ["minecraft:diorite"]           = true,
    ["minecraft:granite"]           = true,
    ["minecraft:tuff"]              = true,
    ["minecraft:netherrack"]        = true,
    ["minecraft:basalt"]            = true,
    ["minecraft:smooth_basalt"]     = true,
    ["minecraft:blackstone"]        = true,
    ["minecraft:end_stone"]         = true,
    -- explicitly keep: "minecraft:stone", "minecraft:deepslate" (block form),
    -- all *_ore, raw_*, ancient_debris, redstone, lapis, coal, etc.
}

function M.isTrash(name)
    return M.TRASH[name] == true
end

-- Drop trash from inventory by dropping forward (or down if blocked).
-- Returns count of stacks dropped.
function M.purge()
    local dropped = 0
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and M.isTrash(d.name) then
            turtle.select(slot)
            if not turtle.drop() then turtle.dropDown() end
            dropped = dropped + 1
        end
    end
    turtle.select(1)
    return dropped
end

function M.firstEmptySlot()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then return slot end
    end
    return nil
end

function M.isFull()
    return M.firstEmptySlot() == nil
end

-- Try to refuel from any slot that holds a fuel-burnable item.
-- Returns the fuel level after attempts.
function M.refuelFromInv(target)
    target = target or math.huge
    for slot = 1, 16 do
        if turtle.getFuelLevel() == "unlimited" or turtle.getFuelLevel() >= target then
            break
        end
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if turtle.refuel(0) then
                turtle.refuel()
            end
        end
    end
    turtle.select(1)
    return turtle.getFuelLevel()
end

return M
