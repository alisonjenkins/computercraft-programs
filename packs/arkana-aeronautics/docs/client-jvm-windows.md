# Client JVM tuning (Windows x86_64)

**Status in this pack:** Drop-in JVM args for running the Arkana Aeronautics client on Windows 10 / 11 x86_64. Uses generational ZGC (stable on Windows since Java 17, generational since Java 21). Validated against Adoptium Temurin 21 and Microsoft Build of OpenJDK 21 on Windows 11.

## Drop-in args

Paste into PrismLauncher / CurseForge / MultiMC JVM arguments (replace any existing GC flags first):

```
-Xms8G -Xmx8G -XX:SoftMaxHeapSize=6G
-XX:+UseZGC -XX:+ZGenerational
-XX:+UseStringDeduplication
-XX:+ParallelRefProcEnabled
-XX:+DisableExplicitGC
-XX:ReservedCodeCacheSize=400M
-XX:-DontCompileHugeMethods
-XX:MaxDirectMemorySize=2G
-XX:+PerfDisableSharedMem
-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8
-Djava.net.preferIPv4Stack=true
-Dlog4j2.formatMsgNoLookups=true
```

Tune `-Xmx` to fit. 8 GB comfortable for Arkana on 16 GB+ systems. Match `-Xms` to `-Xmx` so the JVM never resizes. **Don't exceed `physical RAM - 4 GB`** — Windows itself, browsers, and the launcher all want headroom.

On Java 25+, drop `-XX:+ZGenerational` (generational ZGC is the default, the flag was removed).

## Why these flags

Identical rationale to the Linux variant — see `client-jvm-linux.md` for the per-flag table. Windows-specific differences:

| Difference | Why |
|---|---|
| **No `-XX:+AlwaysPreTouch`** | On Windows, pre-touching pages is slower than on Linux and the page-fault cost during play is lower (Windows commits memory more eagerly). Adding it makes launch ~3-5 s slower with marginal during-play benefit. Add it if you specifically want zero post-launch hitches and don't mind the wait. |
| **No `UseLargePages`** | Windows requires `SeLockMemoryPrivilege` (group policy: "Lock pages in memory") for the launcher user. Most users haven't configured it. Skip unless you've done that setup explicitly. |
| **No `UseTransparentHugePages`** | Linux-only feature. JVM ignores it on Windows. |
| **No `UseNUMA`** | Windows desktops are virtually always single-socket. Threadripper Pro / Xeon workstations can opt in. |

Everything else (StringDedup, ParallelRefProc, DisableExplicitGC, ReservedCodeCacheSize, DontCompileHugeMethods, MaxDirectMemorySize, PerfDisableSharedMem, file.encoding, preferIPv4Stack, log4j) applies identically.

## Optional flags worth considering

| Flag | When |
|---|---|
| `-XX:+AlwaysPreTouch` | You see a 1-2 s hitch the first time you fly through unloaded chunks. Adds 3-5 s to launch. |
| `-XX:ReservedCodeCacheSize=512M` | Bump if logs show `CodeCache is full` after extended play. |
| `-XX:+UseLargePages` | Only after enabling "Lock pages in memory" group policy for your account. See https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/enable-the-lock-pages-in-memory-option-windows |

## Sharp edges to skip

- `-XX:+AggressiveOpts` — removed in JDK 11+, JVM refuses to start.
- `-XX:+UseG1GC` — defeats the purpose. Distant Horizons specifically warns against it.
- Aikar's flag set — G1-tuned for Paper servers, hurts ZGC client performance.
- `-XX:MaxGCPauseMillis` — ignored by ZGC.
- `-XX:ParallelGCThreads` / `-XX:ConcGCThreads` — ZGC auto-tunes.
- `-Dlwjgl.glfw.checkThread0=false` — NeoForge bootstrap already sets it.
- `-Xss` overrides — Windows default thread stack is 1 MB, fine for modded MC. Don't shrink it.

## Verifying it's working

In the game log:

```
[main/INFO] [...] Using The Z Garbage Collector
```

Or press `F3` in-game; bottom-right info column shows:

```
GC: ZGC | Concurrent
```

If you see `G1` instead, the flags didn't apply — check the launcher's JVM args field has no leading whitespace and `Java arguments` is ticked (Prism) or pasted into "Additional Arguments" without quoting (CurseForge).

CodeCache pressure: open `%APPDATA%\.minecraft\logs\latest.log` (or instance-specific log path) and search for `CodeCache is full`. If present, bump `-XX:ReservedCodeCacheSize` to 512M.

## Per-launcher steps

### Prism Launcher

1. Right-click instance → `Edit`.
2. `Settings` → `Java`.
3. Tick `Java arguments` (override global), paste the args.
4. `Apply`. Restart instance.

### CurseForge Launcher

1. Settings (gear icon) → `Minecraft`.
2. `Minecraft Maximum RAM` slider → 8192.
3. `Java settings` → `Additional Arguments`: paste everything **except** `-Xms` and `-Xmx` (CurseForge handles those from the slider).

### MultiMC

Same as Prism (shared lineage).

### ATLauncher

`Instance` → `Settings` → `Memory & Java` → `Java Parameters` → paste args minus `-Xms`/`-Xmx`. Use the RAM slider for heap.

### Modrinth App

`Instance` → `Settings` (cog) → `Java and memory` → `Custom JVM arguments` → paste args.

## Sources

- OpenJDK ZGC Wiki — https://wiki.openjdk.org/display/zgc/Main
- ZGC Configuration Guide — https://docs.oracle.com/en/java/javase/21/gctuning/z-garbage-collector.html
- Microsoft Build of OpenJDK — https://learn.microsoft.com/en-us/java/openjdk/
- Adoptium Temurin 21 (Windows installers) — https://adoptium.net/temurin/releases/
- Windows large-pages setup — https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/enable-the-lock-pages-in-memory-option-windows
