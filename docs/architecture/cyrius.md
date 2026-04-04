# Cyrius

> Sovereign, self-hosting systems language. Assembly up.

## What It Is

Cyrius is the language. It started as a rustc fork to understand the compiler and strip ecosystem dependencies. What emerged is a self-hosting systems language that owns its entire toolchain — from a 29KB bootstrap binary to a compiler to an assembler — all built from assembly, all ours. Cyrius writes the AGNOS kernel.

The cornerstone is assembly. Cyrius doesn't abstract away the machine — it starts from the primitives and builds upward. You touch the registers, the memory layout, the calling conventions. The language gives you safety on top of that, not instead of it.

## Core Principles

1. **Assembly is the cornerstone** — The language is grounded in machine primitives. Inline assembly, raw memory, register control are first-class, not escape hatches. Safety is layered on top, not in place of understanding.
2. **Self-hosting** — Cyrius compiles Cyrius. No Rust. No Python. No external compiler dependency. The bootstrap requires only a 29KB binary and a shell script.
3. **Sovereignty** — No crates.io. No external governance. The language, compiler, stdlib, and package backend (Ark) are all owned.
4. **Kernel-native** — Cyrius is designed to write operating system kernels. AGNOS will be written in Cyrius. The language understands bare metal, interrupts, page tables — not as afterthoughts but as core use cases.
5. **No external build dependencies** — The bootstrap chain is: committed binary → assembler → compiler. No Python, no cmake, no ninja, no Rust, no LLVM.

## Why Not Just Fork Rust

Rust's compiler bootstrap depends on:
- Python (`x.py`) for build orchestration
- cmake/ninja for LLVM
- A pre-built beta `rustc` downloaded from Rust CI
- Nested git submodules (cargo, LLVM, gcc, etc.)

This means "building Rust from source" actually means "downloading a binary compiler someone else built and using it." That's not sovereignty. Cyrius closes this loop — the language builds itself from a single auditable binary.

## Reference Library: Vidya

[vidya](../../../vidya) (`../vidya`) is the multi-language programming reference library. It contains tested implementations across Rust, C, Python, Go, TypeScript, and Shell — including `compiler_bootstrapping`, `instruction_encoding`, `kernel_topics`, `memory_management`, `concurrency`, and `type_systems`.

Cyrius learns from all of them. Every mistake documented in vidya's gotchas, every cross-language comparison, every performance note — these inform the language design. Vidya is the corpus of what existing languages got right and wrong. Cyrius is the response.

## Lineage

```
Assembly (the cornerstone)
  → cyrius-seed (Rust, archived — used to prove bootstrap correctness)
    → stage1a → stage1b → stage1c → stage1d → stage1e → stage1f
      → asm.cyr (self-hosting assembler, 43 mnemonics)
        → bootstrap closure ✓ (byte-identical output)
          → bootstrap/asm (29KB committed binary — root of trust)
            → stage1f (compiler) + asm (assembler)  ← WE ARE HERE
              → cc.cyr (Phase 4 — language extensions)
                → Cyrius (structs, types, modules, inline asm)
                  → AGNOS kernel
```

## Current State

**Phase 3 is complete.** The bootstrap is fully self-hosting:

```
sh bootstrap/bootstrap.sh

Produces:
  build/stage1f  — compiler (12KB, compiles .cyr high-level language)
  build/asm      — assembler (29KB, assembles .cyr x86_64 assembly)

Requires: Linux x86_64 + /bin/sh. Nothing else.
```

The current language (compiled by stage1f) supports:
- Variables, arrays, functions (6 params, 64 locals)
- if/else, while loops
- Arithmetic: + - * / %
- Bitwise: & | ^ ~ << >>
- syscall(), load8(), store8(), &var
- Hex literals, string literals, comments
- Enough to write a self-hosting assembler (proven)

## Phases

