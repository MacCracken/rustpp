# Cyrius Development Roadmap

> **v1.7.4.** 140KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Constant folding, tail call optimization, DCE, 512KB input buffer, 256 locals.
>
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## P1 Bugs

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | **assert+bench+12 modules fails** | P1 | Including assert.cyr + bench.cyr + all 12 agnostik modules produces `unexpected '+'` at ~line 2556. bench alone works, assert alone works, both together fail. ~693 functions, 347 vars pre-expansion. Might be token/VCNT overflow with combined libs. |
| 2 | **Bump allocator no arena** | P2 | alloc_reset() invalidates outstanding pointers. Need arena pattern for benchmarks. |
| 3 | **cc2_aarch64 1.7.4 regression: large kernel fails silently** | P1 | AGNOS aarch64 build (33 files via include, ~3000 lines) compiles OK on 1.7.1 but fails silently (no error message, just FAIL) on 1.7.4. Simple aarch64 kernels still work. Likely related to constant folding changes interacting with include preprocessing. |
| 4 | **1.7.4 allocator codegen regression: PMM/heap 50-70% slower** | P2 | AGNOS PMM alloc+free went from 1304 to 2044 cycles/op (+57%), heap_32B from 1207 to 2065 (+71%). Serial I/O improved (-28%). Constant folding may have changed register allocation in tight loops. |

---

## Current — v1.7 Keystone Ports

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos:

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Const generics | Medium | `Matrix<N,M>`, `[T; N]` |
| 2 | Derive macros | Medium | serde Serialize/Deserialize |

---

## v1.8 — Infrastructure + Security

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Ownership / borrow checker | Very High | Memory safety |
| 2 | Sandbox borrow checker | Very High | AGNOS security model |

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
| 1 | Branch optimization | `notify_parse`: 20ns vs Rust 2ns | Jump tables for dense switches |
| 2 | Inline small functions | `W* macros`: 7ns vs Rust 1ns | Needs token replay or IR |
| 3 | Stack-allocated small strings | `str_builder`: 371ns vs Rust 52ns | Avoid heap < 64 bytes |
| 4 | Arena allocator | `seccomp_build`: 2.4us vs Rust 69ns | Batch allocation |
| 5 | Return-by-value small structs | General | Structs <= 2 registers |
| 6 | Register allocation | General | High effort, reduce spills |
| 7 | Constant folding for + - & \| ^ | General | Same approach as * / << >>, needs paren-safety |

### Done

| Optimization | Version |
|-------------|---------|
| Dead code elimination (3-byte stubs) | v1.7.0 |
| Tail call optimization (epilogue + jmp) | v1.7.2 |
| EMOVI optimization (xor/mov eax) | v1.6.7 |
| Compare-and-branch fusion (cmp + jCC) | Always (if/while/for) |
| Constant folding (* / << >>) | v1.7.3 |

---

## Systems Language Features

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit |
| Variables (VCNT) | 2048 | Never resets between functions |
| Locals per function | 256 | Expanded from 64 in v1.7.4 |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Code buffer | 196608 bytes | Overflow detected |
| Identifier buffer | 65536 bytes | Error with count |
| Macros | 16 | |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 140KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Crate Migration

108 repos, ~1M lines. See [migration-strategy.md](migration-strategy.md).

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

## cyrius-ts — TypeScript/JavaScript Replacement (v2.0+)

Not a transpiler. A replacement for the entire JS/TS runtime stack.

| Phase | Scope |
|-------|-------|
| 1 | Web-pattern syntax sugar |
| 2 | HTTP server library |
| 3 | DOM-equivalent for aethersafha |
| 4 | JS/TS migration tool |
| 5 | npm compatibility layer |

---

## Known Gotchas

| # | Behavior | Fix |
|---|----------|-----|
| 1 | Global var as loop bound re-evaluates each iteration | Snapshot to local |
| 2 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals |
| 3 | `var buf[N]` is N bytes, not N elements | `var buf[120]` for 120-byte struct |
| 4 | ~~`&&`/`\|\|` only in conditions~~ | **Fixed** (v1.7.4). `return a > 0 && b > 0;` and `var r = a == b;` now work. PARSE_CMP_EXPR handles `&&`/`\|\|` as AND/OR on 0/1 values. Both `var =` and `x =` assignments use PARSE_CMP_EXPR. |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Two-step bootstrap for any heap offset change
