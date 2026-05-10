-- Pack: arkana-aeronautics
-- Computer: mining turtle (plain turtle + diamond pickaxe equipped)
-- Hardware at base:
--   - dump chest above turtle's start (dropUp on return)
--   - fuel chest below turtle's start (suckDown on return)
--
-- Usage:
--   mining/room.lua <length> <width> <height> --start [--left] [--up]
--   mining/room.lua                                 -- resume from saved state
--
-- Layout convention (turtle-relative):
--   - Turtle's forward at start  = +LENGTH axis (carves into the room)
--   - Turtle's right at start    = +WIDTH axis  (--left flips to left)
--   - DOWN from start            = +HEIGHT axis (--up flips to up)
--
-- Home is one block BEHIND the room's near face. The cell directly
-- forward of the turtle is the first cell mined (room corner). The
-- turtle never digs its own home cell, so the dump+fuel chests stay
-- intact above and below.

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local pos    = require("mining.pos")
local state  = require("mining.state")
local filter = require("mining.filter")

-- room_state lives at /.miner_state too — single file, but the schema
-- carries a `program = "room"` tag so an accidental cross-launch with
-- miner.lua bails out instead of corrupting state.
local STATE_TAG = "room"

local CONFIG = {
    return_safety_margin = 64,
    mid_fuel_threshold   = 256,
    refuel_target        = 4096,   -- after dump, refuel to this
    fuel_poll_seconds    = 5,
}

local PLUG_NAMES = {
    ["minecraft:cobblestone"]       = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:stone"]             = true,
    ["minecraft:deepslate"]         = true,
    ["minecraft:dirt"]              = true,
    ["minecraft:gravel"]            = true,
    ["minecraft:netherrack"]        = true,
    ["minecraft:tuff"]              = true,
    ["minecraft:granite"]           = true,
    ["minecraft:diorite"]           = true,
    ["minecraft:andesite"]          = true,
    ["minecraft:basalt"]            = true,
    ["minecraft:blackstone"]        = true,
}

local FLUID_KIND = {
    ["minecraft:lava"]          = "lava",
    ["minecraft:flowing_lava"]  = "lava",
    ["minecraft:water"]         = "water",
    ["minecraft:flowing_water"] = "water",
}

-- ── arg parsing ───────────────────────────────────────────────────────────

local argv = { ... }
local args = {
    length      = tonumber(argv[1]),
    width       = tonumber(argv[2]),
    height      = tonumber(argv[3]),
    fresh_start = false,
    sweep_left  = false,
    dig_up      = false,
}
for i = 1, #argv do
    if     argv[i] == "--start" then args.fresh_start = true
    elseif argv[i] == "--left"  then args.sweep_left = true
    elseif argv[i] == "--up"    then args.dig_up = true end
end

local function usage()
    print("usage: mining/room.lua <length> <width> <height> --start [--left] [--up]")
    print("       mining/room.lua                              # resume saved run")
end

-- ── position + movement primitives ────────────────────────────────────────

local p   -- live position table (relative to home)

local function selectPlug()
    for slot = 1, 16 do
        local d = turtle.getItemDetail(slot)
        if d and PLUG_NAMES[d.name] then turtle.select(slot) ; return slot end
    end
    return nil
end

local function fluidKindAt(inspect)
    local ok, b = inspect()
    if ok and b and FLUID_KIND[b.name] then return FLUID_KIND[b.name] end
    return nil
end

local function plugIfLavaForward()
    if fluidKindAt(turtle.inspect) == "lava" then
        if not selectPlug() then return false end
        turtle.dig()
        turtle.place()
    end
    return true
end

local function plugIfLavaUp()
    if fluidKindAt(turtle.inspectUp) == "lava" then
        if not selectPlug() then return false end
        turtle.digUp()
        turtle.placeUp()
    end
    return true
end

local function plugIfLavaDown()
    if fluidKindAt(turtle.inspectDown) == "lava" then
        if not selectPlug() then return false end
        turtle.digDown()
        turtle.placeDown()
    end
    return true
end

local function moveForward()
    plugIfLavaForward()
    while not turtle.forward() do
        if turtle.detect() then turtle.dig()
        else turtle.attack() end
        sleep(0.1)
    end
    pos.advance(p)
end

local function moveUp()
    plugIfLavaUp()
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp()
        else turtle.attackUp() end
        sleep(0.1)
    end
    pos.up(p)
end

local function moveDown()
    plugIfLavaDown()
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown()
        else turtle.attackDown() end
        sleep(0.1)
    end
    pos.down(p)
end

local function turnLeft()  turtle.turnLeft()  ; pos.turn(p, "left")  end
local function turnRight() turtle.turnRight() ; pos.turn(p, "right") end

