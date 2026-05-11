# Client JVM tuning (Linux x86_64)

**Status in this pack:** Drop-in JVM args for running the Arkana Aeronautics client on Linux x86_64. Uses generational ZGC (stable + battle-tested on this platform, unlike Apple Silicon — see `client-jvm-macos.md` for the Shenandoah variant). Validated against OpenJDK 21 (Adoptium Temurin, Azul Zulu, Liberica, GraalVM CE) on x86_64.

## Drop-in args

Paste into PrismLauncher → Edit Instance → Settings → Java → JVM arguments (replace any existing GC flags first):

```
-Xms8G -Xmx8G -XX:SoftMaxHeapSize=6G
-XX:+UseZGC -XX:+ZGenerational
-XX:+AlwaysPreTouch
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

Tune `-Xmx` to fit. 8 GB comfortable for Arkana on 16 GB+ systems. Match `-Xms` to `-Xmx` so the JVM never resizes the heap. **Don't exceed `physical RAM - 4 GB`** (kernel + page cache + other processes need headroom).

On Java 25+, drop `-XX:+ZGenerational` (generational ZGC is the default, the flag was removed).

## Why these flags

| Flag | What it does |
|---|---|
| `-Xms8G -Xmx8G` | Fixed heap. Equal min/max avoids resize stutter. |
| `-XX:SoftMaxHeapSize=6G` | ZGC aims for 6 GB; expands to 8 GB only under pressure. Idle RSS stays lower, kinder to the page cache. |
| `-XX:+UseZGC` | Concurrent mark + relocate. Sub-millisecond pauses regardless of heap size — silences Distant Horizons' G1GC stutter warning. |
| `-XX:+ZGenerational` | Generational ZGC (Java 21+). Massively better throughput than legacy ZGC. Removed in 25 (default). |
| `-XX:+AlwaysPreTouch` | Faults in every heap page at startup. Adds ~1-2 s to launch but eliminates the page-fault stutters you'd otherwise get during the first few minutes of play. Worth it for fixed-heap + ZGC. |
| `-XX:+UseStringDeduplication` | Folds duplicate String char arrays. Recipes / advancements / lang files duplicate a lot — saves a few hundred MB on resource-pack-heavy runs. |
| `-XX:+ParallelRefProcEnabled` | Parallelises weak/soft reference processing. |
| `-XX:+DisableExplicitGC` | Drops `System.gc()` calls (Netty, some mods). Without it, full-GC pause storms during chunk loads. |
| `-XX:ReservedCodeCacheSize=400M` | Default 240 MB fills up in modded MC; once full the JIT falls back to interpreter and frametime stutters. Bump to 512 MB if you see `CodeCache is full` in logs. |
| `-XX:-DontCompileHugeMethods` | Lets the JIT compile mods' giant generated methods (Mixins, ASM transforms). |
| `-XX:MaxDirectMemorySize=2G` | Caps NIO direct buffers (LWJGL textures, Netty). Without it a runaway mod can swallow RAM outside `-Xmx`. |
| `-XX:+PerfDisableSharedMem` | Skips `/tmp/hsperfdata` writes — saves a few syscalls per second. Useful if `/tmp` is tmpfs and you want to keep it small. |
| `-Dfile.encoding=UTF-8` (+ stdout/stderr) | Forces UTF-8. Already default on most Linux distros, but harmless and consistent across launchers. |
| `-Djava.net.preferIPv4Stack=true` | Shorter DNS resolution path. Helps multiplayer on dual-stack home networks. |
| `-Dlog4j2.formatMsgNoLookups=true` | Log4Shell mitigation. NeoForge bootstrap already sets it; harmless if duplicated. |

## Optional flags worth considering

| Flag | When |
|---|---|
| `-XX:+UseLargePages` | Linux-only. Requires `vm.nr_hugepages > 0` (`sysctl`) OR `transparent_hugepage=always` in kernel cmdline. ZGC + hugepages = 1-3% throughput gain. Skip if you haven't already configured hugepages — silently no-ops with a warning otherwise. |
| `-XX:+UseTransparentHugePages` | Linux-only. Less manual setup than `UseLargePages`, requires `/sys/kernel/mm/transparent_hugepage/enabled` set to `madvise` or `always`. Most distros default to `madvise` — flag is safe to add. |
| `-XX:+UseNUMA` | Multi-socket systems only (Threadripper, dual-CPU workstations). Single-socket desktops/laptops: no-op. |
| `-XX:ReservedCodeCacheSize=512M` | Bump if logs show `CodeCache is full` after extended play. |

## Sharp edges to skip

- `-XX:+AggressiveOpts` — removed in JDK 11+, JVM refuses to start.
- `-XX:+UseG1GC` — defeats the purpose. Distant Horizons specifically warns against it.
- Aikar's flag set — G1-tuned for Paper servers, hurts ZGC client performance.
- `-XX:MaxGCPauseMillis` — ignored by ZGC (pause is always sub-millisecond).
- `-XX:ParallelGCThreads` / `-XX:ConcGCThreads` — ZGC auto-tunes from `Runtime.availableProcessors()`.
- `-Dlwjgl.glfw.checkThread0=false` — NeoForge bootstrap already sets it.

## Verifying it's working

In PrismLauncher's log or in-game:

```
[main/INFO] [...] Using The Z Garbage Collector
```

Or press `F3` in-game; bottom-right info column shows:

```
GC: ZGC | Concurrent
```

If you see `G1` instead, the flags didn't apply — check PrismLauncher's JVM args field has no leading whitespace and `Java arguments` is ticked under Settings → Java.

CodeCache pressure: `grep "CodeCache is full" .minecraft/logs/latest.log` after an hour of play. If present, bump `-XX:ReservedCodeCacheSize` to 512M.

## Per-launcher steps

### Prism Launcher

1. Right-click instance → `Edit`.
2. `Settings` → `Java`.
3. Tick `Java arguments` (override global), paste the args.
4. `Apply`. Restart instance.

### MultiMC

Same as Prism (shared lineage).

### CurseForge Launcher

1. Settings (gear icon) → `Minecraft`.
2. `Minecraft Maximum RAM` slider → 8192.
3. `Java settings` → `Additional Arguments`: paste everything **except** `-Xms` and `-Xmx` (CurseForge handles those from the slider).

### Vanilla launcher

NeoForge not supported by vanilla launcher without manual install — use Prism or CurseForge.

## Sources

- OpenJDK ZGC Wiki — https://wiki.openjdk.org/display/zgc/Main
- ZGC Configuration Guide — https://docs.oracle.com/en/java/javase/21/gctuning/z-garbage-collector.html
- Distant Horizons GC warning rationale — `packs/arkana-aeronautics/docs/client-jvm-macos.md` covers the same context
- Linux transparent_hugepage tuning — https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html
