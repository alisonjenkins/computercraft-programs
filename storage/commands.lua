local M = {}

local function tokenize(s)
    local out = {}
    for w in s:gmatch("%S+") do out[#out + 1] = w end
    return out
end

function M.parse(message)
    if not message or message:sub(1, 1) ~= "!" then return nil end
    local toks = tokenize(message:sub(2))
    if #toks == 0 then return nil end
    local cmd = table.remove(toks, 1):lower()
    return cmd, toks
end

function M.help()
    return {
        "!list [prefix] [n]    - top n items by count (default 20)",
        "!find <name...>       - fuzzy locate (multi-word AND match)",
        "!give <name...> [n]   - deliver n of best match (default 1)",
        "!reindex              - force full rescan",
        "!help                 - this message",
    }
end

return M
