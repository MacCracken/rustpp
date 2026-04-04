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
| 1 | Linux CLI tools | Done | 15 programs: cat, echo, head, tee, wc, rev, nl, seq, tr, uniq, sum, grep, yes, true, false |
| 2 | Proof programs | Done | fizzbuzz (elif, %), primes (nested loops), sort (load64/store64, arrays) |
| 3 | Buffered I/O | Done | 85x speedup, wc beats GNU 2.4x |
| 4 | Benchmarks vs GNU | Done | docs/benchmarks.md — 10-233x smaller binaries |
| 5 | Fix codegen bug | Done | `var x = fn(); return x;` — investigated, works correctly. Was not a bug. |
| 6 | Logical && / \|\| | Done | Short-circuit &&/||, chained (a && b && c), 8 tests. Token arrays expanded 16384→32768. |
| 7 | Migrate Ark to Cyrius | Not started | First real-world project |

---

## Planned

### Phase 6 — Kernel Prerequisites

**Goal**: Add the features needed to touch bare metal. Each item unlocks kernel capabilities.

**Must-Have (blocking kernel boot):**

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Typed pointers with scaling (`*i64`, ptr+1 adds 8) | 1 session | Page table walks, struct arrays |
| 2 | Nested structs (struct field is struct) | 1 session | IDT entries, GDT entries, page table entries |
| 3 | Inline asm with mnemonics (embed encoder from asm.cyr) | 2-3 sessions | `mov cr3, rax`, `lidt`, `lgdt`, `iretq`, port I/O |
| 4 | Bare metal ELF (custom base address, multiboot header) | 1 session | Kernel binary that GRUB can boot |
| 5 | Interrupt handler support (`#[interrupt]` save/restore) | 2 sessions | IDT, timer, keyboard, page fault |
| 6 | Bitfield access (pack/unpack bits) | 1 session | Page table flags, GDT/IDT descriptors |
| 7 | Global initializers (`var x = expr` at top level in fn zone) | 1 session | Static page tables, GDT, calc.cyr |
| 8 | Linker control (kernel at 0xFFFF800000000000) | 1 session | Higher-half kernel mapping |

**Nice-to-Have (quality of life):**

| # | Item | Effort | Why |
|---|------|--------|-----|
| 9 | For loops (`for (i = 0; i < n; i = i + 1)`) | 1 session | Syntactic sugar |
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
| 2 | Multiboot2 header + bare metal boot | GRUB loads AGNOS kernel ELF |
| 3 | Serial console output | First AGNOS proof of life |
| 4 | GDT + IDT setup | Protected mode tables |
| 5 | Page tables + higher-half mapping | Virtual memory |
| 6 | Timer interrupt (PIT/APIC) | Preemptive scheduling foundation |
| 7 | Keyboard interrupt | User input |
| 8 | Physical memory manager | Page frame allocator |
| 9 | Virtual memory manager | mmap equivalent |
| 10 | Process/task abstraction | Agent model foundation |
| 11 | Syscall interface | User-space boundary |
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
