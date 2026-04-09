# Cyrius Development Roadmap

> **v2.8.0.** 215KB self-hosting compiler, both architectures.
> 21 test suites (251 assertions), 4 fuzz harnesses, 9 benchmarks. Self-hosting byte-identical.
> Argonaut: 424 tests pass. Heap audit clean. 31 stdlib modules.
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

| 23 | ~~argonaut audit.tcyr test 6 flakiness~~ | ~~P4~~ | **Resolved v2.7.2** — tests split into 15 suites (395 assertions), all pass. Original single-file heap exhaustion no longer triggered. |
| 29 | ~~stdlib crashes (math, matrix, regex)~~ | ~~P2~~ | **Fixed v2.6.1** — FINDVAR fix in v2.1.0 resolved the root cause. str_replace had Str/cstring mismatch (used strlen on Str args). |
| 30 | ~~String data buffer overflow (8KB limit)~~ | ~~P1~~ | **Fixed v2.6.4** — str_data expanded 8KB→16KB. Programs with many string literals (agnostik 198 tests) silently overflowed into str_pos/data_size. |
| 24 | ~~`#ref` directive broken~~ | ~~P2~~ | **Fixed v2.2.0** — PP_REF_PASS was never called from PREPROCESS. One-line fix. |

| 25 | ~~Include path shadows stdlib~~ | ~~P2~~ | **Fixed v2.1.2** — fallback to `$HOME/.cyrius/lib/` when local path fails. |

| 26 | ~~Nested hashmap crash~~ | ~~P2~~ | **Not a bug** — missing `include "lib/fmt.cyr"`. assert.cyr now auto-includes its deps. |

| 27 | ~~>6 function args wrong values~~ | ~~P3~~ | **Fixed v2.2.0** — ECALLPOPS pops extras to r11-r14, pops 6 regs, pushes extras back. Note: `return fn7(...)` returns wrong value; use `var r = fn7(...); return r;` as workaround. |

| 28 | ~~Bad error for undefined variable~~ | ~~P3~~ | **Fixed v2.2.0** — now prints `error:N: undefined variable 'name'`. |

