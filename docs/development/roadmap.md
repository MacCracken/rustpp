# Cyrius Development Roadmap

> **Current**: v0.9.0 — ecosystem testing baseline
>
> 35 libraries, 55 programs, 8 tools, 18 cyrb commands, 38 benchmarks.
> 157 x86_64 + 29 aarch64 tests, 0 failures. `cyrb audit` → 10/10 green.
> 5 crate rewrites. 14 runnable vidya reference files. Self-compile: 9ms.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Critical Path — AGNOS Pillar Ports

Bhava (emotion engine, 29K LOC) and hisab (math library, 31K LOC) are core AGNOS
pillars currently in Rust. Porting them to Cyrius requires these language features
in dependency order:

### Tier 1 — Minimum Viable Port

| # | Feature | Blocks | Why |
|---|---------|--------|-----|
| 1 | **Floating point (f64)** | hisab entirely | Every transform, intersection, integration, FFT |
| 2 | **Methods on structs** (`impl`-like) | both | `point.normalize()`, `state.decay()` — pervasive pattern |
| 3 | **Real generics** (monomorphization) | both | `Vec<T>`, `Option<T>`, typed containers everywhere |
| 4 | **Module system** (pub/mod/use) | both | 60+ modules in bhava, 15+ in hisab — textual include won't scale |
| 5 | **Multi-file compilation** | both | Follows from module system — separate compilation units |
| 6 | **Error message line numbers** | developer experience | Currently reports token index — need line:col for 30K+ LOC files |

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
| 1 | Floating point (f64/f32) | **Critical** | hisab port, scientific computing, any real math |
| 2 | Methods on structs | **Critical** | OOP-style dispatch, both pillar ports |
| 3 | Real generics (Phase 2) | **Critical** | Type-safe containers, catch bugs at compile time |
| 4 | Module system (pub/mod/use) | **Critical** | Namespace, visibility, large projects |
| 5 | Multi-file compilation | **Critical** | Beyond textual include |
| 6 | Error message line numbers | High | Currently reports token index — need line:col |
| 7 | Closures / lambdas | High | Anonymous functions, captured variables |
| 8 | Pattern matching (destructuring) | High | match with exhaustiveness checking |
| 9 | Iterators (language-level) | High | for-in loops, range expressions |
| 10 | Trait impl blocks | High | `impl Display for Point { ... }` |
| 11 | Feature flags | High | Conditional compilation, `#[cfg(feature = "...")]` |
| 12 | String type (owned) | High | Safe string manipulation without manual pointer math |
| 13 | Enum constructors | High | `enum Option { None; Some(val); }` auto-generates fns |
| 14 | Block scoping | Medium | var in loops, scope depth + token replay |
| 15 | Preprocessor fix | Medium | Don't eat string literals containing include pattern |
| 16 | Code coverage instrumentation | Medium | `cyrb coverage` — inject counters, report % |

### Tooling

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 17 | `cyrb.toml` native parser | High | cyrb reads manifest without shell grep |
| 18 | `cyrb publish` / `cyrb install` connected | High | Ark registry backend |
| 19 | Version bump script | High | scripts/version-bump.sh (update VERSION + cyrb.toml) |
| 20 | Architecture decision records | Medium | docs/adr/ — numbered design decisions |
| 21 | Threat model | Medium | docs/development/threat-model.md |
| 22 | `cyrb docs` | Medium | Local HTTP server for project documentation |
| 23 | `cyrb watch` | Medium | Auto-rebuild on file changes (inotify) |
| 24 | `cyrb coverage` | Medium | Code coverage reports |
| 25 | `cyrb security` | Medium | Deep pattern scan (unvalidated pointers, raw execve) |
| 26 | Doc-test runner | Medium | Runnable examples in doc comments |
| 27 | `cyrb repl` | Low | Interactive expression evaluator |

### aarch64

| # | Feature | Priority |
|---|---------|----------|
| 28 | aarch64 self-hosting | High — cc2_aarch64 compiles itself on ARM |
| 29 | aarch64 kernel port | High — AGNOS on ARM |
| 30 | Cross-compilation verified | Medium — x86 host → aarch64 binaries |

### Language Maturity (Tier 3)

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 31 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 32 | Operator overloading | 2 sessions | `+`, `-`, `*`, `/` on custom types |
| 33 | Const generics | 3 sessions | Fixed-size arrays, matrix dimensions |
| 34 | Derive macros | 3 sessions | Auto-generate Serialize, Display, Eq |
| 35 | Concurrency primitives | 3 sessions | Threads, atomics, channels |
| 36 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 37 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

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
| 2 | **bhava**, **hisab** | Floats + methods + generics + modules (Tier 1) |
| 3 | mudra, vinimaya, taal, natya, kshetra, libro | Traits + type checking + closures (Tier 2) |
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
| 2026-04-06 | Tag **v0.9.0** — ecosystem testing baseline |
| 2026-04-07–15 | Compiler: floats, methods, line numbers, enum constructors |
| 2026-04-15–25 | Compiler: generics Phase 2, module system, pattern matching |
| 2026-04-25–30 | aarch64 self-hosting, tooling (bench history, version bump, ADRs) |
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
