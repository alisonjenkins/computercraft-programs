-- Persists miner state across reboots. CC:T's textutils.serialize/unserialize
-- handle Lua tables; we wrap with atomic write (tmp file + fs.move).

local M = {}
local PATH = "/.miner_state"
local TMP  = "/.miner_state.tmp"

function M.load()
    if not fs.exists(PATH) then return nil end
    local f = fs.open(PATH, "r")
    if not f then return nil end
    local body = f.readAll()
    f.close()
    local ok, t = pcall(textutils.unserialize, body)
    if not ok or type(t) ~= "table" then return nil end
    return t
end

function M.save(state)
    if fs.exists(TMP) then fs.delete(TMP) end
    local f = fs.open(TMP, "w")
    f.write(textutils.serialize(state))
    f.close()
    if fs.exists(PATH) then fs.delete(PATH) end
    fs.move(TMP, PATH)
end

function M.clear()
    if fs.exists(PATH) then fs.delete(PATH) end
    if fs.exists(TMP)  then fs.delete(TMP)  end
end

return M
