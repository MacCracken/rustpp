# Cyrius Development Roadmap

> **v2.0.0.** 190KB self-hosting compiler, both architectures.
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
| 16 | ~~`var buf[N]` shared across functions~~ | ~~P3~~ | **Fixed v2.1.0** — FINDVAR returns last match. Each function's array shadows previous. |
| 17 | ~~`fncall2` undefined warning~~ | ~~P4~~ | **Fixed v1.12.1** |

| 18 | ~~bridge.cyr stale heap map~~ | ~~P4~~ | **Fixed v2.1.0** — heap map rewritten to match actual code (tok_types at 0xA2000, tok_values at 0xE2000). |
| 19 | ~~aarch64 cross-compiler missing module/DCE~~ | ~~P3~~ | **Fixed v2.1.0** — pass 1/2 synced with main.cyr. mod/pub/use/impl/union/enum-ctor all supported. |
| 20 | ~~bridge.cyr dead code (EMOVC)~~ | ~~P5~~ | **Fixed v2.1.0** — removed. |
| 21 | ~~bitset/bitclr crash at top level~~ | ~~P4~~ | **Fixed v2.1.0** — clear error message instead of SIGSEGV. |

| 22 | ~~`fmt_int` / `_sk_fmt_line` garbled output~~ | ~~P2~~ | **Fixed v2.1.0** — same root cause as #16: `var buf[N]` shared across functions. |

| 23 | argonaut audit.tcyr test 6 fails 45/46 — runtime state corruption from earlier tests | P4 | Passes in isolation. Fails after tests 1-5 run. Runtime issue in argonaut allocator/vec. |
| 24 | `#ref` directive broken — emitted `var` declarations cause parse errors | P2 | `#ref "file.toml"` emits `var x = 42;` but parsing fails with "unexpected ';'". Likely pre-existing (never tested in .tcyr suite). Blocks #ref perfect hash. |

| 25 | ~~Include path shadows stdlib~~ | ~~P2~~ | **Fixed v2.1.2** — fallback to `$HOME/.cyrius/lib/` when local path fails. |

| 26 | ~~Nested hashmap crash~~ | ~~P2~~ | **Not a bug** — missing `include "lib/fmt.cyr"`. assert.cyr now auto-includes its deps. |

**Open bugs:** #24 (P2, blocks #ref_fn), #25 (P2, include path). All other compiler bugs fixed.

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

### Tier 1 — Foundation

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 1 | **Multi-width types** (i8, i16, i32) | High | **Done** | Width-correct loads/stores/allocation. Type annotations parsed. |

### Tier 2 — Type system completion

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 2 | **sizeof** operator | Low | **Done** | `sizeof(Type)` returns byte size. Token 100. |
| 3 | **Struct field width** | Medium | **Done** | Typed fields packed at declared width. FIELDOFF/STRUCTSZ respect widths. |
| 4 | **Unions** | Medium | **Done** | `union` keyword. All fields at offset 0, size = max field. Token 101. |
| 5 | **Bitfield builtins** | Medium | **Done** | `bitget`/`bitset`/`bitclr` — inline shift/mask codegen. Tokens 102-104. |
| 6 | **Variadic functions** | Medium | Deferred | Vec-based pattern (`fmt_sprintf`) sufficient for all current ports. |
| - | **Expression type propagation** | Medium | **Done** | Narrowing warnings on assignment. GEXW/SEXW. |

### Tier 3 — Performance

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 7 | **u128** | High | Research | 128-bit integers via register pairs. |
| 8 | **Cross-function inlining** | High | Research | Beyond token replay. |

### Tier 4 — Compilation model

| # | Feature | Effort | Status | Detail |
|---|---------|--------|--------|--------|
| 9 | **Multi-file compilation** (.o + link) | High | Researched | vidya entry written. Fixup→relocation mapping designed. |

### Tier 5 — New targets (scaffold in 2.0, ship in 2.1/2.2)

| # | Feature | Effort | Target | Detail |
|---|---------|--------|--------|--------|
| 10 | **cyrius-x** bytecode | Very High | **v2.1** | Researched. Register VM, 32-bit instructions. Backend stub at src/backend/cx/. |
| 11 | **Deferred formatting** (defmt) | High | **v2.1** | Store string ID + raw args at runtime, decode externally. Needs compiler string interning. Eliminates runtime fmt overhead for logging/tracing. |
| 12 | **cyrius-ts** frontend | High | **v2.2** | TS subset → cyrius-x. Needs cyrius-x first. |
| 13 | **.tcyr/.bcyr** extensions | Low | **Done** | `cyrb test` auto-discovers .tcyr, `cyrb bench` discovers .bcyr. |

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
| Variables (VCNT) | 8192 | Expanded from 4096 in v2.1.0. var_noffs/var_sizes/var_types relocated to end of heap. |
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

## `#ref` & Preprocessor — Compile-Time Data Tables

| Phase | Status |
|-------|--------|
| 1 | **Done** (v1.10.0) — `#ref "file.toml"` emits `var key = value;` |
| 2 | Perfect hash generation — O(1) lookup tables from TOML |
| 3 | Static hashmap init — compile-time populated hashmaps |
| 4 | Config-driven codegen — feature flags, platform tables |
| 5 | **Done** (v2.1.0) — `#if NAME OP VALUE` with ==, !=, <, >, <=, >=. `#define NAME VALUE` stores integers. Unblocks sakshi log level gating. |

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