local SAVED = {}
local function persist() SAVED.pos = pos.copy(p) ; state.save(SAVED) end

local function turnTo(target)
    local cur = pos.faceIndex(p)
    local goal
    for i = 1, 4 do if pos.FACINGS[i] == target then goal = i - 1 ; break end end
    local diff = (goal - cur) % 4
    if     diff == 1 then turnRight()
    elseif diff == 3 then turnLeft()
    elseif diff == 2 then turnRight() ; turnRight() end
end

-- ── fuel + inv ────────────────────────────────────────────────────────────

local function midRefuel()
    local lvl = turtle.getFuelLevel()
    if lvl ~= "unlimited" and lvl < CONFIG.mid_fuel_threshold then
        filter.refuelFromInv(CONFIG.mid_fuel_threshold * 2)
    end
end

local function fuelOK()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" then return true end
    return lvl > pos.distHome(p) + CONFIG.return_safety_margin
end

-- ── return / navigate / dump / refuel ─────────────────────────────────────

-- Return to home (0,0,0). The home column at (0, ±1, 0) is the chest column
-- (dump above, fuel below) — those cells must NOT be dug. Route via the room's
-- col-0 spine instead:
--   1. Walk back along width axis to x=0           (current layer, all cells mined)
--   2. Walk back along length axis to z=1          (col 0 of current layer, mined)
--   3. Move y back to 0 along (0, *, 1)            (col-0 entry cells of each
--                                                   completed layer, mined by
--                                                   descend; doorway at y=0
--                                                   mined by initial entry)
--   4. Walk south one block to (0, 0, 0)           (the doorway cell)
local function returnHome()
    print(("returning home from (%d,%d,%d %s)"):format(p.x, p.y, p.z, p.facing))
    if p.x > 0 then turnTo("west")  elseif p.x < 0 then turnTo("east")  end
    while p.x ~= 0 do moveForward() end
    if p.z > 1 then turnTo("south") ; while p.z > 1 do moveForward() end end
    if p.z < 1 then turnTo("north") ; while p.z < 1 do moveForward() end end
    while p.y > 0 do moveDown() end
    while p.y < 0 do moveUp() end
    if p.z > 0 then turnTo("south") ; while p.z > 0 do moveForward() end end
    turnTo("north")
    persist()
end

-- Block until fuel level is at least `target`. First refuels from anything
-- already in inventory; then loops on suckDown (fuel chest below); and if the
-- chest is dry, prompts the user to drop fuel into the turtle's inventory and
-- polls every CONFIG.fuel_poll_seconds. Idempotent — safe to call any time.
local function ensureFuel(target)
    if turtle.getFuelLevel() == "unlimited" then return end
    filter.refuelFromInv(target)
    local warned = false
    while turtle.getFuelLevel() < target do
        local pulled = turtle.suckDown()
        if pulled then
            filter.refuelFromInv(target)
        else
            -- nothing to pull from below; check if any new fuel was hand-fed
            filter.refuelFromInv(target)
            if turtle.getFuelLevel() < target then
                if not warned then
                    print(("fuel %d / target %d — drop coal/charcoal/logs into the turtle (or fuel chest below). polling every %ds…")
                        :format(turtle.getFuelLevel(), target, CONFIG.fuel_poll_seconds))
                    warned = true
                end
                sleep(CONFIG.fuel_poll_seconds)
            end
        end
    end
    if warned then print(("fuel ok: %d"):format(turtle.getFuelLevel())) end
end

