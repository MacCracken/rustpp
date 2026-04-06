# Cyrius Development Roadmap

> **Current**: v0.9.2 — floats, methods, line numbers, capacity fixes
>
> 104KB compiler, 222 functions, 35 libraries, 56 programs, 8 tools.
> 160 x86_64 + 12 aarch64 tests, 0 failures. Self-compile: 9ms.
> f64 arithmetic + comparisons, struct methods, error line numbers.

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
| ~~2~~ | ~~Methods on structs~~ | **Done (v0.9.2)** | `point.scale(2)` → `Point_scale(&point, 2)` |
| 3 | **Real generics** (monomorphization) | Next | `Vec<T>`, `Option<T>`, typed containers everywhere |
| 4 | **Module system** (pub/mod/use) | Next | 60+ modules in bhava, 15+ in hisab — textual include won't scale |
| 5 | **Multi-file compilation** | Next | Follows from module system — separate compilation units |
| ~~6~~ | ~~Error message line numbers~~ | **Done (v0.9.2)** | `error:3: unexpected token (type=5)` |

### Tier 2 — Functional Parity

| # | Feature | Blocks | Why |
|---|---------|--------|-----|
| 7 | **Closures / lambdas** | both | `.iter().map(\|x\| x + 1)`, callbacks, event handlers |
| 8 | **Pattern matching** (destructuring match) | both | `match result { Ok(v) => ..., Err(e) => ... }` — exhaustive |
| 9 | **Iterators** (language-level) | both | for-in loops, range expressions, `.map().filter().collect()` chains |
| 10 | **Trait impl blocks** (`impl Trait for Type`) | both | bhava: 15+ traits, hisab: Serialize/Display/Error on every type |
| 11 | **Feature flags / conditional compilation** | both | bhava: 18 features, hisab: 11 features — modules gated on flags |
| 12 | **String type** (owned + slice) | both | `String`/`&str` pervasive — current manual pointer mgmt won't port |
| 13 | **Enum constructors** | both | `Option::Some(val)`, `Result::Ok(val)` auto-generated |

### Tier 3 — Full Fidelity

| # | Feature | Blocks | Why |
|---|---------|--------|-----|
| 14 | **Ownership / borrow checker** | memory safety | Both crates are zero-unsafe — Cyrius needs equivalent guarantee |
| 15 | **Concurrency primitives** | bhava ai, hisab parallel | tokio/rayon usage in both — threads, atomics, channels |
| 16 | **Derive macros** (serde) | both | Serialize/Deserialize on every public type |
| 17 | **Operator overloading** | hisab | `Vec3 + Vec3`, `Matrix * Vector` — core math ergonomics |
| 18 | **Const generics** | hisab | `[TraitLevel; 15]` fixed arrays, `Matrix<N, M>` |

---

## Before v1.0 — Must Have

### Compiler

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 1 | Real generics (Phase 2) | **Critical** | Type-safe containers, catch bugs at compile time |
| 2 | Module system (pub/mod/use) | **Critical** | Namespace, visibility, large projects |
| 3 | Multi-file compilation | **Critical** | Beyond textual include |
| 4 | Closures / lambdas | High | Anonymous functions, captured variables |
| 5 | Pattern matching (destructuring) | High | match with exhaustiveness checking |
| 6 | Iterators (language-level) | High | for-in loops, range expressions |
| 7 | Trait impl blocks | High | `impl Display for Point { ... }` |
| 8 | Feature flags | High | Conditional compilation, `#[cfg(feature = "...")]` |
| 9 | String type (owned) | High | Safe string manipulation without manual pointer math |
| 10 | Enum constructors | High | `enum Option { None; Some(val); }` auto-generates fns |
| 11 | Block scoping | Medium | var in loops, scope depth + token replay |
| 12 | Preprocessor fix | Medium | Don't eat string literals containing include pattern |
| 13 | Code coverage instrumentation | Medium | `cyrb coverage` — inject counters, report % |

### Tooling

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 14 | `cyrb.toml` native parser | High | cyrb reads manifest without shell grep |
| 15 | `cyrb publish` / `cyrb install` connected | High | Ark registry backend |
| 16 | Version bump script | High | scripts/version-bump.sh (update VERSION + cyrb.toml) |
| 17 | Architecture decision records | Medium | docs/adr/ — numbered design decisions |
| 18 | Threat model | Medium | docs/development/threat-model.md |
| 19 | `cyrb docs` | Medium | Local HTTP server for project documentation |
| 20 | `cyrb watch` | Medium | Auto-rebuild on file changes (inotify) |
| 21 | `cyrb coverage` | Medium | Code coverage reports |
| 22 | `cyrb security` | Medium | Deep pattern scan (unvalidated pointers, raw execve) |
| 23 | Doc-test runner | Medium | Runnable examples in doc comments |
| 24 | `cyrb repl` | Low | Interactive expression evaluator |

### aarch64

| # | Feature | Priority |
|---|---------|----------|
| 25 | aarch64 self-hosting | High — cc2_aarch64 compiles itself on ARM |
| 26 | aarch64 kernel port | High — AGNOS on ARM |
| 27 | Cross-compilation verified | Medium — x86 host → aarch64 binaries |

### Language Maturity (Tier 3)

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 28 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 29 | Operator overloading | 2 sessions | `+`, `-`, `*`, `/` on custom types |
| 30 | Const generics | 3 sessions | Fixed-size arrays, matrix dimensions |
| 31 | Derive macros | 3 sessions | Auto-generate Serialize, Display, Eq |
| 32 | Concurrency primitives | 3 sessions | Threads, atomics, channels |
| 33 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 34 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

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
| 2026-04-xx | **v0.9.3** — generics Phase 2, enum constructors, pattern matching |
| 2026-04-xx | **v0.9.4** — module system, multi-file compilation, string type |
| 2026-04-30 | aarch64 self-hosting, tooling (version bump, ADRs) |
| **2026-05-01** | **BELTANE RELEASE (v1.0)** — both architectures, kernel + compiler + userland |
| 2026-05-01–15 | Crate migration wave 2: **bhava + hisab** ports begin |
| 2026-06-01 | Wave 3 crates (mudra, vinimaya, taal, natya, kshetra, libro) |

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
