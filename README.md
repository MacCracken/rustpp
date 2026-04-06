# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python, no libc. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

136KB compiler. Self-hosting on x86_64 and aarch64. 263 tests, 0 failures.

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

    # Structs + methods + operators
    var a = Point { 10, 20 };
    var b = Point { 32, 22 };
    var c = a + b;

    # Strings with methods
    var s: Str = str_from("hello world");
    var len = s.len();

    # Pattern matching
    var r = Ok(42);
    match load64(r) {
        0 => { return load64(r + 8); }
        _ => { return 0; }
    }
    return 0;
}
var exit_code = main();
syscall(60, exit_code);
```

### Features

- **Types**: structs, enums (with data), tagged unions (Option/Result)
- **OOP**: methods on structs, trait impl blocks, operator overloading (+, -, *, /)
- **Control flow**: if/elif/else, while, for, for-in (range + collections), match, switch, break/continue
- **Functions**: closures/lambdas, function pointers, >6 params, recursion
- **Modules**: mod/use/pub, feature flags (#define/#ifdef)
- **Types**: f64 floating point (SSE2), string type with 16 methods
- **System**: inline asm, raw syscalls, 50+ syscall wrappers
- **Generics**: syntax parsed (Phase 1), everything is i64

### Metrics

| Metric | Value |
|--------|-------|
| Compiler | **136KB** (x86_64), 130KB (aarch64) |
| Self-compile | ~11ms |
| Seed binary | **29KB** |
| External dependencies | **0** |
| Tests | **263** (0 failures) |
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

## Architecture

```
bootstrap/asm (29KB committed binary — root of trust)
  → stage1f (12KB compiler)
    → cc_bridge.cyr (bridge compiler)
      → cc2 (modular compiler, 139KB, 7 modules)
        → cc2_aarch64 (cross-compiler)
```

## Migration

107 Rust repos (~980K lines) planned for conversion. 5 done. `cyrb port` scaffolds Cyrius projects from Rust repos. See [migration strategy](docs/development/migration-strategy.md).

## License

GPL-3.0-only
