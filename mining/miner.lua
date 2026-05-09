-- Pack: arkana-aeronautics
-- Computer: mining turtle (plain turtle + diamond pickaxe equipped)
-- Hardware at base:
--   - dump chest above turtle's start position
--   - fuel chest below turtle's start position (or share one chest above)
-- Usage:
--   mining/miner.lua <shaft_length> <branch_length> --start [--tall]
--   mining/miner.lua                                  -- resume from saved state
--
-- --tall  carves a 1x3 player-walkable corridor (digs ceiling + floor on
--         every advance). Default is 1x1 — twice as fuel-efficient,
--         same ore-detection coverage on the 4 perpendicular faces.

package.path = package.path .. ";/disk/?.lua;/disk/?/init.lua;../?.lua"

local pos    = require("mining.pos")
local state  = require("mining.state")
local filter = require("mining.filter")

local CONFIG = {
    return_safety_margin = 64,    -- fuel headroom over manhattan(home)
    mid_fuel_threshold   = 256,   -- below this, try refuel from inv mid-mine
    refuel_target        = 2048,  -- after dump, refuel until this level
    vein_max_depth       = 16,    -- DFS bound for vein-mining
}

local argv = { ... }
local args = {
    shaft_length  = tonumber(argv[1]) or 64,
    branch_length = tonumber(argv[2]) or 8,
    fresh_start   = false,
    corridor_tall = false,             -- false = 1×1 (smart), true = 1×3 (walkable)
}
-- Track whether the user explicitly named a corridor mode on the CLI. On
-- resume, an explicit flag overrides the saved mode so you can swap mid-run
-- ("mining/miner.lua --tall" turns the rest of the run into a 1x3 corridor
-- without losing shaft_progress); no flag means "keep saved mode".
local explicitMode = nil
for _, a in ipairs(argv) do
    if     a == "--start" then args.fresh_start = true
    elseif a == "--tall"  then args.corridor_tall = true ; explicitMode = true
    elseif a == "--smart" then args.corridor_tall = false; explicitMode = false end
end

-- ── ore detection ─────────────────────────────────────────────────────────

local function isOre(blockData)
    if not blockData then return false end
    if blockData.tags and (blockData.tags["c:ores"] or blockData.tags["forge:ores"]) then
        return true
    end
    local n = blockData.name or ""
    return n:find("_ore", 1, true) ~= nil
        or n == "minecraft:ancient_debris"
        or n == "minecraft:gilded_blackstone"
end

-- ── movement primitives that update position ──────────────────────────────

local p   -- shared position table

local function digOreInspect(inspect, dig)
    local present, data = inspect()
    if present and isOre(data) then dig() ; return true end
    return false
end

local function moveForward()
    while not turtle.forward() do
        if turtle.detect() then turtle.dig() else turtle.attack() end
        sleep(0.1)
    end
    pos.advance(p)
end

local function moveUp()
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp() else turtle.attackUp() end
        sleep(0.1)
    end
    pos.up(p)
end

local function moveDown()
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown() else turtle.attackDown() end
        sleep(0.1)
    end
    pos.down(p)
end

local function turnLeft()  turtle.turnLeft()  ; pos.turn(p, "left")  end
local function turnRight() turtle.turnRight() ; pos.turn(p, "right") end

-- Save state on every step. Cheap (file is small) and saves us from drift on
-- disconnect mid-run.
local SAVED = {}
local function persist()
    SAVED.pos  = pos.copy(p)
    state.save(SAVED)
end

-- ── facing helpers ────────────────────────────────────────────────────────

local function turnTo(target)
    local cur = pos.faceIndex(p)              -- 0..3
    local FACINGS = pos.FACINGS
    local goal
    for i = 1, 4 do if FACINGS[i] == target then goal = i - 1 ; break end end
    local diff = (goal - cur) % 4
    if diff == 1 then turnRight()
    elseif diff == 3 then turnLeft()
    elseif diff == 2 then turnRight() ; turnRight() end
end

-- ── vein mining (bounded DFS) ─────────────────────────────────────────────

local function veinMineNeighbours(depth)
    if depth <= 0 then return end
    -- Try forward
    if digOreInspect(turtle.inspect, turtle.dig) then
        moveForward()
        veinMineNeighbours(depth - 1)
        -- back out
        turnRight() ; turnRight()
        moveForward()
        turnRight() ; turnRight()
    end
    if digOreInspect(turtle.inspectUp, turtle.digUp) then
        moveUp()
        veinMineNeighbours(depth - 1)
        moveDown()
    end
    if digOreInspect(turtle.inspectDown, turtle.digDown) then
        moveDown()
        veinMineNeighbours(depth - 1)
        moveUp()
    end
    -- Sides: turn, inspect, turn back. Cheap because we don't move.
    for _, dir in ipairs({ "left", "right" }) do
        if dir == "left" then turnLeft() else turnRight() end
        if digOreInspect(turtle.inspect, turtle.dig) then
            moveForward()
            veinMineNeighbours(depth - 1)
            turnRight() ; turnRight()
            moveForward()
            turnRight() ; turnRight()
        end
        if dir == "left" then turnRight() else turnLeft() end  -- restore facing
    end
