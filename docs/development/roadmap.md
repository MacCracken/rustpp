# Cyrius Development Roadmap

> **Current**: v0.9.0 — preparing for Beltane Release (May 1, 2026)
>
> 168 tests, 0 failures. 24 library modules. 5 crate rewrites.
> Self-hosting compiler (93KB), AGNOS kernel (62KB), Ark package manager (44KB).
> Zero external dependencies.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active

### Phase 9 — Multi-Architecture (aarch64) — Remaining

| # | Item | Notes |
|---|------|-------|
| 1 | aarch64 instruction correctness | Fix jmp encoding, get `var x = 42` running |
| 2 | aarch64 bootstrap | cc2_aarch64 compiles itself on ARM hardware |
| 3 | aarch64 kernel port | Same AGNOS kernel, different arch |
| 4 | Cross-compilation | x86_64 host → aarch64 binaries verified |

### Phase 10 — Deferred Items

| # | Item | Notes |
|---|------|-------|
| 1 | Error message line numbers | Needs tok_lines array (262KB) + heap expansion |
| 2 | Block scoping | Scope depth + token replay interaction needs investigation |
| 3 | Performance pass | Compiler is 11ms — optimize when it matters |

---

## Planned — Pre-Release (before May 1)

### Phase 12 — Full Sovereignty

**Goal**: AGNOS builds entirely with Cyrius. No external toolchain.

| # | Item | Notes |
|---|------|-------|
| 1 | AGNOS builds entirely with Cyrius | Both architectures |
| 2 | Full cross-bootstrap | x86_64 ↔ aarch64 |
| 3 | No external toolchain in any path | The entire stack is owned |

### Phase 13 — Language Maturity (Tier 2)

**Goal**: Scale features for larger codebases. Unlock 1:1 Rust parity.

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Enums with data (tagged unions) | 2 sessions | Error(String), Option, Result |
| 2 | Generics / templates | 3 sessions | Vec\<T\>, Result\<T\>, type-safe containers |
| 3 | Traits / interfaces | 3 sessions | Abstraction, polymorphism, Display/From |
| 4 | Proper module system | 2 sessions | pub/mod/use, large project organization |
| 5 | HashMap | 1 session | Key-value lookup (needs generics) |
| 6 | Nested function calls in expressions | 1 session | Fix register save across calls |
| 7 | Multi-file compilation | 2 sessions | Beyond textual include |
| 8 | Array bounds checking (opt-in) | 1 session | Memory safety |
| 9 | `cyrb vet` — dependency auditing | 1 session | Verify included libraries are trusted |
| 10 | `cyrb deny` — license/policy enforcement | 1 session | Block untrusted includes, enforce GPL-3.0 |

### Phase 14 — Language Maturity (Tier 3)

**Goal**: Advanced features for the sovereign language vision.

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 2 | Closures / lambdas | 2 sessions | Functional patterns |
| 3 | Iterators | 2 sessions | Clean collection processing |
| 4 | Pattern matching (destructuring) | 2 sessions | Destructuring, exhaustiveness |
| 5 | Concurrency primitives | 3 sessions | Multi-core kernel, parallel apps |
| 6 | Agent/capability annotations | 3 sessions | Cyrius-native OS constructs |
| 7 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention |
| 8 | String formatting (sprintf/format) | 1 session | Clean string building |

---

## Planned — Post-Release

### Phase 15 — AGNOS Crate Migration

**Goal**: Migrate remaining AGNOS crates from Rust to Cyrius.

| Wave | Crates | Prerequisite |
|------|--------|-------------|
| 1 — Prove it | agnostik, agnosys, kybernet, nous, ark | Done (Phase 11) |
| 2 — Pure computation | mudra, vinimaya, taal, natya, kshetra, libro | Phase 13 (generics, traits) |
| 3 — System + crypto | sigil | Phase 14 (ownership) |
| 4 — Language-native | kavach, bote, t-ron, nein, majra | Phase 14 (sandbox borrow checker) |
| 5 — The brain | daimon, hoosh, takumi | Phase 14 (concurrency) |
| 6 — The interface | aethersafha, agnoshi | All phases complete |

### Phase 16 — Polymorphic Codegen

**Goal**: Every deployment unique. Same behavior, different binary. Sovereign defense.

| Tier | Items | Effort |
|------|-------|--------|
| 1 | `--poly-seed`, instruction encoding alternatives, semantic NOPs | Small |
| 2 | Register shuffling, basic block reordering, stack layout randomization | Medium |
| 3 | kavach/seema/sigil/phylax/libro integration | Small-Medium |

---

## Milestones

| Date | Milestone |
|------|-----------|
| 2026-04-06 | Tag **v0.9.0** |
| 2026-04-07–12 | Phase 13: enums-with-data, generics, traits |
| 2026-04-12–20 | Phase 14 + Phase 15 wave 2 |
| 2026-04-20–28 | Phase 12 sovereignty, aarch64 bootstrap |
| **2026-05-01** | **BELTANE RELEASE** — both architectures, kernel + compiler + userland |

---

## Principles

- Assembly is the cornerstone — primitives map to machine reality
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies — bootstrap from a single binary
- Every extension is built from within, not forked from outside
- Byte-exact testing is the gold standard
- Programs are the best compiler fuzzers — build real things early
- Prove the language before building the kernel
- One architecture first, port after stabilization
- Documentation (vidya) compounds — 10x implementation speed
- Tests catch bugs at seams — build programs, not just test cases
- Defer when cost exceeds benefit — the work loop is a decision engine
- Polymorphic codegen is defense, not offense — sovereign purpose
