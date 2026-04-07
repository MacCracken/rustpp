# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python, no libc. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

164KB compiler. Self-hosting on x86_64 and aarch64. 267 tests, 0 failures.

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
cyrb run hello.cyr

# Create a project
cyrb init myproject
cd myproject
cyrb build src/main.cyr build/myproject

# Port a Rust project
cyrb port /path/to/rust-project

# Full audit (format, lint, vet, deny, test, bench, doc)
cyrb audit
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

- Structs, enums, match, for-in, closures, impl blocks
- 20 f64 builtins (add/sub/mul/div + sin/cos/exp/ln/log2/exp2/sqrt/abs/floor/ceil)
- Constant folding for all arithmetic operators
- Dead code elimination, tail call optimization, jump tables for dense switches
- `#derive(Serialize)` for auto-generated JSON serialization
- Include-once semantics (duplicate includes silently skipped)
- Inline assembly (`asm { }`)

### Metrics

| Metric | Value |
|--------|-------|
| Compiler | **164KB** (x86_64) |
| Self-compile | ~11ms |
| Seed binary | **29KB** |
| External dependencies | **0** |
| Tests | **267** (216 compiler + 51 programs, 0 failures) |
| Architectures | x86_64 + aarch64 (byte-identical self-hosting) |

## Build Tool (cyrb)

```
Build:     build, run, test, bench, check, self, clean
Project:   init, package, publish, install, update, port
Quality:   audit, fmt, lint, doc, vet, deny
Testing:   coverage, doctest
Docs:      docs [--agent], header
Interactive: repl
Info:      version, which, help
```

## Standard Library (21 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged (Option/Result), hashmap, trait, assert, bounds |
| System | syscalls (50 wrappers), callback, process, bench |
| Data | json, fs, net, regex |

## Compiler Architecture (v1.8.0)

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
      -> cc2 (modular compiler, 164KB, 8 modules)
        -> cc2_aarch64 (cross-compiler)
```

## Migration

108 Rust repos (~1M lines) planned for conversion. 5 done. `cyrb port` scaffolds Cyrius projects from Rust repos. See [migration strategy](docs/development/migration-strategy.md).

## License

GPL-3.0-only
