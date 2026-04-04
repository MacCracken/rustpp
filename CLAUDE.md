# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up. Fork of rustc.

- **Type**: Compiler toolchain (forked from rust-lang/rust)
- **License**: GPL-3.0-only (diverged code) | MIT/Apache-2.0 (upstream)
- **Status**: Phase 2 — Assembly foundation (seed + stage 1)

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Ark is the package backend. Names belong to builders. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Bootstrap Chain

```
rustc 1.96.0-dev (built from source)
  → cyrius-seed (Rust, 69 mnemonics, 195 tests)
    → stage1a (2641-byte .cyr binary, 16 tests)
      → stage1b (5235-byte .cyr binary, 39 tests)
        → stage1c (7581-byte .cyr binary, 37 tests)
          → stage1d (11187-byte .cyr binary, 28 tests)
            → generated ELF programs with functions + I/O
```

## Project Structure

- `seed/` — Stage 0 assembler (Rust, zero deps, emits x86_64 ELF)
- `stage1/` — Stage 1 compiler (.cyr assembly, assembled by seed)
- `upstream/` — rust-lang/rust submodule with Ark cargo patches
- `docs/architecture/` — Cyrius spec, cargo codepath analysis, ADRs
- `docs/development/` — Roadmap, process notes

## Key References

- `docs/architecture/cyrius.md` — Language vision and phases
- `docs/architecture/cargo-codepaths.md` — Surgical map of crates.io in cargo
- `docs/architecture/adr/001-registry-sovereignty.md` — Ark patches ADR
- `../vidya` — Multi-language reference corpus (compiler bootstrapping, binary formats)
- `../ark` — AGNOS unified package manager

## Development Process

### Phase 0: Fork & Build (Done)
1. Fork rust-lang/rust ✓
2. Build rustc from source ✓
3. Map cargo registry resolution codepaths ✓
4. Map `cargo publish` validation pipeline ✓
5. Document findings ✓

### Phase 1: Registry Sovereignty (Done)
1. Ark constants added to cargo ✓
2. Default registry changed to Ark ✓
3. Git/path deps allowed for non-crates.io registries ✓
4. `publish = false` deps skip version requirement ✓
5. ADR documented ✓

### Phase 2: Assembly Foundation (In Progress)
1. cyrius-seed — stage 0 assembler ✓
2. stage1a — expression evaluator compiler ✓
3. stage1b — control flow (if/else, while) ✓
4. stage1c — memory + syscalls ✓
5. stage1d — functions ✓

### Phase 3: Self-Hosting Bootstrap
1. Stage 1 compiles itself
2. Eliminate Python/cmake/ninja from toolchain
3. Assembly seed is the only external artifact

### Phase 4: Language Extensions
1. Agent types as language primitives
2. Capability annotations on functions
3. Sandbox-aware borrow checker extensions
4. OS-native IPC types

### Phase 5: Kernel
1. Cyrius writes the AGNOS kernel
2. Bare metal, interrupts, page tables — all in Cyrius

## Key Principles

- **Assembly is the cornerstone** — primitives map to machine reality
- **All existing Rust code must compile unchanged** — superset, not replacement
- **Don't diverge from upstream unnecessarily** — cherry-pick upstream improvements
- **Fix the ecosystem, not the language** — type system and borrow checker are correct
- **Own the toolchain** — compiler, stdlib, package manager, build system
- **Every divergence gets an ADR** — no undocumented changes

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not break backward compatibility with existing Rust code
- Do not diverge from upstream Rust without a documented reason
- Do not add language features without an ADR (architectural decision record)
