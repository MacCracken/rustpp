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

## Phase 3 — Self-Hosting Bootstrap

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Stage 1 compiles itself | Not started | The bootstrap closes |
| 2 | Eliminate Python/cmake/ninja from toolchain | Not started | Assembly seed is the only external artifact |
| 3 | Cyrius compiles Cyrius | Not started | |

## Phase 4 — Language Extensions

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `#[agent]` attribute — marks a type as an AGNOS agent | Not started | |
| 2 | `#[capability(...)]` — declares required capabilities | Not started | |
| 3 | `#[sandbox]` — sandbox-aware lifetime annotations | Not started | |
| 4 | Built-in IPC channel types | Not started | |

## Phase 5 — Kernel

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Cyrius writes the AGNOS kernel | Not started | Bare metal, no_std default |
| 2 | Cyrius stdlib (OS-aware, agent-aware) | Not started | |
| 3 | AGNOS builds entirely with Cyrius | Not started | |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- All existing Rust code compiles unchanged
- Cherry-pick upstream Rust improvements — don't maintain a stale fork
- Fix the ecosystem first, extend the language second
- Every divergence from upstream gets an ADR
