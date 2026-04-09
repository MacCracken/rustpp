# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python, no libc. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

215KB compiler. Self-hosting on x86_64 and aarch64. 31 stdlib modules. 13 test suites, 0 failures.

## Install

```sh
curl -sSf https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh | sh
```

Or build from source:

```sh
sh bootstrap/bootstrap.sh
```

## Quick Start

```sh
# Compile and run
cyrius run hello.cyr

# Create a project
cyrius init myproject
cd myproject
cyrius build src/main.cyr build/myproject

# Port a Rust project
cyrius port /path/to/rust-project

# Full audit (format, lint, vet, deny, test, bench, doc)
cyrius audit
```

## Language

```cyrius
include "lib/alloc.cyr"
include "lib/str.cyr"
include "lib/vec.cyr"

struct Point { x; y; }

impl Math for Point {
    fn sum(self) { return load64(self) + load64(self + 8); }
}

fn Point_add(a, b) {
    store64(a, load64(a) + load64(b));
    store64(a + 8, load64(a + 8) + load64(b + 8));
    return a;
}

enum Result { Ok(val) = 0; Err(code) = 1; }

fn main() {
    alloc_init();
    var a = Point { 1, 2 };
    var b = Point { 3, 4 };
    Point_add(&a, &b);
    return Point_sum(&a);
}

var r = main();
syscall(60, r);
```

### Features

- Structs, enums (`Enum.VARIANT` namespacing), match, for-in, closures, impl blocks
- 20+ f64 builtins (add/sub/mul/div + sin/cos/exp/ln/log2/exp2/sqrt/abs/floor/ceil + atan)
- Constant folding for all arithmetic operators
- Dead code elimination, tail call optimization, jump tables for dense switches
- `#derive(Serialize)` for auto-generated JSON serialization
- `#ref "file.toml"` directive for TOML config loading
- Return-by-value: `ret2(a,b)` and `rethi()` builtins
- Inline small functions (token replay), R12 register spill
- Relaxed fn ordering (functions can appear after statements)
- Include-once semantics (duplicate includes silently skipped)
- Inline assembly (`asm { }`)

### Metrics

| Metric | Value |
|--------|-------|
| Compiler | **215KB** (x86_64) |
| Self-compile | ~74ms (full), ~11ms (bridge) |
| Seed binary | **29KB** |
| External dependencies | **0** |
| Tests | 13 .tcyr suites (139 assertions), 3 .fcyr fuzz harnesses, 57 programs |
| Architectures | x86_64 + aarch64 (byte-identical self-hosting) |

## Build Tool (cyrius)

```
Build:     build, run, test, bench, check, self, clean
Project:   init, package, publish, install, update, port
Quality:   audit, fmt, lint, doc, vet, deny
Testing:   coverage, doctest
Docs:      docs [--agent], header
Interactive: repl
Info:      version, which, help
```

## Standard Library (31 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged (Option/Result), hashmap, trait, assert, bounds |
| System | syscalls (50 wrappers), callback, process, bench |
| Concurrency | thread (clone+mmap, mutex, MPSC), async |
| Allocators | freelist (O(1) alloc/free) |
| Math | math (f64_atan, extended ops) |
| Data | json, toml, fs, net, regex, matrix, vidya |
| Tracing | sakshi (minimal), sakshi_full (structured logging) |

## Compiler Architecture

```
src/
  main.cyr              Entry point (orchestration, passes)
  main_aarch64.cyr      Cross-compiler entry
  bridge.cyr            Bridge compiler (stage1f feature set)

  frontend/
    lex.cyr             Lexer + preprocessor (include-once, #derive, #ifdef)
    parse.cyr           Parser + codegen dispatch

  backend/x86/
    emit.cyr            x86_64 instruction emission
    float.cyr           SSE2/SSE4.1/x87 float ops
    jump.cyr            Jump/patch helpers
    fixup.cyr           Address fixup + ELF emission

  backend/aarch64/      (same structure as x86)

  common/
    util.cyr            State accessors, error functions
```

### Bootstrap Chain

```
bootstrap/asm (29KB committed binary -- root of trust)
  -> stage1f (12KB compiler)
    -> bridge.cyr (bridge compiler)
      -> cc2 (modular compiler, 215KB, 8 modules)
        -> cc2_aarch64 (cross-compiler)
```

## Migration

108 Rust repos (~1M lines) planned for conversion. 5 done. `cyrius port` scaffolds Cyrius projects from Rust repos. See [migration strategy](docs/development/migration-strategy.md).

## License

GPL-3.0-only
