-- Defragment storage network. Two passes:
--   1. sortPass — chests ranked by per-slot capacity desc (so SS
--      stack-upgrade III/IV chests come first), items ranked by total
--      count desc; high-volume items assigned to high-cap chests so the
--      expensive slots aren't wasted on rare items. Multi-pass eviction
--      with overflow fallback when a target chest is full.
--   2. mergePass — collapse partial stacks of the same item within each
--      chest. Trusts pushItems' returned moved count so SS upgraded slots
--      fill to their real getItemLimit (>64) without us computing it.
local M = {}

-- Sample per-item effective stack limit. inventory.getItemLimit(slot)
-- returns the slot's real cap for the contained item — Sophisticated
-- Storage stack upgrades and item-specific minimums (ender pearls=16,
-- tools=1) both factor in. Probe one occupied slot per item; parallelise
-- to keep cost ~one tick total instead of N×50ms serial.
local function sampleItemLimits(idx, wrap)
    local limits = {}
    local fns = {}
    for name, entry in pairs(idx) do
        local loc = entry.locations[1]
        if loc and wrap[loc.chest] then
            local chest = wrap[loc.chest]
            local slot, n = loc.slot, name
            fns[#fns + 1] = function()
                local ok, lim = pcall(chest.getItemLimit, slot)
                if ok and type(lim) == "number" and lim > 0 then
                    limits[n] = lim
                end
            end
        end
    end
    if #fns > 0 then parallel.waitForAll(table.unpack(fns)) end
    return limits
end

-- Probe each chest for size() + base per-slot capacity. getItemLimit on
-- slot 1 returns the chest's stack-upgrade-aware cap (e.g. 64 vanilla,
-- 256 SS upgrade III, 1024 upgrade IV). Parallelise — one tick total.
local function probeChests(invs)
    local info = {}
    local fns = {}
    for i, e in ipairs(invs) do
        local ci = { entry = e, name = e.name, size = 27, cap = 64 }
        info[i] = ci
        fns[#fns + 1] = function()
            local ok, sz = pcall(e.inv.size)
            if ok and type(sz) == "number" then ci.size = sz end
            local ok2, lim = pcall(e.inv.getItemLimit, 1)
            if ok2 and type(lim) == "number" and lim > 0 then ci.cap = lim end
        end
    end
    if #fns > 0 then parallel.waitForAll(table.unpack(fns)) end
    return info
end

-- Build target-chest plan. Chests sorted by per-slot capacity desc (so
-- highest-upgrade SS chests come first); name asc as tiebreaker for stable
-- ordering. Items sorted by total count desc — high-volume items consume
-- the upgraded chests' slots first so we don't waste 1024-stack capacity
-- on items we only have 4 of. Per-item slot demand uses the item's real
-- per-slot limit so quota math is exact.
local function planAssignment(idx, invs)
    local plan = {}
    if #invs == 0 then return plan, {} end

    local chestInfo = probeChests(invs)
    table.sort(chestInfo, function(a, b)
        if a.cap ~= b.cap then return a.cap > b.cap end
        return a.name < b.name
    end)
    local chestOrder = {}
    for _, ci in ipairs(chestInfo) do chestOrder[#chestOrder + 1] = ci.entry end

    local names = {}
    for name in pairs(idx) do names[#names + 1] = name end
    if #names == 0 then return plan, chestOrder end
    table.sort(names, function(a, b)
        if idx[a].total ~= idx[b].total then return idx[a].total > idx[b].total end
        return a < b
    end)

    local wrap = {}
    for _, e in ipairs(invs) do wrap[e.name] = e.inv end
    local limits = sampleItemLimits(idx, wrap)

    local chestIdx = 1
    local quotaLeft = chestInfo[1].size
    for _, n in ipairs(names) do
        local lim = limits[n] or 64
        local demand = math.max(1, math.ceil(idx[n].total / lim))
        while demand > quotaLeft and chestIdx < #chestInfo do
            chestIdx = chestIdx + 1
            quotaLeft = chestInfo[chestIdx].size
        end
        plan[n] = chestOrder[chestIdx].name
        quotaLeft = quotaLeft - demand
    end
    return plan, chestOrder
end

-- Multi-pass eviction sweep. Each pass: for every chest, push items that
-- aren't assigned here to their target. If target full, walk forward
-- through alphabetical chest order, then backward, until something
-- accepts the stack or all chests refuse. Pass count capped at 5 so a
-- truly full network can't loop forever.
local function sortPass(idx, invs, stats, yieldEvery, emit)
    local plan, chestOrder = planAssignment(idx, invs)
    if not plan then return end
    for _ in pairs(plan) do
        stats.items_processed = stats.items_processed + 1
    end
    emit("planned " .. stats.items_processed .. " items across " .. #chestOrder .. " chests")

    local chestNames = {}
    for i, e in ipairs(chestOrder) do chestNames[i] = e.name end
    local chestIdxOf = {}
    for i, n in ipairs(chestNames) do chestIdxOf[n] = i end

    for pass = 1, 5 do
        local movesThisPass = 0
        -- Iterate in alphabetical chestOrder, not invs discovery order, so
        -- items moved to earlier chests aren't re-processed within the same
        -- pass.
        for i, e in ipairs(chestOrder) do
            local ok, list = pcall(e.inv.list)
            if ok and type(list) == "table" then
                for slot, item in pairs(list) do
                    local target = plan[item.name]
                    if target and target ~= e.name then
                        local startIdx = chestIdxOf[target] or 1
                        local remaining = item.count
                        local function tryPush(destIdx)
                            if remaining == 0 then return end
                            local dest = chestNames[destIdx]
                            if not dest or dest == e.name then return end
                            local pok, moved = pcall(e.inv.pushItems, dest, slot, remaining)
                            moved = (pok and moved) or 0
                            if moved > 0 then
                                stats.moves = stats.moves + 1
                                stats.moved_count = stats.moved_count + moved
                                movesThisPass = movesThisPass + 1
                                remaining = remaining - moved
                            end
                        end
                        tryPush(startIdx)
                        for d = startIdx + 1, #chestNames do tryPush(d) end
                        for d = startIdx - 1, 1, -1 do tryPush(d) end
                        if remaining == 0 then
                            stats.slots_freed = stats.slots_freed + 1
                        end
                    end
                end
            end
            if i % yieldEvery == 0 then sleep(0) end
        end
        stats.sort_passes = (stats.sort_passes or 0) + 1
        emit(("sort pass %d: %d moves"):format(pass, movesThisPass))
        if movesThisPass == 0 then break end
    end
end

-- Pass 2: within each chest, merge partial stacks of the same item into the
-- largest slot. pushItems with explicit toSlot respects that slot's
-- getItemLimit, so SS upgraded slots fill to their real capacity (256, 1024,
-- whatever) without us computing it.
local function mergePass(invs, stats, yieldEvery)
    for i, e in ipairs(invs) do
        local ok, list = pcall(e.inv.list)
        if ok and type(list) == "table" then
            local byName = {}
            for slot, item in pairs(list) do
                local g = byName[item.name]
                if not g then g = {}; byName[item.name] = g end
                g[#g + 1] = { slot = slot, count = item.count }
            end
            for _, slots in pairs(byName) do
                if #slots >= 2 then
                    table.sort(slots, function(a, b) return a.count > b.count end)
                    for s = #slots, 2, -1 do
                        local src = slots[s]
                        for d = 1, s - 1 do
                            if src.count == 0 then break end
                            local dst = slots[d]
                            local pok, moved = pcall(e.inv.pushItems, e.name, src.slot, src.count, dst.slot)
                            moved = (pok and moved) or 0
                            if moved > 0 then
                                stats.moves = stats.moves + 1
                                stats.moved_count = stats.moved_count + moved
                                src.count = src.count - moved
                                dst.count = dst.count + moved
                                if src.count == 0 then
                                    stats.slots_freed = stats.slots_freed + 1
                                end
                            end
                        end
                    end
                end
            end
        end
        if i % yieldEvery == 0 then sleep(0) end
    end
end

function M.run(idx, invs, opts)
    opts = opts or {}
    local yieldEvery = opts.yield_every or 8
    local emit = opts.on_status or function(_msg) end
    local stats = {
        items_processed = 0,
        moves           = 0,
        moved_count     = 0,
        slots_freed     = 0,
        sort_passes     = 0,
    }
    emit("sort start")
    sortPass(idx, invs, stats, yieldEvery, emit)
    local sortMoves = stats.moves
    emit("merge start")
    mergePass(invs, stats, yieldEvery)
    emit(("merge done: %d moves"):format(stats.moves - sortMoves))
    return stats
end

return M
