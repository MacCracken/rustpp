# Cyrius Development Roadmap

> **Status**: Phase 5 — Prove the Language | **Last Updated**: 2026-04-04

---

## Completed

### Phase 0 — Fork & Understand
Forked rust-lang/rust, built rustc from source, mapped cargo registry codepaths.

### Phase 1 — Registry Sovereignty
Ark as default registry, git/path deps first-class, publish validation relaxed.

### Phase 2 — Assembly Foundation
Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e (63 tests) → stage1f (16384 tokens, 256 fns).

### Phase 3 — Self-Hosting Bootstrap
asm.cyr (1110 lines, 43 mnemonics), bootstrap closure, 29KB committed binary. Zero external dependencies.

### Phase 4 — Language Extensions
cc2 self-hosting modular compiler (7 modules, 150 functions). Features beyond stage1f:
- Structs, pointers (*deref, *store), >6 params, load/store 16/32/64
- Include, inline asm (raw bytes), progressive type annotations
- elif, break/continue, duplicate var detection, error messages with token position
- 15 Linux programs, buffered I/O (wc 2.4x faster than GNU)

---

## In Progress

### Phase 5 — Prove the Language

**Goal**: Build enough real programs to expose and fix all remaining language gaps before kernel work.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Linux CLI tools | Done | 23 programs: cat, echo, head, tee, wc, rev, nl, seq, tr, uniq, sum, grep, yes, true, false, hexdump, basename, cols, tail, fib, sieve, points, memset |
| 2 | Proof programs | Done | fizzbuzz, primes, sort, calc (&&, global inits), sieve (for loops), points (nested structs + typed ptrs) |
| 3 | Buffered I/O | Done | 85x speedup, wc beats GNU 2.4x |
| 4 | Benchmarks vs GNU | Done | docs/benchmarks.md — 10-233x smaller binaries |
| 5 | Logical && / \|\| | Done | Short-circuit, chained. Token arrays 16384→32768. |
| 6 | For loops | Done | `for (init; cond; step) { body }` with break, nested, function support |
| 7 | Typed pointers | Done | `var p: *i64 = &buf; *(p + 1)` scales by element size |
| 8 | Nested structs | Done | `struct Outer { x; inner: Inner; y; }` with chained dot access |
| 9 | Global initializers | Done | Two-pass declaration scanning. calc.cyr unblocked. |
| 10 | Bootstrap repair | Done | Fixed codebuf split, expanded codebuf/input buffers, source reproduces binary |
| 11 | Migrate Ark to Cyrius | Not started | First real-world project |

---

## Planned

### Phase 6 — Kernel Prerequisites

**Goal**: Add the features needed to touch bare metal. Each item unlocks kernel capabilities.

**Must-Have (blocking kernel boot):**

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | ~~Typed pointers with scaling~~ | Done | `*i64`, ptr+1 adds 8 |
| 2 | ~~Nested structs~~ | Done | `struct Outer { x; inner: Inner; }` |
| 3 | ~~Global initializers~~ | Done | Two-pass declaration scanning |
| 4 | ~~For loops~~ | Done | `for (init; cond; step) { body }` |
| 5 | ~~Inline asm with mnemonics~~ | Done | 18 instructions: cli, sti, hlt, mov crN, lgdt, lidt, iretq, etc. |
| 6 | ~~Bare metal ELF~~ | Done | `kernel;` directive, multiboot2 header, base 0x100000 |
| 7 | ~~Interrupt handler support~~ | Done | ISR save/restore pattern proven (14 GPR push/pop + iretq) |
| 8 | ~~Bitfield access~~ | Done | Proven with PTE/GDT/IDT program — no new features needed |
| 9 | ~~Linker control~~ | Done | p_vaddr/p_paddr in kernel ELF, entry at 0x100090 |

**Nice-to-Have (quality of life):**

