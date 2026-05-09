# Arkana Aeronautics

Create-focused 1.21.1 NeoForge modpack with the Aeronautics + Sable physics overlay. CC programs in this repo target this pack unless noted otherwise.

## Versions (locked)

| Component | Version | Source |
|---|---|---|
| Minecraft | 1.21.1 | `../../../nix-config/pkgs/create-arkana-aeronautics-server/default.nix` |
| NeoForge | 21.1.228 | same |
| CC: Tweaked | 1.118.0 | `overlays.nix` (Modrinth `gu7yAYhd`) |
| CC:C Bridge | 1.7.2 | `overlays.nix` (Modrinth `fXt291FO`) |
| Advanced Peripherals | 0.7.61b | `overlays.nix` (Modrinth `SOw6jD6x`) |
| Create | 6.0.10 | `arkana-mods-extras.nix` (replacement) |
| Create: Aeronautics | 1.2.1 | `overlays.nix` (Modrinth `oWaK0Q19`) |
| Sable | 1.2.1 | `overlays.nix` (Modrinth `T9PomCSv`) |
| Create: Big Cannons | 5.11.3 | `overlays.nix` |
| Create: New Age | 1.1.7c | `overlays.nix` |
| Tiny Redstone | 6.1.3 | `overlays.nix` |

## Source files in nix-config

- `pkgs/create-arkana-aeronautics-server/default.nix` — MC + loader version
- `pkgs/create-arkana-aeronautics-server/overlays.nix` — overlay/replacement mods (CC:T, AP, CC:C Bridge, Aeronautics, etc.)
- `pkgs/create-arkana-aeronautics-server/arkana-mods.nix` — full mod list (~2800 lines)
- `pkgs/create-arkana-aeronautics-server/arkana-mods-extras.nix` — Create version replacement
- `pkgs/create-arkana-aeronautics-server/arkana-groups.nix` — mod-group classifications

## Other Create-family mods present (selection)

Create: Central Kitchen, Create: Enchantment Industry, Create: Dragons+, Create: Factory Logistics, Create: Liquid Fuel, Create: Oxidized, Create: Ultimate Factory, Create: Wizardry, Create: Aquatic Ambitions, Create: BetterFPS, Create: Ultimine, Aeronautics Compat.

## Storage mods present

Sophisticated Storage, Sophisticated Backpacks, Sophisticated Storage Create Integration, Sophisticated Backpacks Create Integration, EnderStorage, vanilla.

## Notable absences (matters for CC programs)

No AE2, no Refined Storage, no Mekanism, no MineColonies. AP's ME Bridge / RS Bridge / Colony Integrator / Mekanism methods are inert here. See `docs/absent-mods.md`.

## Where to start

`docs/index.md` — routing table from intent to doc.
