-- Pack: arkana-aeronautics
-- Computer: basic computer with wired modem (advanced works too — but no colour/mouse needed)
-- Peripherals expected:
--   N× inventory          (storage chests on the wired modem network)
--   1× inventory          (delivery chest — set CONFIG.delivery_chest, items pushed here on !give)
--   0..1× inventory       (input chest — set CONFIG.input_chest, drained into storage)
--   1× chat_box           (Advanced Peripherals)
--   0..1× inventory_manager + linked Memory Card (optional direct-to-player)

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local log_lib  = require("lib.log")
local index    = require("storage.index")
local commands = require("storage.commands")
local defrag   = require("storage.defrag")

local CONFIG = {
    delivery_chest    = nil,   -- e.g. "sophisticatedstorage:chest_3" — REQUIRED
    input_chest       = nil,   -- optional: items here get auto-drained into storage
    inv_manager_dir   = "up",
    reindex_period_s  = 60,
    ingest_period_s   = 5,
    whitelist         = nil,   -- nil = open; { ["alice"]=true } = whitelist
}

local function loadSettings()
    settings.define("delivery_chest", {
        description = "Network name of the chest items are pushed to on !give",
        type        = "string",
    })
    settings.define("input_chest", {
        description = "Optional: chest auto-drained into storage on a timer",
        type        = "string",
    })
    settings.load()
    local v = settings.get("delivery_chest")
    if v and v ~= "" then CONFIG.delivery_chest = v end
    local i = settings.get("input_chest")
    if i and i ~= "" then CONFIG.input_chest = i end
end

local function isReservedChest(name)
    return name == CONFIG.delivery_chest or name == CONFIG.input_chest
end

