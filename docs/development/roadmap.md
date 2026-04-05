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

### Phase 7 — Kernel (COMPLETE) (x86_64)

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
| 8 | ~~Keyboard interrupt~~ | Done | IRQ1 ISR, ring buffer, scancode-to-ASCII, interactive loop |
| 9 | ~~Page tables~~ | Done | 16MB identity map (8x2MB), Cyrius pt_map_2mb, CR3 reload |
| 10 | ~~Physical memory manager~~ | Done | Bitmap allocator, 4096 pages, alloc/free/test |
| 11 | ~~Virtual memory manager~~ | Done | vmm_map/unmap/alloc_at, 2MB pages, invlpg flush |
| 12 | ~~Process abstraction~~ | Done | Process table, create/state, 3 processes tested |
| 13 | ~~Syscall interface~~ | Done | ksyscall: exit(0), write(1), getpid(2) |
| 12 | Agent/capability enforcement | `#[agent]`, `#[capability]` ELF metadata |

> **Note**: Phase 7 is the initial kernel boot. Full-featured AGNOS (drivers, networking, full userland, multi-user) continues beyond Phase 11.

### Phase 8 — Language Foundations

**Goal**: Add the features that make Cyrius a real language for real projects.

**Tier 1 — Core language (blocking real-world use):**

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | ~~Type enforcement~~ | Done | Warnings on pointer/scalar mismatch at assignment |
| 2 | ~~Enums~~ | Done | enum Name { A; B = 5; C; } with auto-increment + explicit values |
| 3 | ~~Switch/match~~ | Done | switch (expr) { case N: stmts; default: stmts; } |
| 4 | ~~Heap allocator~~ | Done | Bump allocator from brk, alloc/reset/used |
| 5 | ~~Function pointers~~ | Done | &fn_name + indirect call rax, vtable pattern works |
| 6 | ~~argc/argv access~~ | Done | /proc/self/cmdline, argc()/argv(n) |
| 7 | Block scoping | Deferred | Function scope works, var-in-loop documented as known limitation |
| 8 | ~~String type~~ | Done | Str struct (data+len), str_from/eq/cat/sub/print |

**Tier 2 — Scale features (for larger codebases):**

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 9 | Generics / templates | 3 sessions | Type-safe containers, reusable code |
| 10 | Traits / interfaces | 3 sessions | Abstraction, polymorphism |
| 11 | Proper module system (namespace, visibility) | 2 sessions | Large project organization |
| 12 | Array bounds checking (opt-in) | 1 session | Memory safety |
| 13 | Nested function calls in expressions | 1 session | Fix register save across calls |
| 14 | Multi-file compilation | 2 sessions | Beyond textual include |

**Tier 3 — Advanced (future vision):**

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 15 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 16 | Closures / lambdas | 2 sessions | Functional patterns |
| 17 | Iterators | 2 sessions | Clean collection processing |
| 18 | Pattern matching | 2 sessions | Destructuring, exhaustiveness |
| 19 | Concurrency primitives | 3 sessions | Multi-core kernel, parallel apps |

### Phase 9 — Multi-Architecture (aarch64) (STARTED)

**Goal**: Factor codegen into backends. Port to ARM.

| # | Item | Notes |
|---|------|-------|
| 1 | ~~Factor codegen into backend interface~~ | Done — shared frontend, per-arch emit/jump/fixup |
| 2 | ~~aarch64 emit + jump + fixup~~ | Done — 61 functions, cross-compiler builds |
| 3 | aarch64 instruction correctness | Fix jmp encoding, get var x = 42 running |
| 4 | aarch64 bootstrap (self-hosting on ARM) | cc2_aarch64 compiles itself on ARM hardware |
| 5 | aarch64 kernel port | Same AGNOS kernel, different arch |
| 6 | Cross-compilation | x86_64 host → aarch64 binaries verified |

### Phase 10 — Audit, Refactor, Stabilize

**Goal**: Clean up after kernel + language features. Fix what real usage found.

| # | Item | Notes |
|---|------|-------|
| 1 | Kernel audit round | Memory safety, interrupt correctness |
| 2 | Compiler refactor | Apply lessons from all phases |
| 3 | Performance pass | Profile kernel + compiler, optimize |
| 4 | Test suite expansion | Kernel-level tests, stress tests, fuzzing |

### Phase 11 — Prove at Scale

**Goal**: Real-world projects in Cyrius.

| # | Item | Notes |
|---|------|-------|
| 1 | Migrate Ark package manager | First non-kernel project |
| 2 | AGNOS userland tools | Prove stdlib + I/O story |
| 3 | Benchmark suite vs C/Rust | Compile times, binary sizes, runtime perf |
| 4 | Documentation + tutorials | Developer onboarding |

### Phase 12 — Full Sovereignty

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
