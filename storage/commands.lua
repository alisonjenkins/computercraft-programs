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
        "!list [prefix]     - top items by count",
        "!find <name>       - locate an item",
        "!give <name> <n>   - deliver n of name",
        "!reindex           - force full rescan",
        "!help              - this message",
    }
end

return M
