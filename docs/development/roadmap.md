# Cyrius Development Roadmap

> **Status**: Phase 9 — Multi-Architecture + Phase 8 Tier 1 Complete | **Last Updated**: 2026-04-05
>
> **Achieved**: Self-hosting compiler (29KB seed, 92KB binary, 10ms self-compile),
> 46 programs, 8 stdlib libraries (53 functions), 58KB OS kernel,
> 157 tests, 0 failures. Phase 8 Tier 1 language features complete.
> Zero external dependencies.

---

## Completed

### Phase 0 — Fork & Understand
Forked rust-lang/rust, built rustc from source, mapped cargo registry codepaths.

### Phase 1 — Registry Sovereignty
Ark as default registry, git/path deps first-class, publish validation relaxed.

### Phase 2 — Assembly Foundation
Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e (63 tests) → stage1f (16384 tokens, 256 fns).

### Phase 3 — Self-Hosting Bootstrap
asm.cyr (1110 lines, 43 mnemonics), bootstrap closure, 29KB committed binary. Zero external dependencies. Byte-exact reproducibility.

### Phase 4 — Language Extensions
cc2 modular compiler (7 modules, 182 functions). Structs, pointers, >6 params, load/store 16/32/64, include, inline asm, elif, break/continue, for loops, &&/||, typed pointers, nested structs, global initializers.

### Phase 5 — Prove the Language
46 programs, 157 tests. 10-233x smaller than GNU. wc 2.4x faster.

### Phase 6 — Kernel Prerequisites
All 9 items: typed pointers, nested structs, global inits, for loops, inline asm (18 mnemonics), bare metal ELF, ISR pattern, bitfields, linker control.

### Phase 7 — Kernel (x86_64)
58KB kernel: multiboot1 boot, 32-to-64 shim, serial, GDT, IDT, PIC, PIT timer, keyboard, page tables (16MB), PMM (bitmap), VMM, process table, syscalls.

### Phase 8 — Language Foundations (Tier 1)
7/8 complete: type enforcement (warnings), enums, switch/match, heap allocator, function pointers (&fn_name), argc/argv, String type. Block scoping deferred.

Standard library: 8 libs (string, alloc, str, vec, io, fmt, args, fnptr) — 53 functions.

---

## Active

### Phase 9 — Multi-Architecture (aarch64)

**Goal**: Factor codegen into backends. Port to ARM. Both architectures ready for May 1.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Factor codegen into backend interface | Done | Shared frontend, per-arch emit/jump/fixup |
| 2 | aarch64 emit + jump + fixup | Done | 61 functions, cross-compiler builds |
| 3 | aarch64 instruction correctness | In progress | Fix jmp encoding, get var x = 42 running |
| 4 | aarch64 bootstrap (self-hosting on ARM) | Not started | cc2_aarch64 compiles itself on ARM hardware |
| 5 | aarch64 kernel port | Not started | Same AGNOS kernel, different arch |
| 6 | Cross-compilation | Not started | x86_64 host → aarch64 binaries verified |

---

## Planned — Pre-Release (before May 1)

### Phase 10 — Audit, Refactor, Stabilize

**Goal**: Harden everything built in Phases 2-8. Fix what real usage found.

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | Kernel audit round | High | Memory safety, interrupt correctness, stack overflow protection |
| 2 | Compiler refactor | High | Apply lessons from all phases, clean up codegen paths |
| 3 | Performance pass | Medium | Profile kernel + compiler, optimize hot paths |
| 4 | Test suite expansion | High | Kernel-level tests, stress tests, edge cases |
| 5 | Error message improvement | Medium | Line numbers, source context (not just token index) |
| 6 | Block scoping | Low | Deferred — scope depth + token replay interaction needs investigation |

### Phase 11 — Prove at Scale

**Goal**: Real-world projects in Cyrius. Prove the language handles production code.

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | Migrate Ark package manager | High | First non-kernel project. Proves stdlib + I/O + file handling |
| 2 | AGNOS userland tools | High | Prove the language handles real system code |
| 3 | Benchmark suite vs C/Rust | Medium | Compile times, binary sizes, runtime perf — publishable data |
| 4 | Documentation + tutorials | Medium | Developer onboarding, cyrius-guide.md expansion |

---

## Planned — Post-Release

### Phase 12 — Full Sovereignty

**Goal**: AGNOS builds entirely with Cyrius. No external toolchain in any path.

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | AGNOS builds entirely with Cyrius | High | Both architectures |
| 2 | Full cross-bootstrap | High | x86_64 ↔ aarch64 |
| 3 | No external toolchain in any path | High | The entire stack is owned |
| 4 | agnostik types compile under Cyrius | High | Shared vocabulary migration (see cyrius-lang-migration.md Phase 1) |

### Phase 13 — Polymorphic Codegen

**Goal**: Every deployment unique. Same behavior, different binary. Sovereign defense strategy.

**Tier 1 — Near-term (small effort):**

