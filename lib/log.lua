local M = {}

local sinks = {
    term = true,
    chat = nil,
    monitor = nil,
    prefix = "[log]",
    chat_prefix = nil,
}

function M.attach(opts)
    if opts.chat ~= nil then sinks.chat = opts.chat end
    if opts.monitor ~= nil then sinks.monitor = opts.monitor end
    if opts.term ~= nil then sinks.term = opts.term end
    if opts.prefix then sinks.prefix = opts.prefix end
    if opts.chat_prefix then sinks.chat_prefix = opts.chat_prefix end
end

local function emit(level, msg)
    local line = ("%s [%s] %s"):format(sinks.prefix, level, msg)
    if sinks.term then print(line) end
    if sinks.monitor then
        local ok = pcall(function()
            sinks.monitor.write(line)
            sinks.monitor.scroll(1)
            local _, h = sinks.monitor.getSize()
            sinks.monitor.setCursorPos(1, h)
        end)
        if not ok then sinks.monitor = nil end
    end
    if sinks.chat and (level == "WARN" or level == "ERROR") then
        local ok = pcall(sinks.chat.sendMessage, msg, sinks.chat_prefix or sinks.prefix)
        if not ok then sinks.chat = nil end
    end
end

function M.info(fmt, ...)  emit("INFO",  fmt:format(...)) end
function M.warn(fmt, ...)  emit("WARN",  fmt:format(...)) end
function M.error(fmt, ...) emit("ERROR", fmt:format(...)) end

return M