| # | Item | Effort | Why |
|---|------|--------|-----|
| 10 | String stdlib (strcmp, memcpy, memset) | 1 session | Common operations as builtins |
| 11 | argv access | 1 session | Command-line programs |
| 12 | Heap allocator (malloc/free) | 2 sessions | Dynamic allocation beyond brk |
| 13 | Volatile load/store | Trivial | MMIO correctness (no optimizer yet, so safe) |
| 14 | Type enforcement (warnings → errors) | 2 sessions | Catch bugs at compile time |
| 15 | Proper error messages (line numbers, source context) | 2 sessions | Developer experience |

### Phase 7 — Kernel (x86_64)

**Goal**: Compile the Linux kernel with Cyrius. Then boot AGNOS. Proves the language handles real kernel-scale code.

| # | Item | Notes |
|---|------|-------|
| 1 | Compile Linux kernel with Cyrius | The proof — Cyrius handles real kernel C replacement |
| 2 | ~~Multiboot1 + bare metal boot~~ | Done | 32-bit ELF, multiboot1 header, QEMU boots |
| 3 | ~~Serial console~~ | Done | Cyrius serial_print/serial_println from 64-bit code |
| 4 | ~~32-to-64 shim~~ | Done | Page tables, PAE, LME, paging, far jump |
| 5 | ~~GDT + IDT~~ | Done | Cyrius-built GDT (lgdt), IDT (256 vectors, lidt) |
| 6 | ~~PIC remap~~ | Done | IRQ 0-7→32-39, 8-15→40-47 |
| 7 | ~~Timer interrupt (PIT)~~ | Done | 100Hz PIT, ISR increments counter + EOI, hlt wakes on tick |
| 8 | Keyboard interrupt | Not started | User input |
| 9 | Page tables + higher-half mapping | Not started | Virtual memory |
| 10 | Physical memory manager | Not started | Page frame allocator |
| 12 | Agent/capability enforcement | `#[agent]`, `#[capability]` ELF metadata |

> **Note**: Phase 7 is the initial kernel boot. Full-featured AGNOS (drivers, networking, full userland, multi-user) continues beyond Phase 11.

### Phase 8 — Audit, Refactor, Stabilize

**Goal**: Clean up after kernel brings. Fix what real usage found.

| # | Item | Notes |
|---|------|-------|
| 1 | Kernel audit round | Memory safety, interrupt correctness, edge cases |
| 2 | Compiler refactor | Apply lessons from kernel development |
| 3 | Performance pass | Profile kernel, optimize hot paths |
| 4 | Test suite expansion | Kernel-level tests, stress tests |

### Phase 9 — Multi-Architecture (aarch64)

**Goal**: Factor codegen into backends. Port to ARM.

| # | Item | Notes |
|---|------|-------|
| 1 | Factor codegen into backend interface | Shared lexer/parser, per-arch emission |
| 2 | aarch64 assembler + codegen + bootstrap | Fixed-width 32-bit instructions |
| 3 | aarch64 kernel port | Same kernel, different arch |
| 4 | Cross-compilation | x86_64 host → aarch64 binaries |

### Phase 10 — Prove at Scale

**Goal**: Real-world projects in Cyrius. Language ergonomics pass.

| # | Item | Notes |
|---|------|-------|
| 1 | Migrate Ark package manager | First non-kernel project |
| 2 | AGNOS userland tools | Prove stdlib + I/O story |
| 3 | Benchmark suite vs C/Rust | Compile times, binary sizes, runtime perf |
| 4 | Language ergonomics pass | Fix pain points from real usage |
| 5 | Documentation + tutorials | Developer onboarding |

### Phase 11 — Full Sovereignty

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS builds entirely with Cyrius | Both architectures |
| 2 | Full cross-bootstrap | x86_64 ↔ aarch64 |
| 3 | No external toolchain in any path | The entire stack is owned |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies — bootstrap from a single binary
- Every extension is built from within, not forked from outside
- Byte-exact testing is the gold standard
- Programs are the best compiler fuzzers — build real things early
- Prove the language before building the kernel
- One architecture first, port after stabilization
