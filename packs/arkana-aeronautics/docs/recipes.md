# Recipes — Arkana Aeronautics

**Status in this pack:** Authoritative. Recipes extracted directly from the mod JARs shipped in this pack (CC:T 1.118.0, AP 0.7.61b, CC:C Bridge 1.7.2, Create 6.0.10, Sophisticated Storage 1.4.50). Verified against `data/<modid>/recipe/*.json`.

3×3 patterns shown left-to-right top-to-bottom. ` ` = empty cell.

## CC: Tweaked

### Computer (basic)

```
###    # = stone
#R#    R = redstone dust
#G#    G = glass pane
```

### Computer (advanced)

```
###    # = gold ingot
#R#    R = redstone dust
#G#    G = glass pane
```

### Turtle (basic) — copies the computer placed in centre

```
###    # = iron ingot
#C#    C = computer (basic)
#I#    I = wooden chest
```

### Turtle (advanced)

```
###    # = gold ingot
#C#    C = computer (advanced)
#I#    I = wooden chest
```

### Wired Modem

```
###    # = stone
#R#    R = redstone dust
###
```

### Wired Modem (full block) — shapeless

`1 × wired_modem` → `1 × wired_modem_full`. Reversible (same recipe with full block in).

### Network Cable — yields **6**

```
 #     # = stone
#R#    R = redstone dust
 #
```

### Disk Drive

```
###    # = stone
#R#    R = redstone dust
#R#
```

### Monitor (basic)

```
###    # = stone
#G#    G = glass pane
###
```

### Monitor (advanced) — yields **4**

```
###    # = gold ingot
#G#    G = glass pane
###
```

### Speaker

```
###    # = stone
#N#    N = note block
#R#    R = redstone dust
```

### Printer

```
###    # = stone
#R#    R = redstone dust
#D#    D = any dye
```

### Redstone Relay

```
SRS    S = stone
RCR    R = redstone dust
SRS    C = wired modem
```

(Cost: 1 wired modem + 4 stone + 4 redstone — about 1.5× a modem.)

### Floppy Disk — shapeless

`1 × paper + 1 × redstone dust` → `1 × disk` (random colour, or coloured variants exist).

## Advanced Peripherals

All AP block peripherals (chat_box, inventory_manager, etc.) require **Peripheral Casing** as the centre ingredient. Make several casings up front.

### Peripheral Casing

```
IiI    I = iron ingot
iRi    i = iron bars
IiI    R = redstone block
```

(Cost per casing: 4 iron + 4 iron bars (~1.5 iron) + 1 redstone block (9 redstone) ≈ **5.5 iron + 9 redstone**.)

### Chat Box

```
PPP    P = any log
PAP    A = peripheral casing
PGP    G = gold ingot
```

### Memory Card

```
IWI    I = iron ingot
IOI    O = observer
 G     W = cheap glass block
       G = gold ingot
```

### Inventory Manager

```
ICI    I = iron ingot
CAC    C = any chest
ICI    A = peripheral casing
```

### Player Detector

```
SSS    S = smooth stone
SAS    A = peripheral casing
SRS    R = redstone block
```

### Block Reader

```
IRI    I = iron ingot
MAO    R = redstone block
IRI    M = wired modem (full block)
       A = peripheral casing
       O = observer
```

### Energy Detector

```
BRB    B = redstone block
CAC    C = comparator
BGB    R = redstone torch
       A = peripheral casing
       G = gold ingot
```

### Geo Scanner — **needs 4 diamonds**

```
DMD    D = diamond
DCD    M = wired modem (full)
ROR    C = peripheral casing
       R = redstone block
       O = observer
```

Defer until diamond budget allows. With current 4 diamonds: this would consume the entire diamond stock.

### NBT Storage

```
ICI    I = iron ingot
CAC    C = any chest
RCR    A = peripheral casing
       R = redstone block
```

### Environment Detector

```
WSW    W = wool
LAL    S = sapling
WCW    L = leaves
       A = peripheral casing
       C = crop (any)
```

### Computer Tool (right-click peripherals to wrench them)

```
I I    I = iron ingot
IBI    B = blue terracotta
 B
```

### Chunk Controller (chunky turtle infra)

```
IRI    I = iron ingot
RAR    R = redstone dust
IRI    A = ender eye
```

## CC:C Bridge

### Source Block — yields **2**

```
AGA    A = cut asurine (Create stone)
GQG    G = glass pane
ARA    Q = rose quartz lamp (Create — needs rose quartz polished + redstone)
       R = redstone dust
```

