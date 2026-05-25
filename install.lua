local argv = { ... }

-- Bootstrap installer for computercraft-programs.
-- Run on a CC: Tweaked computer to fetch program files from an HTTP source
-- (default: this repo on GitHub raw) and lay them out at the expected paths.
--
-- Usage:
--   install                       — install all programs
--   install <program> [<program>] — install one or more (storage|treefarm|builder|smelter)
--   install --list                — list known programs
--   install --base <url>          — override the source base URL
--   install --autostart <program> — also write /startup.lua to launch this program
--   install --branch <name>       — switch git branch (default: master)
--   install --user <github-user>  — switch GitHub user (default below)
--
-- Examples:
--   wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua storage
--   pastebin run <id> --autostart storage
--
-- Re-running the installer overwrites existing files (treats it as an update).

local DEFAULT_USER   = "alisonjenkins"  -- override with --user
local DEFAULT_REPO   = "computercraft-programs"
local DEFAULT_BRANCH = "master"

local PROGRAMS = {
    storage = {
        "lib/inv.lua",
        "lib/log.lua",
        "storage/controller.lua",
        "storage/index.lua",
        "storage/commands.lua",
        "storage/defrag.lua",
    },
    treefarm = {
        "lib/inv.lua",
        "lib/log.lua",
        "treefarm/monitor.lua",
    },
    builder = {
        "lib/inv.lua",
        "lib/log.lua",
        "builder/builder.lua",
        "builder/schemas/5x5x3-shed.lua",
    },
    smelter = {
        "smelter.lua",
    },
    mining = {
        "lib/inv.lua",
        "lib/log.lua",
        "mining/pos.lua",
        "mining/state.lua",
        "mining/filter.lua",
        "mining/miner.lua",
        "mining/digdown.lua",
        "mining/room.lua",
    },
}

local AUTOSTART_ENTRY = {
    storage  = 'shell.run("storage/controller.lua")',
    treefarm = 'shell.run("treefarm/monitor.lua")',
    builder  = '-- builder is run on demand: shell.run("builder/builder.lua", "builder/schemas/<name>.lua")',
    smelter  = 'shell.run("smelter.lua")',
    mining   = '-- mining is run on demand: shell.run("mining/miner.lua", "64", "8", "--start"), shell.run("mining/digdown.lua", "122"), or shell.run("mining/room.lua", "16", "16", "4", "--start")',
}

local function parseArgs(args)
    local opts = {
        base       = nil,
        user       = DEFAULT_USER,
        repo       = DEFAULT_REPO,
        branch     = DEFAULT_BRANCH,
        list       = false,
        autostart  = nil,
        programs   = {},
    }
    local i = 1
    while i <= #args do
        local a = args[i]
        if     a == "--list"      then opts.list = true
        elseif a == "--base"      then i = i + 1; opts.base   = args[i]
        elseif a == "--branch"    then i = i + 1; opts.branch = args[i]
        elseif a == "--user"      then i = i + 1; opts.user   = args[i]
        elseif a == "--repo"      then i = i + 1; opts.repo   = args[i]
        elseif a == "--autostart" then i = i + 1; opts.autostart = args[i]
        elseif a:sub(1, 2) == "--" then
            error("unknown flag: " .. a)
        else
            opts.programs[#opts.programs + 1] = a
        end
        i = i + 1
    end
    if not opts.base then
        opts.base = ("https://raw.githubusercontent.com/%s/%s/%s")
            :format(opts.user, opts.repo, opts.branch)
    end
    return opts
end

local function ensureDirOf(path)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
end

local function fetch(url)
    -- Cache-bust raw.githubusercontent.com — its CDN can lag pushes by minutes.
    local sep = url:find("?", 1, true) and "&" or "?"
    url = url .. sep .. "nocache=" .. tostring(os.epoch("utc"))
    local h, err = http.get(url, nil, true)  -- binary=true so we don't break on non-utf8 bytes
    if not h then return nil, err or "http error" end
    local body = h.readAll()
    local code = h.getResponseCode()
    h.close()
    if code ~= 200 then return nil, ("HTTP %d"):format(code) end
    return body
end

local function writeFile(path, body)
    ensureDirOf(path)
    local f = fs.open(path, "wb")
    f.write(body)
    f.close()
end

local function installFile(base, path)
    local url = base .. "/" .. path
    io.write(("  %s … "):format(path))
    local body, err = fetch(url)
    if not body then
        print("FAIL (" .. err .. ")")
        return false
    end
    writeFile(path, body)
    print(("OK (%d bytes)"):format(#body))
    return true
end

local function installProgram(base, name)
    local files = PROGRAMS[name]
    if not files then
        print(("unknown program: %s"):format(name))
        return false
    end
    print(("[%s]"):format(name))
    -- de-dup the file list (lib/inv.lua appears in multiple programs)
    local seen, ordered = {}, {}
    for _, p in ipairs(files) do
        if not seen[p] then seen[p] = true ; ordered[#ordered + 1] = p end
    end
    local ok = true
    for _, p in ipairs(ordered) do
        ok = installFile(base, p) and ok
    end
    return ok
end

local function writeAutostart(name)
    local entry = AUTOSTART_ENTRY[name]
    if not entry then
        print("no autostart entry for " .. name)
        return
    end
    local f = fs.open("/startup.lua", "w")
    f.writeLine("-- generated by install.lua --autostart " .. name)
    f.writeLine(entry)
    f.close()
    print("/startup.lua → " .. name)
end

local function listPrograms()
    print("known programs:")
    for name, files in pairs(PROGRAMS) do
        print(("  %s (%d files)"):format(name, #files))
    end
end

local function main()
    local opts = parseArgs(argv)
    if opts.list then listPrograms() return end

    if #opts.programs == 0 then
        for name in pairs(PROGRAMS) do
            opts.programs[#opts.programs + 1] = name
        end
    end

    print("base: " .. opts.base)
    local allOK = true
    for _, name in ipairs(opts.programs) do
        if not installProgram(opts.base, name) then allOK = false end
    end

    if opts.autostart then writeAutostart(opts.autostart) end

    if allOK then
        print("done")
    else
        printError("some files failed; check URLs and http allowlist")
    end
end

main()
