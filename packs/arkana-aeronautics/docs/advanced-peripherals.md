# Advanced Peripherals

**Status in this pack:** Active for block peripherals listed below + smart turtle upgrades. Inert: ME Bridge, RS Bridge, Colony Integrator, Mekanism methods (target mods absent — see `absent-mods.md`).

Version in pack: **0.7.61b** for MC 1.21.1 NeoForge. Type strings are **snake_case** (the 1.21.1+ convention). Older guides use camelCase — translate.

Upstream docs: https://docs.advanced-peripherals.de/latest/

## Active block peripherals

### `player_detector`

```lua
getPlayerPos(username) -> table|nil
getOnlinePlayers() -> { string }
getPlayersInRange(range) -> { string }
getPlayersInCoords(posOne, posTwo) -> { string }
getPlayersInCubic(w, h, d) -> { string }
isPlayerInRange(range, username) -> bool
isPlayerInCoords(posOne, posTwo, username) -> bool
isPlayerInCubic(w, h, d, username) -> bool
isPlayersInRange(range) -> bool
isPlayersInCoords(posOne, posTwo) -> bool
isPlayersInCubic(w, h, d) -> bool
```

Events:

- `playerClick (username, devicename)` — fires when a player right-clicks the detector
- `playerJoin (username, dimension)`
- `playerLeave (username, dimension)`
- `playerChangedDimension (username, fromDim, toDim)`

### `chat_box`

```lua
sendMessage(message[, prefix, brackets, bracketColor, range, utf8Support])
sendMessageToPlayer(message, username[, prefix, brackets, bracketColor, range, utf8Support])
sendToastToPlayer(message, title, username[, prefix, brackets, bracketColor, range, utf8Support])
sendFormattedMessage(json[, prefix, brackets, bracketColor, range, utf8Support])
sendFormattedMessageToPlayer(json, username[, ...])
sendFormattedToastToPlayer(messageJson, titleJson, username[, ...])
```

`json` accepts Minecraft's text-component JSON. Event `chat (username, message, uuid, isHidden, messageUtf8)`.

### `energy_detector`

In-line FE meter / resistor. Place between two cables; energy flows through it.

```lua
getTransferRate() -> int                -- FE/t passing through right now
getTransferRateLimit() -> int           -- configured ceiling
setTransferRateLimit(limit)             -- FE/t cap
```

No events.

### `block_reader`

Reads the block directly in front of the peripheral.

```lua
getBlockName() -> string                -- "minecraft:dirt"
getBlockData() -> table|nil             -- TE NBT, nil if not a TE
getBlockStates() -> table               -- properties like { facing="north", lit=true }
isTileEntity() -> bool
```

No events. Useful for inspecting Create signal blocks, contraption controllers, etc.

### `geo_scanner`

FE-fueled chunk scanner. Returns block positions + names within a radius.

```lua
scan(radius) -> { { name, tags, x, y, z } } | nil, err
chunkAnalyze() -> table | nil, err      -- ore distribution in current chunk
cost(radius) -> int                     -- FE for a scan
getMaxFuelLevel() -> int
```

There is a per-scan FE cost and a cooldown.

### `environment_detector`

```lua
getBiome() -> string
getBlockLightLevel() -> int             getDayLightLevel() -> int
getSkyLightLevel() -> int               getDimension() -> string
listDimensions() -> { string }          -- includes modded dims
getMoonId() -> int                      getMoonName() -> string
getTime() -> int                        -- ticks-of-day
isRaining() -> bool                     isSunny() -> bool
isThunder() -> bool                     isSlimeChunk() -> bool
scanEntities(range) -> { { name, x, y, z, health, uuid, effects } }
-- getRadiation() -> table              -- requires Mekanism (NOT in this pack)
```

### `inventory_manager`

**Requires a Memory Card** linked to a player (right-click the card with the player to bind it, then place it in the manager). One card per manager.

```lua
addItemToPlayer(direction, item) -> int       -- moves from adjacent container into player
removeItemFromPlayer(direction, item) -> int  -- moves from player into adjacent container
getArmor() -> { table }
getItems() -> { table }
getOwner() -> string|nil
isPlayerEquipped() -> bool
isWearing(slot) -> bool                       -- 100..103 = armor slots
getItemInHand() -> table|nil
getItemInOffHand() -> table|nil
getFreeSlot() -> int
isSpaceAvailable() -> bool
getEmptySpace() -> int
```

`direction` is `"up" | "down" | "north" | "south" | "east" | "west"`. `item` is a filter table like `{ name = "minecraft:diamond", count = 1 }`.

### `nbt_storage`

Persistent disk-resident NBT key/value.

```lua
read() -> table
writeJson(json) -> bool, err
writeTable(tbl) -> bool, err
```

No events.

### `ar_controller`

HUD overlay rendered by AR Goggles linked to the controller (right-click the controller while holding the goggles). Colours are hex (`0xff00ff`).

```lua
drawString(text, x, y, color)
drawCenteredString(text, x, y, color)
drawRightboundString(text, x, y, color)
horizontalLine(x1, x2, y, color)
verticalLine(x, y1, y2, color)
fill(x1, y1, x2, y2, color)
fillGradient(x1, y1, x2, y2, colorFrom, colorTo)
drawCircle(x, y, radius, color)
fillCircle(x, y, radius, color)
drawItemIcon(itemId, x, y)
clear()
clearElement(id)
setRelativeMode(enabled[, virtualWidth, virtualHeight])
```

Upstream notes the AR system is being reworked in 0.8r/1.0r — expect occasional flicker.

## Inert in this pack (target mod absent)

- `me_bridge` — no AE2
- `rs_bridge` — no Refined Storage
- `colony_integrator` — no MineColonies
- Mekanism telemetry methods — no Mekanism

The blocks/items still craft (AP ships them in the JAR), but the methods either error or return empties. See `absent-mods.md`.

## Removed / superseded in this pack version

- `redstone_integrator` — **removed in AP 0.7.50b**, this pack ships 0.7.61b. Use CC:T's `redstone_relay` (see `cc-tweaked-peripherals.md`).

## Smart turtle upgrades

Equip these as turtle upgrades; the equipped peripheral becomes findable from inside the turtle via `peripheral.find("<type>")`.

| Turtle | Equipped peripheral | Notes |
|---|---|---|
| Chatty Turtle | `chat_box` | Send messages from a turtle in-field |
| Chunky Turtle | (chunkloader, no API) | Keeps surrounding chunks loaded; consumes FE |
| Environment Turtle | `environment_detector` | Onboard env scanner |
| Player Turtle | `player_detector` | Onboard player detection |
| Geoscanning Turtle | `geo_scanner` | The most useful surveyor |
| Metaphysics / "End Automata" Turtle | varies | World-interaction abilities; check upstream |

For full upgrade method-shape parity with the block versions, refer back to the block sections above.
