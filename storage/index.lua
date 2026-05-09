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

local function shortName(name)
    local i = name:find(":", 1, true)
    return i and name:sub(i + 1) or name
end

-- Lower score = better match. Used to disambiguate "andesite" → minecraft:andesite
-- rather than create:andesite_funnel.
function M.rank(name, entry, tokens)
    local short = shortName(name):lower()
    local query = table.concat(tokens, " ")
    local disp  = entry.displayName and entry.displayName:lower() or ""

    -- 1. Exact short name match wins outright.
    if short == query then return 0 end
    -- 2. Display name exactly equals query (case-insensitive).
    if disp == query then return 1 end
    -- 3. Joined-by-underscore short name equals tokens.
    if short == table.concat(tokens, "_") then return 2 end
    -- 4. Score by exact word-component coverage in the short name.
    local parts = {}
    for w in short:gmatch("[^_]+") do parts[#parts + 1] = w end
    local hits = 0
    for _, t in ipairs(tokens) do
        for _, p in ipairs(parts) do
            if p == t then hits = hits + 1 ; break end
        end
    end
    -- More exact-component hits = better. Shorter name = better tiebreaker.
    return 1000 - hits * 100 + #short
end

function M.rankSort(matches, tokens)
    local rows = {}
    for name, entry in pairs(matches) do
        rows[#rows + 1] = {
            name = name, entry = entry,
            score = M.rank(name, entry, tokens),
        }
    end
    table.sort(rows, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.entry.total > b.entry.total  -- tiebreaker: more in stock first
    end)
    return rows
end

M.tokenize = toTokens

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
