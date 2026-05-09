# CC: Tweaked — networking

**Status in this pack:** Active. http allow/deny is server-config — defaults are usually open. Upstream: https://tweaked.cc/module/rednet.html, https://tweaked.cc/module/http.html, https://tweaked.cc/module/gps.html

## `rednet` — over a modem

```lua
rednet.open(side)             rednet.close([side])
rednet.isOpen([side]) -> bool

rednet.host(protocol, hostname)
rednet.unhost(protocol)
rednet.lookup(protocol[, hostname]) -> id, ...

rednet.send(recipient, message[, protocol]) -> bool
rednet.broadcast(message[, protocol])
rednet.receive([protocol[, timeout]]) -> id, message, protocol
```

Reserved channels: `CHANNEL_BROADCAST = 65535`, `CHANNEL_REPEAT = 65533`. Computer ID is the rednet address.

`message` can be any serialisable Lua value (number, string, bool, table). Tables get `textutils.serialise`d under the hood.

## Modems (raw)

For non-rednet patterns (custom protocols, multi-channel pubsub):

```lua
local m = peripheral.find("modem")
m.open(42)
m.transmit(42, 99, { type = "ping" })
local _, side, ch, replyCh, msg, dist = os.pullEvent("modem_message")
```

Range: wireless 64 → 384 (linear with altitude). Ender modems: unlimited + cross-dimension. Wired: unlimited within cable network. `m.isWireless()` distinguishes.

## `http`

```lua
http.get(url[, headers[, binary]]) -> handle, err
http.post(url, body[, headers[, binary]]) -> handle, err
http.request(opts)                 -- async; fires http_success / http_failure
http.checkURL(url) -> bool, err
http.checkURLAsync(url)            -- fires http_check

http.websocket(url[, headers]) -> ws, err     -- sync
http.websocketAsync(url[, headers])           -- fires websocket_success
```

Response handle:

```lua
local h = http.get(url)
local body = h.readAll()
local code, msg = h.getResponseCode()
local hdrs = h.getResponseHeaders()
h.close()
```

Websocket:

```lua
ws.send(text|bytes[, isBinary])
ws.receive([timeout]) -> message, isBinary
ws.close()
```

**1.109+ caveat:** response bodies are returned as raw bytes, not auto-decoded UTF-8. Use `cc.strings` or `string.char` to handle. Server-side `http.rules` can blacklist hosts and limit websocket message sizes (`http.max_websocket_message`).

## `gps`

```lua
gps.locate([timeout[, debug]]) -> x, y, z | nil
```

Needs **≥4** GPS hosts in line of sight running:

```lua
gps host <x> <y> <z>
```

…on wireless modems with non-overlapping positions. Without coverage, returns `nil`.

`vector.new(x, y, z)` plus `gps.locate()` is the standard pose primitive for turtle pathing.

## Worked patterns

**Single-protocol pubsub:**

```lua
rednet.open("back")
rednet.host("smelter", os.getComputerLabel() or "anon")

while true do
  local id, msg = rednet.receive("smelter")
  -- handle …
end
```

**Direct modem fan-out (one channel per topic):**

```lua
local CH_STATUS = 100
m.transmit(CH_STATUS, CH_STATUS, { node = id, fuel = turtle.getFuelLevel() })
```
