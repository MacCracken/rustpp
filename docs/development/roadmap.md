# Cyrius Development Roadmap

> **v1.11.3.** 205KB self-hosting compiler, both architectures.
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

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 14 | **Compiler segfault on ~6000+ line programs** | **P1** | See details below. |
| 15 | **`#derive(Serialize)` + `#derive(Deserialize)` duplicate variable** | P2 | See details below. |

### Bug #14 — Compiler segfault on ~6000+ line programs

**Severity**: P1 — blocks argonaut port (300 tests, 18 benchmarks proven on v1.10.2, cannot compile on v1.11.x)

**Versions affected**: v1.11.0, v1.11.1 (v1.10.2 compiles the same code successfully)

**Symptom**: `cc2` crashes with SIGSEGV (exit 139), produces a 0-byte output binary, no error message on stderr.

**Reproduction** (from `~/Repos/argonaut`):
```sh
# This compiles and runs correctly on v1.10.2, crashes cc2 on v1.11.x:
cat src/main.cyr | cc2 > build/argonaut
# Exit 139, 0-byte output
```

**Bisection results** — adding modules one at a time to find the threshold:
```
include count  | total lines | result
-------------- | ----------- | ------
12 stdlib      |        2262 | OK
+ types.cyr   |        3199 | OK
+ boot.cyr    |        3250 | OK
+ services    |        3792 | OK
+ process_mgmt|        4174 | OK
+ health      |        4495 | OK
+ edge_boot   |        4787 | OK
+ notify      |        4950 | OK
+ security    |        5082 | OK
+ systemd     |        5279 | OK
+ tmpfiles    |        5407 | OK  (5569 lines — last success)
+ init.cyr    |        6257 | COMPILER SEGFAULT
```

Each module compiles individually with the full stdlib — the crash only occurs when the combined source crosses ~6000 lines. `init.cyr` (688 lines) is the module that pushes past the threshold, but it is not the cause — any 688+ line module at that position would trigger the crash.

**Likely cause**: Code buffer (262144 bytes) or preprocess output buffer (512KB) overflow introduced by v1.11.0 changes (freelist allocator, enum namespacing, relaxed fn ordering, or other new features adding per-line codegen overhead that wasn't present in v1.10.2).

**Impact**: argonaut Cyrius port has 12 source modules (6240 lines) + 7 test suites + 18 benchmarks. All 300 tests pass on v1.10.2. None can compile on v1.11.x. The serde test suite (which only includes ~2000 lines of stdlib, no argonaut modules) compiles and runs correctly on v1.11.x, confirming the issue is size-dependent.

**Workaround**: Use v1.10.2 compiler. No source-level workaround — splitting `init.cyr` into smaller files would still exceed the threshold when all modules are combined.

### Bug #15 — `#derive(Serialize)` + `#derive(Deserialize)` duplicate variable

**Severity**: P2

**Versions affected**: v1.11.0, v1.11.1

**Symptom**: `error:NNNN: duplicate variable` when both `#derive(Serialize)` and `#derive(Deserialize)` are used in the same compilation unit, whether on the same struct or on two structs with identical field names.

**Reproduction**:
```cyrius
#derive(Serialize)
#derive(Deserialize)
struct Foo { x; y; z; }
# Error: duplicate variable
```

Also fails with separate structs sharing field names:
```cyrius
#derive(Serialize)
struct Foo { x; y; z; }

#derive(Deserialize)
struct Foo2 { x; y; z; }
# Error: duplicate variable (generated code for both uses same var names)
```

**Cause**: `PP_DERIVE_SERIALIZE` and `PP_DERIVE_DESER` generate functions with local variables that share names (e.g., `var v`). Since Cyrius variables are function-scoped, the second derive's generated code conflicts with the first's if both are in the same preprocessor output scope.

**Workaround**: Use `#derive(Serialize)` only. Deserialize manually via `json_parse()` + `json_get_int()` / `json_get()`. This is the pattern used in argonaut's serde test suite (39 tests, all passing).

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
