# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external language dependencies. No Rust, no LLVM, no Python. Designed to write the AGNOS kernel.

## Quick Start

```sh
sh bootstrap/bootstrap.sh    # 40ms, produces compiler + assembler
cat stage1/cc2.cyr | ./build/stage1f > ./build/cc2 && chmod +x ./build/cc2

# Compile a program
echo 'syscall(1, 1, "Hello from Cyrius!\n", 19); syscall(60, 0);' | ./build/cc2 > hello && chmod +x hello && ./hello
```

**Requirements**: Linux x86_64 + `/bin/sh`. Nothing else.

## Benchmarks

| Metric | Value |
|--------|-------|
| Full bootstrap | 40ms |
| Self-compile (1960 lines) | 8ms |
| Build 35 programs | ~45ms (3ms each) |
| Cyrius `wc` vs GNU `wc` | **2.4x faster** (9ms vs 22ms for 1MB) |
| Cyrius `true` vs GNU `true` | **233x smaller** (168B vs 39KB) |
| Cyrius `cat` vs GNU `cat` | **10x smaller, same throughput** |
| Total toolchain | 128KB |
| External dependencies | 0 |

See [full benchmarks](docs/benchmarks.md) for details.

## 27 Programs

19 CLI tools + 8 proof programs, all written in Cyrius:

`true` `false` `echo` `cat` `head` `tee` `yes` `nl` `wc` `rev` `seq` `tr` `uniq` `sum` `grep` `hexdump` `basename` `cols` `tail` `fib` `sieve` `points` `memset` `calc`

## Language Features

- Variables, arrays, structs (definition, init, field access)
- Functions (unlimited params, locals, forward calls)
- Control flow: if/elif/else, while, for, break/continue (+ global initializers)
- Logical: `&&`, `||` with short-circuit evaluation and chaining
- Arithmetic: `+ - * / %`, Bitwise: `& | ^ ~ << >>`
- Pointers: `*ptr` dereference, `*ptr = val` store
- Memory: `load8/16/32/64`, `store8/16/32/64`
- `syscall()`, `&var` address-of
- String literals, hex literals (`0xFF`), comments (`#`)
- Type annotations: `var x: i64 = 42` (opt-in, no enforcement)
- Modules: `include "file.cyr"`
- Inline assembly: `asm { 0xNN; ... }`
- Error messages: `error at token N (type=T)`, duplicate var detection

## Status

| Phase | Status |
|-------|--------|
| 0–3 | Done (fork → assembly → self-hosting bootstrap) |
| 4 | Done (structs, pointers, includes, inline asm, elif, types) |
| 5 | **In progress** (prove language: 35 programs, &&/\|\|, benchmarks) |
| 6 | **In progress** (kernel prereqs: typed ptrs ✓, nested structs ✓, global inits ✓, for loops ✓. Remaining: inline asm, bare metal ELF) |
| 7 | Planned (compile Linux kernel with Cyrius, boot AGNOS kernel) |
| 8 | Planned (audit + refactor) |
| 9 | Planned (multi-architecture: aarch64) |
| 10 | Planned (prove at scale: migrate Ark, AGNOS userland) |
| 11 | Planned (full sovereignty) |

## Structure

```
bootstrap/       Root of trust (29KB binary + scripts)
stage1/          Compiler stages + assembler + compiler modules
stage1/cc/       Modular compiler (6 files: util, emit, jump, lex, parse, fixup)
stage1/programs/ 15 Linux programs + buffered I/O library + tests
build/           Generated binaries (gitignored)
archive/seed/    Historical Rust seed (verification only)
docs/            Architecture, roadmap, benchmarks, ADRs
```

## Tests

```sh
sh stage1/test_cc.sh ./build/cc2 ./build/stage1f   # 80 compiler tests
sh stage1/test_asm.sh ./build/asm                    # 11 assembler tests
sh stage1/programs/test_programs.sh ./build/cc2      # 44 program tests
# Total: 135 tests, 0 failures
```

## Part of AGNOS

Cyrius is the language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only
