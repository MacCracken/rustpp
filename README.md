# Cyrius

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

Fork of the Rust compiler with sovereign package management, self-hosting bootstrap chain, and no dependency on external registries or governance bodies. Designed to write the AGNOS kernel.

## Why

Rust's type system and safety model are correct. Its ecosystem governance is a liability:

- **crates.io name squatting** — bots and speculators claim names, blocking legitimate projects
- **Registry coupling** — `cargo publish` validates optional deps against a registry you don't use
- **No sovereignty** — your project's ability to ship depends on a foundation you don't control
- **Bootstrap dependency** — "building from source" requires downloading a pre-built binary compiler

Cyrius fixes the ecosystem and owns the toolchain. All existing Rust code compiles unchanged.

## What Changes

| Rust | Cyrius |
|------|--------|
| crates.io is the default registry | Ark is the native package backend |
| `cargo publish` validates all deps against crates.io | Git/path deps are first-class, no registry validation for `publish = false` |
| Bootstrap requires Python + pre-built compiler | Assembly seed → stage 0 → stage 1 → self-hosting |
| Packages, sandboxes, agents are library abstractions | OS primitives in the language (planned) |
| Names belong to whoever squats first | Names belong to builders |

## Bootstrap Chain

```
rustc 1.96.0-dev (built from source)
  → cyrius-seed (Rust, 38 instructions, 102 tests)
    → stage1a (2642-byte .cyr binary, 14 tests)
      → generated ELF programs (144 bytes each)
```

## Status

| Phase | Status |
|-------|--------|
| Phase 0 — Fork & Understand | Done |
| Phase 1 — Registry Sovereignty (Ark) | Done |
| Phase 2 — Assembly Foundation (seed + stage 1a) | In progress |
| Phase 3 — Self-Hosting Bootstrap | Planned |
| Phase 4 — Language Extensions | Planned |
| Phase 5 — Kernel | Planned |

## Structure

```
seed/           Cyrius seed — stage 0 assembler (Rust, emits x86_64 ELF)
stage1/         Stage 1 compiler (written in .cyr, assembled by seed)
upstream/       rust-lang/rust submodule (with Ark cargo patches)
docs/           Architecture docs, ADRs, roadmap
```

## Part of AGNOS

Cyrius is the future language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only (diverged portions) | MIT/Apache-2.0 (upstream Rust portions)
