# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

## Quick Start

```sh
# Bootstrap (40ms, requires only Linux x86_64 + /bin/sh)
sh bootstrap/bootstrap.sh

# Build the compiler
cat stage1/cc2.cyr | ./build/stage1f > ./build/cc2 && chmod +x ./build/cc2

# Compile and run a program
echo 'syscall(1, 1, "Hello from Cyrius!\n", 19); syscall(60, 0);' | ./build/cc2 > hello
chmod +x hello && ./hello

# Cross-compile for aarch64
echo 'var x = 42;' | ./build/cc2_aarch64 > prog_arm

# Run tests (168 tests, 0 failures)
sh stage1/test_cc.sh ./build/cc2 ./build/stage1f
sh stage1/programs/test_programs.sh ./build/cc2
```

## Benchmarks

| Metric | Value |
|--------|-------|
| Self-compile (93KB compiler) | **11ms** |
| Full bootstrap (from 29KB seed) | **40ms** |
| Binary sizes vs GNU coreutils | **10-233x smaller** |
| Total toolchain | **162KB** |
| External dependencies | **0** |

See [full benchmarks](docs/benchmarks.md).

## Language

Everything is a 64-bit integer. No floats, no GC. Direct syscalls.

```
fn fizzbuzz(n) {
    for (var i = 1; i <= n; i = i + 1) {
        if (i % 15 == 0) { println("FizzBuzz"); }
        elif (i % 3 == 0) { println("Fizz"); }
        elif (i % 5 == 0) { println("Buzz"); }
        else { print_num(i); println(""); }
    }
    return 0;
}
```

**Features**: variables, arrays, structs, enums, functions, if/elif/else, while, for, break/continue, `&&`/`||`, pointers, typed pointers, inline asm, include, switch/match, function pointers, syscalls, comparison expressions in function args.

See [language guide](docs/cyrius-guide.md).

## Ecosystem

| Tool | Size | Description |
|------|------|-------------|
| cc2 | 93KB | Self-hosting compiler (x86_64) |
| cc2_aarch64 | 91KB | Cross-compiler (aarch64) |
| cyrb | 30KB | Build tool: compile, test, self-host, dual-arch |
| ark | 44KB | Package manager: install/remove/search/list/info/verify |

| Library | Modules | Purpose |
|---------|---------|---------|
| stdlib | 8 | string, alloc, vec, io, fmt, str, args, fnptr |
| agnostik | 6 | Shared types: error, security, agent, audit, config |
| agnosys | 1 | Linux syscall bindings (50 syscalls, 20+ wrappers) |
| kybernet | 7 | PID 1 init: signals, reaper, mount, cgroup, epoll |
| nous | 1 | Dependency resolver |
| assert | 1 | Test framework |

**24 library modules, 150+ functions.**

## Tests

```
111 compiler tests    — expressions, control flow, structs, enums, functions, edge cases
 57 program tests     — CLI tools, algorithms, data structures, library suites, kernel ELF
 29 aarch64 tests     — arithmetic, control flow, functions, structs, enums, strings, syscalls
---
168 x86_64 tests, 0 failures
 29 aarch64 tests, 0 failures
```

## Structure

```
bootstrap/           29KB seed binary + bootstrap.sh
stage1/
  cc2.cyr            Compiler entry point
  cc/                Compiler modules (util, emit, jump, lex, parse, fixup)
  arch/aarch64/      aarch64 backend (emit, jump, fixup)
  lib/               Standard library (8 modules)
  lib/agnostik/      Shared AGNOS types (6 modules)
  lib/agnosys/       Syscall bindings (1 module)
  lib/kybernet/      PID 1 init system (7 modules)
  lib/nous/          Dependency resolver (1 module)
  programs/          52 programs (CLI tools, algorithms, tests, tools)
build/               Generated binaries
kernel/              AGNOS kernel (source of truth at github.com/MacCracken/agnos)
docs/                Architecture, roadmap, benchmarks, language guide
```

## Part of AGNOS

Cyrius is the language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only