end

-- ── single forward mining step (1×1 corridor, ore-aware) ─────────────────
--
-- 1-tall corridor inspects 4 perpendicular faces per advance (L/R walls,
-- floor, ceiling) for 1 dig + 1 move = 2 fuel. The previous 3-tall version
-- spent 4 fuel per advance for the same 4 inspectable faces — ore yield
-- per fuel was strictly worse. We never carve up/down speculatively now;
-- we only dig those cells if they're ore.

local function veinSide(direction)
    if direction == "left" then turnLeft() else turnRight() end
    local present, data = turtle.inspect()
    if present and isOre(data) then
        turtle.dig()
        moveForward()
        veinMineNeighbours(CONFIG.vein_max_depth)
        -- U-turn back into corridor.
        turnRight() ; turnRight()
        moveForward()
        turnRight() ; turnRight()
    end
    -- restore corridor facing
    if direction == "left" then turnRight() else turnLeft() end
end

local function veinAbove()
    local present, data = turtle.inspectUp()
    if present and isOre(data) then
        turtle.digUp()
        moveUp()
        veinMineNeighbours(CONFIG.vein_max_depth)
        moveDown()
    end
end

local function veinBelow()
    local present, data = turtle.inspectDown()
    if present and isOre(data) then
        turtle.digDown()
        moveDown()
        veinMineNeighbours(CONFIG.vein_max_depth)
        moveUp()
    end
end

local function mineStep()
    -- 1. Mine forward + advance.
    if turtle.detect() then turtle.dig() end
    moveForward()
    -- 2. Inspect each of the 4 perpendicular faces and vein-mine ores.
    --    Order matters: side walls first (cheap), then up/down. veinAbove /
    --    veinBelow only dig the cell if it's ore — they don't clear the
    --    corridor speculatively.
    veinSide("left")
    veinSide("right")
    veinAbove()
    veinBelow()
    -- 3. If --tall is set, clear ceiling + floor of any non-ore block so
    --    the corridor is player-walkable. Done after vein scans so we
    --    haven't already turned the cell into air before inspect ran.
    if args.corridor_tall then
        if turtle.detectUp()   then turtle.digUp()   end
        if turtle.detectDown() then turtle.digDown() end
    end
    persist()
end

-- ── tunneling without digging (used for resume / return paths) ────────────

local function travelForward(n)
    for _ = 1, n do moveForward() end
    persist()
end

-- ── return-home + resume ──────────────────────────────────────────────────

local function fuelOK()
    local lvl = turtle.getFuelLevel()
    if lvl == "unlimited" then return true end
    return lvl > pos.distHome(p) + CONFIG.return_safety_margin
end

local function midRefuel()
    local lvl = turtle.getFuelLevel()
    if lvl ~= "unlimited" and lvl < CONFIG.mid_fuel_threshold then
        filter.refuelFromInv(CONFIG.mid_fuel_threshold * 2)
    end
end

local function returnHome()
    print("returning home from", p.x, p.y, p.z, p.facing)
    -- 1. Strip back to x = 0, z = 0 in three legs. We're guaranteed to be in
    --    a mined corridor: branches off the main shaft start at z>=0 and may
    --    extend +x or -x, and the shaft itself runs along +z.
    --    Walk back along x first (in branch), then back along z (main shaft).
    if p.x > 0 then turnTo("west")
    elseif p.x < 0 then turnTo("east") end
    while p.x ~= 0 do moveForward() end

    if p.z > 0 then turnTo("south")
    elseif p.z < 0 then turnTo("north") end
    while p.z ~= 0 do moveForward() end

    if p.y > 0 then while p.y > 0 do moveDown() end
    elseif p.y < 0 then while p.y < 0 do moveUp() end end

    turnTo("north")  -- canonical facing at home
    persist()
end

local function dumpAndRefuel()
    -- Drop everything (except keep at least one stack of fuel for the trip back)
    -- by attempting dropUp on each slot; trash gets dropped first to make sure
    -- ores don't go to the chest above by accident if the chest only accepts ores.
    -- For v1: dump everything up, then refuel from below.
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            local d = turtle.getItemDetail(slot)
            -- skip dropping fuel-burnable items so we still have refuel headroom
            -- if the fuel chest below is empty
            if d and turtle.refuel(0) then
                -- it's burnable — keep it
            else
                turtle.dropUp()
            end
        end
    end
    turtle.select(1)
    -- Top up from below
    while turtle.getFuelLevel() ~= "unlimited"
          and turtle.getFuelLevel() < CONFIG.refuel_target do
        local pulled = turtle.suckDown()
        if not pulled then break end
        filter.refuelFromInv(CONFIG.refuel_target)
    end
    persist()