local function dumpAndRefuel()
    -- Dump everything that isn't a fuel-burnable item. Burnables stay so we
    -- can refuel from them on the next ensureFuel call (covers the case
    -- where the fuel chest is empty but the turtle's own inv has logs etc.)
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            if turtle.refuel(0) then
                -- burnable — keep
            else
                turtle.dropUp()
            end
        end
    end
    turtle.select(1)
    ensureFuel(CONFIG.refuel_target)
    persist()
end

-- Inverse of returnHome. Route is the col-0 spine to avoid the chest column.
--   1. From home (0,0,0), forward 1 into the doorway (0, 0, 1)
--   2. Move y to target.y along (0, *, 1)
--   3. Walk along z to target.z (still at x=0 — col 0 of target layer)
--   4. Walk along x to target.x (target layer rows up to col=current are
--      mined; cells we cut through past the swept frontier get re-dug)
local function goToMiningPos(target)
    if p.z < 1 then turnTo("north") ; while p.z < 1 do moveForward() end end
    while p.y < target.y do moveUp()   end
    while p.y > target.y do moveDown() end
    if target.z > p.z then turnTo("north") ; while p.z < target.z do moveForward() end
    elseif target.z < p.z then turnTo("south") ; while p.z > target.z do moveForward() end end
    if target.x > p.x then turnTo("east") ; while p.x < target.x do moveForward() end
    elseif target.x < p.x then turnTo("west") ; while p.x > target.x do moveForward() end end
    turnTo(target.facing)
    persist()
end

-- ── room geometry helpers ─────────────────────────────────────────────────

-- The +length axis is "north" in pos coords (turtle starts facing "north").
-- The width axis is right of start by default, left if --left.
-- The height axis is down by default, up if --up.

local function widthSign() return args.sweep_left and -1 or 1 end
local function heightSign() return args.dig_up and 1 or -1 end

-- ── one-block dig helpers (with lava-guard) ───────────────────────────────

local function digForwardStep()
    plugIfLavaForward()
    if turtle.detect() then turtle.dig() end
    moveForward()
end

local function digDownStep() plugIfLavaDown() ; moveDown() end
local function digUpStep()   plugIfLavaUp()   ; moveUp()   end

-- ── core sweep ────────────────────────────────────────────────────────────

local function bailoutIfLow()
    midRefuel()
    filter.purge()
    if not fuelOK() or filter.isFull() then return true end
    return false
end

-- Mine a single column along the length axis. The turtle MUST start at the
-- column's entry cell (already mined by whoever called us — the initial
-- forward-from-home, the previous stepToNextColumn's width-step, or
-- descendToNextLayer's vertical step). Performs (args.length - 1) forward
-- digSteps. col_progress = 0 means we're at the entry cell with no sweep
-- steps done; col_progress = args.length - 1 means the column is fully
-- swept and the turtle is at the far cell.
local function sweepColumn(start_progress)
    for k = (start_progress or 0) + 1, args.length - 1 do
        if bailoutIfLow() then
            SAVED.col_progress = k - 1
            persist()
            return false
        end
        digForwardStep()
        SAVED.col_progress = k
        persist()
    end
    return true
end

-- After finishing a column, shift one cell along the width axis and turn to
-- face the opposite length direction. `dir` is the current length-facing
-- ("north" or "south"). Returns the new length-facing.
local function stepToNextColumn(dir)
    -- Pivot: turn toward width axis, dig+move 1, turn back toward the
    -- opposite length axis. Direction of the two turns depends on whether
    -- we're heading +length or -length, and whether width sweep is right
    -- or left.
    --
    -- Truth table (first turn / second turn):
    --   north + sweep_right: right, right  (lands facing south)
    --   north + sweep_left:  left,  left   (lands facing south)
    --   south + sweep_right: left,  left   (lands facing north)
    --   south + sweep_left:  right, right  (lands facing north)
    local first, second
    if dir == "north" then
        if args.sweep_left then first, second = "left",  "left"
        else                    first, second = "right", "right" end
    else  -- south
        if args.sweep_left then first, second = "right", "right"
        else                    first, second = "left",  "left"  end
    end
    if first  == "left" then turnLeft()  else turnRight() end
    digForwardStep()
    if second == "left" then turnLeft()  else turnRight() end
    return (dir == "north") and "south" or "north"
end

-- Sweep one full layer at the turtle's current Y. Turtle must enter at
-- column 0, facing +length (north). On exit, turtle is at the far corner
-- of the layer (column W-1) facing whichever length direction it ended
-- on (parity of W).
local function sweepLayer()
    local dir = (SAVED.col_dir == "south") and "south" or "north"
    turnTo(dir)
    for col = (SAVED.col or 0), args.width - 1 do
        SAVED.col = col
        SAVED.col_dir = dir
        persist()
        local complete = sweepColumn(SAVED.col_progress)
        if not complete then return false end
        SAVED.col_progress = 0
        if col < args.width - 1 then
            dir = stepToNextColumn(dir)
        end
    end
    SAVED.col = nil
    SAVED.col_dir = nil
    SAVED.col_progress = 0
    persist()
    return true
end

-- Move from end-of-layer N to start-of-layer N+1.
--
-- End-of-layer N: turtle at the layer's far corner (column W-1).
--   Position depends on W's parity:
--     W odd  → last column was north-bound, end at z = length    (col W-1 facing north)
--     W even → last column was south-bound, end at z = 1         (col W-1 facing south)
-- We must end at (x=0, y=layer_(N+1), z=1) facing north — the entry cell of
-- col 0 of layer N+1, with that cell mined by the descend step.
local function descendToNextLayer()
    -- 1) Travel back along width axis to column 0 (already mined).
    if args.sweep_left then turnTo("east") else turnTo("west") end
    for _ = 1, args.width - 1 do moveForward() end
    -- 2) If we ended layer N at z=length (W odd), walk back to z=1.
    --    If W even we're already at z=1.
    if args.width % 2 == 1 then
        turnTo("south")
        for _ = 1, args.length - 1 do moveForward() end
    end
    -- 3) Descend one block in height direction. This mines the entry cell
    --    of col 0 of layer N+1.
    if args.dig_up then digUpStep() else digDownStep() end
    -- 4) Face +length to start the new layer.
    turnTo("north")
    persist()
