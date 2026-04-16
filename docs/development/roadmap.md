# Cyrius Development Roadmap

> **v5.1.12.** cc5 compiler (408KB), x86_64 + aarch64 cross. IR + CFG.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5 (408KB). Closure verified.
> **60 test suites**, 14 benchmarks, 5 fuzz harnesses. **60 stdlib modules** (includes 6 deps).
> Caps: ident buffer 128KB (4.6.2), fn table 4096 (4.7.1).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | Localized with `CYRIUS_SYMS`. Classic memory corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG now available for diagnosis (5.0.0 IR). Note: ark cyml_parse crash (SA-002) was NOT this bug — was calling wrong function signature (nous.cyr 1-arg vs cyml.cyr 2-arg). |
| aarch64 native FIXUP address mismatch | Cross-compiled binaries run on Pi (exit 42 PASS). Native cc5 compiles input but output has wrong MOVZ/MOVK data addresses (0x800120 vs expected 0x4000A8). Heap synced to 21MB. Likely a 64-bit arithmetic or heap corruption issue in the native binary. Cross-compiler is the shipping path. | Tested on real Pi (agnosarm.local, Raspberry Pi aarch64). |

---

## Shipped

<details>
<summary>Click to expand shipped v5.x items</summary>

### v5.0.0 — cc5 Generation Bump
- cc5 IR (812 lines, 40 opcodes), CFG edge builder, LASE analysis, dead block detection
- cyrius.cyml manifest, `cyrius version`, CLI tool integrations
- cc3→cc5 rename, patra 1.0.0, sankoch 1.2.0

### v5.0.1 — Security Hardening
- alloc() overflow guard + size cap (256MB), negative/zero rejection
- vec/map capacity doubling overflow caps, alloc return checks
- arena_alloc overflow guard

### v5.0.2 — Preprocessor Fix
- `#ref` bol tracking — no longer matches inside strings or mid-line

### v5.0.3 — aarch64 Native + Version Tooling
- `main_aarch64_native.cyr` with host syscall numbers (openat, native read/write/brk/exit)
- Version check openat-aware, `version-bump.sh` cc3→cc5 fix

### v5.1.0 — macOS x86_64 (Mach-O)
- `CYRIUS_MACHO=1` triggers Mach-O output, tested on real hardware
- `lib/syscalls_macos.cyr`, `lib/alloc_macos.cyr` (mmap-based)

### v5.1.1 — Stdlib: sakshi + log.cyr
- sakshi 0.9.0 → 0.9.3 (SA-001 UDP fix, SK_FATAL, trace ID)
- log.cyr level mapping + output routing rewrite (delegates to sakshi)
- Removed duplicate sakshi symlinks, migrated to cyrius.cyml, CI cc3→cc5

### v5.1.2 — sakshi 1.0.0 + Release Pipeline
- sakshi 0.9.3 → 1.0.0 (first stable release)
- macOS Mach-O tarball in release pipeline (three-platform release)
- release.yml cc3→cc5, dep resolver prefers cyrius.cyml

### v5.1.3 — Codebase Cleanup
- Removed stale cyrius.toml, all cc2/cc3 refs in scripts + docs + programs
- cyrius-port.sh generates cyrius.cyml, read_manifest() prefers cyml
- CLAUDE.md recommended minimum → v5.0.0

### v5.1.4 — Starship + Dispatcher Fixes
- Starship detects cyrius.cyml, dispatcher manifest refs unified via find_manifest()
- Deep cc3→cc5 sweep: install.sh, ci.sh, dispatcher, regression tests, check.sh

### v5.1.5 — Script Inlining
- Native coverage, doctest, header in cyrius.cyr (115KB)
- Removed 3 shell scripts (237 lines)

### v5.1.6 — Modular Refactor
- Split cyrius.cyr into 7 modules (core, build, commands, project, quality, deps, main)
- cc3→cc5 in tool discovery

### v5.1.7 — cbt/ + Dep Fix
- Build tool → top-level `cbt/`, dep duplicate symlink fix, cyrc vet trust

### v5.1.8 — Native capacity, soak, pulsar
- `cyrius capacity/soak/pulsar` all native in cbt/, tool 129KB

### v5.1.9–v5.1.12 — Cleanup, fixes, closeout
- Stale refs swept, LSP cc3→cc5, starship fixed, cyriusly cmdtools
- toml_get cstring crash fixed, dep duplicates removed
- Shell dispatcher → 30-line shim, heapmap audit, benchmark baseline
- patra 1.1.0, capacity --check fixed

</details>

---

## v5.1.x — Tooling Consolidation

Compiled `programs/cyrius.cyr` (105KB) replaces shell dispatcher as primary entry point.

