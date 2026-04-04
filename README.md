# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external language dependencies. No Rust, no LLVM, no Python. Designed to write the AGNOS kernel.

## Quick Start

```sh
sh bootstrap/bootstrap.sh    # 41ms, produces compiler + assembler

echo 'fn fact(n) {
    var f = 1;
    while (n > 1) { f = f * n; n = n - 1; }
    return f;
}
var x = fact(10);' | ./build/stage1f > prog && chmod +x prog && ./prog
# exit code: 120 (= 5!)
```

**Requirements**: Linux x86_64 + `/bin/sh`. Nothing else.

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary)
  → assembles stage1f.cyr → stage1f (12KB compiler)
    → compiles asm.cyr → asm (29KB assembler, byte-identical)
    → compiles cc.cyr → cc (43KB self-hosting compiler)
      → cc compiles cc.cyr → cc2 (byte-identical ✓)
```

## Benchmarks

| Metric | Value |
|--------|-------|
| Full bootstrap | 41ms |
| Self-compile (1467 lines) | 9ms |
| Assembler throughput | 1.3M lines/sec |
| Compiler throughput | 367K lines/sec |
| Bootstrap binary | 29KB |
| Self-hosting compiler | 43KB |
| Total source (compiler + assembler) | 2577 lines |
| External dependencies | 0 |

## Language Features

The stage1f language (compiled by cc.cyr):

- Variables, arrays, assignment
- Functions (up to 6 params, locals, forward calls)
- if/else, while loops
- Arithmetic: `+ - * / %`
- Bitwise: `& | ^ ~ << >>`
- Comparisons: `== != < > <= >=`
- `syscall()`, `load8()`, `store8()`, `&var`
- String literals with escapes
- Hex literals (`0xFF`), comments (`#`)

## Status

| Phase | Status |
|-------|--------|
| 0 — Fork & Understand | Done |
| 1 — Registry Sovereignty (Ark) | Done |
| 2 — Assembly Foundation (7 stages) | Done |
| 3 — Self-Hosting Bootstrap | Done |
| 4 — Language Extensions | **In progress** (cc.cyr self-hosting ✓, structs next) |
| 5 — Multi-Architecture (aarch64) | Planned |
| 6 — Kernel (AGNOS) | Planned |
| 7 — Prove the Language | Planned |
| 8 — Full Sovereignty | Planned |

## Structure

```
bootstrap/       Root of trust (29KB binary + scripts)
stage1/          Compiler stages + assembler (asm.cyr) + compiler (cc.cyr)
build/           Generated binaries (gitignored)
archive/seed/    Historical Rust seed (verification only)
docs/            Architecture, roadmap, process notes
```

## Tests

```sh
sh stage1/test_stage1e.sh ./build/stage1f   # 63 compiler tests
sh stage1/test_cc.sh ./build/cc             # 36 cc tests + self-hosting
sh stage1/test_asm.sh ./build/asm           # 11 assembler tests (byte-exact)
```

## Part of AGNOS

Cyrius is the language of [AGNOS](https://agnosticos.org), the AI-Native General Operating System.

## License

GPL-3.0-only
