# Create rotational power — early-game guide

**Status in this pack:** Reference. Default Create 6.0.10 stress numbers (pack ships no stress-config override per `datapacks.nix`/`overlays.nix`). Verify exact SU in-game with a stressometer.

Goal: a cheap, scalable, low-effort source of Stress Units (SU) for a freshly-redstone'd base in Arkana Aeronautics. Used to power the tree farm saw, mechanical press, mixers, mills, etc.

## Power source comparison (default Create 6.0)

| Source | Cost (per unit) | Output | Footprint | Notes |
|---|---|---|---|---|
| Hand Crank | 3 planks + 1 andesite alloy | 32 SU @ 32 RPM (while held) | 1×1 | Manual. Not for sustained power. |
| **Water Wheel** | 8 planks + 1 shaft (= 1/8 alloy) | ~256 SU @ ~8 RPM | 1×1×1 | Cheap, renewable, scales horizontally. |
| **Large Water Wheel** | 1 water wheel + 8 planks | ~1024 SU @ ~8 RPM | **3×3**×1 | 4× the SU per shaft. Best ratio if you have water. |
| Windmill Bearing | 1 wooden slab + 1 stone + 1 shaft + N sails | scales linearly with sails | small bearing + tall sail superstructure | Variable. Needs lots of wool for sails. Good if no water. |
| Steam Engine | 1 gold plate + 1 andesite alloy + 1 copper block | 1024+ SU @ 16 RPM, scales with boiler | small + boiler infra | Mid-game. Needs Mechanical Press (for gold plate), blaze burner, fluid tank, fuel pipeline. |
| Flywheel | needs brass | passive multiplier on Steam Engine | small | Late game. Skip until brass-tier industry. |

**Verdict for early-game Arkana with a dedicated server:**

1. **Primary recommendation: Large Water Wheel array.** Best SU-per-shaft, simple build, river-friendly.
2. **Backup: Windmill Bearing.** Use if base is far from running water. Linear scale with sails.
3. **Skip: Steam Engine, Flywheel, Hand Crank** until later or for niche uses.

## Recommended build — 4× Large Water Wheel array

Provides ~4096 SU @ ~8 RPM. Easily covers tree farm + mechanical press + mixer + handful of small machines with headroom.

### Materials

| Item | Qty | Recipe |
|---|---|---|
| Andesite alloy | ~6 | 1 andesite + 1 iron nugget (Mixer or shapeless, see `recipes.md`) |
| Shaft | ~8 (1 alloy stack craft = 8) | 2 alloy → 8 shafts |
| Plank (any wood) | 64 | 4 logs → 16 planks |
| Water Wheel | 4 | 8 planks + 1 shaft each |
| Large Water Wheel | 4 | 1 water wheel + 8 planks each (so 4 wheels intermediate) |
| Stressometer | 1 | speedometer ↔ stressometer (shapeless conversion). Speedometer = compass + andesite casing. |
| Andesite Casing | ~4 (for stressometer + connecting via gearboxes if needed) | 1 alloy + 1 stripped log |
| Compass | 1 | 4 iron + 1 redstone (vanilla) |
| Cogwheel | a few | 1 shaft + 1 plank (shapeless) |
| Gearbox (optional, for 90° turns) | 1–2 | 4 cogwheels + 1 andesite casing |

**Totals:** ~6 andesite + ~6 iron nuggets + 64 planks + 4 iron (for compass) + 1 redstone + ~2 stripped logs.

### Layout — flat river / canal

The simplest pattern: dig a 1-deep × N-wide canal next to your base. Place water source blocks at one end; the flow carries past the wheels.

```
plan view (looking down):
  ┌──────────────────────────────────────────────────────┐
  │ ░░░░░░░░░░░░░░░ flowing water ░░░░░░░░░░░░░░░░░░░░░░ │   ← canal, 1 deep
  └──────────────────────────────────────────────────────┘
  [LWW] [LWW] [LWW] [LWW]                                    ← 4 large water wheels in a row
   ║     ║     ║     ║                                       ← shafts come out of each LWW
   └──┬──┴──┬──┴──┬──┴──┐
      └─────┴─────┴─────┘── shaft to base                    ← all wheels share the same axle
```

