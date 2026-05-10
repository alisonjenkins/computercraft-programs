local M = {}

-- Display-name cache, keyed by registry name (e.g. "minecraft:cobblestone").
-- getItemDetail is the slowest CC inventory call (~50ms per slot, full NBT).
-- Building the index for N chests × 27 slots used to call it once per slot
-- on every rebuild — multiple seconds of blocking on every !give. By caching
-- across rebuilds we pay the cost once per never-before-seen item name and
-- reuse it forever.
local DISPLAY_NAME = {}

function M.cachedDisplayName(name) return DISPLAY_NAME[name] end

function M.build(invs)
    -- 1. Fan out list() calls so each chest yields concurrently against
    --    the server tick instead of serializing.
    local lists = {}
    local fetchers = {}
    for i, e in ipairs(invs) do
        fetchers[i] = function() lists[i] = e.inv.list() end
    end
    if #fetchers > 0 then parallel.waitForAll(table.unpack(fetchers)) end

    -- 2. Build the index from the parallel-fetched lists. Detect any item
    --    names not in the displayName cache so we can fan out
    --    getItemDetail calls for just those (instead of every slot).
    local idx = {}
    local pendingDetail = {}  -- list of { invIdx=..., slot=..., name=... }
    for i, e in ipairs(invs) do
        local list = lists[i]
        if list then
            for slot, item in pairs(list) do
                local entry = idx[item.name] or {
                    total = 0,
                    locations = {},
                    displayName = DISPLAY_NAME[item.name],
                }
                entry.total = entry.total + item.count
                entry.locations[#entry.locations + 1] = {
                    chest = e.name,
                    slot  = slot,
                    count = item.count,
                }
                idx[item.name] = entry
                if not entry.displayName then
                    pendingDetail[#pendingDetail + 1] = {
                        invIdx = i, slot = slot, name = item.name,
                    }
                end
            end
        end
    end

    -- 3. Fan out getItemDetail for unseen names only — at most one per
    --    distinct item name, parallelized.
    if #pendingDetail > 0 then
        local seenNames = {}
        local fns = {}
        for _, p in ipairs(pendingDetail) do
            if not seenNames[p.name] then
                seenNames[p.name] = true
                local invIdx, slot, name = p.invIdx, p.slot, p.name
                fns[#fns + 1] = function()
                    local d = invs[invIdx].inv.getItemDetail(slot)
                    if d and d.displayName then
                        DISPLAY_NAME[name] = d.displayName
                    end
                end
            end
        end
        if #fns > 0 then parallel.waitForAll(table.unpack(fns)) end
        for name, entry in pairs(idx) do
            if not entry.displayName then
                entry.displayName = DISPLAY_NAME[name]
            end
        end
    end

    return idx
end

-- Decrement an item's stock at a specific (chest, slot) by `count`. Used
-- by !give to keep the index honest after a successful pull, without
-- triggering a full rebuild.
function M.recordWithdrawal(idx, itemName, chest, slot, count)
    local entry = idx[itemName]
    if not entry then return end
    entry.total = entry.total - count
    -- Find and decrement the matching location. We may have multiple
    -- entries for the same chest+slot if the index was built across
    -- chest changes; iterate all matches.
    local kept = {}
    local left = count
    for _, loc in ipairs(entry.locations) do
        if loc.chest == chest and loc.slot == slot and left > 0 then
            local take = math.min(left, loc.count)
            loc.count = loc.count - take
            left = left - take
        end
        if loc.count > 0 then kept[#kept + 1] = loc end
    end
    entry.locations = kept
    if entry.total <= 0 or #entry.locations == 0 then
        idx[itemName] = nil
    end
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
