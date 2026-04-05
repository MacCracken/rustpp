# Cyrius Development Roadmap

> **Current**: v0.9.0 — feature-complete for ecosystem testing
>
> 35 libraries, 55 programs, 8 tools, 18 cyrb commands.
> 168 x86_64 + 29 aarch64 tests, 0 failures. `cyrb audit` → 10/10 green.
> 5 crate rewrites. 14 runnable vidya reference files.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Before v1.0 — Must Have

### Compiler

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 1 | Enum constructors | High | `enum Option { None; Some(val); }` auto-generates fns |
| 2 | Type checking (Generics Phase 2) | High | Warn on mismatches, catch bugs at compile time |
| 3 | Module system (pub/mod/use) | High | Namespace, visibility, large projects |
| 4 | Multi-file compilation | High | Beyond textual include |
| 5 | Error message line numbers | High | Currently reports token index — need line:col |
| 6 | Block scoping | Medium | var in loops, scope depth + token replay |
| 7 | Preprocessor fix | Medium | Don't eat string literals containing include pattern |
| 8 | Pattern matching (destructuring) | Medium | match with exhaustiveness checking |
| 9 | Closures / lambdas | Medium | Anonymous functions, captured variables |
| 10 | Code coverage instrumentation | Medium | `cyrb coverage` — inject counters, report % |
| 11 | MSRV compatibility check | Low | Verify code compiles with older cc2 versions |

### Tooling

| # | Feature | Priority | Unlocks |
|---|---------|----------|---------|
| 12 | `cyrb.toml` native parser | High | cyrb reads manifest without shell grep |
| 13 | `cyrb publish` / `cyrb install` connected | High | Ark registry backend |
| 14 | `cyrb docs` | Medium | Local HTTP server for project documentation |
| 15 | `cyrb watch` | Medium | Auto-rebuild on file changes (inotify) |
| 16 | `cyrb coverage` | Medium | Code coverage reports |
| 17 | `cyrb security` | Medium | Deep pattern scan (unvalidated pointers, raw execve) |
| 18 | `cyrb repl` | Low | Interactive expression evaluator |
| 19 | Bootstrap restructure | Low | Move root-of-trust binaries out of build/ |

### aarch64

| # | Feature | Priority |
|---|---------|----------|
| 20 | aarch64 self-hosting | High — cc2_aarch64 compiles itself on ARM |
| 21 | aarch64 kernel port | High — AGNOS on ARM |
| 22 | Cross-compilation verified | Medium — x86 host → aarch64 binaries |

### Language Maturity (Tier 3)

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 23 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 24 | Iterators (language-level) | 2 sessions | for-in loops, range expressions |
| 25 | Concurrency primitives | 3 sessions | Threads, atomics, channels |
| 26 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 27 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

---

## After v1.0

### Full Sovereignty

| # | Item |
|---|------|
| 1 | AGNOS builds entirely with Cyrius (both architectures) |
| 2 | Full cross-bootstrap (x86_64 ↔ aarch64) |
| 3 | No external toolchain in any path |

### Crate Migration (remaining waves)

| Wave | Crates | Prerequisite |
|------|--------|-------------|
| 1 | agnostik, agnosys, kybernet, nous, ark | Done |
| 2 | mudra, vinimaya, taal, natya, kshetra, libro | Traits + type checking |
| 3 | sigil | Ownership |
| 4 | kavach, bote, t-ron, nein, majra | Sandbox borrow checker |
| 5 | daimon, hoosh, takumi | Concurrency |
| 6 | aethersafha, agnoshi | All features complete |

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
| 2026-04-07–15 | Compiler: enum constructors, type checking, modules, line numbers |
| 2026-04-15–25 | aarch64 self-hosting, crate migration wave 2 |
| **2026-05-01** | **BELTANE RELEASE (v1.0)** — both architectures, kernel + compiler + userland |

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
