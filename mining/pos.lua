-- Pure position math for a dead-reckoning turtle.
-- Convention: north = +z (matches gps.locate). y is altitude. East = +x.

local M = {}

M.FACINGS = { "north", "east", "south", "west" }
local INDEX = { north = 1, east = 2, south = 3, west = 4 }
local DELTAS = {
    north = {  0, 0,  1 },
    east  = {  1, 0,  0 },
    south = {  0, 0, -1 },
    west  = { -1, 0,  0 },
}

function M.new()
    return { x = 0, y = 0, z = 0, facing = "north" }
end

function M.faceIndex(p) return INDEX[p.facing] - 1 end

function M.faceDelta(facing)
    local d = DELTAS[facing]
    return { dx = d[1], dy = d[2], dz = d[3] }
end

function M.advance(p, n)
    n = n or 1
    local d = DELTAS[p.facing]
    p.x = p.x + d[1] * n
    p.z = p.z + d[3] * n
end

function M.up(p, n)   p.y = p.y + (n or 1) end
function M.down(p, n) p.y = p.y - (n or 1) end

function M.turn(p, dir)
    local i = INDEX[p.facing]
    if dir == "right" then i = (i % 4) + 1
    elseif dir == "left" then i = ((i - 2) % 4) + 1
    else error("turn dir must be left|right") end
    p.facing = M.FACINGS[i]
end

function M.distHome(p)
    return math.abs(p.x) + math.abs(p.y) + math.abs(p.z)
end

function M.copy(p)
    return { x = p.x, y = p.y, z = p.z, facing = p.facing }
end

function M.equal(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z and a.facing == b.facing
end

return M
