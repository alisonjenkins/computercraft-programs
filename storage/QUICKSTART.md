# Storage system — quickstart

Walk-through from "I have redstone" to "`!give iron_ingot 64` works in chat." Targets minimum viable setup; expand later.

## Phase 0 — minimum viable parts list

Smallest working storage with chat-driven retrieval. Scale up by adding chests + modems later.

| Item | Qty | Materials |
|---|---|---|
| Computer (basic) | 1 | 7 stone + 1 redstone + 1 glass pane |
| Sophisticated Storage Chest | 4 | 8 oak planks + 1 redstone torch each (32 planks + 4 torches total) |
| Wired Modem | 6 | 8 stone + 1 redstone each (48 stone + 6 redstone) — 4 chests + computer + chat box |
| Network Cable | ≥6 | 4 stone + 1 redstone → yields 6 cable. One craft is usually enough for a small layout. |
| Chat Box | 1 | 8 logs + 1 gold + 1 peripheral casing |
| Peripheral Casing | 1 | 4 iron + 4 iron bars + 1 redstone block |
| Iron bars | 4 | 6 iron makes 16 bars; one craft gives plenty |
| Redstone block | 1 | 9 redstone |

**Totals:** 1 gold (chat box only), ~12 iron (5.5 for casing + headroom), ~25 redstone, 32 oak planks, 55 stone, 1 glass pane, 8 logs.

**Note:** Basic computer is enough — the storage controller doesn't use colour or mouse. Save advanced (gold-cased) for things that drive a coloured monitor or need mouse input. Same applies to the treefarm monitor and the builder turtle.

Designate one of the four chests as the **delivery slot** — somewhere a player can reach without standing on top of the modem network. The other three are bulk storage.

## Phase 1 — gather resources

Priority order:

1. **Iron** — for peripheral casing + iron bars. Need 6+ ingots minimum. Deep-cave iron deposits or basic mob-grinder pre-iron-pick.
2. **Gold** — 7 ingots = one advanced computer. Mine in badlands biomes (surface gold) or trade with piglins.
3. **Redstone** — ~25 dust + 9 dust to compact into 1 block. Y=-58 in deepslate.
4. **Oak planks + logs** — abundant. Get from the (manual) tree-chopping that the Create farm will eventually replace.
5. **Stone** — smelt cobblestone. Furnace + the existing `smelter.lua` if you've wired one up.
6. **Glass pane** — 6 sand → 1 furnace cycle → 6 glass → 16 panes (3 panes per glass × 6).

**Defer:** Do NOT craft a Geo Scanner — that consumes all 4 of your diamonds. Save them for a mining turtle later.

## Phase 2 — craft

Order matters; some items are inputs to others.

```
1. iron bars        : 6 iron ingots             (1 craft yields 16; one is enough)
2. redstone block   : 9 redstone dust
3. peripheral casing: 4 iron + 4 iron bars + 1 redstone block
4. chat box         : 8 logs + 1 gold ingot + 1 peripheral casing
5. computer (basic): 7 stone + 1 redstone + 1 glass pane
6. wired modem ×6   : 8 stone + 1 redstone each
7. network cable    : 4 stone + 1 redstone (yields 6 segments)
8. soph. chest ×4   : 8 oak planks + 1 redstone torch each
```

(Redstone torch = 1 stick + 1 redstone — make 4 at a craft.)

See `packs/arkana-aeronautics/docs/recipes.md` for exact 3×3 patterns. Verify in JEI/EMI in-game before committing materials.

## Phase 3 — wire up in-game

```
              [chat box]
                  │
                  │  (modem)
                  │
   [chest]──cable──[chest]──cable──[chest]──cable──[chest]
      │                                              │
      │                                              │
   (modem)                                       (modem)
      │                                              │
   ┌──┴──┐                                       (delivery)
   │ comp│
   │(adv)│
   └─────┘
      │
   (modem)
```

Steps:

1. Place all 4 Sophisticated chests in a row (or any layout — modems make distance irrelevant).
2. Place computer somewhere reachable.
3. Place chat box anywhere connected.
4. Stick a wired modem on each of: every chest, the computer, the chat box. (Right-click the block face you want, with the modem in hand.)
5. Connect adjacent modems with network cable. Cable can go in straight lines or around corners.
6. Right-click each modem once — the red ring lights up and the block joins the network.