local function discoverStorageInventories()
    local out = {}
    for _, p in ipairs({ peripheral.find("inventory") }) do
        local name = peripheral.getName(p)
        if not isReservedChest(name) then
            out[#out + 1] = { name = name, inv = p }
        end
    end
    return out
end

-- pushItems errors (instead of returning 0) when the target peripheral name
-- doesn't resolve. That's noisy when chests come and go on the network, so
-- swallow the error and let the caller move on.
local function safePush(from, toName, fromSlot, count)
    local ok, moved = pcall(from.pushItems, toName, fromSlot, count)
    if not ok then return 0, moved end
    return moved or 0
end

-- The Advanced Peripherals chat_box rate-limits per source — if you fire 10
-- sends back-to-back the back end silently drops most of them. Bundle short
-- lines into ≤200-char chunks and sleep between sends.
local CHUNK_MAX = 200
local CHAT_GAP_S = 1.1

local function chunkLines(lines)
    local out, cur = {}, ""
    for _, l in ipairs(lines) do
        if #cur == 0 then
            cur = l
        elseif #cur + 3 + #l > CHUNK_MAX then
            out[#out + 1] = cur ; cur = l
        else
            cur = cur .. " | " .. l
        end
    end
    if #cur > 0 then out[#out + 1] = cur end
    return out
end

local function sendLines(chat, user, lines)
    local chunks = chunkLines(lines)
    for i, ch in ipairs(chunks) do
        pcall(chat.sendMessageToPlayer, ch, user, "storage")
        if i < #chunks then sleep(CHAT_GAP_S) end
    end
end

local function delivered(chat, user, name, total)
    if total > 0 then
        sendLines(chat, user, { ("delivered %d × %s"):format(total, name) })
    else
        sendLines(chat, user, { ("nothing matched %q"):format(name) })
    end
end

local function handleGive(state, args, user)
    local chat, idx = state.chat, state.idx
    -- Last arg is the count if numeric; everything before it is the query.
    local count = 1
    local queryTokens = {}
    if #args >= 1 then
        local tail = tonumber(args[#args])
        if tail then
            count = tail
            for i = 1, #args - 1 do queryTokens[#queryTokens + 1] = args[i] end
        else
            for i = 1, #args do queryTokens[#queryTokens + 1] = args[i] end
        end
    end
    if #queryTokens == 0 then
        sendLines(chat, user, { "usage: !give <name...> [count]" })
        return
    end

    local q = table.concat(queryTokens, " ")
    log_lib.info("give: q=%q count=%d", q, count)

    local matches = index.matchNames(idx, queryTokens)
    local matchCount = 0 ; for _ in pairs(matches) do matchCount = matchCount + 1 end
    local ranked  = index.rankSort(matches, index.tokenize(queryTokens))
    -- Only pull from the single best-ranked item. Avoids "andesite" pulling
    -- andesite_funnel slots when minecraft:andesite is also stocked.
    local pickedName
    local total = 0
    local attempts, zeroPushes = 0, 0
    -- Record per-location withdrawals so we can apply them incrementally
    -- to the index instead of triggering a full rebuild after.
    local withdrawals = {}
    if ranked[1] then
        local entry = ranked[1].entry
        pickedName  = ranked[1].name
        log_lib.info("give: matches=%d picked=%s locations=%d total_in_idx=%d",
            matchCount, pickedName, #entry.locations, entry.total)
        for _, loc in ipairs(entry.locations) do
            if total >= count then break end
            local from = peripheral.wrap(loc.chest)
            if not from then
                log_lib.warn("give: peripheral.wrap(%s) returned nil", loc.chest)
            else
                -- Drain this location: some inventory backends (especially
                -- Sophisticated Storage's Storage Controller pseudo-slots)
                -- cap a single pushItems() to one source stack even when the
                -- logical slot holds more. Loop until pushItems returns 0
                -- or the request is filled. Bounded — moved>0 strictly
                -- decreases (count - total) so finite iterations.
                while total < count do
                    attempts = attempts + 1
                    local req = count - total
                    local moved, err = safePush(from, CONFIG.delivery_chest, loc.slot, req)
                    log_lib.info("give: push %s slot=%d req=%d moved=%d%s",
                        loc.chest, loc.slot, req, moved,
                        err and (" err=" .. tostring(err)) or "")
                    if err then log_lib.warn("push from %s: %s", loc.chest, tostring(err)) end
                    if moved == 0 then
                        zeroPushes = zeroPushes + 1
                        break
                    end
                    total = total + moved
                    withdrawals[#withdrawals + 1] = { chest = loc.chest, slot = loc.slot, count = moved }
                end
            end
        end
    else
        log_lib.info("give: no matches for %q", q)
    end
    log_lib.info("give: done attempts=%d zero_pushes=%d total=%d/%d",
        attempts, zeroPushes, total, count)
    if total > 0 then
        -- Apply withdrawals incrementally instead of rebuilding the whole
        -- index — for N chests × 27 slots, full rebuild is O(N) yields and
        -- was the dominant source of post-give lag.
        for _, w in ipairs(withdrawals) do
            index.recordWithdrawal(state.idx, pickedName, w.chest, w.slot, w.count)
        end
        delivered(chat, user, pickedName, total)
    elseif pickedName then
        -- Match found but nothing moved: usually delivery chest full or
        -- destination peripheral name not on the network.
        sendLines(chat, user, {
            ("matched %s but moved 0 — delivery chest full or %s unreachable?"):format(
                pickedName, CONFIG.delivery_chest),
        })
    else
        delivered(chat, user, q, 0)
    end
end

local function handleFind(chat, idx, args, user)
    if #args == 0 then
        sendLines(chat, user, { "usage: !find <name...>" }) ; return
    end
    local matches = index.matchNames(idx, args)
    local rows    = index.rankSort(matches, index.tokenize(args))
    local lines = {}
    for i, r in ipairs(rows) do
        if i > 20 then break end
        lines[#lines + 1] = ("%s: %d (%d)"):format(r.name, r.entry.total, #r.entry.locations)
    end
    if #lines == 0 then
        lines[1] = ("no match for %q"):format(table.concat(args, " "))
    end
    sendLines(chat, user, lines)
end

local function handleDefrag(state, _args, user)
    local chat = state.chat
    sendLines(chat, user, { "defragmenting…" })
    log_lib.info("defrag: starting (%d chests, %d items)",
        #state.invs, (function() local n = 0 for _ in pairs(state.idx) do n = n + 1 end return n end)())
    local stats = defrag.run(state.idx, state.invs)
    -- Index now stale (slot positions shifted). Rebuild before reporting so
    -- subsequent !give/!find see fresh state.
    state.idx = index.build(state.invs)
    log_lib.info("defrag: done items=%d moves=%d moved=%d slots_freed=%d sort_passes=%d",
        stats.items_processed, stats.moves, stats.moved_count, stats.slots_freed, stats.sort_passes or 0)
    sendLines(chat, user, {
        ("defrag: %d items, %d moves, %d items moved, %d slots freed (sort=%d passes)"):format(
            stats.items_processed, stats.moves, stats.moved_count, stats.slots_freed, stats.sort_passes or 0),
    })
end

local function handleList(chat, idx, args, user)
    local prefix = args[1]
    local limit  = tonumber(args[2]) or 20
    local rows = index.topByCount(idx, limit, prefix)
    if #rows == 0 then sendLines(chat, user, { "(empty)" }) ; return end
    local lines = {}
    for _, r in ipairs(rows) do
        lines[#lines + 1] = ("%s: %d"):format(r.name, r.count)
    end
    sendLines(chat, user, lines)
end

local function isAuthed(user)
    if not CONFIG.whitelist then return true end
    return CONFIG.whitelist[user] == true
end

local function ingestOnce(invs)
    if not CONFIG.input_chest then return 0 end
    local input = peripheral.wrap(CONFIG.input_chest)
    if not input then return 0 end
    -- input.list() can throw (peripheral detached mid-tick) or return nil
    -- (peripheral wrap is stale). Tolerate both rather than kill the
    -- ingest loop — the parallel chatLoop must keep running.
    local ok, listing = pcall(input.list)
    if not ok then
        log_lib.warn("ingest: %s.list() errored: %s",
            tostring(CONFIG.input_chest), tostring(listing))
        return 0
    end
    if type(listing) ~= "table" then
        log_lib.warn("ingest: %s.list() returned %s — input chest detached?",
            tostring(CONFIG.input_chest), type(listing))
        return 0
    end
    local total_moved = 0
    for slot, item in pairs(listing) do
        local remaining = item.count
        for _, target in ipairs(invs) do
            if remaining <= 0 then break end
            local moved = safePush(input, target.name, slot, remaining)
            remaining = remaining - moved
            total_moved = total_moved + moved
        end
    end
    return total_moved
end

local function chatLoop(state)
    local reindexAt = os.startTimer(CONFIG.reindex_period_s)
    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "chat" then
            local _, user, msg = table.unpack(ev)
            if isAuthed(user) then
                local cmd, args = commands.parse(msg)
                -- Wrap dispatch: a chat_box throw (rate limit, peripheral
                -- detach mid-send) must not kill chatLoop and silently end
                -- parallel.waitForAny.
                local ok, err = pcall(function()
                    if cmd == "give"     then handleGive(state, args, user)
                    elseif cmd == "find" then handleFind(state.chat, state.idx, args, user)
                    elseif cmd == "list" then handleList(state.chat, state.idx, args, user)
                    elseif cmd == "reindex" then
                        state.invs = discoverStorageInventories()
                        state.idx  = index.build(state.invs)
                        sendLines(state.chat, user, { "reindexed" })
                    elseif cmd == "defrag" then handleDefrag(state, args, user)
                    elseif cmd == "help" then
                        sendLines(state.chat, user, commands.help())
                    end
                end)
                if not ok then log_lib.warn("handler %s: %s", tostring(cmd), tostring(err)) end
            end
        elseif ev[1] == "timer" and ev[2] == reindexAt then
            state.invs = discoverStorageInventories()
            state.idx  = index.build(state.invs)
            reindexAt = os.startTimer(CONFIG.reindex_period_s)
        elseif ev[1] == "peripheral" or ev[1] == "peripheral_detach" then
            log_lib.info("network change (%s %s) — reindexing", ev[1], tostring(ev[2]))
            state.invs = discoverStorageInventories()
            state.idx  = index.build(state.invs)
        end
    end
end

local function ingestLoop(state)
    if not CONFIG.input_chest then return end
    log_lib.info("ingest from %s every %ds", CONFIG.input_chest, CONFIG.ingest_period_s)
    while true do
        sleep(CONFIG.ingest_period_s)
        local moved = ingestOnce(state.invs)
        if moved > 0 then
            log_lib.info("ingested %d items", moved)
            -- Trigger reindex after ingest so !find/!give see new items quickly.
            state.idx = index.build(state.invs)
        end
    end
end

local function run()
    loadSettings()
    assert(CONFIG.delivery_chest,
        "delivery chest unset. Run in shell: set delivery_chest <chest_name>")

    local chat = peripheral.find("chat_box")
    assert(chat, "no chat_box found on the network")

    log_lib.attach({ prefix = "[storage]", chat = chat, chat_prefix = "storage" })

    local invs = discoverStorageInventories()
    log_lib.info("indexing %d chests", #invs)
    local idx = index.build(invs)
    log_lib.info("index built: %d distinct items", (function()
        local n = 0 ; for _ in pairs(idx) do n = n + 1 end ; return n end)())

    local state = { chat = chat, idx = idx, invs = invs }
    parallel.waitForAny(
        function() chatLoop(state) end,
        function() ingestLoop(state) end
    )
end

run()
