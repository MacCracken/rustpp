# Cyrius Development Roadmap

> **v1.12.0.** 190KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Argonaut unblocked (346 tests + 39 serde + 46 audit + 29 benchmarks).
> 28 stdlib modules. 8192 fixup entries.
>
> agnostik: 58 tests, all 22 modules. agnosys: all 20 modules compile.
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Bugs

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 14 | ~~Compiler segfault on ~6000+ line programs~~ | ~~P1~~ | **Fixed v1.11.4** — heap offset collision between `&&` extra_patches and `continue` forward-patches. |
| 15 | ~~`#derive(Serialize)` + `#derive(Deserialize)` duplicate variable~~ | ~~P2~~ | **Fixed v1.11.1** |
| 16 | Adding `include` shifts global addresses, breaks existing assertions | P3 | Adding a new `.cyr` file with `enum` blocks to a shared test header changed string/data offsets in the compiled binary, causing existing tests to fail with corrupted assertion labels (e.g. "^" instead of "mode server"). Workaround: keep new enum-heavy modules in separate compilation units. Root cause: global enum numbering or data section layout is position-dependent on total include count. Found in argonaut port (2026-04-07). |
| 17 | ~~`fncall2` undefined warning~~ | ~~P4~~ | **Fixed v1.12.1** — `hashmap.cyr` now includes `fnptr.cyr` directly. |

**Open bugs:** #16 (P3). Needs reproduction case — likely triggered by majra port.

---

## v1.12 — Compiler Hardening (pre-2.0 foundation)

The heap map has outgrown manual management. Bug #14 was a 16-byte overlap that
went undetected across 4 releases. Before adding multi-width types, unions, or
multi-file compilation, the compiler internals need a cleanup pass.

### 1. Heap map audit tool

Script that parses every `0x8____` offset from source code, builds a region map,
and flags overlaps or regions with < 16 bytes of padding. Catches the class of
bug that caused #14, permanently.

| Item | Status |
|------|--------|
| Parse offsets from heap map comments + code | |
| Build interval map, detect overlaps | |
| Warn on < 16-byte gaps between regions | |
| Run as part of `tests/compiler.sh` | |

### 2. Region consolidation + overflow guards

Group related state, add bounds checks at region boundaries.

| Item | Status |
|------|--------|
| Group all loop state contiguous (loop_top, break, continue) | |
| Group all expression state contiguous (extra_patches, ptr_scale, expr_stype) | |
| Add overflow check to ADDXP (extra_patches bounds) | |
| Add overflow check to continue patches | |
| Clean stale heap map comments (aarch64 local_types, etc.) | |
| Two-step bootstrap verification | |

### 3. Output buffer honesty

The output buffer at `0x6A000` (128KB) is routinely overwritten past its boundary
by EMITELF. Safe today because it runs last, but a trap for any future change.

| Item | Status |
|------|--------|
| Move output_buf to end of heap (after fn_inline) | |
| Expand to 256KB or dynamic via brk extension | |
| Add overflow check in EMITELF_USER / EMITELF_KERNEL | |
| Two-step bootstrap verification | |

### 4. DCE optimization

Dead code elimination scans all tokens per function — O(N*T). Fine at 358
functions / 36K tokens, but bhava (29K lines) will hit 500+ functions / 100K+
tokens = 50M+ iterations.

| Item | Status |
|------|--------|
| Build referenced-name bitset in one pass over tokens | |
| Check membership per function — O(T + N) total | |
| Verify no behavior change (same functions eliminated) | |

---

## Current — Ports & Ecosystem

| Target | Status | Blocked by |
|--------|--------|------------|
| argonaut | **Done** — 346 tests + 39 serde + 46 audit = 431 assertions, 29 benchmarks. Bug #12 resolved (serde unblocked). | — |
| majra | Next. Config/env library. | — |
| libro | Logging library. | majra |
| ai-hwaccel | Hardware detection. | majra, libro |
| bhava (29K) | Keystone port. Unlocks hoosh + 37 downstream repos. | — |
| hisab (31K) | Math library port. Pairs with bhava. | — |
| vidya MCP | Blocked on bote Cyrius port. | bote |

---

## v2.0 — Systems Language Features

These are heavy lifts that touch every compiler module (lex, parse, emit, fixup).
They should be built on the v1.12 hardened foundation.

### Type system expansion

| Feature | Effort | Unlocks | Depends on |
|---------|--------|---------|------------|
| Multi-width types (i8, i16, i32, u128) | High | Memory efficiency, big-number math | v1.12 heap cleanup |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI | Multi-width types |
| Unions, bitfields | Medium | Hardware, protocols | Struct padding |
| Variadic functions | Medium | printf-style APIs | Multi-width types |

### Compilation model

| Feature | Effort | Unlocks | Depends on |
|---------|--------|---------|------------|
| Multi-file compilation (.o + link) | High | True separate compilation | v1.12 heap cleanup |
| Cross-function inlining | High | DSP scalar: 300-700x vs Rust | Multi-file or token replay v2 |

### Performance

| # | Optimization | Target | Effort |
|---|-------------|--------|--------|
| 1 | u128 / mul-with-overflow | `is_prime`: 18-33x vs Rust | High |
| 2 | Cross-function inlining | DSP scalar: 300-700x vs Rust | High |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit |
| Variables (VCNT) | 4096 | Expanded from 2048 in v1.8.2 |
| Locals per function | 256 | Expanded from 64 in v1.7.4 |
| Fixup entries | 8192 | Expanded from 4096 in v1.10.2 |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Preprocess output | 512KB | Expanded from 256KB in v1.8.1 |
| Code buffer | 262144 bytes | Overflow detected |
| Identifier buffer | 65536 bytes | Dedup since v1.7.8 (~50% savings) |
| Include-once table | 64 files | Tracked filenames for dedup (v1.8.0) |
| Macros | 16 | |
| Extra patches (&&) | 8 | Unenforced — silent overflow into adjacent state |
| Continue patches | 8 | Unenforced — silent overflow into adjacent state |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 188KB |
| 2 | aarch64 | **Done** — cross + native, inline disabled |
| 3 | RISC-V | Planned |

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

## v2.0+ — Future

- **cyrius-x** — portable bytecode format (not WASM)
- **cyrius-ts** — TypeScript/JS bridge frontend
- **.tcyr/.bcyr** — native test/bench file extensions

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
