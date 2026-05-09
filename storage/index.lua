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

-- Tokenise a query into lowercase non-empty tokens.
local function toTokens(q)
    local out = {}
    if type(q) == "string" then
        for w in q:lower():gmatch("%S+") do out[#out + 1] = w end
    elseif type(q) == "table" then
        for _, w in ipairs(q) do
            for s in tostring(w):lower():gmatch("%S+") do out[#out + 1] = s end
        end
    end
    return out
end

-- Fuzzy match: every token must appear (substring, case-insensitive) in
-- either the registry name or the display name. Empty query → empty result.
function M.matchNames(idx, query)
    local tokens = toTokens(query)
    if #tokens == 0 then return {} end

    -- exact registry-name hit short-circuits
    if type(query) == "string" and idx[query] then
        return { [query] = idx[query] }
    end

    local out = {}
    for name, entry in pairs(idx) do
        local hay = name:lower()
        if entry.displayName then hay = hay .. "\0" .. entry.displayName:lower() end
        local all = true
        for _, t in ipairs(tokens) do
            if not hay:find(t, 1, true) then all = false; break end
        end
        if all then out[name] = entry end
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
