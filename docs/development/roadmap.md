# Cyrius Development Roadmap

> **v1.9.0.** 176KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Frontend/backend/common architecture. 20 f64 builtins. #derive(Serialize). Include-once.
> Identifier dedup. Jump tables. TOML parser. VCNT 4096. Preprocess output 512KB.
>
> agnostik: 58 tests, all 22 modules. agnosys: all 20 modules compile.
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Bugs

All P1/P2 compiler bugs resolved. Only open item:

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 2 | **Bump allocator no arena** | P3 | alloc_reset() invalidates outstanding pointers. Need arena pattern for benchmarks. Library design, not compiler bug. |
| 3 | ~~aarch64 tarball ships x86 binary~~ | ~~P1~~ | **Fixed** (v1.8.3). |
| 4 | ~~cyrb --aarch64 -D flag~~ | ~~P1~~ | **Fixed** (v1.8.4). |
| 5 | **Release tarball `cyrb` doesn't support `-D` flag** | P1 | The `cyrb` in `cyrius-1.8.5-x86_64-linux.tar.gz` (54824 bytes) silently ignores `-D`. The locally-built `cyrb` (54176 bytes) supports it. Same version string "1.1.0" but different binaries. The release workflow compiles `cyrb` from an older source. AGNOS requires `-D ARCH_X86_64` for multi-arch builds — without it, all `#ifdef` blocks are skipped producing a broken kernel. Fix: rebuild `cyrb` in the release workflow from current `programs/cyrb.cyr`. |
| 6 | **Cross-compiler vs native-compiler naming ambiguity** | P1 | `build/cc2_aarch64` is ambiguous: release packages the **native** aarch64 binary (aarch64→aarch64), but x86 developers need the **cross-compiler** (x86→aarch64, built from `main_aarch64.cyr`). The native binary can't run on x86 — fails silently, produces empty output. Proposal: `cc2 --target aarch64` flag, or explicit naming: `cc2_aarch64` = cross (x86→arm), `cc2-native-aarch64` = native (arm→arm). x86 release tarball must ship the cross-compiler. aarch64 release tarball ships the native compiler. Currently must manually build cross-compiler: `cat src/main_aarch64.cyr \| ./build/cc2 > cc2_aarch64_cross`. |

---

## Current — v1.8 Keystone Ports

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos:

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | ~~Const generics~~ | ~~Medium~~ | **Not needed** (v1.8.3). Cyrius runtime-sized `alloc` + `var buf[N]` covers all bhava/hisab patterns. Added `lib/matrix.cyr` for DenseMatrix ops. |
| 2 | ~~Derive macros~~ | ~~Medium~~ | **Done** (v1.7.7). `#derive(Serialize)` for JSON. |

Port vidya — programming reference corpus:

| # | Feature | Status |
|---|---------|--------|
| 1 | TOML parser | **Done** (v1.8.2). `lib/toml.cyr` — parses vidya content. |
| 2 | Content loader | Next — load `content/` directory, build registry. |
| 3 | Search | `hashmap.cyr` + `str.cyr` — full-text and tag search. |
| 4 | MCP protocol | Blocked on bote Cyrius port. |

---

## v1.9 — Concurrency

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Concurrency primitives | High | Threads, atomics, channels |
| 2 | Async/await | High | tokio-style patterns |

---

## AGNOS Kernel — Next

Current: 97KB x86_64, boots on QEMU, 25 syscalls, interactive shell.

| # | Feature | Effort |
|---|---------|--------|
| 1 | **VirtIO net** | Medium |
| 2 | **TCP/IP stack** | Very High |
| 3 | **SMP** | High |
| 4 | **Signals** | Medium |
| 5 | **Pipe/redirect** | Medium |
| 6 | **ATA/NVMe** | High |
| 7 | **FAT32 or ext2** | High |

---

## Performance Optimizations

### Remaining

| # | Optimization | Target | Status |
|---|-------------|--------|--------|
| 1 | Inline small functions | `W* macros`: 7ns vs Rust 1ns | Needs token replay or IR |
| 2 | Stack-allocated small strings | `str_builder`: 371ns vs Rust 52ns | Avoid heap < 64 bytes |
| 3 | Arena allocator | `seccomp_build`: 2.4us vs Rust 69ns | Batch allocation |
| 4 | Return-by-value small structs | General | Structs <= 2 registers |
| 5 | Register allocation | General | High effort, reduce spills |
| 6 | u128 / mul-with-overflow | `is_prime`: 18-33x vs Rust | mod_mul bottleneck |
| 7 | SIMD auto-vectorization | `poly_blep_4096`: 9.6x vs Rust | Batch DSP ops |
| 8 | Cross-function inlining | DSP scalar: 300-700x vs Rust | Call overhead floor |
| 9 | Compile-time perfect hash | `syscall_name_to_nr`: 106ns vs Rust 2ns | See `#ref` below |

