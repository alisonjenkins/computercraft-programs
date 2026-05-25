-- Defragment storage network: group like items into one chest where possible,
-- then merge partial stacks within each chest. Capacity-aware via pushItems'
-- moved-count return — Sophisticated Storage stack-upgraded slots accept
-- >64 transparently because we never hard-code 64; we just push and trust
-- what the peripheral says it accepted.
local M = {}

-- Pass 1: per item, pick chest holding most of it (primary) and push every
-- other location there. Falls back when primary full: tries other chests
-- that already hold this item by count desc (keeps it dense), then any
-- remaining chest with room. Lets the destination pick the target slot —
-- fills matching partials first, then empties.
local function groupPass(idx, wrap, invs, stats, yieldEvery)
    local allChests = {}
    for _, e in ipairs(invs) do allChests[#allChests + 1] = e.name end

    local nameCount = 0
    for _, entry in pairs(idx) do
        local byChest = {}
        local chests = 0
        for _, l in ipairs(entry.locations) do
            if not byChest[l.chest] then chests = chests + 1 end
            byChest[l.chest] = (byChest[l.chest] or 0) + l.count
        end
        if chests >= 2 then
            local primary, best = nil, -1
            for chest, c in pairs(byChest) do
                if c > best then primary, best = chest, c end
            end
            -- Destination order: primary, then other chests with this item
            -- by count desc, then chests without it (last-resort spillover).
            local secondaries = {}
            for chest in pairs(byChest) do
                if chest ~= primary then secondaries[#secondaries + 1] = chest end
            end
            table.sort(secondaries, function(a, b) return byChest[a] > byChest[b] end)
            local ranked = { primary }
            for _, c in ipairs(secondaries) do ranked[#ranked + 1] = c end
            local seen = { [primary] = true }
            for _, c in ipairs(secondaries) do seen[c] = true end
            for _, c in ipairs(allChests) do
                if not seen[c] then ranked[#ranked + 1] = c end
            end

            for _, l in ipairs(entry.locations) do
                if l.chest ~= primary and l.count > 0 then
                    local from = wrap[l.chest]
                    if from then
                        local remaining = l.count
                        for _, dest in ipairs(ranked) do
                            if remaining == 0 then break end
                            if dest ~= l.chest then
                                local ok, moved = pcall(from.pushItems, dest, l.slot, remaining)
                                moved = (ok and moved) or 0
                                if moved > 0 then
                                    stats.moves = stats.moves + 1
                                    stats.moved_count = stats.moved_count + moved
                                    remaining = remaining - moved
                                end
                            end
                        end
                        if remaining == 0 then
                            stats.slots_freed = stats.slots_freed + 1
                        end
                    end
                end
            end
            stats.items_processed = stats.items_processed + 1
        end
        nameCount = nameCount + 1
        if nameCount % yieldEvery == 0 then sleep(0) end
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
    local stats = {
        items_processed = 0,
        moves           = 0,
        moved_count     = 0,
        slots_freed     = 0,
    }
    local wrap = {}
    for _, e in ipairs(invs) do wrap[e.name] = e.inv end

    groupPass(idx, wrap, invs, stats, yieldEvery)
    mergePass(invs, stats, yieldEvery)
    return stats
end

return M
