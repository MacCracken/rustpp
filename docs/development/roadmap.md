# Cyrius Development Roadmap

> **Status**: Phase 6 — Prove the Language | **Last Updated**: 2026-04-04

---

## Completed

### Phase 0 — Fork & Understand
Forked rust-lang/rust, built rustc from source, mapped cargo registry codepaths. Informed the design.

### Phase 1 — Registry Sovereignty
Ark as default registry, git/path deps first-class, publish validation relaxed. ADR documented.

### Phase 2 — Assembly Foundation
Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e (63 tests) → stage1f (16384 tokens, 256 fns).

### Phase 3 — Self-Hosting Bootstrap
asm.cyr (1110 lines, 43 mnemonics), bootstrap closure verified, 29KB committed binary. Zero external dependencies.

### Phase 4a — Language Extensions (Core)
cc.cyr self-hosting compiler with extensions beyond stage1f:
- Structs: definition, initialization, field access (dot), field assignment
- Multi-width memory: load16/32/64, store16/32/64
- Pointers: `*ptr` dereference, `*ptr = val` store
- >6 function parameters: stack-passed args 7+, System V ABI
- Modules: `include "file.cyr"` preprocessing
- Inline assembly: `asm { 0xNN; ... }` raw byte emission
- **Stats**: 1960 lines, 149 fns, 59 tests, cc2==cc3 verified

### Phase 4b — Language Maturity (Done)
- cc2 modular split (7 files), load64/store64 refactor, error messages
- Progressive type annotations, elif keyword, duplicate var detection
- Benchmarks: wc 2.4x faster than GNU, 92 total tests

---

## In Progress

### Phase 6 — Prove the Language

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Linux CLI tools in Cyrius | Done | 15 programs: true, false, echo, cat, head, tee, yes, nl, wc, rev, seq, tr, uniq, sum, grep |
| 2 | Buffered I/O | Done | 85x speedup, wc beats GNU by 2.4x |
| 3 | Benchmark suite (v3) | Done | docs/benchmarks.md — sizes, runtimes, compile times vs GNU |
| 4 | Migrate Ark package manager | Not started | First real-world project |
| 5 | Language ergonomics pass | In progress | elif done, break/continue next |

---

## Planned

### Phase 5 — Multi-Architecture

**Goal**: Factor codegen into backends. Add aarch64 as second target.

| # | Item | Notes |
|---|------|-------|
| 1 | Factor codegen into backend interface | Shared lexer/parser, per-arch emission |
| 2 | aarch64 assembler + codegen + bootstrap | Fixed-width instructions, simpler encoding |
| 3 | Cross-compilation | x86_64 host → aarch64 binaries and vice versa |

### Phase 6 — Prove the Language

**Goal**: Build real Linux binaries. Prove Cyrius is a functional systems language.

| # | Item | Notes |
|---|------|-------|
| 1 | Linux CLI tools in Cyrius | Done: true, false, echo, cat, head, tee — all under 1KB, 14 tests |
| 2 | Benchmark suite (v3) | Compile times, binary sizes, runtime perf vs C |
| 3 | Migrate Ark package manager | First real-world project in the language |
| 4 | Language ergonomics pass | Fix pain points from real usage |
| 5 | Documentation + tutorials | Developer onboarding |

### Phase 7 — Kernel

**Goal**: AGNOS kernel written entirely in Cyrius.

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS kernel in Cyrius | Bare metal, no_std default |
| 2 | Interrupt handlers | `#[interrupt]` attribute, auto save/restore |
| 3 | Page table management | Structs + typed pointers + load64 |
| 4 | Device I/O | Inline asm for in/out, volatile_load/store for MMIO |
| 5 | Agent/capability enforcement | Kernel reads ELF metadata sections |
| 6 | Cyrius stdlib | OS-aware, agent-aware |

### Phase 8 — Full Sovereignty

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS builds entirely with Cyrius | Both architectures, kernel + userland |
| 2 | Full cross-bootstrap | x86_64 + aarch64 |
| 3 | No external toolchain in any path | The entire stack is owned |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies — bootstrap from a single binary
- Every extension is built from within, not forked from outside
- Byte-exact testing is the gold standard
- Prove the language with real binaries before building the kernel
