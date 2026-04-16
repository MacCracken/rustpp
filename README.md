# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python, no libc. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

~373KB compiler. Self-hosting on x86_64 and aarch64. 41 stdlib modules + 5 deps. 51 test suites (396 assertions), 5 fuzz harnesses, 11 benchmarks.

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
- Constant folding, dead store elimination, tail call optimization, jump tables
- `#derive(Serialize)` for JSON serialization, `#derive(accessors)` for field getters/setters
- `#ref "file.toml"` directive for TOML config loading
- Native multi-return: `return (a, b)` + `var x, y = fn()` destructuring
- Switch case blocks: `case N: { ... }` with scoped variables
- Defer on all exit paths (per-defer runtime flags, unreached defers skipped)
- Str/cstr auto-coercion, compile-time string interning, `#assert`
- Expression-position comparisons: `var r = (a == b)` works everywhere
- Inline small functions (token replay), relaxed fn ordering
- Include-once semantics, inline assembly (`asm { }`)

### Metrics

| Metric | Value |
|--------|-------|
| Compiler | **~373KB** x86_64, **268KB** aarch64 cross |
| Self-compile | ~74ms (full), ~11ms (bridge) |
| Seed binary | **29KB** |
| External dependencies | **0** |
| Tests | 51 .tcyr suites (396 assertions), 5 .fcyr fuzz, 11 .bcyr bench |
| Architectures | x86_64 + aarch64 (byte-identical self-hosting) |
| Limits | 1MB codebuf, 128KB tok_names, 4096 fns, 8192 vars, 262K tokens, 16384 fixups, 64 structs |

## Build Tool (cyrius)

```
Build:     build [-v] [--aarch64] [-D NAME], run, test, bench, check, self, clean
Deps:      deps — resolve [deps] from cyrius.toml into lib/ (auto-runs on build)
Project:   init, package, publish, install, update, port
Quality:   audit, fmt, lint, doc, vet, deny
Testing:   coverage, doctest
Info:      version, which, help
```

Dependencies declared in `cyrius.toml` are auto-resolved on `build`/`run`/`test`:

```toml
[deps]
stdlib = ["string", "fmt", "alloc", "io", "vec", "str"]

[deps.agnostik]
path = "../agnostik"
modules = ["src/types.cyr", "src/error.cyr"]
```

Named deps are namespaced: `lib/{depname}_{basename}` (e.g. `lib/agnostik_types.cyr`).
Includes are auto-prepended — source files only need project-specific includes.

## Standard Library (41 modules + 5 deps)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged (Option/Result), hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread (clone+mmap, mutex, MPSC), async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log (structured, over sakshi) |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, cffi |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda |

## Compiler Architecture

```
src/
  main.cyr              Entry point (orchestration, passes)
  main_aarch64.cyr      Cross-compiler entry
  bridge.cyr            Bridge compiler (cyrc feature set)

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
  -> cyrc (12KB compiler)
    -> bridge.cyr (bridge compiler)
      -> cc5 (modular compiler + IR, 408KB, 9 modules)
        -> cc5_aarch64 (cross-compiler)
```

## Migration

108 Rust repos (~1M lines) planned for conversion. 16 done (see [roadmap](docs/development/roadmap.md) — Ports & Ecosystem). `cyrius port` scaffolds Cyrius projects from Rust repos. See [migration strategy](docs/development/migration-strategy.md).

## License

GPL-3.0-only
