# Cyrius

> Sovereign, self-hosting systems language. Assembly up.

## What It Is

Cyrius is the language. Rust++ was the working name — a fork of rustc to understand the compiler and strip ecosystem dependencies. Cyrius is what comes after: a self-hosting systems language that owns its entire toolchain, from bootstrap to package management — and writes the AGNOS kernel.

The cornerstone is assembly. Cyrius doesn't abstract away the machine — it starts from the primitives and builds upward. You touch the registers, the memory layout, the calling conventions. The language gives you safety on top of that, not instead of it.

## Core Principles

1. **Assembly is the cornerstone** — The language is grounded in machine primitives. Inline assembly, raw memory, register control are first-class, not escape hatches. Safety is layered on top, not in place of understanding.
2. **Self-hosting** — Cyrius compiles Cyrius. No Python bootstrap. No external compiler dependency once bootstrapped.
3. **Sovereignty** — No crates.io. No external governance. The language, compiler, stdlib, and package backend (ark) are all owned.
4. **Rust-compatible** — Existing Rust code compiles unchanged. Cyrius is a superset, not a replacement. The type system and borrow checker are correct — we keep them.
5. **Kernel-native** — Cyrius is designed to write operating system kernels. AGNOS will be written in Cyrius. The language understands `no_std`, bare metal, interrupts, page tables — not as afterthoughts but as core use cases.
6. **No external build dependencies** — The compiler bootstrap chain is: assembly seed → stage 0 → stage 1 → full Cyrius. No Python, no cmake, no ninja in the final toolchain.

## Why Not Just Fork Rust

Rust's compiler bootstrap depends on:
- Python (`x.py`) for build orchestration
- cmake/ninja for LLVM
- A pre-built beta `rustc` downloaded from Rust CI
- Nested git submodules (cargo, LLVM, gcc, etc.)

This means "building Rust from source" actually means "downloading a binary compiler someone else built and using it." That's not sovereignty. Cyrius closes this loop — the language builds itself.

## Reference Crate: Vidya

[vidya](../../) (`../vidya`) is the multi-language programming reference library. It contains tested implementations across Rust, C, Python, Go, TypeScript, and Shell — including `kernel_topics`, `memory_management`, `concurrency`, and `type_systems`.

Cyrius learns from all of them. Every mistake documented in vidya's gotchas, every cross-language comparison, every performance note — these inform the language design. Vidya is the corpus of what existing languages got right and wrong. Cyrius is the response.

## Lineage

```
Assembly (the cornerstone)
  |
rust-lang/rust (upstream -- learn the type system, borrow checker)
  +-- Rust++ (fork, Phase 0-1: understand + strip crates.io)
       +-- cyrius-seed (stage 0 -- assembler, 42 instructions)
            +-- stage1a/1b (expressions, control flow) <-- WE ARE HERE
                 +-- stage1c/1d (memory, syscalls, functions)
                      +-- Cyrius (self-hosting, sovereign, kernel-native)
                           +-- AGNOS kernel
```

## Phases

### Phase 0 (Current) — Learn from Rust
- Fork rustc, build it, understand the compiler internals
- Map cargo's registry validation codepaths
- Study vidya's cross-language corpus — what works, what doesn't, across all languages
- Identify what to keep (type system, borrow checker, codegen) vs. what to replace (bootstrap, ecosystem governance)

### Phase 1 — Registry Sovereignty
- Strip crates.io from cargo
- ark as native package backend
- Git/path deps are first-class

### Phase 2 — Assembly Foundation
- Define the Cyrius assembly layer — inline asm, intrinsics, register-level primitives
- Primitives are not abstract — they map to machine reality (integers are register-width, pointers are addresses)
- Write the seed: a minimal assembler/compiler in assembly that can bootstrap stage 0
- This is the bottom of the stack. Everything else builds on this.

### Phase 3 — Self-Hosting Bootstrap
- Stage 0 (from assembly seed) compiles stage 1
- Stage 1 compiles the full Cyrius compiler
- Eliminate Python, cmake, ninja from the toolchain
- The assembly seed is the only external artifact — and it's ours

### Phase 4 — Language Extensions
- Agent types as language primitives
- Capability annotations
- Sandbox-aware borrow checker
- OS-native IPC types

### Phase 5 — Kernel
- Cyrius writes the AGNOS kernel
- Bare metal from day one — `no_std` is the default, `std` is the extension
- Interrupts, page tables, device drivers — all in Cyrius with full safety where possible, explicit `unsafe` where necessary
- The kernel is the proof that the language works

### Phase 6 — Full Sovereignty
- Cyrius compiles Cyrius from an assembly seed
- Cyrius stdlib (OS-aware, agent-aware, kernel-aware)
- AGNOS builds entirely with Cyrius

## What Stays from Rust

- Ownership + borrow checker
- Type system (traits, generics, lifetimes)
- Zero-cost abstractions
- `unsafe` as an explicit opt-in
- LLVM codegen (initially — backend may change later)

## What Goes

- Python bootstrap (`x.py`)
- crates.io as default registry
- Dependency on external governance (Rust Foundation, crates.io policies)
- Nested submodule build complexity
- Requirement to download a pre-built compiler to build the compiler
- The illusion that you don't need to understand the machine

## Assembly Process — The Cornerstone

Cyrius starts where every real systems language must: at the metal.

The **assembly process** is the foundation of the bootstrap chain:

```
hand-written assembly seed (x86_64, aarch64)
  → minimal Cyrius stage 0 compiler
    → full Cyrius stage 1 compiler
      → Cyrius compiles Cyrius
        → Cyrius compiles the AGNOS kernel
```

The seed is small, auditable, and ours. No downloaded binaries. No trust in someone else's CI. The primitives — integers, pointers, registers, memory — are real. They correspond to hardware. The safety system (borrow checker, lifetimes, ownership) is built *on top of* this reality, not as a replacement for understanding it.

This is what "touching the primitives" means: the language doesn't hide the machine. It gives you the machine, then helps you not shoot yourself in the foot.
