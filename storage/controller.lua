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

local function delivered(chat, user, name, count, total)
    if total > 0 then
        chat.sendMessageToPlayer(("delivered %d × %s"):format(count, name), user, "storage")
    else
        chat.sendMessageToPlayer(("nothing matched %q"):format(name), user, "storage")
    end
end

local function handleGive(chat, idx, args, user)
    local query = args[1]
    local count = tonumber(args[2] or "1")
    if not query or not count then
        chat.sendMessageToPlayer("usage: !give <name> <count>", user, "storage")
        return
    end
    local matches = index.matchNames(idx, query)
    local total = 0
    for name, entry in pairs(matches) do
        if total >= count then break end
        for _, loc in ipairs(entry.locations) do
            if total >= count then break end
            local from = peripheral.wrap(loc.chest)
            if from then
                local moved, err = safePush(from, CONFIG.delivery_chest, loc.slot, count - total)
                total = total + moved
                if err then log_lib.warn("push from %s: %s", loc.chest, tostring(err)) end
            end
        end
        if total > 0 then delivered(chat, user, name, total, total) ; break end
    end
    if total == 0 then delivered(chat, user, query, 0, 0) end
end

local function handleFind(chat, idx, args, user)
    local query = args[1]
    if not query then
        chat.sendMessageToPlayer("usage: !find <name>", user, "storage") ; return
    end
    local matches = index.matchNames(idx, query)
    local lines = {}
    for name, entry in pairs(matches) do
        lines[#lines + 1] = ("%s: %d (%d locs)"):format(name, entry.total, #entry.locations)
        if #lines >= 5 then break end
    end
    if #lines == 0 then lines[1] = ("no match for %q"):format(query) end
    for _, l in ipairs(lines) do chat.sendMessageToPlayer(l, user, "storage") end
end

local function handleList(chat, idx, args, user)
    local prefix = args[1]
    local rows = index.topByCount(idx, 10, prefix)
    if #rows == 0 then chat.sendMessageToPlayer("(empty)", user, "storage") ; return end
    for _, r in ipairs(rows) do
        chat.sendMessageToPlayer(("%s: %d"):format(r.name, r.count), user, "storage")
    end
end

local function isAuthed(user)
    if not CONFIG.whitelist then return true end
    return CONFIG.whitelist[user] == true
end

local function ingestOnce(invs)
    if not CONFIG.input_chest then return 0 end
    local input = peripheral.wrap(CONFIG.input_chest)
    if not input then return 0 end
    local total_moved = 0
    for slot, item in pairs(input.list()) do
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
                if cmd == "give"     then handleGive(state.chat, state.idx, args, user)
                elseif cmd == "find" then handleFind(state.chat, state.idx, args, user)
                elseif cmd == "list" then handleList(state.chat, state.idx, args, user)
                elseif cmd == "reindex" then
                    state.invs = discoverStorageInventories()
                    state.idx  = index.build(state.invs)
                    state.chat.sendMessageToPlayer("reindexed", user, "storage")
                elseif cmd == "help" then
                    for _, l in ipairs(commands.help()) do
                        state.chat.sendMessageToPlayer(l, user, "storage")
                    end
                end
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
