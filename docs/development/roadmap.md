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

### Systems Language Features

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 25 | Struct padding/alignment (sizeof, alignof) | 2 sessions | ABI-compatible structs, FFI |
| 26 | Unions | 1 session | Overlapping memory layouts, type punning |
| 27 | Bitfields | 2 sessions | Hardware register access, protocol headers |
| 28 | Variadic functions | 2 sessions | printf-style APIs, syscall wrappers |
| 29 | Object files (.o) + linker integration | 3+ sessions | Separate compilation, link with ld |
| 30 | Optimization passes (-O1) | 5+ sessions | Constant folding, dead code elimination, register allocation |
| 31 | Multi-width types (i8, i16, i32) | 3 sessions | Memory-efficient structs, protocol parsing |
| 32 | Array types with length | 2 sessions | Bounds checking, stack arrays with known size |
| 33 | Inline functions | 1 session | Zero-overhead abstractions |
| 34 | Preprocessor macros (with args) | 3 sessions | `#define MAX(a,b)`, generic patterns |

---

## Completed (v0.9.0–v0.9.6)

### Language
- [x] Floating point f64 — SSE2 codegen, 10 builtins, float literals (v0.9.2)
- [x] Methods on structs — convention dispatch `point.scale(2)` (v0.9.2)
- [x] Error line numbers — `error:3: unexpected token` (v0.9.2)
- [x] Block scoping — variables in if/while/for don't leak (v0.9.5)
- [x] Enum constructor syntax — `Ok(val)` parsed (v0.9.6)
- [x] Feature flags — `#define`/`#ifdef`/`#endif` (v0.9.6)
- [x] Comparison in function args — `f(x == 1)` via setCC (v0.9.0)
- [x] Generics Phase 1 — syntax parsed, not enforced (v0.9.0)
- [x] Preprocessor fix — strings with "include" no longer trigger inclusion (v0.9.4)

### Compiler Infrastructure
- [x] Token arrays 32K → 64K (v0.9.2)
- [x] tok_names 32K → 64K + var_noffs relocation (v0.9.2)
- [x] Fixup table 512 → 1024 entries (v0.9.0)
- [x] Preprocessor buffer relocation (v0.9.2)
- [x] P-1 hardening: hashmap tombstones, vec bounds, alloc OOM, json null (v0.9.3)
- [x] Dead code removal: src/arch/x86_64/ (v0.9.6)

### Tooling
- [x] cyrb shell dispatcher — 18+ commands (v0.9.0)
- [x] cyrfmt, cyrlint, cyrdoc, cyrc, ark — 8 tool binaries (v0.9.0)
- [x] Benchmark suite — 45 benchmarks, bench-history.sh, CSV tracking (v0.9.1)
- [x] Installer — tarball download, version manager, bootstrap fallback (v0.9.1)
- [x] Release pipeline — dual-arch CI, SHA256, GitHub Releases (v0.9.1)
- [x] `cyrb docs --agent` — markdown server for bots (v0.9.6)
- [x] `cyrb.toml` parser — `toml_get` replaces grep/sed (v0.9.6)
- [x] Version bump script (v0.9.4)
- [x] cyrb version synced to VERSION file (v0.9.6)

### Documentation
- [x] 5 ADRs (v0.9.6)
- [x] Threat model (v0.9.6)
- [x] 32 vidya implementation entries (v0.9.4–v0.9.6)
- [x] 14/14 runnable vidya reference files (v0.9.4)
- [x] Tutorial, stdlib reference, FAQ, benchmarks docs (v0.9.0)

### Ecosystem
- [x] 5 crate rewrites: agnostik, agnosys, kybernet, nous, ark (v0.9.0)
- [x] Kybernet rewritten from Rust (v0.9.0)
- [x] AGNOS kernel 62KB with dual-arch CI (v0.9.0)
- [x] 35 stdlib modules, 199 functions (v0.9.0)

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

### cycc — C Compiler Frontend

Separate tool that parses C and emits Cyrius codegen. Reuses ELF emitter,
fixup system, and code buffer from cc2. Does NOT extend cc2 — new parser.

| Phase | Scope | Unlocks |
|-------|-------|---------|
| 1 | C89 subset: functions, structs, pointers, arrays, control flow | Compile simple C libraries |
| 2 | C99/C11: designated initializers, VLAs, _Bool, stdint | Compile most portable C |
| 3 | GCC extensions: __attribute__, __builtin_*, statement expressions | Compile Linux kernel headers |
| 4 | Full preprocessor: macros with args, ##, #if expressions | Compile real-world C codebases |
| 5 | Object files (.o) + linker integration | Separate compilation, link with ld |
| 6 | Optimization passes (-O1 minimum) | Kernel boot requires some optimization |

**Prerequisite**: Cyrius v1.0 (module system, multi-file compilation).
**Goal**: Compile the Linux kernel with zero external toolchain.
**Not a priority until**: AGNOS is self-sufficient and all crate waves are complete.

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
