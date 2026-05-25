# Storage controller

CC computer indexes a wired-modem network of inventory chests and serves chat-driven retrieval.

**New here? Read [QUICKSTART.md](QUICKSTART.md) first** — step-by-step from "I have redstone" to "`!give iron_ingot 64` works."

## Hardware

| Block | Purpose |
|---|---|
| Computer (basic) | Runs `controller.lua`. Advanced not required — no colour/mouse needed. |
| Wired Modem (×N+2) | One per storage chest + computer + chat_box |
| Network Cable | Connects everything |
| Sophisticated Storage Chest (×N) | Capacity. Start with 4 chests; add more as needed |
| Sophisticated Storage Chest (×1) | **Delivery slot** — player accesses this |
| Chat Box | Command surface |
| Inventory Manager + Memory Card | (optional) direct-to-player delivery |

See `packs/arkana-aeronautics/docs/recipes.md`.

## Setup

1. Build storage chests in a row/grid. Place a wired modem on each.
2. Designate ONE chest as the delivery slot — somewhere the player can reach (kitchen counter, etc).
3. Connect everything with cable. Right-click each modem to attach.
4. Find the delivery chest's network name:
   ```
   peripherals  -- shell command
   ```
   Look for `sophisticatedstorage:chest_<n>`. Note the exact name.
5. Set the delivery chest. Either:
   - Edit `CONFIG.delivery_chest` in `controller.lua` directly, OR
   - On the computer: `set delivery_chest sophisticatedstorage:chest_3` (uses CC:T `settings` API; the controller loads `/.storage_settings`).
6. Copy files to the computer. Layout must mirror the repo:
   ```
   /lib/inv.lua
   /lib/log.lua
   /storage/controller.lua
   /storage/index.lua
   /storage/commands.lua
   ```
7. Run `storage/controller.lua`. Add a `startup.lua` with `shell.run("storage/controller.lua")` to auto-run.

## Commands (in chat)

| Command | Effect |
|---|---|
| `!list [prefix]` | Top 10 items by count, optional name filter |
| `!find <name>` | Up to 5 matches with totals + location count |
| `!give <name> <n>` | Move up to n of name into the delivery chest. Substring match. |
| `!reindex` | Force full rescan of all chests |
| `!defrag` | Merge partial stacks and group like items into the same chest. Respects per-slot capacity, so Sophisticated Storage stack-upgraded slots fill above 64 correctly. |
| `!help` | List commands |

The chat_box prefixes outgoing replies with `[storage]`.

## Whitelist (optional)

Edit `CONFIG.whitelist` in `controller.lua`:

```lua
whitelist = { ["alice"] = true, ["bob"] = true }
```

Default `nil` = open to everyone.

## Auto-ingest

Set `CONFIG.input_chest` (or `set input_chest <name>` in the shell) and the controller drains that chest into the rest of the network every 5 s. Useful as a "dump everything here" loot box. Routing is naive: first chest with space wins, no smart binning.

## Limits / known gaps

- Index is full-scan on startup + every 60s. Fine for ~100 chests; gets slow above that.
- No reservation locks — two simultaneous `!give` may double-allocate from the same slot.
- Substring match only. No fuzzy search, no tag-based search yet.
- Doesn't track NBT — two stacks of "the same" item with different durability/components are merged in the index.
- The Inventory Manager path (direct-to-player) is documented as optional but not implemented yet — current version uses the delivery chest only.
