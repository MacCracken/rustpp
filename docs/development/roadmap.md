# Cyrius Development Roadmap

> **Current**: v0.9.7 — module system, coverage, doc-tests, REPL
>
> 115KB compiler, 57 programs, 8 tools, 45 benchmarks.
> 190 tests (139 compiler + 51 programs) + 12 aarch64, 0 failures.
> `cyrb audit` → 10/10 green. Self-hosting verified. 14/14 vidya pass.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Release Plan to v1.0

### v0.9.8 — Language: Pattern Matching + Iterators

Quick wins that build on existing infrastructure (switch + for loops).

| Feature | Effort | Approach |
|---------|--------|---------|
| **Pattern matching** | Medium | `match expr { val => { }, _ => { } }` — extends switch codegen |
| **Iterators (for-in)** | Low | `for item in v.iter() { }` — syntactic sugar over while + method calls |

### v0.9.9 — Language: Traits + Strings

Complete Tier 2 functional parity for crate ports.

| Feature | Effort | Approach |
|---------|--------|---------|
| **Trait impl blocks** | Medium | `impl Display for Point { fn format(self) { } }` — name mangling to `Point_Display_format` |
| **String type** | Medium | Length-prefixed heap block, single i64 pointer, `s"hello"` literal syntax |
| **Operator overloading** | Low | `+` `-` `*` `/` dispatch to `Type_add(a, b)` when struct typed |

### v0.9.10 — Architecture: aarch64 Maturity

Required for "both architectures" claim in v1.0.

| Feature | Effort | Approach |
|---------|--------|---------|
| **aarch64 self-hosting** | High | cc2_aarch64 compiles itself on ARM hardware/qemu |
| **Cross-compilation verified** | Medium | Full test suite passes via qemu |
| **aarch64 kernel port** | Medium | AGNOS boots on aarch64 (qemu-system) |

### v1.0-rc — Hardening + Polish

Final quality gate before release.

| Task | Detail |
|------|--------|
| P-1 hardening | Audit all 35 lib modules, fix any remaining edge cases |
| Test expansion | Target 250+ tests, cover all language features |
| Benchmark baseline | Full bench-history run, BENCHMARKS.md updated |
| Documentation audit | All docs current, no stale references |
| Vidya sync | All new features have implementation + usage entries |
| `cyrb audit` → 10/10 | Format, lint, vet, deny, test, bench, doc, self-host |
| CI green | All jobs pass on both ubuntu and AGNOS container |

### v1.0 — BELTANE RELEASE (May 1, 2026)

**Definition of done:**
- Self-hosting compiler (both x86_64 and aarch64)
- AGNOS kernel boots on both architectures
- Complete developer toolchain (20+ cyrb commands)
- Pattern matching, iterators, trait impls, string type
- Module system with pub/use
- 250+ tests, 0 failures
- All documentation current
- Installer + version manager
- Release pipeline with dual-arch tarballs

---

## Post-v1.0

### Crate Migration Wave 2 (May 2026)

| Crate | LOC | Key Requirement |
|-------|-----|----------------|
| **bhava** | 29K | Traits, iterators, strings, generics validation |
| **hisab** | 31K | Floats (done), operator overloading, const generics |

### Language Features (v1.1–v2.0)

Priority order based on crate wave requirements:

| Feature | Blocks Wave | Effort |
|---------|-------------|--------|
| Real generics (Phase 2 — type checking) | Wave 2 | Low |
| Closures / lambdas | Wave 3 | High |
| Const generics | Wave 2 (hisab) | Medium |
| Derive macros (serde) | Wave 3 | Medium |
| Concurrency primitives | Wave 6 | High |
| Ownership / borrow checker | Wave 4 | Very High |
| Sandbox-aware borrow checker | Wave 5 | Very High |
| Agent/capability annotations | Wave 5 | Medium |

### Systems Language Features (v1.x)

For cycc compatibility and general-purpose use:

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI-compatible structs, FFI |
| Unions | Low | Type punning, hardware registers |
| Bitfields | Medium | Protocol headers, hardware access |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory-efficient structs |
| Array types with length | Medium | Bounds checking |
| Inline functions | Low | Zero-overhead abstractions |
| Preprocessor macros (with args) | Medium | `#define MAX(a,b)` |
| Optimization passes (-O1) | Very High | Performance, kernel boot |
| Code coverage instrumentation | Medium | Compiler-injected line counters |

### cycc — C Compiler Frontend (v2.0+)

Separate tool: C parser → Cyrius codegen. Reuses ELF emitter + fixup.

| Phase | Scope |
|-------|-------|
| 1 | C89 subset |
| 2 | C99/C11 |
| 3 | GCC extensions |
| 4 | Full preprocessor |
| 5 | Object files + linker |
| 6 | Optimization |

### Crate Migration (full roadmap)

| Wave | Crates | Prerequisite |
|------|--------|-------------|
| 1 | agnostik, agnosys, kybernet, nous, ark | **Done** |
| 2 | **bhava**, **hisab** | v1.0 + generics |
| 3 | mudra, vinimaya, taal, natya, kshetra, libro | Closures + derive |
| 4 | sigil | Ownership |
| 5 | kavach, bote, t-ron, nein, majra | Sandbox borrow checker |
| 6 | daimon, hoosh, takumi | Concurrency |
| 7 | aethersafha, agnoshi | All features |

### Polymorphic Codegen

| Tier | Items |
|------|-------|
| 1 | `--poly-seed`, instruction alternatives, semantic NOPs |
| 2 | Register shuffling, block reordering, stack randomization |
| 3 | kavach/seema/sigil/phylax/libro integration |

---

## Milestones

| Milestone | Status |
|-----------|--------|
| **v0.9.0–v0.9.7** — 8 releases (ecosystem → language → tooling) | Done |
| **v0.9.8** — pattern matching, for-in, aarch64 self-hosting on real ARM | Done |
| **v0.9.9** — trait impls, string type, operator overloading | Planned |
| **v0.9.10** — aarch64 self-hosting + kernel port | Planned |
| **v1.0-rc** — hardening, 250+ tests, docs polish | Planned |
| **v1.0** — target: this week (2026-04-06–12) | In progress |
| Wave 2: bhava + hisab ports | After v1.0 |
| Wave 3 crates | After wave 2 |
| cycc Phase 1 (C89 subset) | After all waves |

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
