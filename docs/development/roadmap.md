# Cyrius Development Roadmap

> **Status**: Phase 4 — Language Extensions | **Last Updated**: 2026-04-04

---

## Completed

### Phase 0 — Fork & Understand
Forked rust-lang/rust, built rustc from source, mapped cargo registry codepaths, documented findings. Informed the design of Cyrius.

### Phase 1 — Registry Sovereignty
Ark constants in cargo, default registry changed, git/path deps first-class, publish validation relaxed. ADR documented.

### Phase 2 — Assembly Foundation
Seven-stage compiler chain from assembly seed to token-scaled compiler:
- cyrius-seed (Rust, 69 mnemonics, 195 tests) → archived
- stage1a (expressions) → stage1b (control flow) → stage1c (syscalls) → stage1d (functions) → stage1e (bitwise ops, 63 tests) → stage1f (16384 tokens)

### Phase 3 — Self-Hosting Bootstrap
- asm.cyr: self-hosting assembler (1110 lines, 43 mnemonics, 11 byte-exact matches)
- Bootstrap closure: asm assembles stage1f.cyr → byte-identical to seed output
- Committed binary seed: bootstrap/asm (29KB) + bootstrap.sh
- Rust seed archived, upstream submodule removed
- **Zero external dependencies: Linux x86_64 + sh**

---

## In Progress

### Phase 4 — Language Extensions (Internalized)

**Goal**: Extend the Cyrius compiler from within. No Rust, no upstream fork. Progressive hybrid syntax.

**Current**: cc.cyr V2 — editable compiler with vars, expressions, if/else, while, functions (1224 lines, 11 byte-exact matches with stage1f)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | cc.cyr — self-hosting compiler | Done | 1467 lines, 43504-byte binary, compiles itself byte-identical in 9ms |
| 2 | Benchmark suite (v1) | Done | Bootstrap 41ms, self-compile 9ms, asm 1.3M lines/sec |
| 3 | Structs / composite types | Done | struct def, init, field access (dot), field assign. 1688 lines, 136 functions. Stage1f fn table bumped to 256. |
| 4 | >6 function parameters | Not started | Stack-passed extras beyond System V's 6 regs |
| 5 | Typed pointers | Not started | `*T` syntax, scaled pointer arithmetic |
| 6 | Multi-width load/store | Not started | load16/32/64, store16/32/64 intrinsics |
| 7 | Module system | Not started | `include "file.cyr"` textual include |
| 8 | Inline assembly | Not started | `asm { }` blocks, register bindings |
| 9 | Self-hosting rewrite (cc2.cyr) | Not started | Rewrite in extended language |
| 10 | Progressive type checking | Not started | Opt-in annotations, warnings not errors |
| 11 | Agent/capability attributes | Not started | `#[agent]`, `#[capability(...)]` as ELF metadata |

---

## Planned

### Phase 5 — Multi-Architecture

**Goal**: Factor codegen into backends. Add aarch64 as second target.

| # | Item | Notes |
|---|------|-------|
| 1 | Factor cc codegen into backend interface | Separate lexer/parser (shared) from instruction emission (per-arch) |
| 2 | aarch64 assembler (asm_aarch64.cyr) | Fixed-width 32-bit instructions, simpler encoding than x86_64 |
| 3 | aarch64 codegen backend for cc | Same parser, different emit functions |
| 4 | aarch64 bootstrap binary | Committed aarch64 ELF, parallel to bootstrap/asm |
| 5 | aarch64 syscall ABI | Different syscall numbers + register conventions |
| 6 | Cross-compilation | x86_64 host emits aarch64 binaries and vice versa |

### Phase 6 — Kernel

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS kernel in Cyrius | Bare metal, no_std default |
| 2 | Interrupt handlers | `#[interrupt]` attribute, auto save/restore |
| 3 | Page table management | Structs + typed pointers + load64 |
| 4 | Device I/O | Inline asm for in/out, volatile_load/store for MMIO |
| 5 | Agent/capability enforcement | Kernel reads ELF metadata sections |
| 6 | Cyrius stdlib | OS-aware, agent-aware |

### Phase 7 — Prove the Language

**Goal**: Migrate AGNOS ecosystem projects to Cyrius. Prove the language works at scale.

| # | Item | Notes |
|---|------|-------|
| 1 | Migrate Ark package manager to Cyrius | First real-world project in the language |
| 2 | Migrate AGNOS userland tools | Prove stdlib + I/O story |
| 3 | Benchmark suite | Compile times, binary sizes, runtime perf vs C/Rust |
| 4 | Language ergonomics pass | Fix pain points discovered during migration |
| 5 | Documentation + tutorials | Developer onboarding for the language |

### Phase 8 — Full Sovereignty

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS builds entirely with Cyrius | Both architectures, kernel + userland |
| 2 | Cyrius compiles Cyrius on both x86_64 and aarch64 | Full cross-bootstrap |
| 3 | No external toolchain in any path | The entire stack is owned |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies — bootstrap from a single binary
- Every language extension is built from within, not forked from outside
- Byte-exact testing is the gold standard