end

-- ── resume helpers ────────────────────────────────────────────────────────

-- Compute the in-room position the turtle should resume mining from, given
-- SAVED.layer / col / col_progress / col_dir. Returns {x,y,z,facing} in
-- home-relative coords.
--
-- Convention (matches sweepColumn): the column's entry cell is at z=1
-- (north-bound) or z=length (south-bound). col_progress is the count of
-- sweep steps already taken in the current column (0..length-1). After k
-- sweep steps:
--   north-bound: z = 1 + k        (progress 0 → z=1, progress L-1 → z=L)
--   south-bound: z = length - k   (progress 0 → z=L, progress L-1 → z=1)
local function resumeTarget()
    local layer = SAVED.layer or 1
    local col   = SAVED.col   or 0
    local progress = SAVED.col_progress or 0
    local dir = SAVED.col_dir or "north"
    local z, facing
    if dir == "north" then
        z = 1 + progress
        facing = "north"
    else
        z = args.length - progress
        facing = "south"
    end
    local x = col * widthSign()
    local y = (layer - 1) * heightSign()
    return { x = x, y = y, z = z, facing = facing }
end

-- ── main ──────────────────────────────────────────────────────────────────

local function validateArgs()
    if not args.length or args.length < 1
       or not args.width or args.width < 1
       or not args.height or args.height < 1 then
        return false
    end
    return true
end

local function run()
    if not turtle.dig then error("not a turtle") end

    local loaded = state.load()
    if loaded and loaded.program == STATE_TAG and not args.fresh_start then
        SAVED = loaded
        SAVED.args = SAVED.args or {}
        p = SAVED.pos or pos.new()
        args.length     = SAVED.args.length     or args.length
        args.width      = SAVED.args.width      or args.width
        args.height     = SAVED.args.height     or args.height
        args.sweep_left = SAVED.args.sweep_left == true
        args.dig_up     = SAVED.args.dig_up     == true
        if not validateArgs() then usage() ; return end
        print(("resumed at (%d,%d,%d %s) layer=%d col=%d progress=%d")
            :format(p.x, p.y, p.z, p.facing,
                SAVED.layer or 1, SAVED.col or 0, SAVED.col_progress or 0))
    else
        if not validateArgs() then usage() ; return end
        if loaded and loaded.program ~= STATE_TAG then
            print("warning: existing /.miner_state is from another program;"
                .. " --start will overwrite it")
        end
        SAVED = {
            program        = STATE_TAG,
            args           = {
                length     = args.length,
                width      = args.width,
                height     = args.height,
                sweep_left = args.sweep_left,
                dig_up     = args.dig_up,
            },
            layer          = 1,
            col            = 0,
            col_progress   = 0,
            col_dir        = "north",
        }
        p = pos.new()
        state.clear()
        persist()
        print(("starting fresh: %dL x %dW x %dH  width=%s height=%s")
            :format(args.length, args.width, args.height,
                args.sweep_left and "left" or "right",
                args.dig_up     and "up"   or "down"))
    end

    -- Pre-flight: top up fuel before starting.
    ensureFuel(CONFIG.refuel_target)

    while true do
        midRefuel()

        -- Navigate to the saved mining position. For a fresh start this
        -- walks one block forward from home into the first cell of layer 1
        -- col 0 (digging through the wall on the way). After a return-home,
        -- this re-enters and walks back to wherever we left off. After a
        -- descendToNextLayer the turtle is already at the target so this
        -- is a no-op.
        local tgt = resumeTarget()
        local atTarget = (p.x == tgt.x and p.y == tgt.y and p.z == tgt.z and p.facing == tgt.facing)
        if not atTarget then
            goToMiningPos(tgt)
        end

        -- If fuel is too tight to mine + return, head home now.
        if not fuelOK() then
            returnHome()
            dumpAndRefuel()
        else
            local ok = sweepLayer()
            if not ok then
                returnHome()
                dumpAndRefuel()
            else
                -- Layer done.
                if SAVED.layer == args.height then
                    print("final layer done")
                    returnHome()
                    dumpAndRefuel()
                    state.clear()
                    print("room complete — state cleared")
                    return
                end
                descendToNextLayer()
                SAVED.layer = SAVED.layer + 1
                SAVED.col = 0
                SAVED.col_progress = 0
                SAVED.col_dir = "north"
                persist()
            end
        end
    end
end

run()
