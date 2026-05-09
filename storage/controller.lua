-- Pack: arkana-aeronautics
-- Computer: basic computer with wired modem (advanced works too — but no colour/mouse needed)
-- Peripherals expected:
--   N× inventory          (storage chests on the wired modem network)
--   1× inventory          (the "delivery slot" chest — set CONFIG.delivery_chest)
--   1× chat_box           (Advanced Peripherals)
--   0..1× inventory_manager + linked Memory Card (optional direct-to-player)

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local log_lib  = require("lib.log")
local index    = require("storage.index")
local commands = require("storage.commands")

local CONFIG = {
    delivery_chest    = nil,   -- e.g. "sophisticatedstorage:chest_3" — REQUIRED
    inv_manager_dir   = "up",  -- direction from inventory_manager to its adjacent chest
    reindex_period_s  = 60,
    whitelist         = nil,   -- nil = open; { ["alice"]=true } = whitelist
}

local function loadSettings()
    if settings.load("/.storage_settings") then
        local v = settings.get("delivery_chest")
        if v then CONFIG.delivery_chest = v end
    end
end

local function discoverInventories()
    local skip = { [CONFIG.delivery_chest or ""] = true }
    local out = {}
    for _, p in ipairs({ peripheral.find("inventory") }) do
        local name = peripheral.getName(p)
        if not skip[name] then out[#out + 1] = { name = name, inv = p } end
    end
    return out
end

local function delivered(chat, user, name, count, total)
    local label = name
    if total > 0 then
        chat.sendMessageToPlayer(("delivered %d × %s"):format(count, label), user, "storage")
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
                local moved = from.pushItems(CONFIG.delivery_chest, loc.slot, count - total)
                total = total + moved
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

local function run()
    loadSettings()
    assert(CONFIG.delivery_chest,
        "set CONFIG.delivery_chest in storage/controller.lua or via settings")

    local chat = peripheral.find("chat_box")
    assert(chat, "no chat_box found on the network")

    log_lib.attach({ prefix = "[storage]", chat = chat, chat_prefix = "storage" })

    local invs = discoverInventories()
    log_lib.info("indexing %d chests", #invs)
    local idx = index.build(invs)
    log_lib.info("index built: %d distinct items", (function()
        local n = 0 ; for _ in pairs(idx) do n = n + 1 end ; return n end)())

    local reindexAt = os.startTimer(CONFIG.reindex_period_s)

    while true do
        local ev = { os.pullEvent() }
        if ev[1] == "chat" then
            local _, user, msg = table.unpack(ev)
            if isAuthed(user) then
                local cmd, args = commands.parse(msg)
                if cmd == "give"     then handleGive(chat, idx, args, user)
                elseif cmd == "find" then handleFind(chat, idx, args, user)
                elseif cmd == "list" then handleList(chat, idx, args, user)
                elseif cmd == "reindex" then
                    invs = discoverInventories()
                    idx = index.build(invs)
                    chat.sendMessageToPlayer("reindexed", user, "storage")
                elseif cmd == "help" then
                    for _, l in ipairs(commands.help()) do
                        chat.sendMessageToPlayer(l, user, "storage")
                    end
                end
            end
        elseif ev[1] == "timer" and ev[2] == reindexAt then
            invs = discoverInventories()
            idx = index.build(invs)
            reindexAt = os.startTimer(CONFIG.reindex_period_s)
        end
    end
end

run()
