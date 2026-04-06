# Cyrius Development Roadmap

> **Current**: v0.9.6 — enum constructors, feature flags, ADRs, threat model, docs server
>
> 110KB compiler, 57 programs, 8 tools, 45 benchmarks.
> 186 tests (135 compiler + 51 programs) + 12 aarch64, 0 failures.
> `cyrb audit` → 10/10 green. Self-hosting verified. 14/14 vidya pass.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Critical Path — AGNOS Pillar Ports

Bhava (29K LOC) and hisab (31K LOC) are core AGNOS pillars in Rust.
Remaining language features needed to port them:

### Tier 1 — Minimum Viable Port

| # | Feature | Why |
|---|---------|-----|
| 1 | **Real generics** (type checking) | `Vec<T>`, `Option<T>` — compile-time validation |
| 2 | **Module system** (pub/mod/use) | 60+ modules in bhava — textual include won't scale |
| 3 | **Multi-file compilation** | Follows from module system |

### Tier 2 — Functional Parity

| # | Feature | Why |
|---|---------|-----|
| 4 | **Closures / lambdas** | `.iter().map(\|x\| x + 1)`, callbacks |
| 5 | **Pattern matching** (destructuring) | `match result { Ok(v) => ..., Err(e) => ... }` |
| 6 | **Iterators** (language-level) | for-in loops, `.map().filter().collect()` |
| 7 | **Trait impl blocks** | `impl Display for Point { ... }` |
| 8 | **String type** (owned + slice) | `String`/`&str` — replace manual pointer management |

### Tier 3 — Full Fidelity

| # | Feature | Why |
|---|---------|-----|
| 9 | **Ownership / borrow checker** | Memory safety — both crates are zero-unsafe |
| 10 | **Concurrency primitives** | tokio/rayon in bhava ai + hisab parallel |
| 11 | **Derive macros** (serde) | Serialize/Deserialize on every public type |
| 12 | **Operator overloading** | `Vec3 + Vec3`, `Matrix * Vector` |
| 13 | **Const generics** | `[TraitLevel; 15]`, `Matrix<N, M>` |

---

## Before v1.0 — Must Have

### Compiler

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 1 | Real generics (Phase 2) | **Critical** | Type-safe containers, catch bugs at compile time |
| 2 | Module system (pub/mod/use) | **Critical** | Namespace, visibility, large projects |
| 3 | Multi-file compilation | **Critical** | Beyond textual include |
| 4 | Closures / lambdas | High | Anonymous functions, captured variables |
| 5 | Pattern matching | High | match with exhaustiveness checking |
| 6 | Iterators (language-level) | High | for-in loops, range expressions |
| 7 | Trait impl blocks | High | `impl Display for Point { ... }` |
| 8 | String type (owned) | High | Safe string manipulation |
| 9 | Code coverage instrumentation | Medium | `cyrb coverage` — inject counters |

### Tooling

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 10 | `cyrb publish` / `cyrb install` connected | High | Ark registry backend |
| 11 | `cyrb watch` | Medium | Auto-rebuild on file changes (inotify) |
| 12 | `cyrb coverage` | Medium | Code coverage reports |
| 13 | Doc-test runner | Medium | Runnable examples in doc comments |
| 14 | `cyrb repl` | Low | Interactive expression evaluator |

### aarch64

| # | Feature | Priority |
|---|---------|----------|
| 15 | aarch64 self-hosting | High — cc2_aarch64 compiles itself on ARM |
| 16 | aarch64 kernel port | High — AGNOS on ARM |
| 17 | Cross-compilation verified | Medium — x86 host → aarch64 binaries |

### Language Maturity (Tier 3)

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 18 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 19 | Operator overloading | 2 sessions | `+`, `-`, `*`, `/` on custom types |
| 20 | Const generics | 3 sessions | Fixed-size arrays, matrix dimensions |
| 21 | Derive macros | 3 sessions | Auto-generate Serialize, Display, Eq |
| 22 | Concurrency primitives | 3 sessions | Threads, atomics, channels |
| 23 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 24 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

---

## Completed (v0.9.0–v0.9.6)

| Version | Feature |
|---------|---------|
| v0.9.0 | Ecosystem baseline — 5 crate rewrites, 35 libs, 8 tools, 18 cyrb commands |
| v0.9.1 | Benchmarks (38), installer, release pipeline, dual-arch CI |
| v0.9.2 | **Floating point** (SSE2), **methods on structs**, **error line numbers** |
| v0.9.2 | Token arrays 32K→64K, tok_names 32K→64K, preprocessor buffer relocation |
| v0.9.3 | P-1 hardening: hashmap tombstones, vec bounds, alloc OOM, json null guard |
| v0.9.4 | **Preprocessor fix** (include in strings), version bump script |
| v0.9.5 | **Block scoping**, 19 new compiler tests, float/hashmap test programs |
| v0.9.6 | **Enum constructor syntax**, **feature flags** (#define/#ifdef/#endif) |
| v0.9.6 | 5 ADRs, threat model, `cyrb docs --agent`, cyrb.toml parser, version sync |

---

## After v1.0

### Full Sovereignty

| # | Item |
|---|------|
| 1 | AGNOS builds entirely with Cyrius (both architectures) |
| 2 | Full cross-bootstrap (x86_64 ↔ aarch64) |
| 3 | No external toolchain in any path |

### Crate Migration (waves)

| Wave | Crates | Prerequisite |
|------|--------|-------------|
| 1 | agnostik, agnosys, kybernet, nous, ark | **Done** |
| 2 | **bhava**, **hisab** | Generics + modules (remaining Tier 1) |
| 3 | mudra, vinimaya, taal, natya, kshetra, libro | Closures + trait impls + iterators (Tier 2) |
| 4 | sigil | Ownership |
| 5 | kavach, bote, t-ron, nein, majra | Sandbox borrow checker |
| 6 | daimon, hoosh, takumi | Concurrency |
| 7 | aethersafha, agnoshi | All features complete |

### Polymorphic Codegen

| Tier | Items |
|------|-------|
| 1 | `--poly-seed`, instruction encoding alternatives, semantic NOPs |
| 2 | Register shuffling, basic block reordering, stack layout randomization |
| 3 | kavach/seema/sigil/phylax/libro integration |

---

## Milestones

| Date | Milestone |
|------|-----------|
| 2026-04-05 | **v0.9.0–v0.9.6** — 7 releases in one day (ecosystem → language features → tooling) |
| 2026-04-xx | **v0.9.7+** — generics Phase 2, pattern matching, iterators, closures |
| 2026-04-xx | **v0.9.x** — module system, multi-file compilation, string type |
| 2026-04-30 | aarch64 self-hosting |
| **2026-05-01** | **BELTANE RELEASE (v1.0)** — both architectures, kernel + compiler + userland |
| 2026-05-01–15 | Crate migration wave 2: **bhava + hisab** ports begin |
| 2026-06-01 | Wave 3 crates |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Programs are the best compiler fuzzers
- Documentation (vidya) compounds
- Prove in a library first, add syntax when earned
- Polymorphic codegen is defense, not offense
- `cyrb audit` must pass before every commit
- bhava and hisab are AGNOS pillars — their needs drive language priorities
- Heap layout bugs are silent corruption — always verify after relocation
- Two-step bootstrap for any heap offset change