### Phase 0 (Done) — Learn from Rust
- Forked rustc, built it, understood the compiler internals
- Mapped cargo's registry validation codepaths
- Studied vidya's cross-language corpus
- Identified what to keep vs. replace

### Phase 1 (Done) — Registry Sovereignty
- Stripped crates.io from cargo (Ark patches)
- Ark as native package backend
- Git/path deps first-class
- ADR documented

### Phase 2 (Done) — Assembly Foundation
- cyrius-seed: stage 0 assembler (Rust, 69 mnemonics, 195 tests)
- stage1a through stage1f: progressive compiler chain (expressions → control flow → syscalls → functions → bitwise ops → token scaling)
- 378 tests across 6 stages, all passing

### Phase 3 (Done) — Self-Hosting Bootstrap
- asm.cyr: self-hosting assembler (43 mnemonics, 1128 lines, 11 byte-exact matches)
- Bootstrap closure: asm assembles stage1f.cyr, output matches seed
- Committed binary seed (bootstrap/asm, 29KB)
- Rust archived, upstream submodule deinited
- Zero external language dependencies

### Phase 4 (Next) — Language Extensions (Internalized)
Language features added FROM WITHIN — no Rust, no upstream fork.

1. **cc.cyr** — Editable compiler in stage1f's language (self-hosting clone)
2. **Structs** — Composite types, heap-allocated, pass by pointer
3. **Typed pointers** — `*T` syntax, scaled pointer arithmetic
4. **Multi-width load/store** — load16/32/64, store16/32/64 intrinsics
5. **Modules** — `include "file.cyr"` textual include
6. **Inline assembly** — `asm { }` blocks with register bindings
7. **Self-hosting rewrite** — Compiler rewrites itself in its own extended language
8. **Progressive type checking** — Opt-in annotations, warnings not errors
9. **Agent/capability attributes** — `#[agent]`, `#[capability(...)]` as ELF metadata

Progressive hybrid syntax: Cyrius-native first, Rust compatibility later.

### Phase 5 — Kernel
- AGNOS kernel written entirely in Cyrius
- Bare metal from day one — `no_std` is the default
- Interrupts, page tables, device drivers — all in Cyrius
- Agent/capability model enforced by the kernel
- The kernel is the proof that the language works

### Phase 6 — Full Sovereignty
- Cyrius compiles Cyrius from a committed binary seed
- Cyrius stdlib (OS-aware, agent-aware, kernel-aware)
- AGNOS builds entirely with Cyrius
- The entire stack — language, compiler, assembler, package manager, kernel — is owned

## What Stays from Rust (Eventually)

- Ownership + borrow checker (the core safety model)
- Type system concepts (traits, generics, lifetimes)
- Zero-cost abstractions
- `unsafe` as an explicit opt-in

## What's Already Gone

- ~~Python bootstrap (`x.py`)~~ — never needed
- ~~crates.io as default registry~~ — Ark
- ~~Dependency on external governance~~ — sovereign
- ~~Nested submodule build complexity~~ — upstream archived
- ~~Requirement to download a pre-built compiler~~ — bootstrap/asm is the only binary
- ~~Rust as a build dependency~~ — archived, not in any build path
- ~~LLVM~~ — direct x86_64 codegen, no intermediate

## The Bootstrap — From Metal to Language

```
bootstrap/asm (29KB committed binary)
  → assembles stage1f.cyr → stage1f (12KB compiler)
    → compiles asm.cyr → asm_v2 (byte-identical ✓)

Archive: seed (Rust, 2254 lines) — independent verification path
Trust: SHA256 manifest + reproducibility script
```

The seed is small, auditable, and ours. No downloaded binaries. No trust in someone else's CI. The primitives — integers, pointers, registers, memory — are real. They correspond to hardware. The safety system (borrow checker, lifetimes, ownership) will be built *on top of* this reality, not as a replacement for understanding it.

This is what "assembly up" means: the language doesn't hide the machine. It gives you the machine, then helps you not shoot yourself in the foot.
