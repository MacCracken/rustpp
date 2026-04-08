# Cyrius Development Roadmap

> **v2.0.0-dev.** 190KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Argonaut: 424 tests pass. Heap audit clean. 28 stdlib modules.
>
> agnostik: 58 tests, all 22 modules. agnosys: all 20 modules compile.
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Bugs

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 14 | ~~Compiler segfault on ~6000+ line programs~~ | ~~P1~~ | **Fixed v1.11.4** |
| 15 | ~~`#derive(Serialize)` + `#derive(Deserialize)` duplicate variable~~ | ~~P2~~ | **Fixed v1.11.1** |
| 16 | Adding `include` shifts global addresses, breaks existing assertions | P3 | Enum-heavy includes shift data section layout. Needs repro case from majra port. |
| 17 | ~~`fncall2` undefined warning~~ | ~~P4~~ | **Fixed v1.12.1** |

**Open bugs:** #16 (P3). Needs reproduction case — likely triggered by majra port.

---

## v2.0 — Development Plan

Research first, implement second. Each feature gets a vidya entry before code.
Release after: all features in, full audit, feedback cycle.

### Dependency graph

```
multi-width types (i8, i16, i32)
  ├── sizeof operator
  │     └── struct padding/alignment
  │           ├── unions
  │           └── bitfields
  ├── variadic functions
  ├── u128
  └── cyrius-x bytecode
        └── cyrius-ts frontend

multi-file compilation (.o + link)
  └── cross-function inlining

.tcyr/.bcyr test/bench extensions (independent)
```

### Tier 1 — Foundation (blocks everything)

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 1 | **Multi-width types** (i8, i16, i32) | High | Research | Width-correct loads/stores, type ID encoding, var declarations with explicit widths. Touches lex, parse, emit, fixup. Currently "everything is i64" — this is THE fundamental change for 2.0. |

### Tier 2 — Type system completion (needs Tier 1)

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 2 | **sizeof** operator | Low | Research | `sizeof(Type)` returns byte size. Needed for struct padding and alloc. |
| 3 | **Struct padding/alignment** | Medium | Research | ABI-compatible field layout. Enables FFI with C. |
| 4 | **Unions** | Medium | Research | Tagged and untagged. Overlay fields at same offset. |
| 5 | **Bitfields** | Medium | Research | Bit-level field access within structs/unions. Hardware registers, protocols. |
| 6 | **Variadic functions** | Medium | Research | `fn printf(fmt, ...)` with va_arg. Needs multi-width for correct stack layout. |

### Tier 3 — Performance (can parallel Tier 2)

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 7 | **u128** | High | Research | 128-bit integers via register pairs (rax:rdx). Mul-with-overflow. Closes 18-33x gap vs Rust on is_prime. |
| 8 | **Cross-function inlining** | High | Research | Beyond token replay. Closes 300-700x gap on DSP scalar. |

### Tier 4 — Compilation model

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 9 | **Multi-file compilation** (.o + link) | High | Research | ELF .o output, symbol tables, relocation entries. True separate compilation. |

### Tier 5 — New targets

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 10 | **cyrius-x** bytecode | Very High | Research | Portable bytecode format (not WASM). Register-based or stack-based VM. Enables cross-platform without recompilation. |
| 11 | **cyrius-ts** frontend | High | Research | TypeScript/JS bridge. Parse TS subset → cyrius-x or native. |
| 12 | **.tcyr/.bcyr** extensions | Low | Research | Native test/bench file formats. `cyrb test` reads .tcyr, `cyrb bench` reads .bcyr. |

---

## Ports & Ecosystem

| Target | Status | Blocked by |
|--------|--------|------------|
| argonaut | **Done** — 424 tests pass on v1.12.1. | — |
| majra | In progress (separate agent). Config/env library. | — |
| libro | Logging library. | majra |
| ai-hwaccel | Hardware detection. | majra, libro |
| bhava (29K) | Keystone port. Unlocks hoosh + 37 downstream repos. | — |
| hisab (31K) | Math library port. Pairs with bhava. | — |
| vidya MCP | Blocked on bote Cyrius port. | bote |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit |
| Variables (VCNT) | 4096 | Expanded from 2048 in v1.8.2 |
| Locals per function | 256 | Expanded from 64 in v1.7.4 |
| Fixup entries | 8192 | Expanded from 4096 in v1.10.2 |
| Struct fields | 32 | Expanded from 16 in v1.12.0 |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Preprocess output | 512KB | Expanded from 256KB in v1.8.1 |
| Code buffer | 262144 bytes | Overflow detected |
| Output buffer | 262144 bytes | Relocated to end of heap v1.12.0 |
| Identifier buffer | 32768 bytes | Dedup since v1.7.8 (~50% savings) |
| Include-once table | 64 files | Tracked filenames for dedup (v1.8.0) |
| Macros | 16 | |
| Extra patches (&&) | 8 | Enforced v1.11.5 |
| Continue patches | 8 | Enforced v1.11.5 |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 190KB |
| 2 | aarch64 | **Done** — cross + native |
| 3 | RISC-V | Planned |
| 4 | cyrius-x | v2.0 target |

---

## Standard Library (28 modules)

| Module | Added |
|--------|-------|
| string, alloc, str, vec, fmt, io, args | v0.9.x |
| fnptr, callback, assert, bench, bounds | v0.9.x |
| hashmap, json, toml, tagged, trait | v1.7–1.8 |
| matrix, vidya, regex, net, fs | v1.8–1.9 |
| syscalls, process | v1.9.x |
| thread, async, freelist, math | v1.10–1.11 |

Expansion targets:
- `lib/chrono.cyr` — timestamps, duration math, `clock_gettime`
- `lib/http.cyr` — minimal HTTP client (blocked on net.cyr TCP)

---

## `#ref` — Compile-Time Data Tables

| Phase | Status |
|-------|--------|
| 1 | **Done** (v1.10.0) — `#ref "file.toml"` emits `var key = value;` |
| 2 | Perfect hash generation — O(1) lookup tables from TOML |
| 3 | Static hashmap init — compile-time populated hashmaps |
| 4 | Config-driven codegen — feature flags, platform tables |

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
- Two-step bootstrap for any heap offset change
- Research before implementation — vidya entry before code
