# Cyrius Development Roadmap

> **v1.11.1.** 205KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Inline functions. R12 register spill. Threads + channels + async. Freelist allocator.
> Enum namespacing. Relaxed fn ordering. 28 stdlib modules. 8192 fixup entries.
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

| Target | Status |
|--------|--------|
| ai-hwaccel | **Unblocked** — getenv (#9), exec_capture (#10) fixed. Live hardware detection ready. |
| bhava (29K) | Next keystone port. Unlocks hoosh + 37 downstream repos. |
| hisab (31K) | Math library port. Pairs with bhava. |
| vidya MCP | Blocked on bote Cyrius port. |

---

## Performance — Remaining

| # | Optimization | Target | Effort |
|---|-------------|--------|--------|
| 1 | u128 / mul-with-overflow | `is_prime`: 18-33x vs Rust | High |
| 2 | Cross-function inlining | DSP scalar: 300-700x vs Rust | High |

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
| Fixup entries | 8192 | Expanded from 4096 in v1.10.2 |
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
