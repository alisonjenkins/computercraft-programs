local M = {}

function M.totalOf(inv, name)
    local total = 0
    for _, item in pairs(inv.list()) do
        if item.name == name then total = total + item.count end
    end
    return total
end

function M.findSlot(inv, name)
    for slot, item in pairs(inv.list()) do
        if item.name == name then return slot, item end
    end
    return nil
end

function M.pushAll(from, toName, name, max)
    max = max or math.huge
    local moved = 0
    for slot, item in pairs(from.list()) do
        if moved >= max then break end
        if item.name == name then
            local want = math.min(item.count, max - moved)
            local got = from.pushItems(toName, slot, want)
            moved = moved + got
            if got < want then break end
        end
    end
    return moved
end

function M.matches(item, query)
    if not item then return false end
    if item.name == query then return true end
    if item.name:find(query, 1, true) then return true end
    if query:sub(1, 1) == "#" then
        local tag = query:sub(2)
        return item.tags and item.tags[tag] == true
    end
    return false
end

function M.allInventories(exclude)
    exclude = exclude or {}
    local skip = {}
    for _, n in ipairs(exclude) do skip[n] = true end
    local out = {}
    for _, p in ipairs({ peripheral.find("inventory") }) do
        local n = peripheral.getName(p)
        if not skip[n] then out[#out + 1] = { name = n, inv = p } end
    end
    return out
end

return M
