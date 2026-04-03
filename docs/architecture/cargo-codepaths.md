# Cargo Registry Codepath Analysis

> Surgical map of where crates.io is hardcoded in cargo.
> These are the exact locations to cut for Cyrius/Ark registry sovereignty.

## TL;DR

Cargo's crates.io dependency is concentrated in **~20 locations** across 8 files. The registry infrastructure (remote.rs, http_remote.rs, RegistrySource) is fully generic — it takes URLs from SourceId, not hardcoded. The work is: swap constants, change defaults, relax publish validation.

## End-to-End Publish Flow

```
cargo publish
  → publish()                      [ops/registry/publish.rs:72]
    → resolve_registry_or_index()  [publish.rs:853]
      → infer_registry()           [ops/registry/mod.rs:325]
      → validate_registry()        [publish.rs:893]           ← defaults to CRATES_IO_REGISTRY
    → get_source_id()              [ops/registry/mod.rs:192]
      → get_initial_source_id()    [mod.rs:250]               ← defaults to crates_io()
    → registry()                   [mod.rs:123]
    → verify_dependencies()        [publish.rs:502]           ← THE GATEKEEPER
      → check_dep_has_version()    [ops/mod.rs:86]            ← rejects path/git without version
      → cross-registry check       [publish.rs:524]           ← crates.io-specific block
    → prepare_transmit()           [publish.rs:539]
      → map_dependency()           [util/toml/mod.rs:3233]    ← strips path/git, keeps version
    → transmit()                   [publish.rs:664]
```

## Priority 1 — Constants (change once, propagates everywhere)

All in `src/cargo/sources/registry/mod.rs`:

| Line | Constant | Value |
|------|----------|-------|
| 222 | `CRATES_IO_INDEX` | `https://github.com/rust-lang/crates.io-index` |
| 223 | `CRATES_IO_HTTP_INDEX` | `sparse+https://index.crates.io/` |
| 224 | `CRATES_IO_REGISTRY` | `crates-io` |
| 225 | `CRATES_IO_DOMAIN` | `crates.io` |

Also `crates/crates-io/lib.rs` line 519-523: `is_url_crates_io()` — checks if host is `crates.io`.

## Priority 2 — Default Registry Fallbacks

Where "no flag specified" means "use crates.io":

| File | Line | Function | What to Change |
|------|------|----------|----------------|
| `util/context/mod.rs` | 2015 | `crates_io_source_id()` | Point at Ark index URL |
| `core/source_id.rs` | 263 | `crates_io()` | Delegates to above |
| `core/source_id.rs` | 269 | `crates_io_maybe_sparse_http()` | Uses CRATES_IO_HTTP_INDEX |
| `core/source_id.rs` | 296 | `alt_registry()` | Special-cases CRATES_IO_REGISTRY name |
| `core/source_id.rs` | 548 | `is_crates_io()` | Matches against crates.io URLs |
| `sources/config.rs` | 104 | `SourceConfigMap::empty()` | Registers crates.io as built-in default |
| `sources/config.rs` | 315 | `add_config()` | Defaults crates-io name to sparse |
| `ops/registry/mod.rs` | 255 | `get_initial_source_id()` | `None → SourceId::crates_io` |

## Priority 3 — Publish Validation (crates.io-specific policy)

| File | Line | Function | Issue |
|------|------|----------|-------|
| `ops/registry/publish.rs` | 524 | `verify_dependencies()` | Blocks cross-registry deps TO crates.io. Remove or replace with Ark policy. |
| `ops/registry/publish.rs` | 557 | `prepare_transmit()` | Default dep registry = `SourceId::crates_io` |
| `ops/registry/publish.rs` | 878 | `resolve_registry_or_index()` | Compares against CRATES_IO_REGISTRY |
| `ops/registry/publish.rs` | 896 | `validate_registry()` | Default reg_name = CRATES_IO_REGISTRY |
| `ops/mod.rs` | 97 | `check_dep_has_version()` | Error message references CRATES_IO_DOMAIN |

## Priority 4 — Dependency Rewriting

`util/toml/mod.rs` line 3233 `map_dependency()`:
- Strips `path`, `git`, `branch`, `tag`, `rev` from deps during publish
- Converts named registries to index URLs
- **Registry-agnostic** — no changes needed unless we want to allow path deps in Ark

## No Changes Needed (Generic Infrastructure)

These files are registry-agnostic — they get URLs from SourceId:

- `sources/registry/remote.rs` — git-based registry access
- `sources/registry/http_remote.rs` — sparse HTTP registry access
- `sources/registry/mod.rs` — RegistrySource, RegistryConfig, RegistryData trait
- `sources/config.rs` `load()` — source replacement chain
- `core/source_id.rs` `load()` — source dispatch

## The Cyrius/Ark Cut Plan

### Phase 1a — Swap the Default (minimal, non-breaking)

1. Change the 4 constants to Ark values
2. Change `crates_io_source_id()` to return Ark
3. Change `get_initial_source_id()` default
4. Change `validate_registry()` default
5. Update `is_crates_io()` → `is_ark()`

This makes `cargo publish` default to Ark instead of crates.io. Existing `[registries.crates-io]` config still works for backward compat.

### Phase 1b — Relax Publish Validation

1. Remove the cross-registry block in `verify_dependencies()` line 524
2. In `check_dep_has_version()`: for `publish = false` deps, skip the version requirement entirely
3. In `map_dependency()`: optionally preserve path/git deps for local-only packages

### Phase 1c — Add Ark as Native Backend

1. Add `[registries.ark]` as a built-in (like crates-io is today)
2. Ark API client in `crates/crates-io/` (or a new `crates/ark/` crate)
3. `cargo install` from Ark

### What NOT to Touch

- The type system, borrow checker, codegen — all correct
- RegistrySource/RegistryData trait — generic and clean
- Source replacement chain — useful for Ark fallback config
- Git/path source implementations — they work