Verify: at the computer, run `peripherals` — you should see the chests, the chat box, and `top` (or whichever side the computer's modem is on).

## Phase 4 — name the delivery chest

At the computer's shell:

```
peripherals
```

You'll see something like:

```
Connected peripherals:
  sophisticatedstorage:chest_0  (storage_unit, inventory)
  sophisticatedstorage:chest_1  (storage_unit, inventory)
  sophisticatedstorage:chest_2  (storage_unit, inventory)
  sophisticatedstorage:chest_3  (storage_unit, inventory)
  chatBox_0                     (chat_box)
```

Pick one of the chest names as the delivery chest — the one closest to where you'll stand. Note its exact name (e.g. `sophisticatedstorage:chest_3`).

Tell the program. Two ways:

```
# (A) via shell, using CC:T's settings API:
set delivery_chest sophisticatedstorage:chest_3
set save /.storage_settings  # then call settings.save in-game
```

Cleaner: edit `storage/controller.lua` line 16 directly:

```lua
delivery_chest = "sophisticatedstorage:chest_3",
```

## Phase 5 — install the program files

Goal: get these files onto the computer:

```
/lib/inv.lua
/lib/log.lua
/storage/controller.lua
/storage/index.lua
/storage/commands.lua
/startup.lua          (optional — auto-run on reboot)
```

### Path A — `install.lua` over HTTP (RECOMMENDED — easiest in-game)

If the repo is pushed to GitHub at `<user>/computercraft-programs`:

```
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua storage
```

That single command fetches `install.lua`, runs it, and the installer in turn pulls all storage files (`lib/inv.lua`, `lib/log.lua`, `storage/controller.lua`, `storage/index.lua`, `storage/commands.lua`) into the right paths. Re-running it is the update mechanism.

Add `--autostart storage` to also write a `/startup.lua` so it auto-runs on reboot:

```
wget run https://raw.githubusercontent.com/<user>/computercraft-programs/master/install.lua storage --autostart storage
```

If you'd rather not type the GitHub URL every time, paste `install.lua` to pastebin once and use `pastebin run <id> storage`.

### Path B — drop into world directory (server-side)

CC:T stores per-computer files under `<world>/computercraft/computer/<id>/`. With shell access to the server:

1. Note the computer's ID — at its shell type `id` or look at the title bar.
2. On the server:

   ```bash
   COMPUTER_DIR="<world-dir>/computercraft/computer/<id>"
   cd /path/to/computercraft-programs
   mkdir -p "$COMPUTER_DIR"/lib "$COMPUTER_DIR"/storage
   cp lib/inv.lua lib/log.lua            "$COMPUTER_DIR"/lib/
   cp storage/controller.lua storage/index.lua storage/commands.lua "$COMPUTER_DIR"/storage/
   ```

3. In-game, on the computer: `ls`, `ls lib`, `ls storage` — confirm files appear. (If not, `reboot` the computer.)

### Path C — host an HTTP server temporarily (no GitHub)

From your dev machine, in this repo's root:

```bash
python3 -m http.server 8000
```

In-game on the computer (replace `<dev-ip>` with your machine's LAN IP):

```
mkdir lib
mkdir storage
wget http://<dev-ip>:8000/lib/inv.lua            lib/inv.lua
wget http://<dev-ip>:8000/lib/log.lua            lib/log.lua
wget http://<dev-ip>:8000/storage/controller.lua storage/controller.lua
wget http://<dev-ip>:8000/storage/index.lua      storage/index.lua
wget http://<dev-ip>:8000/storage/commands.lua   storage/commands.lua
```

CC:T server config must allow `http` to your dev IP — usually open by default.

In-game: `wget run http://<dev-ip>:8000/install.lua --base http://<dev-ip>:8000 storage`

### Path D — pastebin per file

Each file can go into a pastebin paste, then `pastebin get <id> <path>` on the computer. Slow for 5 files; only worth it if neither A nor B is possible.

### Path E — floppy disk

Two computers + 1 disk drive + N floppies. Tedious; skip unless desperate.

## Phase 6 — first run

On the computer:

```
storage/controller.lua
```

Expected output:

```
[storage] [INFO] indexing 3 chests
[storage] [INFO] index built: 12 distinct items
```

(Numbers depend on what you've stocked.)

Walk to the chat box and type in chat:

```
!list
```

The chat box should reply with the top items by count, prefixed with `[storage]`.

```
!give iron_ingot 32
```

The program should `pushItems` 32 iron from any chest containing iron into your delivery chest. Open the delivery chest — items present.

```
!find redstone
```

Should reply with names matching "redstone" plus their counts and location counts.

## Phase 7 — make it auto-start

On the computer:

```
edit startup.lua
```

Contents:

```lua
shell.run("storage/controller.lua")
```

Save (Ctrl-S → exit). On next reboot the storage controller runs automatically. Useful when the server restarts.

## Phase 8 — extend

Now you have a baseline. Easy upgrades:

- **More chests.** Add Sophisticated chests + modems + cable. The program auto-discovers `inventory` peripherals on every reindex (every 60s by default, or `!reindex` on demand).
- **Better matching.** Currently substring-on-name. To add tag matching: edit `storage/index.lua` `matchNames` to also check `entry.locations[1]`'s tags via `getItemDetail`.
- **Funnel-fed input chest.** Place a Create funnel above one chest pulling from a hopper or belt — items dropped into the hopper end up in storage automatically.
- **Inventory Manager direct-delivery.** Craft an Inventory Manager + Memory Card; bind the card to your player. Adapt `handleGive` to call `inv_manager.addItemToPlayer` instead of `pushItems` when the manager is on the network.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `peripherals` shows nothing | Modems not right-clicked / cable not connected | Right-click each modem once; verify red ring is lit |
| `storage/controller.lua: assertion failed: set CONFIG.delivery_chest` | CONFIG not set | Edit `controller.lua` line 16 with delivery chest name |
| `assertion failed: no chat_box found` | Chat box's modem not attached, or chat_box too far from cable | Re-attach modem; check `peripherals` lists `chat_box` |
| Chat commands don't trigger | Chat box doesn't see your chat | Check chat_box range config; AP defaults to global chat. Try `!help` |
| `!give` reports "nothing matched" | Item name doesn't match | Try the exact ID (`minecraft:iron_ingot`) or a longer substring |
| Index is stale after I add items manually | 60s reindex hasn't run | `!reindex` in chat |
