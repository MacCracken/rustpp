# Cyrius Development Roadmap

> **v1.11.1.** 205KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Inline functions. R12 register spill. ret2/rethi. #ref TOML. 7 SIMD ops. Threads + channels.
> 22 stdlib modules. #derive(Serialize). Include-once. Jump tables. VCNT 4096.
>
> agnostik: 58 tests, all 22 modules. agnosys: all 20 modules compile.
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Bugs

**All bugs resolved.** Zero open issues.

---

## Current — Ports & Ecosystem

Port vidya — programming reference corpus:

| # | Feature | Status |
|---|---------|--------|
| 1 | MCP protocol | Blocked on bote Cyrius port. |

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos.
ai-hwaccel port — **unblocked** (v1.10.1): getenv fix (#9), exec_capture fix (#10).

---

## v1.10.x — Completed

All v1.10 items shipped:
- Inline small functions (v1.10.0)
- Return-by-value ret2/rethi (v1.10.0)
- Register allocation R12 spill (v1.10.0)
- `#ref` TOML Phase 1 (v1.10.0)
- Threads, mutex, channels (v1.10.1)
- Async runtime: spawn, sleep, timeout, epoll (v1.10.1)
- Bug fixes #9 getenv, #10 exec_capture (v1.10.1)

---

## v1.11.0 — Language Ergonomics

Discovered during ai-hwaccel port (Rust → Cyrius, 22K lines).

| # | Feature | Effort | Area |
|---|---------|--------|------|
| 1 | ~~Enum namespacing~~ | ~~Medium~~ | **Done** (v1.11.1). `Foo.BAR` resolves variant as global, falls back to struct field. |
| 2 | ~~Relaxed fn ordering~~ | ~~Medium~~ | **Done** (v1.11.1). PARSE_PROG handles `fn` with jmp-over-body pattern. |
| 3 | ~~Freelist allocator~~ | ~~Medium~~ | **Done** (v1.11.0). `lib/freelist.cyr` with `fl_alloc`/`fl_free`/`fl_calloc`. |

---


## Performance Optimizations

### Remaining

| # | Optimization | Target | Status |
|---|-------------|--------|--------|
| 1 | u128 / mul-with-overflow | `is_prime`: 18-33x vs Rust | mod_mul bottleneck |
| 2 | f64 trig/hyp builtins: asin, acos, atan, sinh, cosh, tanh | abaco eval implements in-library via exp/ln | x87 fpatan + exp-based, avoid per-consumer reimpl |
| 3 | Cross-function inlining | DSP scalar: 300-700x vs Rust | Call overhead floor |

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
| SIMD f64 (SSE2 addpd/mulpd/subpd) | v1.9.2 — 3.2x faster than Rust auto-vectorized |
| Stack-allocated small strings | v1.8.x — str_builder direct buffer, 64-byte inline |
| Arena allocator | v1.8.3 — arena_new, arena_alloc, arena_reset |
| SIMD expand (divpd, sqrtpd, abs, fmadd) | v1.9.5 — f64v_div, f64v_sqrt, f64v_abs, f64v_fmadd |
| Inline small functions | v1.10.0 — token replay, 1-param ≤6 tokens |
| R12 register spill | v1.10.0 — ESPILL/EUNSPILL, first expression temp in callee-saved R12 |
| Return-by-value (ret2/rethi) | v1.10.0 — two values in rax:rdx |
| `#ref` TOML compile-time data (Phase 1) | v1.10.0 — PP_REF_PASS, var key = value emission |

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
| Fixup entries | 4096 | Expanded from 2048 in v1.7.5. **Blocking test coverage** — argonaut (339 tests) and ai-hwaccel both require binary splitting. Next expansion target: 8192+. |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Preprocess output | 512KB | Expanded from 256KB in v1.8.1 |
| Code buffer | 262144 bytes | Overflow detected |
| Identifier buffer | 65536 bytes | Dedup since v1.7.8 (~50% savings) |
| Include-once table | 64 files | Tracked filenames for dedup (v1.8.0) |
| Macros | 16 | |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 205KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Standard Library Expansion

| Module | Scope | Effort | Notes |
|--------|-------|--------|-------|
| `lib/chrono.cyr` | Timestamps, duration math, formatting. Direct `clock_gettime` syscall. UTC default. | Low | Core time library — no timezone data, just math |
| `lib/tz/*.cyr` | Opt-in timezone databases. `tz/america_new_york.cyr`, `tz/asia_tokyo.cyr`, etc. | Low per zone | Pay for what you use. Include one file, get one timezone. |

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
| 1 | ~~`#ref` directive — load TOML at compile time, expose as typed constants~~ **Done** (v1.10.0) |
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

## v2.1 — Native Test & Bench File Extensions

File extensions as intent. The filesystem is the manifest.

```
.cyr   — source
.tcyr  — test
.bcyr  — benchmark
```

| # | Feature | Scope |
|---|---------|-------|
| 1 | `.tcyr` recognition | `cyrb test` discovers and runs all `.tcyr` files. No config, no attributes, no test harness dependency. |
| 2 | `.bcyr` recognition | `cyrb bench` discovers and runs all `.bcyr` files. Timing, iteration, CSV output built in. |
| 3 | Retire `.sh` test/bench scripts | Replace shell-based test runners with native `cyrb test` / `cyrb bench`. |
| 4 | `cyrb test --filter` | Run subset by name or path pattern. |
| 5 | `cyrb bench --compare` | Compare `.bcyr` results against saved baselines. Regression detection. |

**Why extensions, not directives**: `ls *.tcyr` is your test suite. No parsing needed to know what's a test. The file tells you what it is before you open it. Same principle as `.toml` for config — each extension has one job.

**Replaces**: Shell scripts wrapping compile + run + diff. `#[test]` / `#[bench]` attribute parsing. Criterion-style framework dependencies (Rust's bench framework is 4.4MB in abaco).

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
