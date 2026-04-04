# Cyrius Development Roadmap

> **Status**: Phase 4 — Language Extensions | **Last Updated**: 2026-04-04

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
- **Stats**: 1960 lines, 149 functions, 51 tests, cc2==cc3 self-hosting verified

---

## In Progress

### Phase 4b — Language Maturity

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | cc2.cyr modular split | Done | 7 files via include, same binary, cc2==cc3 verified |
| 1b | cc2 refactor: load64 + errors | Done | S64/L64 → store64/load64 (-256B), error messages with token position |
| 1c | cc2 refactor: struct state | Not started | Replace heap offset constants with struct field access |
| 2 | Progressive type checking (V1) | Done | `var x: i64`, `fn f(a: i64)` — annotations parsed, skipped, no enforcement |
| 3 | Benchmark suite (v2) | Not started | cc2 compile times, feature coverage metrics |
| 4 | Agent/capability attributes | Not started | `#[agent]`, `#[capability(...)]` as ELF metadata |

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
| 1 | Linux CLI tools in Cyrius | cat, echo, wc — prove I/O, strings, file handling |
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
