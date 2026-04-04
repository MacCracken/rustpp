# Cyrius Development Roadmap

> **Status**: Phase 2 — Assembly Foundation | **Last Updated**: 2026-04-03

---

## Phase 0 — Fork & Understand (Done)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Fork rust-lang/rust as upstream submodule | Done | `upstream/` — pinned at 5bbdeaa9 |
| 2 | Build rustc from source | Done | `rustc 1.96.0-dev`, 5:19 build time |
| 3 | Build cyrius-seed (stage 0 assembler) | Done | `seed/` — 69 mnemonics, 195 tests |
| 4 | Run rust test suite | Not started | Prove the fork builds clean |
| 5 | Map cargo registry resolution codepaths | Done | `docs/architecture/cargo-codepaths.md` |
| 6 | Map `cargo publish` validation pipeline | Done | 20 locations across 8 files identified |
| 7 | Document findings in `docs/architecture/` | Done | `cyrius.md`, `process-notes.md`, `cargo-codepaths.md` |

## Phase 1 — Registry Sovereignty (Done)

**Goal**: `cargo publish` defaults to Ark. Git/path deps are first-class.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Add Ark constants to cargo | Done | `ARK_INDEX`, `ARK_HTTP_INDEX`, `ARK_REGISTRY`, `ARK_DOMAIN` |
| 2 | Change default registry to Ark | Done | 8 fallback locations updated |
| 3 | Relax publish validation for non-crates.io | Done | Git/path deps allowed for Ark |
| 4 | Skip version requirement for `publish = false` deps | Done | `check_dep_has_version()` relaxed |
| 5 | ADR documented | Done | `docs/architecture/adr/001-registry-sovereignty.md` |
| 6 | Build and test patched cargo | Done | Seed tests pass with patched cargo |

## Phase 2 — Assembly Foundation (In Progress)

**Goal**: Self-hosting bootstrap chain from assembly seed to compiler.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | cyrius-seed — stage 0 assembler | Done | Rust, 69 mnemonics, 195 tests, 14 examples |
| 2 | stage1a — expression evaluator | Done | .cyr assembly, 16/16 tests, reads stdin → emits ELF |
| 3 | stage1b — control flow (if/else, while) | Done | Runtime codegen, 39/39 tests, 5235-byte binary |
| 4 | stage1c — memory + syscalls | Done | syscall(), strings, &var, arrays, load8/store8, 37/37 tests, 7581-byte binary |
| 5 | stage1d — functions | Done | fn/return, 6-param System V ABI, stack locals, 28/28 tests, 11187-byte binary |
| 6 | stage1e — bitwise ops + self-hosting capacity | Done | % & | ^ ~ << >>, hex literals, comments, uppercase idents, 64KB buffers, 63/63 tests, 12344-byte binary |
| 7 | stage1f — token-scaled compiler | Done | 16384 token slots (4x stage1e), needed for compiling the assembler |

## Phase 3 — Self-Hosting Bootstrap (Done)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | asm.cyr — self-hosting assembler | Done | 43 mnemonics, 1128 lines, compiled by stage1f, 11 byte-exact matches with seed |
| 2 | Bootstrap closure | Done | seed→stage1f→asm→stage1f_v2 byte-identical |
| 3 | Commit bootstrap binary | Done | bootstrap/asm (29KB), SHA256 manifest, bootstrap.sh |
| 4 | Archive Rust seed | Done | archive/seed/ — kept for verification, not in build path |
| 5 | No Rust in build path | Done | sh bootstrap/bootstrap.sh — requires only Linux x86_64 + sh |

## Phase 4 — Language Extensions (Internalized)

**Goal**: Extend the Cyrius compiler from within — no Rust, no upstream fork. Progressive hybrid syntax: Cyrius-native first, Rust compatibility later.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | cc.cyr — base compiler (stage1f language clone) | In progress | Lexer + parser + codegen working for literals. Byte-exact for `var x = 42;`. Variable refs in expressions next. |
| 2 | >6 function parameters | Not started | Stack-passed extras beyond System V's 6 regs |
| 3 | Structs / composite types | Not started | Heap-allocated, compiler-computed offsets, pass by pointer |
| 4 | Typed pointers | Not started | `*T` syntax, scaled pointer arithmetic |
| 5 | Multi-width load/store (16/32/64-bit) | Not started | Intrinsics: load16, load32, load64, store16, store32, store64 |
| 6 | Module system | Not started | `include "file.cyr"` textual include |
| 7 | Inline assembly | Not started | `asm { }` blocks, register bindings |
| 8 | Self-hosting rewrite (cc2.cyr) | Not started | Rewrite compiler in its own extended language |
| 9 | Progressive type checking | Not started | Opt-in type annotations, warnings not errors |
| 10 | Agent/capability attributes | Not started | `#[agent]`, `#[capability(...)]` as ELF metadata |

## Phase 5 — Kernel

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Cyrius writes the AGNOS kernel | Not started | Bare metal, no_std default |
| 2 | Interrupt handlers | Not started | `#[interrupt]` attribute, auto save/restore |
| 3 | Page table management | Not started | Structs + typed pointers + load64 |
| 4 | Device I/O | Not started | Inline asm for in/out, volatile_load/store for MMIO |
| 5 | Agent/capability enforcement | Not started | Kernel reads ELF metadata sections |
| 2 | Cyrius stdlib (OS-aware, agent-aware) | Not started | |
| 3 | AGNOS builds entirely with Cyrius | Not started | |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- All existing Rust code compiles unchanged
- Cherry-pick upstream Rust improvements — don't maintain a stale fork
- Fix the ecosystem first, extend the language second
- Every divergence from upstream gets an ADR