**No open bugs.** All reported issues (#14-#28) fixed or resolved. `return fn7()` workaround documented in #27.

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
| 9 | **Multi-file compilation** (.o + link) | High | **Phase 1 done (v2.6.4)** | `object;` directive emits ELF .o with sections, symbols, relocations. Phase 2: minimal linker. |

### Tier 5 — New targets (scaffold in 2.0, ship in 2.1/2.2)

| # | Feature | Effort | Target | Detail |
|---|---------|--------|--------|--------|
| 10 | **cyrius-x** bytecode | Very High | **Done (v2.5)** | Backend emitter + VM. Recursion working. Remaining: nested call register clobber, syscall address translation, >6 args. |
| 11 | **Deferred formatting** (defmt) | High | **v3.0** | Store string ID + raw args at runtime, decode externally. Needs compiler string interning. |
| 12 | **cyrius-ts** frontend | High | **v3.0+** | TS subset → cyrius-x. Needs cyrius-x emitter hardened first. |
| 13 | **.tcyr/.bcyr** extensions | Low | **Done** | `cyrius test` auto-discovers .tcyr, `cyrius bench` discovers .bcyr. |

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
| Globals (initialized) | 1024 | Expanded from 256 in v2.4.0. gvar_toks at 0x98000 (8192 bytes). |
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
| 1 | x86_64 | **Done** — self-hosting, 215KB |
| 2 | aarch64 | **Done** — cross + native |
| 3 | RISC-V | Planned |
| 4 | cyrius-x | v2.0 target |

## Platform Targets

| # | Platform | Output Format | Status | Blocked by |
|---|----------|---------------|--------|------------|
| 1 | Linux x86_64 | ELF | **Done** — primary target |  — |
| 2 | Linux aarch64 | ELF | **Done** — cc2_aarch64 cross-compiler | — |
| 3 | macOS x86_64 | Mach-O | Planned | Mach-O emitter + macOS syscall shim |
| 4 | macOS aarch64 | Mach-O | Planned | Mach-O emitter + aarch64 backend (exists) + macOS ABI |
| 5 | Windows x86_64 | PE/COFF | Planned | PE emitter + Win32 API (or mingw-style libc link) |

**Near-term**: Linux aarch64 is ready — cc2_aarch64 exists. Downstream projects (doom, bsp) can add aarch64 build jobs today.

**macOS path**: Mach-O emitter (new backend module), then either a thin syscall shim (write/exit/mmap → macOS equivalents) or libc FFI for portability. macOS aarch64 combines the Mach-O emitter with the existing aarch64 codegen.

**Windows path**: PE/COFF emitter + either raw Win32 API calls or a mingw-compatible libc link step. Largest effort of the three.

---

## Standard Library (31 modules)

| Module | Added |
|--------|-------|
| string, alloc, str, vec, fmt, io, args | v0.9.x |
| fnptr, callback, assert, bench, bounds | v0.9.x |
| hashmap, hashmap_fast, json, toml, tagged, trait | v1.7–2.1 |
| matrix, vidya, regex, net, fs | v1.8–1.9 |
| syscalls, process | v1.9.x |
| thread, async, freelist, math | v1.10–1.11 |
| sakshi, sakshi_full | v2.2.0 |

Expansion targets:
- `lib/http.cyr` — HTTP/1.1 client + server (socket-based, stdlib module)
- `lib/tls.cyr` — TLS 1.3 via syscall-based approach or bundled
- `lib/ws.cyr` — WebSocket protocol (depends on http.cyr)

---

## `cyrius serve` — Dev Server (v2.2+)

Developer tooling verb. File watcher + auto-rebuild + hot-reload.
No npm, no cargo-watch, no nodemon. One tool.

| Phase | Status | Detail |
|-------|--------|--------|
| 1 | Planned | `cyrius serve src/main.cyr` — watch .cyr files, recompile + restart on change |
| 2 | Planned | HTTP dev server — `cyrius serve --http 8080` serves static files + auto-rebuild |
| 3 | Planned | WebSocket live-reload — browser auto-refreshes on recompile |
| 4 | Planned | Proxy mode — forward API requests to running binary |

Phase 1 needs: `inotify` syscall wrapper (Linux file watching).
Phase 2 needs: `lib/http.cyr` (socket bind/accept/parse/respond).
Phase 3 needs: `lib/ws.cyr` (WebSocket upgrade + frame protocol).

```
cyrius build    — compile
cyrius test     — run .tcyr
cyrius bench    — run .bcyr
cyrius port     — scaffold from Rust
cyrius init     — new project
cyrius serve    — dev server with hot-reload
cyrius audit    — code quality check
```

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

## v3.0 — Release Readiness

| Item | Detail |
|------|--------|
| Soak test | `cyrius fuzz 100000` overnight. Compile all repos (argonaut, sakshi, majra, doom, vidya) in loop for 24h. Watch for memory leaks, state corruption, non-determinism. |
| Full audit | `cyrius audit` clean on every repo. All .tcyr suites green. All benchmarks baselined. |
| cyrius-x VM | ~~Memory-backed stack frames. Recursion working.~~ **Done v2.5.0.** Remaining: nested call register clobber (ack), syscall string address translation, .tcyr suite under VM. |
| defmt | String interning + deferred formatting. Sakshi perf validated. |
| Multi-file compilation | ~~Phase 1: .o emission.~~ **Done v2.6.4.** Phase 2: minimal linker — read .o files, resolve symbols, patch relocations, emit executable. Write in Cyrius. |
| Error messages | Audit all ERR() calls for clarity. No more "unexpected ';'" for real issues. |
| Documentation | All vidya entries current. cyrius-guide.md reflects v3.0 features. |
| Binary size audit | Profile code/data split. Identify bloat. Target: <250KB. |
| Port validation | All 5 converted repos + doom compile and test clean on release binary. |
| Mach-O emitter | macOS x86_64 + aarch64 output. New backend module for Mach-O headers, load commands, sections. |
| PE emitter | Windows x86_64 output. PE/COFF headers + Win32 API or mingw libc link. |
| Cross-platform CI | Downstream projects (doom, bsp) ship Linux x86_64 + aarch64 binaries. macOS/Windows after emitters land. |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Two-step bootstrap for any heap offset change
- Research before implementation — vidya entry before code