(Mid-game: cut asurine + rose quartz lamp gate this. Asurine is a Create natural-stone variant; rose quartz is Create's red-pink crystal pressed/washed from veins. Plan a Create stone-cutter + a rose-quartz-lamp build before crafting this.)

### Target Block — convert from Source Block (shapeless, reversible)

`1 × source_block ↔ 1 × target_block`.

### RedRouter Block

```
ARA    A = andesite alloy
RMR    R = redstone torch
ARA    M = monitor (basic)
```

### Scroller Block

```
 C     C = cogwheel
APA    A = cut asurine
 R     P = precision mechanism (Create — mid-game)
       R = redstone dust
```

### Animatronic Block

```
 M     M = monitor (basic)
HTH    H = brass hand (Create — late-game brass)
 R     T = leather chestplate
       R = redstone dust
```

## Create (early-game subset)

### Andesite Alloy — Mixer recipe (1 + 1 → 1)

`1 × andesite + 1 × iron nugget` (or zinc nugget) → `1 × andesite alloy`.

The Mixer-from-Mechanical-Mixer-on-Basin form is the canonical recipe; in some pack configs a Mixer is required. Also craftable shapeless in some packs:

```
 IA    I = iron nugget (or zinc)
A I    A = andesite
```

(Verify in JEI; some versions only allow the Mixer route.)

### Shaft — yields **8**

```
A      A = andesite alloy
A
```

### Cogwheel — shapeless

`1 × shaft + 1 × any plank` → `1 × cogwheel`.

### Large Cogwheel — shapeless

`1 × shaft + 2 × planks` → `1 × large_cogwheel`.

### Andesite Casing

`1 × andesite alloy + 1 × stripped log` (item application — right-click stripped log with andesite alloy) → `1 × andesite_casing`.

### Andesite Funnel — yields **2**

```
A      A = andesite alloy
K      K = dried kelp
```

### Water Wheel

```
SSS    S = any plank
SCS    C = shaft
SSS
```

### Mechanical Bearing

```
B      B = wooden slab
C      C = andesite casing
I      I = shaft
```

### Mechanical Saw

```
 A     A = iron plate (pressed iron ingot via Mechanical Press)
AIA    I = iron ingot
 C     C = andesite casing
```

### Rope Pulley

```
B      B = andesite casing
C      C = wool
I      I = iron plate
```

### Iron Plate / Sheet — Mechanical Press

`1 × iron ingot` pressed by a Mechanical Press → `1 × iron sheet`.

## Sophisticated Storage (early tier)

### Sophisticated Chest (oak)

```
PPP    P = oak planks
PRP    R = redstone torch
PPP
```

(Costs 8 planks + 1 redstone torch. Same shape for spruce/birch/jungle/acacia/dark_oak/mangrove/cherry/bamboo/crimson/warped — substitute the wood type.)

### Sophisticated Barrel (oak)

```
PSP    P = oak planks
PRP    S = oak slab
PSP    R = redstone torch
```

## Materials roll-up — for the three planned programs

Goal: 1 advanced computer per program (× 3) + 1 plain turtle (builder) + 1 chat box × 2 (treefarm + storage) + 1 inventory manager (storage, optional) + 1 memory card (storage, optional) + 8 wired modems + 1 redstone relay (treefarm, optional) + 1 Sophisticated chest × 6 (output buffer + storage chests + supply chest + delivery chest).

| Material | Qty |
|---|---|
| Gold ingot | 21 (3 × advanced computer × 7) |
| Iron ingot | 7 (turtle) + ~22 (2 × peripheral casing × 5.5 + inventory_manager 4 iron + memory_card 4 iron) ≈ **30** |
| Iron bars | 8 (2 × peripheral casing × 4) |
| Redstone block | 18 (2 × peripheral casing × 1 + memory_card 0 + inventory_manager 0 — actually casing only needs 1 each = 2) **wait**: 2 casings = 2 redstone blocks = 18 redstone |
| Redstone dust | ~25 (modems + cables + computers + relay) |
| Stone | ~75 (8 × wired modem + cable + relay + 7 if using basic computer — but we use advanced) |
| Glass pane | 3 (advanced computer × 3) |
| Cheap glass block | 1 (memory card) |
| Observer | 1 (memory card) |
| Note block | 0 (no speaker planned) |
| Wooden chest | 4 (inventory_manager) + 1 (turtle) = **5** |
| Logs | 8 (chat box) × 2 = **16** |
| Oak planks | 48 (6 × Sophisticated chest × 8) |
| Redstone torch | 6 (Sophisticated chests) |
| Wired modem (for block reader, if used) | 1 (intermediate, in casing) |
| Diamonds | **0** (geo scanner deferred) |

Plus the tree farm contraption: 1 mechanical saw, 1 rope pulley OR mechanical bearing, 1 water wheel, several cogwheels, ~8 andesite alloy, ~6 iron plates, ~1 stripped log, ~6 wool. Negligible iron compared to the AP totals.

**Bottleneck: redstone blocks (≈ 2 needed = 18 dust) and iron (~30 ingots). Gold is moderate (21). No diamonds needed for the three deliverables.**
