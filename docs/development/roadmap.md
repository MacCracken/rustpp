# Cyrius Development Roadmap

> **Current**: v0.9.4 — preprocessor fix, P-1 hardening, vidya updates
>
> 104KB compiler, 222 functions, 35 libraries, 56 programs, 8 tools.
> 160 x86_64 + 12 aarch64 tests, 0 failures. Self-compile: 9ms.
> f64 arithmetic, struct methods, error line numbers, tombstone hashmap.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Critical Path — AGNOS Pillar Ports

Bhava (emotion engine, 29K LOC) and hisab (math library, 31K LOC) are core AGNOS
pillars currently in Rust. Porting them to Cyrius requires these language features
in dependency order:

### Tier 1 — Minimum Viable Port

| # | Feature | Status | Why |
|---|---------|--------|-----|
| ~~1~~ | ~~Floating point (f64)~~ | **Done (v0.9.2)** | SSE2 codegen, 10 builtins, float literals |
| ~~2~~ | ~~Methods on structs~~ | **Done (v0.9.2)** | `point.scale(2)` convention dispatch |
| ~~3~~ | ~~Error message line numbers~~ | **Done (v0.9.2)** | `error:3: unexpected token (type=5)` |
| 4 | **Real generics** (monomorphization) | Next | `Vec<T>`, `Option<T>`, typed containers |
| 5 | **Module system** (pub/mod/use) | Next | 60+ modules in bhava — textual include won't scale |
| 6 | **Multi-file compilation** | Next | Follows from module system |

### Tier 2 — Functional Parity

| # | Feature | Why |
|---|---------|-----|
| 7 | **Closures / lambdas** | `.iter().map(\|x\| x + 1)`, callbacks, event handlers |
| 8 | **Pattern matching** (destructuring) | `match result { Ok(v) => ..., Err(e) => ... }` |
| 9 | **Iterators** (language-level) | for-in loops, `.map().filter().collect()` chains |
| 10 | **Trait impl blocks** | `impl Display for Point { ... }` — bhava has 15+ traits |
| 11 | **Feature flags** | Conditional compilation — bhava: 18 features, hisab: 11 |
| 12 | **String type** (owned + slice) | `String`/`&str` — replace manual pointer management |
| 13 | **Enum constructors** | `Option::Some(val)`, `Result::Ok(val)` auto-generated |

### Tier 3 — Full Fidelity

| # | Feature | Why |
|---|---------|-----|
| 14 | **Ownership / borrow checker** | Memory safety — both crates are zero-unsafe |
| 15 | **Concurrency primitives** | tokio/rayon in bhava ai + hisab parallel |
| 16 | **Derive macros** (serde) | Serialize/Deserialize on every public type |
| 17 | **Operator overloading** | `Vec3 + Vec3`, `Matrix * Vector` |
| 18 | **Const generics** | `[TraitLevel; 15]`, `Matrix<N, M>` |

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
| 8 | Feature flags | High | Conditional compilation |
| 9 | String type (owned) | High | Safe string manipulation |
| 10 | Enum constructors | High | `enum Option { None; Some(val); }` auto-generates fns |
| 11 | Block scoping | Medium | var in loops, scope depth |
| 12 | Code coverage instrumentation | Medium | `cyrb coverage` — inject counters, report % |

### Tooling

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 13 | `cyrb.toml` native parser | High | cyrb reads manifest without shell grep |
| 14 | `cyrb publish` / `cyrb install` connected | High | Ark registry backend |
| 15 | Architecture decision records | Medium | docs/adr/ — numbered design decisions |
| 16 | Threat model | Medium | docs/development/threat-model.md |
| 17 | `cyrb docs` | Medium | Local HTTP server for project documentation |
| 18 | `cyrb watch` | Medium | Auto-rebuild on file changes (inotify) |
| 19 | `cyrb coverage` | Medium | Code coverage reports |
| 20 | Doc-test runner | Medium | Runnable examples in doc comments |
| 21 | `cyrb repl` | Low | Interactive expression evaluator |

### aarch64

| # | Feature | Priority |
|---|---------|----------|
| 22 | aarch64 self-hosting | High — cc2_aarch64 compiles itself on ARM |
| 23 | aarch64 kernel port | High — AGNOS on ARM |
| 24 | Cross-compilation verified | Medium — x86 host → aarch64 binaries |

### Language Maturity (Tier 3)

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 25 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 26 | Operator overloading | 2 sessions | `+`, `-`, `*`, `/` on custom types |
| 27 | Const generics | 3 sessions | Fixed-size arrays, matrix dimensions |
| 28 | Derive macros | 3 sessions | Auto-generate Serialize, Display, Eq |
| 29 | Concurrency primitives | 3 sessions | Threads, atomics, channels |
| 30 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 31 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

---

## Completed (v0.9.0–v0.9.4)

| Version | Feature |
|---------|---------|
| v0.9.0 | Ecosystem baseline — 5 crate rewrites, 35 libs, 8 tools, 18 cyrb commands |
| v0.9.1 | Benchmarks (38), installer, release pipeline, dual-arch CI |
| v0.9.2 | **Floating point** (SSE2), **methods on structs**, **error line numbers** |
| v0.9.2 | Token arrays 32K→64K, tok_names 32K→64K, capacity fixes |
| v0.9.3 | P-1 hardening: hashmap tombstones, vec bounds, alloc OOM, json null guard |
| v0.9.4 | **Preprocessor fix** (include in strings), version bump script, vidya updates |

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
| 2026-04-05 | **v0.9.0** — ecosystem testing baseline |
| 2026-04-05 | **v0.9.1** — benchmarks, installer, release pipeline |
| 2026-04-05 | **v0.9.2** — floats, methods, line numbers, capacity fixes (104KB) |
| 2026-04-05 | **v0.9.3** — P-1 hardening (hashmap, vec, alloc, json) |
| 2026-04-05 | **v0.9.4** — preprocessor fix, version bump script, vidya |
| 2026-04-xx | **v0.9.5+** — generics Phase 2, enum constructors, pattern matching |
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
