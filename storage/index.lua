local M = {}

function M.build(invs)
    local idx = {}
    for _, e in ipairs(invs) do
        for slot, item in pairs(e.inv.list()) do
            local entry = idx[item.name] or { total = 0, locations = {}, displayName = nil }
            entry.total = entry.total + item.count
            entry.locations[#entry.locations + 1] = {
                chest = e.name,
                slot  = slot,
                count = item.count,
            }
            if not entry.displayName then
                local d = e.inv.getItemDetail(slot)
                if d then entry.displayName = d.displayName end
            end
            idx[item.name] = entry
        end
    end
    return idx
end

function M.matchNames(idx, query)
    local out = {}
    if idx[query] then out[query] = idx[query] ; return out end
    local lower = query:lower()
    for name, entry in pairs(idx) do
        if name:lower():find(lower, 1, true) then out[name] = entry end
    end
    return out
end

function M.topByCount(idx, limit, prefix)
    local rows = {}
    for name, entry in pairs(idx) do
        if not prefix or name:lower():find(prefix:lower(), 1, true) then
            rows[#rows + 1] = { name = name, count = entry.total }
        end
    end
    table.sort(rows, function(a, b) return a.count > b.count end)
    while #rows > (limit or 20) do rows[#rows] = nil end
    return rows
end

return M
