# Cyrius Development Roadmap

> **Current**: v0.9.8 — pattern matching, for-in, aarch64 native on real ARM
>
> 120KB compiler (x86), 110KB (aarch64 cross), 57 programs, 8 tools.
> 196 tests (145 compiler + 51 programs) + 26 aarch64 (qemu), 0 failures.
> aarch64 cc3 runs natively on Raspberry Pi. SYS_* portable syscall constants.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Release Plan to v1.0

### v0.9.9 — Language: Traits + Strings + Operator Overloading

| Feature | Effort | Approach |
|---------|--------|---------|
| **Trait impl blocks** | Medium | `impl Display for Point { }` → name mangling `Point_Display_format` |
| **String type** | Medium | Length-prefixed heap block, `s"hello"` literal syntax |
| **Operator overloading** | Low | `+` `-` `*` `/` dispatch to `Type_add(a, b)` when struct typed |

### v0.9.10 — aarch64: Byte-Identical Self-Hosting

| Task | Status |
|------|--------|
| cc3 runs natively on ARM | **Done** |
| cc3 compiles simple programs | **Done** |
| cc4 byte-identical to cc3 | Pending (write buffer issue on large output) |
| aarch64 kernel port | Planned |

### v1.0-rc — Hardening + Polish

| Task | Detail |
|------|--------|
| P-1 hardening | Audit all 35 lib modules |
| Test expansion | Target 250+ tests |
| Benchmark baseline | Full bench-history run |
| Documentation audit | All docs current |
| Vidya sync | All features have entries |
| CI green | All jobs pass |

### v1.0

**Definition of done:**
- Self-hosting compiler (x86_64 verified, aarch64 native runs)
- AGNOS kernel boots
- Complete developer toolchain (20+ cyrb commands)
- Pattern matching, for-in, modules, methods, floats, block scoping, feature flags
- 250+ tests, 0 failures
- All documentation current

---

## Post-v1.0

### Crate Migration Wave 2

| Crate | LOC | Key Requirement |
|-------|-----|----------------|
| **bhava** | 29K | Traits, iterators, strings, generics |
| **hisab** | 31K | Floats (done), operator overloading, const generics |

### Language Features (v1.1–v2.0)

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
| **v0.9.0–v0.9.7** — ecosystem, language features, tooling | Done |
| **v0.9.8** — pattern matching, for-in, aarch64 native on real ARM | Done |
| **v0.9.9** — traits, strings, operator overloading | Next |
| **v0.9.10** — aarch64 byte-identical self-hosting | Planned |
| **v1.0** — target: this week | In progress |

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
- Portable syscall constants (SYS_*) for cross-architecture compilation
