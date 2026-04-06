# Cyrius Development Roadmap

> **Current**: v0.9.12 — subprocess bridge, deep audit, 217 tests
>
> 128KB compiler, 57 programs, 8 tools, 45 benchmarks.
> 217 tests (166 compiler + 51 programs) + 26 aarch64, 0 failures.
> 13 releases in 2 days. 4 items left for v1.0.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## The Migration

**108 Rust repos. ~1 million lines. This is why v1.0 must be right.**

| Bracket | Count | Strategy |
|---------|-------|----------|
| <1K lines | 18 repos | Direct port, minimal features needed |
| 1K–5K lines | 21 repos | Port with current features |
| 5K–15K lines | 51 repos | Need closures, iterators, traits |
| >15K lines | 18 repos | Need full Tier 2 + generics |

Top 10 by size:
- ifran (54K), tarang (33K), hisab (32K), bhava (30K), agnosys (29K)
- agnosai (28K), agnoshi (27K), aethersafha (27K), kavach (26K), dhvani (24K)

5 repos already converted (wave 1): agnostik, agnosys, kybernet, nous, ark.
103 remaining.

---

## v1.0 Requirements

v1.0 ships when the language can port the **small and medium repos** (<5K lines)
without workarounds. That's 39 repos as the first wave proof.

### Remaining for v1.0

| # | Feature | Status | Why |
|---|---------|--------|-----|
| 1 | Shared library output (.so) | Needed | FFI bridge to Rust/TS/Python |
| 2 | C FFI (header generation) | Needed | Call Cyrius from C/Rust |
| 3 | aarch64 byte-identical self-hosting | In progress | Dual-arch claim |
| 4 | P-1 hardening + 250 tests | In progress | Quality gate |

### Nice to Have for v1.0

| # | Feature | Why |
|---|---------|-----|
| 5 | Real generics (type checking) | Catch bugs, not needed for codegen |
| 6 | Enum constructors (auto-generate) | Cleaner Option/Result API |
| 7 | Iterators (for-in over collections) | Sugar over while + methods |

### Post-v1.0 (needed for 5K+ repos)

| # | Feature | Blocks |
|---|---------|--------|
| 8 | Const generics | hisab (Matrix<N,M>) |
| 9 | Derive macros | serde everywhere |
| 10 | Concurrency | tokio/rayon usage |
| 20 | Ownership / borrow checker | Memory safety |
| 21 | Sandbox borrow checker | AGNOS security model |

---

## Release Chunks

### v0.9.10 — Closures + String Type

| Feature | Approach |
|---------|---------|
| **Closures** | Heap-allocated {fn_ptr, captures...}, capture by value |
| **String type** | Length-prefixed heap, `s"hello"` syntax, str.cyr as standard |

### v0.9.11 — Operator Overloading + Auto Enum Constructors

| Feature | Approach |
|---------|---------|
| **Operator overloading** | Track variable addresses through expressions, dispatch to Type_add |
| **Enum constructors** | Auto-generate `EnumName_Variant(payload)` during PARSE_ENUM_DEF |

### v0.9.12 — aarch64 + Hardening

| Feature | Approach |
|---------|---------|
| **aarch64 byte-identical** | Fix write buffer issue, verify cc3==cc4 |
| **P-1 hardening** | Audit all libs, expand tests to 250+ |
| **Documentation** | All features documented, vidya current |

### v1.0 — Ship It

| Criteria | Target |
|----------|--------|
| Compiler | Self-hosting, both architectures |
| Tests | 250+, 0 failures |
| Audit | 10/10 green |
| Docs | Tutorial, reference, FAQ, all current |
| Toolchain | 20+ cyrb commands, installer, CI/CD |
| Ports | First 39 repos (<5K) portable |

---

## Post-v1.0 Waves

### Wave 2 — Core Libraries (18 repos, 5K–15K lines)

bhava, hisab, mudra, vinimaya, taal, natya, kshetra, libro, bodh,
sangha, sharira, jivanu, tanmatra, mastishk, jantu, svara, prani, kana

**Requires**: Generics, closures, derive macros

### Wave 3 — Infrastructure (15 repos, 5K–15K lines)

kavach, sigil, phylax, bote, t-ron, nein, majra, seema, libro,
kimiya, rasayan, pravash, ranga, soorat, szal

**Requires**: Ownership, sandbox borrow checker

### Wave 4 — AI + Platform (18 repos, >15K lines)

daimon, hoosh, agnosai, agnoshi, aethersafha, ifran, tarang,
avatara, stiva, impetus, kiran, dhvani, prakash, raasta, argonaut,
bijli, ai-hwaccel, jyotish

**Requires**: Concurrency, full type system

### Wave 5 — Everything Else

Remaining small repos, tools, utilities.

---

## Systems Language Features (v1.x)

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment | Medium | FFI, ABI compat |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |
| Optimization passes (-O1) | Very High | Performance |
| Preprocessor macros (with args) | Medium | Generic patterns |

## cycc — C Compiler Frontend (v2.0+)

| Phase | Scope |
|-------|-------|
| 1 | C89 subset |
| 2 | C99/C11 |
| 3 | GCC extensions |
| 4 | Full preprocessor |
| 5 | Object files + linker |
| 6 | Optimization |

## Polymorphic Codegen

| Tier | Items |
|------|-------|
| 1 | `--poly-seed`, instruction alternatives, semantic NOPs |
| 2 | Register shuffling, block reordering, stack randomization |
| 3 | kavach/seema/sigil/phylax/libro integration |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Programs are the best compiler fuzzers
- Documentation (vidya) compounds
- Prove in a library first, add syntax when earned
- v1.0 ships when 39 small repos can port cleanly
- 108 repos / ~1M lines is the real measure of success
- Heap layout bugs are silent corruption — always verify after relocation
- Two-step bootstrap for any heap offset change
- Portable syscall constants (SYS_*) for cross-architecture compilation
