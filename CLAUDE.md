# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Status**: Phase 7 started — AGNOS boots on QEMU. 38 programs, 137 tests, 181 functions.

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Ark is the package backend. Names belong to builders. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — the root of trust)
  → assembles stage1f.cyr → stage1f (12KB compiler)
    → compiles asm.cyr → asm_v2 (byte-identical ✓)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

### Historical chain (how we got here)
```
stage1a (expressions) → stage1b (control flow) → stage1c (syscalls)
  → stage1d (functions) → stage1e (bitwise ops) → stage1f (token-scaled)
    → asm.cyr (self-hosting assembler) → bootstrap closure ✓
```

## Project Structure

- `bootstrap/` — Root of trust: committed asm binary + bootstrap scripts
- `stage1/` — Compiler stages (.cyr assembly) + self-hosting assembler (asm.cyr)
- `build/` — Generated binaries (gitignored, created by bootstrap.sh)
- `archive/seed/` — Historical Rust seed (for verification only, not needed to build)
- `docs/architecture/` — Cyrius spec, cargo codepath analysis, ADRs
- `docs/development/` — Roadmap, process notes

## Key References

- `docs/architecture/cyrius.md` — Language vision and phases
- `docs/architecture/cargo-codepaths.md` — Surgical map of crates.io in cargo
- `docs/architecture/adr/001-registry-sovereignty.md` — Ark patches ADR
- `../vidya` — Multi-language reference corpus (compiler bootstrapping, binary formats)
- `../ark` — AGNOS unified package manager

## Development Process

### Phase 0: Fork & Build (Done)
1. Fork rust-lang/rust ✓
2. Build rustc from source ✓
3. Map cargo registry resolution codepaths ✓
4. Map `cargo publish` validation pipeline ✓
5. Document findings ✓

### Phase 1: Registry Sovereignty (Done)
1. Ark constants added to cargo ✓
2. Default registry changed to Ark ✓
3. Git/path deps allowed for non-crates.io registries ✓
4. `publish = false` deps skip version requirement ✓
5. ADR documented ✓

### Phase 2: Assembly Foundation (Done)
1. cyrius-seed — stage 0 assembler ✓
2. stage1a — expression evaluator compiler ✓
3. stage1b — control flow (if/else, while) ✓
4. stage1c — memory + syscalls ✓
5. stage1d — functions ✓
6. stage1e — bitwise ops, self-hosting capacity ✓
7. stage1f — token-scaled compiler (16384 slots) ✓

### Phase 3: Self-Hosting Bootstrap (Done)
1. asm.cyr — self-hosting assembler (43 mnemonics, 11 byte-exact matches) ✓
2. Bootstrap closure — asm assembles stage1f, output matches seed ✓
3. Committed asm binary as root of trust (bootstrap/asm) ✓
4. Rust seed archived, no longer in build path ✓
5. No Rust, no LLVM, no Python in any build path ✓

### Phase 4: Language Extensions (Done)
1. cc.cyr → cc2 modular self-hosting compiler (7 modules, 150 functions) ✓
2. Structs, pointers, >6 params, load/store 16/32/64 ✓
3. Include, inline asm, elif, break/continue, type annotations ✓
4. Duplicate var detection, error messages with token position ✓
5. Self-hosting: cc2==cc3 byte-identical, 94 tests ✓

### Phase 5: Prove the Language (In Progress)
1. 15 Linux programs ✓, benchmarks ✓
2. Codegen bug investigated — not a bug ✓
3. Logical &&/||, for loops, typed pointers, nested structs, global initializers ��
4. Bootstrap repair, codebuf/input buffer expansion ✓
5. 38 programs (19 CLI + 8 proof), 137 tests ✓
6. Migrate Ark to Cyrius — first real-world project

### Phase 6: Kernel Prerequisites (COMPLETE)
All 9 items done: typed pointers, nested structs, global initializers, for loops,
inline asm (18 mnemonics), bare metal ELF (multiboot1, 32-bit ELF), bitfields,
linker control, ISR save/restore pattern.

### Phase 7: Kernel (x86_64) (STARTED)
- boot_serial.cyr: 240-byte kernel boots on QEMU, prints "AGNOS" to serial ✓
- Next: serial console, GDT/IDT, 32-to-64 shim, page tables, interrupts
4. Initial boot — full-featured AGNOS continues beyond Phase 11

### Phase 8: Audit + Refactor
1. Clean up from kernel learnings

### Phase 9: Multi-Architecture (aarch64)
1. Factor codegen, port kernel

### Phase 10: Prove at Scale
1. Migrate Ark + AGNOS projects to Cyrius

### Phase 11: Full Sovereignty
1. AGNOS builds entirely with Cyrius on x86_64 + aarch64

## Key Principles

- **Assembly is the cornerstone** — primitives map to machine reality
- **Own the toolchain** — compiler, stdlib, package manager, build system
- **No external language dependencies** — bootstrap from a single committed binary
- **Every extension is built from within** — no forking someone else's compiler
- **Byte-exact testing** — the gold standard for compiler correctness
- **Every divergence gets an ADR** — no undocumented changes

## Development Loop

Every feature follows this cycle. Skipping steps costs more time than it saves.

```
1. RESEARCH    — Check vidya for existing patterns. If covered, skip to 3.
2. VIDYA       — Document patterns, gotchas, codegen BEFORE coding.
3. BUILD       — ONE change at a time. Before compiling, check:
                 ☐ Duplicate var scan (python3 scanner)
                 ☐ Brace balance (tr -cd '{}' | awk)
                 ☐ Bridge compiler supports syntax used in source
                 ☐ Heap offset map (no collisions — see cc2.cyr header)
4. TEST        — After EACH change, not after the feature:
                 ☐ Basic: 'var x = 42;' → 42
                 ☐ Feature-specific test case
                 ☐ Reconverge: cc2==cc3 byte-identical
                 ☐ Full suite only after basic passes
5. IF BROKEN   — Revert to last known good (git checkout).
                 Apply ONE change. Test. Repeat.
                 If 3 attempts fail: defer, document root cause, move on.
6. AUDIT       — Full chain: bootstrap, all suites, self-hosting, SHA256.
7. VIDYA+DOCS  — Document findings: bugs, gotchas, metrics, deferred items.
                 Update: changelog, roadmap, README, benchmarks.
8. ALIGN       — After every major phase event (feature shipped, phase complete,
                 milestone hit): align ALL docs to current state.
                 ☐ README.md (status table, test counts, features)
                 ☐ CLAUDE.md (phase statuses, metrics)
                 ☐ roadmap.md (phase items, done/in-progress markers)
                 ☐ cyrius.md (current state, lineage, phase descriptions)
                 ☐ benchmarks.md (test counts, program counts)
                 ☐ CHANGELOG.md (unreleased section accurate)
                 ☐ process-notes.md (metrics, phase header)
                 Numbers drift fast. One pass catches all of them.
```

**Why this works:** Vidya front-loads thinking — pointers took 15 lines because the pattern existed. Building programs is the best compiler fuzzer — the VCNT bug, data layout bug, and bridge compiler bug were all found by programs, not test cases. One-step-at-a-time debugging found break/continue's heap collision in 2 minutes.

**Key lessons:**
- `var x = fn(); return x;` works correctly (investigated — not a codegen bug, was a testing artifact)
- Bridge compiler (build/cc) determines what syntax source files can use
- Test after EVERY change, not after the feature is "done"
- 3 failed attempts = defer and document, don't keep hammering

**Reference library:** `../vidya` — 78+ entries in compiler_bootstrapping alone. Check it FIRST.

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add language features without an ADR (architectural decision record)
