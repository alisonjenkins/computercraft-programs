# Client JVM tuning (macOS aarch64)

**Status in this pack:** Drop-in JVM args for running the Arkana Aeronautics client on Apple Silicon. Worked-out flag block plus the rationale for each line. Validated against Zulu 21 arm64; should also work on Liberica 21 arm64. **Will not work on Adoptium Temurin** — Temurin's macOS builds disable Shenandoah.

## Drop-in args

Paste into PrismLauncher → Edit Instance → Settings → Java → JVM arguments (replace any existing GC flags first):

```
-Xms8G -Xmx8G -XX:SoftMaxHeapSize=6G
-XX:+UseShenandoahGC -XX:+UnlockExperimentalVMOptions
-XX:ShenandoahGCMode=satb -XX:ShenandoahUncommitDelay=1000
-XX:+UseStringDeduplication
-XX:+ParallelRefProcEnabled -XX:+DisableExplicitGC
-XX:ReservedCodeCacheSize=400M -XX:-DontCompileHugeMethods
-XX:MaxDirectMemorySize=2G
-XX:+PerfDisableSharedMem
-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8
-Djava.net.preferIPv4Stack=true
-Dlog4j2.formatMsgNoLookups=true
```

Tune `-Xmx` to fit. 8 GB is comfortable for Arkana on a 16 GB Mac.

**PrismLauncher users:** **omit `-Xms` and `-Xmx` from the args string**. Prism injects those from its `Settings → Java → Memory` sliders. Set the sliders to **8192** (min and max) and paste the rest of the args without those two flags. Leaving them in the args string duplicates the flag and the JVM rejects launch.

**CurseForge users:** same — set the `Minecraft Maximum RAM` slider to 8192 and paste the args without `-Xms` / `-Xmx`.

## Why these flags

| Flag | What it does |
|---|---|
| `-Xms8G -Xmx8G` | Fixed heap. Equal min/max avoids resize churn. |
| `-XX:SoftMaxHeapSize=6G` | Shenandoah aims for 6 GB; expands to 8 GB only under pressure. Keeps idle memory lower. |
| `-XX:+UseShenandoahGC` | Concurrent mark + concurrent compact GC. Sub-ms pauses. |
| `-XX:+UnlockExperimentalVMOptions` | Required to use Shenandoah-specific knobs. |
| `-XX:ShenandoahGCMode=satb` | Snapshot-at-the-beginning marking. Default mode, most JNI-tolerant — works around the patterns in modded MC where mods cache raw object pointers across safepoints. |
| `-XX:ShenandoahUncommitDelay=1000` | Return idle pages to OS after 1 s (default is 5 min). Plays nicer with macOS memory pressure indicator. |
| `-XX:+UseStringDeduplication` | Folds duplicate String char arrays. Recipes, advancements, lang files duplicate a lot. Saves a few hundred MB on resource-pack-heavy runs. |
| `-XX:+ParallelRefProcEnabled` | Parallelizes weak/soft reference processing. |
| `-XX:+DisableExplicitGC` | Drops `System.gc()` calls (Netty, mods). Without it, full-GC pause storms during chunk loads. |
| `-XX:ReservedCodeCacheSize=400M` | Default 240 MB fills up in modded MC; once full the JIT falls back to interpreter and frametime stutters. Bump to 512 MB if you see `CodeCache full` in logs. |
| `-XX:-DontCompileHugeMethods` | Lets the JIT compile mods' giant generated methods (Mixins, ASM transforms). |
| `-XX:MaxDirectMemorySize=2G` | Caps NIO direct buffers (LWJGL textures, Netty). Without it a runaway mod can swallow RAM outside `-Xmx`. |
| `-XX:+PerfDisableSharedMem` | Skips `/tmp/hsperfdata` writes. Marginal but reduces fsync noise. |
| `-Dfile.encoding=UTF-8` (+ stdout/stderr) | Forces UTF-8 across the JVM. macOS default locale can cause garbled mod text otherwise. |
| `-Djava.net.preferIPv4Stack=true` | Shorter DNS resolution path. Helps multiplayer on dual-stack home networks. |
| `-Dlog4j2.formatMsgNoLookups=true` | Log4Shell mitigation. Likely already set by NeoForge bootstrap but harmless if duplicated. |

## Bootstrap context — why not ZGC?

ZGC (both generational and non-generational) repeatedly crashes on this modpack on macOS aarch64. Two distinct sites observed in production:

- `SIGSEGV` in `ZRelocateWork::try_relocate_object_inner` (relocation phase) — Microsoft build of OpenJDK 21.0.7.
- `SIGBUS` in `Chunk::chop()` (arena allocator) — Zulu 21.0.11.

Two crash sites across two JVM builds = the GC algorithm is the problem on this platform/workload combo, not a single bug. Likely causes:

- macOS aarch64's 16k native page size + ZGC's coloured-pointer mmap layout — younger backend, less battle-tested than Linux x86_64.
- LWJGL / Sodium / Veil pin native buffers; mods cache raw pointers across safepoints. ZGC's barriers are unforgiving here.

Shenandoah uses simpler load-reference barriers and is far more JNI-tolerant. Empirically stable.

Vanilla / non-modded MC on the same hardware does not exhibit these crashes — the issue is the JNI surface modded MC creates, not Java on macOS aarch64 generally.

## Sharp edges to skip

Don't add these — they're cargo-culted from Aikar's flags collection or from old Linux-x86 advice:

- `-XX:+UseLargePages` — macOS has no transparent huge pages, no-op (may log a warning).
- `-XX:+UseNUMA` — Apple Silicon is single-socket, no-op.
- `-XX:+AlwaysPreTouch` — adds ~2 s to startup, only useful if you see hitching on first GC. Most users don't need it.
- `-XX:+AggressiveOpts` — removed in JDK 11+, JVM will refuse to start.
- `-Dlwjgl.glfw.checkThread0=false` — NeoForge bootstrap already sets it. Redundant.

## Verifying it's working

After launch, in PrismLauncher's log:

```
[main/INFO] [...] Using ConcurrentMarkSweep (Shenandoah GC)
```

(or similar Shenandoah banner). If you see "Using G1 GC" instead, the flags didn't apply — check PrismLauncher's JVM args field for typos.

CodeCache pressure: search the log for `CodeCache is full` after an hour of play. If present, bump `-XX:ReservedCodeCacheSize` to 512M.

## Sources

- OpenJDK Shenandoah Wiki — https://wiki.openjdk.org/display/shenandoah/Main
- Azul Zulu downloads (arm64 macOS) — https://www.azul.com/downloads/
- BellSoft Liberica 21 (arm64 macOS) — https://bell-sw.com/pages/downloads/
- JNI varargs aarch64 macOS crash (unrelated but pertinent JDK 21 sharp edge) — https://github.com/java-native-access/jna/issues/1628