### Done

| Optimization | Version |
|-------------|---------|
| Dead code elimination (3-byte stubs) | v1.7.0 |
| Tail call optimization (epilogue + jmp) | v1.7.2 |
| EMOVI optimization (xor/mov eax) | v1.6.7 |
| Compare-and-branch fusion (cmp + jCC) | Always (if/while/for) |
| Constant folding (* / << >>) | v1.7.3 |
| Constant folding (+ - & \| ^) | v1.7.7 |
| Jump tables (O(1) dense switch) | v1.7.7 |
| Identifier deduplication | v1.7.8 |
| f64 transcendentals (x87 FPU) | v1.7.8 |

---

## Systems Language Features

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32, u128) | Medium | Memory efficiency, big-number math |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit |
| Variables (VCNT) | 4096 | Expanded from 2048 in v1.8.2 |
| Locals per function | 256 | Expanded from 64 in v1.7.4 |
| Fixup entries | 4096 | Expanded from 2048 in v1.7.5. All writers checked. |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Preprocess output | 512KB | Expanded from 256KB in v1.8.1 |
| Code buffer | 196608 bytes | Overflow detected |
| Identifier buffer | 65536 bytes | Dedup since v1.7.8 (~50% savings) |
| Include-once table | 64 files | Tracked filenames for dedup (v1.8.0) |
| Macros | 16 | |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 176KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Crate Migration

108 repos, ~1M lines. See [migration-strategy.md](migration-strategy.md).

---

## `#ref` — Compile-Time Data Tables (v2.0)

TOML as a compile-time data declaration format. The compiler reads `.toml` files via `#ref`, generates perfect hash tables and static data at compile time, and emits them as pre-computed data in the binary. Zero runtime cost for static lookups.

```cyrius
#ref "syscalls.toml"

// compiler generates perfect hash at compile time
// syscall_lookup("read") → O(1), no runtime hashing
var nr = syscall_lookup("read");   // 2ns, not 106ns
```

| Phase | Scope |
|-------|-------|
| 1 | `#ref` directive — load TOML at compile time, expose as typed constants |
| 2 | Perfect hash generation — compiler emits O(1) lookup tables from TOML key-value pairs |
| 3 | Static hashmap init — `#ref` populates hashmaps at compile time, no runtime construction |
| 4 | Config-driven codegen — feature flags, platform tables, error codes from TOML |

**Why TOML**: Already in the Cyrius stdlib. Human-readable. Every AGNOS project already uses it for configuration. Reusing an existing format as a compile-time data source means no new syntax, no new parser — the compiler already knows how to read it.

**What it closes**: The 106ns vs 2ns gap on `syscall_name_to_nr`. Every static lookup table in every port. The `sandbox_config_default` 37x gap (static config from TOML instead of runtime construction). Any pattern where data is known at compile time but constructed at runtime.

---

## cyrius-x — Portable Bytecode (v2.0+)

A Cyrius-native portable bytecode format. Not WASM — designed for AGNOS, systems-first, agent-native.

| Phase | Scope |
|-------|-------|
| 1 | Bytecode format specification |
| 2 | cyrius-x emitter backend |
| 3 | cyrius-x interpreter (~10-20KB) |
| 4 | kavach sandbox integration |
| 5 | Agent distribution |
| 6 | JIT (hot paths) |

---

## cyrius-ts — TypeScript/JavaScript Bridge Frontend (v2.0+)

Not a transpiler. Not a new language. A **compiler frontend** — same pattern as cycc for C. TS-like syntax parsed into Cyrius IR, same backend, same binary output. 20 million JS/TS developers write what they know, the compiler produces sovereign binaries.

```
.cyr  ──→ ┐
.cts  ──→ ├──→ Cyrius IR ──→ codegen ──→ x86_64 / aarch64 / cyrius-x
.c    ──→ ┘
         Three frontends. One compiler. One backend.
```

---

## Known Gotchas

| # | Behavior | Fix |
|---|----------|-----|
| 1 | Global var as loop bound re-evaluates each iteration | Snapshot to local |
| 2 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals |
| 3 | `var buf[N]` is N bytes, not N elements | `var buf[120]` for 120-byte struct |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Two-step bootstrap for any heap offset change
