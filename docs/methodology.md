# Methodology — how the pack docs were built

Pack-agnostic playbook for adding a new pack to `packs/<pack>/` or refreshing an existing one. Used to build `packs/arkana-aeronautics/`.

## 1. Identify pack contents from nix-config

Pack lives in `../nix-config/pkgs/<pack-name>-server/`. Key files:

| File | What's in it |
|---|---|
| `default.nix` | Minecraft + loader (NeoForge/Forge/Fabric) version |
| `overlays.nix` | Overlay/replacement mods (CC:T, AP, CC:C Bridge, etc.) — Modrinth/CurseForge IDs |
| `arkana-mods.nix` | Full mod list with URLs + sha256 |
| `arkana-mods-extras.nix` | Replacement mods (e.g. Create version bump) |
| `arkana-groups.nix` | Mod-group classifications |

Workflow:

```bash
grep -iE "computercraft|cc-tweaked|advancedperipherals|cccbridge|peripheral|computronics|plethora" \
     ../nix-config/pkgs/<pack>-server/*.nix
```

Capture: MC version, loader version, every CC-related mod with its exact version + Modrinth/CF ID.

## 2. Read recipes directly from mod JARs

**Best source of truth** — beats web docs (often stale, often missing recipes). Modern Minecraft mods ship recipes as JSON datapacks inside the JAR at:

- CC: Tweaked: `data/computercraft/recipe/*.json`
- Advanced Peripherals: `data/advancedperipherals/recipe/*.json`
- CC:C Bridge: `data/cccbridge/recipe/*.json`
- Create: `data/create/recipe/{crafting,mixing,pressing,...}/*.json`
- Sophisticated Storage: `data/sophisticatedstorage/recipe/*.json`

Path may use `recipe` or `recipes` depending on MC version (1.21+ uses singular).

### Workflow

```bash
# 1. Get the URLs from overlays.nix / arkana-mods.nix.
grep -B2 -A6 "cc-tweaked-1\.21\|AdvancedPeripherals-1\.21\|cccbridge-mc1\.21" \
     ../nix-config/pkgs/<pack>-server/overlays.nix

# 2. Download to /tmp.
mkdir -p /tmp/arkana-jars && cd /tmp/arkana-jars
curl -sLO "https://cdn.modrinth.com/data/<projectId>/versions/<versionId>/<filename>.jar"

# 3. List recipe files.
unzip -l <mod>.jar | grep -E "data/<modid>/recipe.*\.json" | grep -v advancement

# 4. Dump a specific recipe to stdout (no extraction to disk).
unzip -p <mod>.jar "data/<modid>/recipe/<name>.json"
```

### Recipe JSON shape (vanilla shaped crafting)

```json
{
  "type": "minecraft:crafting_shaped",
  "key": {
    "#": { "item": "minecraft:stone" },
    "R": { "tag": "c:dusts/redstone" }
  },
  "pattern": ["###", "#R#", "###"],
  "result": { "count": 1, "id": "computercraft:wired_modem" }
}
```

Read top→bottom, left→right. `tag` ingredients accept any item with that tag (verify which items in JEI/EMI in-game). Other types: `crafting_shapeless`, `create:mixing`, `create:pressing`, `create:item_application` — each with its own ingredient shape.

### Why not just web-fetch the docs

- AP web docs intentionally omit recipes ("see in-game recipe browser").
- Wikis (Create, CC:T) are often stale — Create's GitHub wiki migrated to wiki.createmod.net mid-2025 and many pages 404 from scrapers.
- JAR-extracted recipes are version-pinned to *exactly* what the pack ships.

## 3. Discover peripheral surface

CC peripheral methods can come from three places. Check in this order:

1. **Upstream docs.** Authoritative for the mod author's intent.
   - CC: Tweaked → https://tweaked.cc/peripheral/<name>.html + /generic_peripheral/<name>.html
   - Advanced Peripherals → https://docs.advanced-peripherals.de/latest/peripherals/<name>/
   - CC:C Bridge → https://cccbridge.kleinbox.dev/peripherals/<name>/
   - Create native → https://wiki.createmod.net/ (search "ComputerCraft")

2. **Mod source on GitHub** when web docs are missing or wrong:
   - `cc-tweaked/CC-Tweaked` — peripheral classes are well-commented Java
   - `IntelligenceModding/AdvancedPeripherals` — `/src/main/java/.../peripheral/`
   - `tweaked-programs/cccbridge` — `/src/main/java/.../peripheral/`
   - Search for `@LuaFunction` annotations — those are the methods Lua sees

3. **In-game introspection** is ground truth:

   ```lua
   peripheral.getNames()           -- list everything attached
   peripheral.getType(name)        -- including any auto-wrapped types
   peripheral.getMethods(name)     -- exhaustive method list
   ```

   Always reconcile docs against `getMethods` before relying on a method name in code.

## 4. Note version-sensitive details

Some changes silently break programs across versions:

- **Advanced Peripherals 1.21.1** switched type strings camelCase → snake_case (`playerDetector` → `player_detector`).
- **AP 0.7.50b** removed `redstone_integrator` (use CC:T's `redstone_relay`).
- **CC:T 1.109+** http response bodies are raw bytes, not UTF-8 strings.
- **CC:T 1.114+** added `redstone_relay`.
- **Mekanism v10.1+** ships native CC:T support; AP's Mekanism integration deprecated.
- **Create 6.x** renamed some peripherals from 5.x (verify with `peripheral.getMethods`).

When the pack bumps any of these, re-run the JAR extraction and diff `data/<mod>/recipe/` listings to spot recipe changes too.

## 5. Document conventions inside `packs/<pack>/docs/`

Every page leads with **`Status in this pack:`** — Active / Inert (mod absent) / Partial / Removed / Superseded. Lets a reader know in one line whether to keep reading.

Method signatures live in fenced `lua` blocks. Peripheral type strings always quoted (`"player_detector"`). Each page links upstream rather than mirroring full text — upstream churns; stale mirrors are worse than no mirror.

## 6. Refreshing when the pack bumps

1. Diff `nix-config` for new versions.
2. Re-download JARs to `/tmp/arkana-jars/` (delete old, fetch new).
3. Diff `unzip -l` recipe lists between old and new JAR — anything added/removed/renamed.
4. Update `packs/<pack>/README.md` version table.
5. Update `recipes.md` for any changed recipes.
6. Update version-sensitive doc pages (AP 1.21.1 naming, etc.).
7. Verify in-game with `peripheral.getMethods` for at least one peripheral per addon.

## 7. Tooling notes

- `unzip -p <jar> <path>` streams a single file to stdout — no need to extract the whole JAR.
- `unzip -l <jar> | grep recipe` finds recipe paths quickly.
- WebFetch via Claude Code is fine for sanity-checking but treat anything past 6 months old as suspect for modern MC mods.
- For modpack-scale searches, Explore agents handle the breadth; for one-shot recipe lookups, direct `unzip -p` is fastest.
