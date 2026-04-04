# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Status**: Phase 4 — Language extensions. No external language dependencies.

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

### Phase 4: Language Extensions (Internalized)
1. cc.cyr — editable compiler in stage1f's language (self-hosting clone)
2. Structs / composite types
3. Typed pointers + multi-width load/store
4. Module system (include)
5. Inline assembly
6. Self-hosting rewrite in extended language
7. Progressive type checking
8. Agent/capability attributes

### Phase 5: Multi-Architecture
1. Factor codegen into backend interface (shared parser, per-arch emission)
2. aarch64 assembler + codegen backend + bootstrap binary
3. Cross-compilation support

### Phase 6: Kernel
1. Cyrius writes the AGNOS kernel
2. Bare metal, interrupts, page tables — all in Cyrius

### Phase 7: Prove the Language
1. Migrate Ark + AGNOS projects to Cyrius
2. Benchmark suite (compile times, binary sizes, runtime perf)
3. Language ergonomics pass

### Phase 8: Full Sovereignty
1. AGNOS builds entirely with Cyrius on x86_64 + aarch64
2. No external toolchain in any path

## Key Principles

- **Assembly is the cornerstone** — primitives map to machine reality
- **Own the toolchain** — compiler, stdlib, package manager, build system
- **No external language dependencies** — bootstrap from a single committed binary
- **Every extension is built from within** — no forking someone else's compiler
- **Byte-exact testing** — the gold standard for compiler correctness
- **Every divergence gets an ADR** — no undocumented changes

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add language features without an ADR (architectural decision record)