| # | Item | Effort | Effect |
|---|------|--------|--------|
| 1 | `--poly-seed` flag | Trivial | Deterministic PRNG seed for all randomization. Same seed = same binary (reproducible). Different seed = different binary (polymorphic) |
| 2 | Instruction encoding alternatives | Small | x86_64 has multiple encodings for the same op (mov rax,0 vs xor rax,rax vs mov imm64). Pick randomly per seed |
| 3 | Semantic NOP insertion | Small | Insert benign instructions (xchg rax,rax, lea rax,[rax+0], add rax,0) to vary layout without changing behavior |

**Tier 2 — Medium-term:**

| # | Item | Effort | Effect |
|---|------|--------|--------|
| 4 | Register shuffling | Medium | Randomize free register choices. ABI-constrained regs (rdi, rsi, rax) stay fixed. Free regs shuffle per seed |
| 5 | Basic block reordering | Medium | Dependency analysis to identify independent blocks. Shuffle order per seed. Same result, different layout |
| 6 | Stack layout randomization | Medium | Vary local variable ordering on the stack per seed |

**Tier 3 — Integration:**

| # | Item | Effort | Effect |
|---|------|--------|--------|
| 7 | kavach integration | Small | Sandbox policy includes deployment seed |
| 8 | seema fleet deployment | Small | Unique seed per edge node — every node runs structurally unique binary |
| 9 | sigil attestation | Small | Sign (binary hash + seed) pair — verify specific deployment |
| 10 | phylax discrimination | Medium | Distinguish AGNOS polymorphism from malware polymorphism — whitelist our patterns |
| 11 | libro audit | Small | Log seed → deployment mapping, traceable |

**Why this matters**: An attacker who reverse-engineers one node's binary cannot replay the exploit on any other node. The fleet becomes exploit-proof through diversity, not through patching.

### Phase 14 — Language Maturity (Tier 2)

**Goal**: Scale features for larger codebases.

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Generics / templates | 3 sessions | Type-safe containers, reusable code |
| 2 | Traits / interfaces | 3 sessions | Abstraction, polymorphism |
| 3 | Proper module system (namespace, visibility) | 2 sessions | Large project organization |
| 4 | Array bounds checking (opt-in) | 1 session | Memory safety |
| 5 | Nested function calls in expressions | 1 session | Fix register save across calls |
| 6 | Multi-file compilation | 2 sessions | Beyond textual include |

### Phase 15 — Language Maturity (Tier 3)

**Goal**: Advanced features for the sovereign language vision.

| # | Item | Effort | Unlocks |
|---|------|--------|---------|
| 1 | Ownership / borrow checker | 5+ sessions | Memory safety without GC |
| 2 | Closures / lambdas | 2 sessions | Functional patterns |
| 3 | Iterators | 2 sessions | Clean collection processing |
| 4 | Pattern matching | 2 sessions | Destructuring, exhaustiveness |
| 5 | Concurrency primitives | 3 sessions | Multi-core kernel, parallel apps |
| 6 | Agent/capability annotations | 3 sessions | `#[agent]`, `#[capability]` — Cyrius-native OS constructs |
| 7 | Sandbox-aware borrow checker | 5+ sessions | Compile-time sandbox escape prevention (kavach integration) |

### Phase 16 — AGNOS Crate Migration

**Goal**: Migrate AGNOS crates from Rust to Cyrius following the dependency graph. See `agnosticos/docs/development/cyrius-lang-migration.md` for the full six-phase plan.

| Migration Phase | Crates | Prerequisite |
|----------------|--------|-------------|
| 1 — Prove it | agnostik (shared types), agnosys (syscall bindings) | Phase 8 stdlib ready — enums, structs, io, vec, fmt |
| 2 — Pure computation | mudra, vinimaya, taal, natya, kshetra, science crates, libro | Phase 14 (generics, traits) |
| 3 — System + crypto | sigil, agnosys | Phase 15 (ownership) |
| 4 — Language-native wins | kavach, bote, t-ron, nein, majra | Phase 15.7 (sandbox-aware borrow checker) |
| 5 — The brain | daimon, hoosh, nous, ark, takumi | Phase 15.5 (concurrency) |
| 6 — The interface | aethersafha, agnoshi, kybernet | All phases complete |

---

## Milestone Targets

| Date | Milestone |
|------|-----------|
| **2026-04-04** | ✅ x86_64 kernel complete (VM, processes, syscalls) |
| **2026-04-05** | aarch64 backend started |
| **2026-04-07–09** | aarch64 bootstrap (projected) |
| **2026-04-10–15** | Phase 10 audit + Phase 11 Ark migration |
| **2026-04-15–25** | Phase 10/11 hardening, documentation, benchmarks |
| **2026-05-01** | 🔥 **BELTANE RELEASE** — AGNOS sovereign, both architectures, kernel + compiler + userland |

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
- Documentation (vidya) compounds — 10x implementation speed when patterns are pre-documented
- Tests catch bugs at seams that unit tests miss — build programs, not just test cases
- Defer when research says the cost exceeds the benefit — the work loop is a decision engine
- Polymorphic codegen is defense, not offense — same technique, sovereign purpose

---

*Last Updated: 2026-04-05*
