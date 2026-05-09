# CC: Tweaked — built-in peripheral types

**Status in this pack:** Active. All built-ins available. Upstream: https://tweaked.cc/peripheral/

Peripheral discovery:

```lua
local m = peripheral.find("monitor")          -- first match anywhere on the wired network
local list = { peripheral.find("inventory") } -- variadic — captures all
peripheral.hasType("foo:bar", "inventory")    -- check by name
peripheral.getMethods(name)                   -- introspect
```

## `computer`

```lua
turnOn()        shutdown()      reboot()
getID() -> int  isOn() -> bool  getLabel() -> string|nil
```

## `monitor`

```lua
write(text)
clear()  clearLine()
setCursorPos(x, y)  getCursorPos() -> x, y  setCursorBlink(b)
getSize() -> w, h
setTextScale(scale)                          -- 0.5 .. 5
setTextColor(c)  getTextColor()
setBackgroundColor(c)  getBackgroundColor()
blit(text, fg, bg)                           -- per-char colours
scroll(n)
isColor() -> bool
setPaletteColor(c, hex)  getPaletteColor(c)  -- only on advanced monitors
```

Events: `monitor_touch (side, x, y)`, `monitor_resize (side)`.

## `modem` (wired, wireless, ender — same type)

```lua
open(channel)  isOpen(channel) -> bool  close(channel)  closeAll()
transmit(channel, replyChannel, payload)
isWireless() -> bool
```

Wired-only:

```lua
getNamesRemote() -> { string }       -- peripherals attached to the same network
isPresentRemote(name)
getTypeRemote(name) -> { string }
hasTypeRemote(name, type) -> bool
getMethodsRemote(name) -> { string }
callRemote(name, method, ...)
getNameLocal() -> string             -- this computer's network name
```

Range: wireless 64 blocks at sea level, scaling linearly to 384 at world height. Ender modems: unlimited, cross-dimension. Wired: unlimited within cable network.

Event: `modem_message (side, channel, replyChannel, message, distance)`.

## `drive` (disk drive)

```lua
isDiskPresent() -> bool
getDiskLabel() -> string|nil   setDiskLabel(label)
hasData() -> bool              getMountPath() -> string|nil
hasAudio() -> bool             getAudioTitle() -> string|nil
playAudio()  stopAudio()       ejectDisk()
getDiskID() -> int|nil
```

Events: `disk (side)`, `disk_eject (side)`.

## `printer`

```lua
write(text)
setCursorPos(x, y)  getCursorPos() -> x, y
getPageSize() -> w, h
newPage() -> bool   endPage() -> bool
setPageTitle(title)
getInkLevel() -> int
getPaperLevel() -> int
```

## `speaker`

```lua
playNote(instrument, volume, pitch)               -- noteblock instruments
playSound(name, volume, pitch)                    -- any minecraft:* sound
playAudio(samples, volume) -> bool                -- 8-bit PCM, 48 kHz, ±127, chunks ≤ 128*1024
stop()
```

Pair with `cc.audio.dfpwm` for streamed audio. Event `speaker_audio_empty (name)` signals the buffer is ready for the next chunk.

## `command` (command computer only)

```lua
getCommand() -> string   setCommand(cmd)
runCommand() -> bool, { string }
-- plus the global commands.* API
```

## `redstone_relay` (added in CC:T 1.114+)

A standalone block whose redstone is exposed over a wired-modem network — lets one computer drive redstone on six sides of the relay rather than its own six sides.

```lua
setOutput(side, on)            getOutput(side) -> bool
setAnalogOutput(side, n)       getAnalogOutput(side) -> n
getInput(side) -> bool         getAnalogInput(side) -> n
setBundledOutput(side, mask)   getBundledOutput(side) -> mask
getBundledInput(side) -> mask  testBundledInput(side, mask) -> bool
```

In this pack this **replaces AP's Redstone Integrator**, which was removed upstream in AP 0.7.50b.
