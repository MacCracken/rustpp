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
    → stage1a → stage1b → stage1c → stage1d → stage1e → cyrc
      → asm.cyr (self-hosting assembler, 43 mnemonics)
        → bootstrap closure ✓ (byte-identical output)
          → bootstrap/asm (29KB committed binary — root of trust)
            → cyrc (compiler) + asm (assembler)
              → cc.cyr → cc3 (modular, 7 modules, 181 fns)
                → 38 programs, 137 tests (Phase 5) ✓
                  → kernel prerequisites (Phase 6) ✓
                    → boot_serial.cyr: "AGNOS" on QEMU  ← WE ARE HERE
                      → AGNOS kernel (Phase 7+)
```

## Current State

**v4.0.0** — cc3 is the active modular compiler (8 modules, 303KB). 36 test suites, 102 regression assertions, 5 fuzz harnesses. 41 stdlib modules + 5 deps. Self-hosting byte-identical on x86_64 + aarch64. `cyrius build` auto-resolves deps + auto-includes from cyrius.toml. 6 downstream projects shipping.

```
sh bootstrap/bootstrap.sh

Produces:
  build/cyrc  — compiler (12KB, compiles .cyr high-level language)
  build/asm      — assembler (29KB, assembles .cyr x86_64 assembly)

Requires: Linux x86_64 + /bin/sh. Nothing else.
```

The current language (compiled by cc3) supports:
- Variables, arrays, functions (unlimited params, 256 locals)
- if/else/elif, while, break/continue, for, for-in, switch (with block bodies), match
- Arithmetic: + - * / %. Bitwise: & | ^ ~ << >>
- syscall(), load8/16/32/64(), store8/16/32/64(), &var
- Structs (64 max, 32 fields), enums (`Enum.VARIANT`), unions, bitfields
- Multi-width types: i8, i16, i32, i64, sizeof()
- Expression-position comparisons: `var r = (a == b)` anywhere
- Native multi-return: `return (a, b)` + `var x, y = fn()` destructuring
- Defer on all exit paths (per-defer runtime flags, unreached defers skipped)
- `#derive(Serialize)` for JSON, `#derive(accessors)` for field getters/setters
- `#assert` compile-time checks, `#ref "file.toml"`, `#ifdef`/`#endif`
- Str/cstr auto-coercion (`: Str` parameter annotations)
- Compile-time string interning (pointer-identity comparison)
- Inline assembly (`asm { }`), inline small functions (token replay)
- 20+ f64 builtins (SSE2/SSE4.1/x87), SIMD vector ops
- Syscall arity warnings, `#skip-lint` directive
- `cyrius deps` — auto-resolve from cyrius.toml, namespaced: `lib/{depname}_{basename}`
- Auto-include: `cyrius build` prepends dep includes before compilation
- 41 stdlib modules + 5 deps, 57+ programs
- Limits: 1MB codebuf, 262K tokens, 16384 fixups, 512KB input, 256KB str_data
- Heap: 14.8MB (brk 0xECA000), aarch64 synced to x86

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
- stage1a through cyrc: progressive compiler chain (expressions → control flow → syscalls → functions → bitwise ops → token scaling)
- 378 tests across 6 stages, all passing

### Phase 3 (Done) — Self-Hosting Bootstrap
- asm.cyr: self-hosting assembler (43 mnemonics, 1128 lines, 11 byte-exact matches)
- Bootstrap closure: asm assembles cyrc.cyr, output matches seed
- Committed binary seed (bootstrap/asm, 29KB)
- Rust archived, upstream submodule deinited
- Zero external language dependencies

### Phase 4 (Done) — Language Extensions
Language features added FROM WITHIN — no Rust, no upstream fork.

- cc.cyr → cc3 modular self-hosting compiler (7 modules, 150 functions)
- Structs, pointers (*deref, *store), >6 params, load/store 16/32/64
- Include directive, inline asm (raw bytes), progressive type annotations
- elif, break/continue, duplicate var detection, error messages with token position
- Self-hosting: cc3==cc3 byte-identical, 94 tests

### Phase 5 (Done) — Prove the Language
- 38 programs (CLI tools + proof programs), 137 tests
- &&/||, for loops, typed pointers, nested structs, global initializers
- String stdlib, bootstrap repair, capacity expansions
- Buffered I/O (wc 2.4x faster than GNU), 10-233x smaller binaries

### Phase 6 (Done) — Kernel Prerequisites
All 9 items complete:
- Inline asm with 18 kernel mnemonics (cli, sti, mov crN, lgdt, lidt, iretq, etc.)
- Bare metal ELF: `kernel;` directive, multiboot1 header, 32-bit ELF, base 0x100000
- Typed pointers, nested structs, global initializers, for loops
- Bitfield access (PTE/GDT/IDT), linker control, ISR save/restore pattern

### Phase 7 — Kernel (x86_64)
- Compile the Linux kernel with Cyrius — the proof that the language handles real kernel code
- Boot the AGNOS kernel — hello from Cyrius
- Multiboot2, serial console, GDT/IDT, page tables, timer/keyboard interrupts
- Physical + virtual memory managers, process/task abstraction
- Syscall interface, agent/capability enforcement
- Initial kernel boot — full-featured AGNOS continues beyond Phase 11

### Phase 8 — Audit, Refactor, Stabilize
- Kernel audit round (memory safety, interrupt correctness, edge cases)
- Compiler refactor (apply lessons from kernel development)
- Performance pass, test suite expansion

### Phase 9 — Multi-Architecture (aarch64)
- Factor codegen into backend interface (shared lexer/parser, per-arch emission)
- aarch64 assembler + codegen + bootstrap
- aarch64 kernel port, cross-compilation

### Phase 10 — Prove at Scale
- Migrate Ark package manager to Cyrius
- AGNOS userland tools
- Benchmark suite vs C/Rust, language ergonomics pass
- Documentation + tutorials

### Phase 11 — Full Sovereignty
- AGNOS builds entirely with Cyrius on both architectures
- Full cross-bootstrap (x86_64 ↔ aarch64)
- No external toolchain in any path — the entire stack is owned

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
  → assembles cyrc.cyr → cyrc (12KB compiler)
    → compiles asm.cyr → asm_v2 (byte-identical ✓)

Archive: seed (Rust, 2254 lines) — independent verification path
Trust: SHA256 manifest + reproducibility script
```

The seed is small, auditable, and ours. No downloaded binaries. No trust in someone else's CI. The primitives — integers, pointers, registers, memory — are real. They correspond to hardware. The safety system (borrow checker, lifetimes, ownership) will be built *on top of* this reality, not as a replacement for understanding it.

This is what "assembly up" means: the language doesn't hide the machine. It gives you the machine, then helps you not shoot yourself in the foot.