### v5.1.5 — Inline shell scripts into cyrius.cyr (shipped) ✅
- Native `cmd_coverage()`, `cmd_doctest()`, `cmd_header()` in cyrius.cyr
- Removed 3 shell scripts (237 lines → 0), compiled tool handles all natively

### v5.1.6 — Refactor cyrius tool into modules (shipped) ✅
- Split 2249-line monolith into 7 modules: core, build, commands, project, quality, deps, cyrius
- cc3→cc5 in tool discovery, output helpers, --quiet flag

### v5.1.7 — Top-level cbt/, dep duplicate fix (shipped) ✅
- Build tool → `cbt/`, cyrc vet trusts cbt/, dep resolver no duplicate symlinks

### v5.1.8 — Native capacity, soak, pulsar (shipped) ✅
- `cyrius capacity` (--check, --json), `cyrius soak`, `cyrius pulsar`
- `cbt/pulsar.cyr` module (165 lines), tool 129KB

### v5.1.12 — Shell shim + cleanup audit (shipped) ✅
- Shell dispatcher 1620 → 30 lines (thin shim, execs compiled tool)
- Heapmap audit: 43 regions, 0 overlaps. Dead code: 19 fns (kept).
- Benchmark baseline captured. Capacity --check fixed.
- patra 1.0.0 → 1.1.0

---

## v5.x — Platform Targets

Each platform is one minor release. cc5 backend-table dispatch
enables adding new targets without touching the frontend.

| Release | Platform | Format | Status |
|---------|----------|--------|--------|
| **v5.1.0** | macOS x86_64 | Mach-O | **Done** — CYRIUS_MACHO=1, tested on hardware |
| **v5.2.0** | macOS aarch64 | Mach-O | Apple Silicon native |
| **v5.3.0** | Windows x86_64 | PE/COFF | Stubs scaffolded (v3.1) |
| **v5.4.0** | RISC-V rv64 | ELF | First-class RISC-V target |
| **v5.5.0** | Bare-metal | ELF (no-libc) | AGNOS kernel target |

---

## v5.x — IR-Driven Optimization (when complete emit coverage)

LASE and DBE analysis is proven but codebuf patching is unsafe until
all emit paths go through IR. The path:

1. Instrument remaining ~50 emit calls (direct EB/E2/E3 from parse.cyr)
2. LASE codebuf patching becomes safe → redundant load elimination
3. DBE becomes safe → dead block NOP-fill
4. Sound multi-register allocation on IR (replaces peephole #regalloc)
5. Constant folding, strength reduction

---

## v5.x — Language Refinements

| Feature | Effort | Votes |
|---------|--------|-------|
| cc5 per-block scoping | Medium | — |
| Incremental compilation | High | — |
| Stack slices | High | — |
| Generics / traits | High | 1 (kavach) |
| Pattern-match destructuring | Medium | 1 (kavach) |
| Enum exhaustiveness checking | Low | 1 (kavach) |
| Closures capturing variables | High | gotcha #8 |
| Hardware 128-bit div-mod | Medium | — |

---

## Stdlib (60 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, linalg, bigint, u128 |
| Network | net, http, http_server, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, cffi |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda |
| Compression (dep) | sankoch |

---

## Platform Status

| Platform | Format | Status |
|----------|--------|--------|
| Linux x86_64 | ELF | **Done** — primary, cc5 408KB self-hosting |
| Linux aarch64 | ELF | **Partial** — cross-compiler works, native entry point ready (v5.0.3, needs ARM hardware validation) |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **Done** (v5.1.0) — CYRIUS_MACHO=1, tested on 2018 MacBook Pro |
| macOS aarch64 | Mach-O | Stub — **v5.2.0** |
| Windows x86_64 | PE/COFF | Stub — **v5.3.0** |
| RISC-V (rv64) | ELF | **v5.4.0** |
| Bare-metal | ELF (no-libc) | **v5.5.0** |

---

## Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik, agnosys, argonaut, kybernet, nous, ark |
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda, hadara |
| **Done** | sigil, patra, libro, shravan, tarang, yukti |
| **Done** | avatara, ai-hwaccel, hoosh, itihas, sankoch |
| **Done** | hisab |
| **In progress** | bhava |
| **Blocked** | vidya MCP (needs bote) |


## Future 6.0

* Book - PDF writen using Vidya and Documentation to Flesh out what the Lanaguage looks
like at 6.0 - publish and amazon / packt

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Test after EVERY change, not after the feature is done
- **Never use raw `cat | cc5` for projects** — always `cyrius build`
- **v5.0.0 recommended minimum** — cc5 IR, cyrius.cyml, patra 1.0.0, sankoch 1.2.0
