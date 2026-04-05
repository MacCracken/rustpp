# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

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
cyrb test src/test.cyr

# Full project audit (format, lint, vet, deny, test, bench, doc)
cyrb audit
```

## Benchmarks

| Metric | Value |
|--------|-------|
| Self-compile (94KB compiler) | **11ms** |
| Full bootstrap (from 29KB seed) | **40ms** |
| Binary sizes vs GNU coreutils | **10-233x smaller** |
| External dependencies | **0** |

See [full benchmarks](docs/benchmarks.md).

## Documentation

- [Getting Started](docs/tutorial.md) — install, hello world, first project
- [Language Guide](docs/cyrius-guide.md) — complete syntax reference
- [Standard Library](docs/stdlib-reference.md) — every function documented
- [FAQ & Troubleshooting](docs/faq.md) — common questions and fixes
- [Benchmarks](docs/benchmarks.md) — sizes, compile times, runtime

## Language

Everything is a 64-bit integer. No floats, no GC. Direct syscalls.

```
include "lib/string.cyr"
include "lib/tagged.cyr"

fn divide(a, b) {
    if (b == 0) { return Err(1); }
    return Ok(a / b);
}

fn main() {
    alloc_init();
    var r = divide(42, 2);
    if (is_ok(r) == 1) {
        print_num(result_unwrap(r));
        println("");
    }
    return 0;
}
```

**Features**: variables, arrays, structs, enums, generics syntax, tagged unions (Option/Result), traits (vtable dispatch), functions, if/elif/else, while, for, break/continue, `&&`/`||`, pointers, typed pointers, inline asm, switch/match, function pointers, syscalls, comparison expressions.

## Build Tool (cyrb)

```
Build:     build, run, test, bench, check, self, clean
Project:   init, package, publish, install, update
Quality:   audit, fmt, lint, doc, vet, deny
Info:      version, which, help
```

## Standard Library (35 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged (Option/Result/Either), hashmap, trait, assert, bounds |
| System | agnosys (50 syscalls), callback, process, bench |
| Ecosystem | agnostik (6), kybernet (7), nous, json, fs, net, regex |

## Tools

| Tool | What |
|------|------|
| cc2 / cc2_aarch64 | Compiler (x86_64 + aarch64 cross) |
| cyrb | Build tool (18 commands — like cargo) |
| cyrfmt | Code formatter |
| cyrlint | Linter (style, warnings) |
| cyrdoc | Documentation generator + coverage check |
| cyrc | Dependency audit + policy enforcement |
| ark | Package manager |

## Quality Gate

`cyrb audit` runs 10 checks in one command:

```
✓ Self-hosting      ✓ Compiler tests (111)   ✓ Program tests (57)
✓ Format            ✓ Lint                    ✓ Vet
✓ Deny              ✓ Benchmarks             ✓ Doc coverage
✓ Documentation
```

## Part of AGNOS

Cyrius is the language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only
