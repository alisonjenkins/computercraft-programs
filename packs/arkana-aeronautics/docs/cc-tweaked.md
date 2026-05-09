# CC: Tweaked — top-level Lua APIs

**Status in this pack:** Active. Version 1.118.0 (Modrinth `gu7yAYhd`). Upstream: https://tweaked.cc/

## Globals (always available, no `require`)

| API | Purpose | Docs |
|---|---|---|
| `_G` | Global table | — |
| `colors` / `colours` | Named colour constants for monitors / term blit | https://tweaked.cc/module/colors.html |
| `commands` | Command-block API (only on command computers) | https://tweaked.cc/module/commands.html |
| `disk` | Floppy/disk drive convenience | https://tweaked.cc/module/disk.html |
| `fs` | Filesystem | https://tweaked.cc/module/fs.html |
| `gps` | Position lookup over wireless modem | https://tweaked.cc/module/gps.html |
| `help` | In-game help system | https://tweaked.cc/module/help.html |
| `http` | HTTP client + websockets | https://tweaked.cc/module/http.html |
| `io` | Lua-style stdio | https://tweaked.cc/module/io.html |
| `keys` | Keycode constants | https://tweaked.cc/module/keys.html |
| `multishell` | Tabbed shells (advanced computers) | https://tweaked.cc/module/multishell.html |
| `os` | Time, events, timers, labels | https://tweaked.cc/module/os.html |
| `paintutils` | Pixel/box/line drawing on terminals | https://tweaked.cc/module/paintutils.html |
| `parallel` | Cooperative multitasking (`waitForAny`, `waitForAll`) | https://tweaked.cc/module/parallel.html |
| `peripheral` | Find/wrap/list peripherals | https://tweaked.cc/module/peripheral.html |
| `pocket` | Pocket-computer upgrade slots (`equipBack`, `unequipBack`, `getEquippedBack` in 1.21.x) | https://tweaked.cc/module/pocket.html |
| `rednet` | Networking layer over modems | https://tweaked.cc/module/rednet.html |
| `redstone` | Read/write redstone on the computer's own sides | https://tweaked.cc/module/redstone.html |
| `settings` | Persistent key/value config | https://tweaked.cc/module/settings.html |
| `shell` | Shell built-ins (only inside the shell) | https://tweaked.cc/module/shell.html |
| `term` | Terminal output / cursor / colour | https://tweaked.cc/module/term.html |
| `textutils` | Pretty-print, tabulate, JSON serialise | https://tweaked.cc/module/textutils.html |
| `turtle` | Turtle movement / inventory (turtles only) | https://tweaked.cc/module/turtle.html |
| `vector` | 3D vector type (used with `gps`) | https://tweaked.cc/module/vector.html |
| `window` | In-process windowing redirect | https://tweaked.cc/module/window.html |

## `cc.*` libraries (require'd)

```lua
local pretty = require("cc.pretty")
```

| Library | Purpose | Docs |
|---|---|---|
| `cc.audio.dfpwm` | DFPWM encode/decode for `speaker.playAudio` | https://tweaked.cc/library/cc.audio.dfpwm.html |
| `cc.completion` | Generic tab-completion helpers | https://tweaked.cc/library/cc.completion.html |
| `cc.expect` | Argument type-checking | https://tweaked.cc/library/cc.expect.html |
| `cc.image.nft` | Read/write `.nft` images | https://tweaked.cc/library/cc.image.nft.html |
| `cc.pretty` | Pretty-printer | https://tweaked.cc/library/cc.pretty.html |
| `cc.require` | Build a custom `require`/`package` env | https://tweaked.cc/library/cc.require.html |
| `cc.shell.completion` | Shell-flavoured completers | https://tweaked.cc/library/cc.shell.completion.html |
| `cc.strings` | Wrap, ensure_width, split | https://tweaked.cc/library/cc.strings.html |

## `require` and package paths

`require` is auto-injected (Lua 5.1, backed by `cc.require`). Default `package.path` includes `?;?.lua;?/init.lua` and `/rom/modules/main/?.lua`. Use `cc.require.make(env, dir)` to scope a custom env.

## Useful `os.pullEvent` events

- `peripheral` / `peripheral_detach` (name)
- `monitor_touch` (side, x, y), `monitor_resize` (side)
- `modem_message` (side, channel, replyChannel, message, distance)
- `rednet_message` (id, message, protocol)
- `redstone`
- `key` (code, held), `key_up`, `char`, `paste`, `mouse_click`, `mouse_up`, `mouse_drag`, `mouse_scroll`
- `turtle_inventory`
- `timer` (id), `alarm` (id)
- `disk` (side), `disk_eject` (side)
- `http_success` / `http_failure` / `http_check`
- `websocket_success` / `websocket_failure` / `websocket_message` / `websocket_closed`
- `speaker_audio_empty` (name) — drive `speaker.playAudio` from a stream

## Server config (admin-controlled)

`computercraft-server.toml`: `http.enabled`, `http.rules`, `http.max_websocket_message`, `command_require_creative`, `turtle.fuel_limit`, `monitor.width`/`height`, `default_computer_settings`. Only relevant if you're running into a sandbox limit.
