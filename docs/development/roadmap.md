# Rust++ Development Roadmap

> **Status**: Phase 0 — Fork | **Last Updated**: 2026-04-03

---

## Phase 0 — Fork & Understand (NOW)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Fork rust-lang/rust as upstream submodule | Not started | `upstream/` directory |
| 2 | Build rustc from source on AGNOS dev machine | Not started | `./x.py build` |
| 3 | Run rust test suite | Not started | Prove the fork builds clean |
| 4 | Map cargo registry resolution codepaths | Not started | `src/cargo/sources/registry/` |
| 5 | Map `cargo publish` validation pipeline | Not started | Where it rejects git deps without version |
| 6 | Document findings in `docs/architecture/` | Not started | |

## Phase 1 — Registry Sovereignty

**Goal**: `cargo publish` works without crates.io validation for deps that aren't being published.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Patch: skip registry validation for optional git deps | Not started | The kavach fix |
| 2 | Patch: `publish = false` deps never validated against any registry | Not started | |
| 3 | Add ark as a cargo registry backend | Not started | `[registries.ark]` |
| 4 | `cargo install` from ark | Not started | |
| 5 | Name resolution: ark-first, crates.io-fallback (configurable) | Not started | |

## Phase 2 — Language Extensions

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | `#[agent]` attribute — marks a type as an AGNOS agent | Not started | |
| 2 | `#[capability(...)]` — declares required capabilities | Not started | |
| 3 | `#[sandbox]` — sandbox-aware lifetime annotations | Not started | |
| 4 | Built-in IPC channel types | Not started | |

## Phase 3 — Self-Hosting

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Rust++ compiles itself | Not started | |
| 2 | Rust++ stdlib (replaces std) | Not started | OS-aware, agent-aware |
| 3 | AGNOS builds with Rust++ | Not started | Incremental migration |

---

## Principles

- All existing Rust code compiles unchanged
- Cherry-pick upstream Rust improvements — don't maintain a stale fork
- Fix the ecosystem first (Phase 1), extend the language second (Phase 2)
- Every divergence from upstream gets an ADR
