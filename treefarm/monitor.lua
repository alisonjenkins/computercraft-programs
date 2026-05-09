-- Pack: arkana-aeronautics
-- Computer: basic computer with wired modem (advanced only useful if you wire a coloured monitor)
-- Peripherals expected (over wired modem):
--   1× inventory (output buffer chest of the Create saw farm)
--   1× chat_box           (Advanced Peripherals)
--   0..1× redstone_relay  (optional: jam-recovery pulse on a Create clutch)
--   0..1× monitor         (optional: status display)

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local log_lib = require("lib.log")

local CONFIG = {
    buffer_name      = nil,                -- nil = first inventory found
    sample_period_s  = 1,
    jam_threshold_s  = 300,
    sapling_min      = 8,
    sapling_max      = 256,
    relay_side       = "front",            -- which side of the relay block fires the clutch
    relay_pulse_s    = 1.0,
}

local LOG_TAGS    = { "minecraft:logs", "c:logs" }
local SAPLING_TAG = "minecraft:saplings"

local function findBuffer()
    if CONFIG.buffer_name then
        return peripheral.wrap(CONFIG.buffer_name), CONFIG.buffer_name
    end
    local p = peripheral.find("inventory")
    return p, p and peripheral.getName(p) or nil
end

local function classify(detail)
    if not detail or not detail.tags then return "other" end
    for _, t in ipairs(LOG_TAGS) do
        if detail.tags[t] then return "log" end
    end
    if detail.tags[SAPLING_TAG] then return "sapling" end
    return "other"
end

local function snapshot(buf)
    local logs, saplings, others = 0, 0, 0
    for slot, item in pairs(buf.list()) do
        local detail = buf.getItemDetail(slot)
        local kind = classify(detail)
        if     kind == "log"     then logs = logs + item.count
        elseif kind == "sapling" then saplings = saplings + item.count
        else                          others = others + item.count end
    end
    return { logs = logs, saplings = saplings, others = others }
end

local function pulseRelay(relay)
    if not relay then return end
    relay.setOutput(CONFIG.relay_side, true)
    sleep(CONFIG.relay_pulse_s)
    relay.setOutput(CONFIG.relay_side, false)
end

local function run()
    local buf, bufName = findBuffer()
    assert(buf, "no inventory peripheral found on the network")

    local chat   = peripheral.find("chat_box")
    local relay  = peripheral.find("redstone_relay")
    local mon    = peripheral.find("monitor")
    if mon then mon.clear() ; mon.setCursorPos(1, 1) end

    log_lib.attach({
        prefix      = "[treefarm]",
        chat        = chat,
        chat_prefix = "treefarm",
        monitor     = mon,
    })

    log_lib.info("buffer = %s", bufName)
    if chat  then log_lib.info("chat_box online") end
    if relay then log_lib.info("redstone_relay online (jam recovery armed)") end

    local last = snapshot(buf)
    local lastChange = os.epoch("utc")
    local jamAlerted, lowSapAlerted = false, false
    local logsPerMin = 0
    local minuteWindow, minuteStart = last.logs, os.epoch("utc")

    while true do
        sleep(CONFIG.sample_period_s)
        local now = snapshot(buf)

        if now.logs ~= last.logs or now.saplings ~= last.saplings then
            lastChange = os.epoch("utc")
            jamAlerted = false
        end

        local idle_s = (os.epoch("utc") - lastChange) / 1000
        if idle_s >= CONFIG.jam_threshold_s and not jamAlerted then
            log_lib.warn("jammed: no items for %ds (logs=%d, saps=%d)",
                math.floor(idle_s), now.logs, now.saplings)
            jamAlerted = true
            pulseRelay(relay)
        end

        if now.saplings < CONFIG.sapling_min and not lowSapAlerted then
            log_lib.warn("low saplings: %d (min=%d)", now.saplings, CONFIG.sapling_min)
            lowSapAlerted = true
        elseif now.saplings >= CONFIG.sapling_min then
            lowSapAlerted = false
        end

        if (os.epoch("utc") - minuteStart) >= 60000 then
            logsPerMin = now.logs - minuteWindow
            minuteWindow, minuteStart = now.logs, os.epoch("utc")
        end

        if mon then
            mon.clear() ; mon.setCursorPos(1, 1)
            mon.write(("Logs:%d  Saps:%d"):format(now.logs, now.saplings))
            mon.setCursorPos(1, 2)
            mon.write(("Logs/min:%d  Idle:%ds"):format(logsPerMin, math.floor(idle_s)))
        end

        last = now
    end
end

run()