Each Large Water Wheel is **3×3×1**. Place them so:

- The **front face** (the side the wheel turns toward) is in contact with at least one **flowing** water source. More flowing sides = higher RPM up to a cap.
- The wheel's axle is horizontal, perpendicular to the water flow.
- The 4 wheels share a single shaft along the rear, summing their SU capacity onto one network.

Use a **straight shaft connection** along the back: each wheel exposes a shaft on its centre back face; place a shaft block at each face and connect with intermediate shafts. Result: one continuous axle running through all 4 wheels.

### Water flow tips

- A 1-deep canal with a single water source block at the upstream end produces flow blocks for ~8 blocks downstream — fits all 4 wheels.
- For longer arrays, place a fresh source block every 8 blocks.
- For the flow to *do work*, the wheel needs to see the water flowing in the direction the wheel is facing. Place the source on the side opposite to the wheel's "front" arrow (visible by hovering with a wrench / Computer Tool).
- Water source blocks can come from a single bucket placed in a 2-block-wide depression — infinite source.

### Connecting to the network

Run a shaft from the back of the array horizontally toward your base. To turn 90°, use a **gearbox** (4 cogwheels + 1 andesite casing). To split 1:1 into multiple branches, use cogwheels meshing on adjacent shafts.

To monitor: place a stressometer on any shaft in the network. Right-click to see current SU usage / capacity. The needle indicates % used. Pair with a CC computer + `peripheral.find("stressometer")` to log SU usage over time (see `create-native-cc.md`).

## Alternative — Windmill Bearing (if no water)

```
1 windmill bearing (slab + stone + shaft) on top of a tall pillar.
Sail blocks attached to the front face of the bearing in a + or X pattern.
Right-click bearing with assemble tool → it spins.
```

- Each sail block adds RPM + a small SU contribution. A 7×7 sail face (~49 sails) gives roughly the same SU as 1 small water wheel.
- Sail Block recipe: 1 wool + 4 sticks (or similar — verify with JEI). Scales painfully if wool is scarce; sheep farm + shears speeds this up.
- Higher altitude = faster RPM (linear up to ~Y=160).

For Arkana with airships, an elevated windmill on the keep is thematic but materially expensive vs water wheels.

## Future scaling — Steam Engine

When you have brass + a Mechanical Press + a fluid pipeline:

- 1 Steam Engine + 1 Boiler (Fluid Tank base) + 1 Blaze Burner heated by fluid (lava or blazing) → 1024 SU at first level.
- Boiler scales with: water tank capacity, heat tier (passive / active / superheated), fuel pipeline.
- Stack engines on the same boiler — 4 engines ÷ 1 boiler is the typical layout.
- A maxed boiler can output >16 384 SU. Replaces the entire water wheel array.

Until brass: stick with water wheels.

## CC integration — monitoring SU

```lua
local stress = peripheral.find("stressometer")
print(("SU %d / %d (%.0f%%)"):format(
    stress.getStress(), stress.getStressCapacity(),
    100 * stress.getStress() / stress.getStressCapacity()))
```

Wire the stressometer to a wired modem on the same network as your storage / treefarm computer to add an SU panel to your dashboard. See `create-native-cc.md` for the full peripheral methods.

## Verification

1. After assembly, place a **speedometer** on the same shaft as the wheels. Should read ~8 RPM with full water flow.
2. Place a **stressometer** on the same shaft. With nothing consuming, should read 0% used. Capacity number = sum of all wheel SU contributions (~4096 for the recommended 4-wheel array).
3. Hook up a Mechanical Press as a smoke test. Press one item; stressometer should briefly spike, then return to baseline.
4. From a CC computer, `peripheral.find("stressometer").getStressCapacity()` should match what the in-game gauge shows.
