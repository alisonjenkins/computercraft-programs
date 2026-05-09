# CC:C Bridge

**Status in this pack:** Active. Version 1.7.2 for MC 1.21.1 NeoForge. Bridges Create blocks with CC: Tweaked.

Upstream docs: https://cccbridge.kleinbox.dev/

## `create_source` — Source Block

Computer → Create display targets (Flap Display, Nixie Tubes, Lectern signs, Sign blocks). Implements a Window-API-like terminal that Create displays read from.

```lua
getSize() -> w, h
clear()
setCursorPos(x, y)
write(text)
getLine(lineNum) -> string
```

**Caveats:** `setBackgroundColor` / `setTextColor` are accepted but ignored — display targets are colour-blind. Refresh is ~1/s by default; a redstone clock on the Display Link can speed it up.

Event: `monitor_resize (peripheralName)`.

Display targets pointable from a Source Block:

- Flap Display (Create)
- Nixie Tubes (Create)
- Lectern (the open book becomes the buffer)
- Sign (vanilla sign)

### Pattern

```lua
local s = peripheral.find("create_source")
s.clear()
s.setCursorPos(1, 1)
s.write("Train: " .. eta .. "s")
```

## `create_target` — Target Block

Reads from Create *display sources* (Stressometer, Steam Engine SU, Speedometer, fluid gauge, etc.) into a CC computer. Read-only window.

```lua
resize(w, h)                            -- min 1x1
getLine(y) -> string
dump() -> { string }                    -- all lines
getSize() -> w, h
```

Refresh rate depends on the connected Create source; a Display Link with a redstone clock helps.

## RedRouter Block

Single-block redstone I/O on six sides, addressable from a CC computer. Same sides convention as a turtle: front/back/left/right/up/down relative to facing.

```lua
setOutput(side, on)                     setAnalogOutput(side, value)
getOutput(side) -> bool                 getAnalogOutput(side) -> int
getInput(side) -> bool                  getAnalogInput(side) -> int
```

Event: `redstone` on signal change.

**Recommendation in this pack:** prefer CC:T's `redstone_relay` (built-in, six sides, supports bundled cable). RedRouter is fine if you already have CC:C Bridge wired up.

## Scroller Pane

Mouse-wheel HID. Returns scroll position; range -15..+15. Useful as a UI input on flat panels.

Type/method specifics: see https://cccbridge.kleinbox.dev/peripherals/ScrollerPanePeripheral/ (page intermittently 404s — confirm in-game with `peripheral.getMethods(name)`).

## Animatronic

Programmable puppet block. Place a modem **directly below** the Animatronic to peripherally connect.

```lua
setHeadRot(x, y, z)        getHeadRot() -> x, y, z          getHeadRotPending() -> x, y, z
setBodyRot(x, y, z)        getBodyRot() -> x, y, z          getBodyRotPending() -> x, y, z
setLeftArmRot(x, y, z)     getLeftArmRot() -> x, y, z       getLeftArmRotPending() -> x, y, z
setRightArmRot(x, y, z)    getRightArmRot() -> x, y, z      getRightArmRotPending() -> x, y, z
setFace(face)              -- "normal" | "happy" | "question" | "sad"
setMode(mode)              -- "linear" | "rusty" | "none"
push()                     -- commit pending rotations
```

Most parts: rotation -180..+180 on each axis. Body x-axis: full 360.

`set*` writes pending values; nothing animates until `push()`. Verify exact method names in-game with `peripheral.getMethods` — the upstream wiki is the source of truth, not this card.