end

local function goToMiningPos(target)
    -- Walk from home (0,0,0) out to the saved last_mining_pos.
    -- Inverse of returnHome: z first, then x, then y.
    if target.z > 0 then turnTo("north")
    elseif target.z < 0 then turnTo("south") end
    while p.z ~= target.z do moveForward() end

    if target.x > 0 then turnTo("east")
    elseif target.x < 0 then turnTo("west") end
    while p.x ~= target.x do moveForward() end

    if target.y > p.y then while p.y < target.y do moveUp() end end
    if target.y < p.y then while p.y > target.y do moveDown() end end

    turnTo(target.facing)
    persist()
end

-- ── high-level mining: branch pattern ─────────────────────────────────────

local function doBranch(length)
    -- Mine `length` blocks forward (with up/down inspect + side veins).
    for _ = 1, length do
        midRefuel()
        filter.purge()
        if not fuelOK() or filter.isFull() then return false end
        mineStep()
    end
    -- Walk back to spine.
    turnRight() ; turnRight()
    travelForward(length)
    turnRight() ; turnRight()
    return true
end

local function mineShaft()
    -- We're at the spine, facing north (the shaft direction).
    -- Resume support: if SAVED.shaft_progress is set, fast-travel to that index.
    local resumeIdx = SAVED.shaft_progress or 0
    if resumeIdx > 0 then
        for _ = 1, resumeIdx do moveForward() end
    end

    for i = resumeIdx + 1, args.shaft_length do
        midRefuel()
        filter.purge()
        if not fuelOK() then SAVED.shaft_progress = i - 1 ; persist() ; return "fuel" end
        if filter.isFull() then SAVED.shaft_progress = i - 1 ; persist() ; return "full" end

        mineStep()
        SAVED.shaft_progress = i
        persist()

        -- Every 3 forwards, branch L then R.
        if i % 3 == 0 then
            turnLeft()
            if not doBranch(args.branch_length) then return "interrupted" end
            turnRight() ; turnRight() ; turnRight()  -- net: turn right (face shaft +1)
            -- After exit of doBranch we face same as before doBranch's first turnLeft;
            -- then turnLeft+L+R+R+R = a single L from spine direction. We want to
            -- end facing north (shaft). doBranch leaves us facing original spine dir.
            -- Net effect of "turnLeft, doBranch, turnRight*3" = facing east. Re-orient:
            turnTo("north")
            turnRight()
            if not doBranch(args.branch_length) then return "interrupted" end
            turnTo("north")
        end
    end
    return "shaft_done"
end

-- ── main ──────────────────────────────────────────────────────────────────

local function run()
    -- Sanity: we need a pickaxe equipped or we can't dig.
    if not turtle.dig then error("not a turtle") end

    local loaded = state.load()
    if loaded and not args.fresh_start then
        SAVED = loaded
        SAVED.args = SAVED.args or {}
        p     = SAVED.pos or pos.new()
        args.shaft_length  = SAVED.args.shaft_length  or args.shaft_length
        args.branch_length = SAVED.args.branch_length or args.branch_length
        -- Corridor mode: CLI flag (if explicitly set) wins, else saved.
        if explicitMode == nil then
            args.corridor_tall = SAVED.args.corridor_tall == true
        else
            args.corridor_tall = explicitMode
            SAVED.args.corridor_tall = explicitMode
        end
        persist()
        print(("resumed at (%d,%d,%d %s) shaft_progress=%d mode=%s")
            :format(p.x, p.y, p.z, p.facing, SAVED.shaft_progress or 0,
                args.corridor_tall and "tall" or "smart"))
    else
        SAVED = { args = args, shaft_progress = 0 }
        p     = pos.new()
        state.clear()
        persist()
        print(("starting fresh: shaft=%d branch=%d mode=%s")
            :format(args.shaft_length, args.branch_length,
                args.corridor_tall and "tall" or "smart"))
    end

    while true do
        -- Top up fuel if we can, before deciding anything.
        midRefuel()

        -- If we're not at home and we don't have enough to mine + return,
        -- go home now.
        if not fuelOK() then
            returnHome() ; dumpAndRefuel()
            goToMiningPos({ x=0, y=0, z=SAVED.shaft_progress or 0, facing="north" })
        end

        local result = mineShaft()
        if result == "shaft_done" then
            print("shaft complete — returning home and stopping")
            returnHome() ; dumpAndRefuel()
            state.clear()
            return
        end
        -- "fuel" or "full" → return, dump/refuel, resume
        returnHome()
        dumpAndRefuel()
        if turtle.getFuelLevel() ~= "unlimited"
           and turtle.getFuelLevel() < CONFIG.return_safety_margin * 2 then
            print("fuel chest empty / not enough fuel after refuel — stopping")
            return
        end
        goToMiningPos({ x = 0, y = 0, z = SAVED.shaft_progress, facing = "north" })
    end
end

run()
