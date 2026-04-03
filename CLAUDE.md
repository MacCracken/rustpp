# Rust++ — Claude Code Instructions

## Project Identity

**Rust++** — Systems language for sovereign operating systems. Fork of rustc.

- **Type**: Compiler toolchain (forked from rust-lang/rust)
- **License**: GPL-3.0-only (diverged code) | MIT/Apache-2.0 (upstream)
- **Status**: Phase 0 — fork, build, understand

## Goal

Own the language. No crates.io. No external governance. ark is the package backend. Names belong to builders.

## Development Process

### Phase 0: Fork & Build

1. Fork rust-lang/rust
2. Build the compiler from source
3. Understand the crate resolution pipeline in cargo
4. Identify the exact codepaths that validate against crates.io
5. Document the architecture for AGNOS-specific changes

### Phase 1: Registry Sovereignty

1. Strip crates.io validation from cargo for `publish = false` crates
2. Add ark as a native registry backend in cargo
3. Git/path deps are first-class — no registry fallback validation
4. `cargo publish` only validates deps that are actually being published

### Phase 2: Language Extensions

1. Agent types as language primitives
2. Capability annotations on functions
3. Sandbox-aware borrow checker extensions
4. OS-native IPC types

### Phase 3+: Self-Hosting

1. Rust++ compiles Rust++
2. Rust++ stdlib (OS-aware, agent-aware)
3. AGNOS codebase migration (incremental, backward compat)

## Key Principles

- **All existing Rust code must compile unchanged** — this is a superset, not a replacement
- **Don't diverge from upstream unnecessarily** — cherry-pick upstream improvements
- **Fix the ecosystem, not the language** — the type system and borrow checker are correct
- **Own the toolchain** — compiler, stdlib, package manager, build system

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not break backward compatibility with existing Rust code
- Do not diverge from upstream Rust without a documented reason
- Do not add language features without an ADR (architectural decision record)
