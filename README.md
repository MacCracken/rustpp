# Rust++

**Rust++** — A systems language for sovereign operating systems.

Fork of the Rust compiler with ecosystem sovereignty, OS-native primitives, and no dependency on external registries or governance bodies.

## Why

Rust's type system and safety model are correct. Its ecosystem governance is a liability:

- **crates.io name squatting** — bots and speculators claim names, blocking legitimate projects
- **Registry coupling** — `cargo publish` validates optional deps against a registry you don't use
- **No sovereignty** — your project's ability to ship depends on a foundation you don't control

Rust++ fixes the ecosystem, not the language. All existing Rust code compiles unchanged.

## What Changes

| Rust | Rust++ |
|------|--------|
| crates.io is the default registry | ark is the native package backend |
| `cargo publish` validates all deps against crates.io | Git/path deps are first-class, no registry validation for `publish = false` |
| Packages, sandboxes, agents are library abstractions | OS primitives in the language |
| Names belong to whoever squats first | Names belong to builders |

## Status

**Phase 0** — Forking rustc. Not yet diverged.

## Part of AGNOS

Rust++ is the future language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only (diverged portions) | MIT/Apache-2.0 (upstream Rust portions)
