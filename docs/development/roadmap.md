# Cyrius Development Roadmap

> **Current**: v0.9.0 — feature-complete for ecosystem testing
>
> 168 x86_64 tests, 29 aarch64 tests, 0 failures.
> 27 library modules, 150+ functions. 5 tools. 5 crate rewrites.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Quicklist — Next Features

| # | Feature | Type | Unlocks |
|---|---------|------|---------|
| 1 | **Traits / interfaces** | Compiler | Display, From, Default — polymorphism |
| 2 | **Enum constructors** | Compiler | `enum Option { None; Some(val); }` auto-generates functions |
| 3 | **Type checking** | Compiler | Generics Phase 2 — warn on type mismatches |
| 4 | **Multi-file compilation** | Compiler | Beyond textual include |
| 5 | **Module system** (pub/mod/use) | Compiler | Namespace, visibility, large project org |
| 6 | **Error message line numbers** | Compiler | Needs tok_lines array + heap expansion |
| 7 | **Block scoping** | Compiler | var in loops — scope depth + token replay |
| 8 | **JSON parser** | Library | Serde replacement for config/manifest files |
| 9 | **String formatting v2** | Library | Format strings with Str type (not just C strings) |
| 10 | **Preprocessor fix** | Compiler | Don't eat `"include "` inside string literals |

## Active — aarch64

| # | Item | Status |
|---|------|--------|
| 1 | Instruction correctness | Done (29 tests passing) |
| 2 | aarch64 bootstrap (self-hosting on ARM) | Not started |
| 3 | aarch64 kernel port | Not started |
| 4 | Cross-compilation verified | Not started |

## Planned — Language Maturity (Tier 3)

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 2 | Closures / lambdas | 2 sessions | Functional patterns |
| 3 | Iterators | 2 sessions | Clean collection processing |
| 4 | Pattern matching (destructuring) | 2 sessions | Exhaustiveness checking |
| 5 | Concurrency primitives | 3 sessions | Multi-core kernel, parallel apps |
| 6 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 7 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |

## Planned — Full Sovereignty

| # | Item |
|---|------|
| 1 | AGNOS builds entirely with Cyrius (both architectures) |
| 2 | Full cross-bootstrap (x86_64 ↔ aarch64) |
| 3 | No external toolchain in any path |

## Planned — Crate Migration (remaining)

| Wave | Crates | Prerequisite |
|------|--------|-------------|
| 1 | agnostik, agnosys, kybernet, nous, ark | Done |
| 2 | mudra, vinimaya, taal, natya, kshetra, libro | Traits |
| 3 | sigil | Ownership |
| 4 | kavach, bote, t-ron, nein, majra | Sandbox borrow checker |
| 5 | daimon, hoosh, takumi | Concurrency |
| 6 | aethersafha, agnoshi | All features complete |

## Planned — Polymorphic Codegen

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
| 2026-04-07–15 | Quicklist items 1-5 (traits, enum constructors, type checking, modules) |
| 2026-04-15–25 | aarch64 self-hosting, crate migration wave 2 |
| **2026-05-01** | **BELTANE RELEASE** — both architectures, kernel + compiler + userland |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain
- No external language dependencies
- Byte-exact testing is the gold standard
- Programs are the best compiler fuzzers
- Documentation (vidya) compounds
- Prove in a library first, add syntax when earned
- Polymorphic codegen is defense, not offense
