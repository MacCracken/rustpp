# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- cc2.cyr — modular compiler split into 7 files using include
  - cc2.cyr (entry), cc/util, cc/emit, cc/jump, cc/lex, cc/parse, cc/fixup
  - Self-hosting: cc2==cc3 byte-identical, 61 compiler tests
- Error messages: `error at token N (type=T)` replaces bare "syntax error"
- Progressive type annotations: `var x: i64 = 42`, `fn f(a: i64, b: i64)` — parsed, no enforcement
- 15 real Linux programs: true, false, echo, cat, head, tee, yes, nl, wc, rev, seq, tr, uniq, sum, grep
  - 168-9864 bytes, 10-233x smaller than GNU equivalents
  - 22 program tests (functionality + size checks)

- Logical `&&` and `||` — short-circuit evaluation with chaining (a && b && c)
  - ECONDCMP/ECONDOP/ECONDOPT/ECOND_AND/ECOND_OR/PATCHXP functions
  - Extra patch mechanism for && false-branch forwarding
  - 8 new tests (both operators, while support, else paths)
- Token arrays expanded 16384→32768 (relocated to end of heap, 4 offset changes)
  - Unblocked by investigating `var x = fn(); return x;` — works correctly, was not a bug
- For loops: `for (init; cond; step) { body }` with break support, nested loops
  - Token replay mechanism for step expression
  - Local-first variable lookup for step inside functions
  - 5 new compiler tests
- 4 new programs: hexdump, basename, cols, tail (6 new program tests)
- Codebuf expanded 65536→196608 (relocated 0x59000→0x20000)
- Input buffer expanded 65536→131072 (handles growing compiler source)
- Bootstrap chain repaired: fixed codebuf offset split and orphaned GVAR references
  - Source now reproduces binary (cc2==cc3 byte-identical)
  - Bootstrap path: stage1f → cc.cyr → cc2 verified
  - build/cc2 committed to git (no longer gitignored)
- Typed pointers: `var p: *i64 = &buf; *(p + 1)` scales by element size
- Nested structs: `struct Outer { x; inner: Inner; }` with chained dot access
- Global initializers: two-pass declaration scanning, calc.cyr unblocked
- String stdlib: stage1/lib/string.cyr (strlen, streq, memcpy, memset, memchr, strchr, print_num)
- AGNOS kernel (Phase 7 complete):
  - 32-to-64 boot shim, serial console, GDT, IDT, PIC remap
  - PIT timer interrupt (100Hz), keyboard interrupt (ring buffer)
  - Page tables (16MB identity map), physical memory manager (bitmap)
  - Virtual memory manager (map/unmap/alloc), process table, syscall interface
  - 606 lines, 32 functions, 58KB kernel binary, boots on QEMU
- aarch64 backend (Phase 9 started):
  - stage1/arch/aarch64/ with emit.cyr (53 fns), jump.cyr (4 fns), fixup.cyr (4 fns)
  - Cross-compiler cc2_aarch64 (84KB, emits aarch64 ELF64)
  - Codegen factored: shared frontend, per-arch backend via include swap
- Language foundations (Phase 8 started):
  - Heap allocator: stage1/lib/alloc.cyr — bump allocator from brk, alloc/reset/used
  - String type: stage1/lib/str.cyr — Str struct (data+len), str_from/eq/cat/sub/print
  - Function pointer library: stage1/lib/fnptr.cyr — fncall0/1/2 indirect calls
  - argc/argv: stage1/lib/args.cyr — reads /proc/self/cmdline
  - Cyrius language guide: docs/cyrius-guide.md
  - Vidya: 17 type system patterns, 14 implementation patterns, 13 aarch64 entries
  - 143 total tests (80 cc + 52 programs + 11 asm)
- Inline asm mnemonics: 18 kernel instructions (cli, sti, hlt, mov crN, lgdt, lidt, iretq, etc.)
- Bare metal ELF: `kernel;` directive, multiboot1 header, 32-bit ELF, base 0x100000
- Bitfield access: PTE/GDT/IDT pack/unpack patterns proven
- ISR save/restore: 14 GPR push/pop pattern for interrupt handlers
- Phase 7 started: boot_serial.cyr (240 bytes) boots on QEMU, prints "AGNOS" to serial
- 23 new programs: hexdump, basename, cols, tail, fib, sieve, points, memset, strtest,
  toupper, count, rot13, bitfield, life, asmtest, xor, collatz, brainfuck,
  kernel_hello, isr_stub, boot_serial, calc (unblocked)

### Fixed
- Global array data layout bug: VCNT was restored after function parsing, erasing globals created inside functions (arrays). String literal addresses overlapped with variable data. Fix: don't restore VCNT — arrays inside functions persist as globals.
- wc trailing byte: now outputs clean numbers
- `break` and `continue` — loop control (single break per loop, nested loop support)
- `elif` keyword — eliminates nested brace chains (recursive implementation, no arrays)
- Duplicate var detection: `error: duplicate var at token N` — catches the #1 bug class
- All 15 programs fully working (rev fixed, 5 new: seq, tr, uniq, sum, grep — all worked first try)
- Buffered I/O: tr 85x faster (766ms→9ms for 1MB), wc now 2.4x faster than GNU
- 141 total tests (80 cc + 11 asm + 50 programs), 38 programs total
- Dead code removed: GSVC, SSVC (orphaned by VCNT fix)
- Phase 4b struct state refactor deferred (accessor functions already provide the abstraction)
- S64/L64 refactored to use store64/load64 (saved 256 bytes in binary)

## [1.1.0] - 2026-04-04

### Added
- Structs: `struct Point { x; y; }` with initialization, field access (dot), field assignment
- Multi-width load/store: `load16/32/64`, `store16/32/64` intrinsics
- Pointer dereference: `*ptr` (read) and `*ptr = val;` (write through pointer)
- >6 function parameters: args 7+ passed on stack, System V ABI compliant
- Inline assembly: `asm { 0xNN; ... }` raw byte emission blocks
- Include directive: `include "file.cyr"` preprocessing with sys_open/read/close
- Test suite: 51 tests (34 byte-exact compat + 17 cc-only features)
- vidya: 69 entries compiler_bootstrapping, 22 code_generation, 17 type_systems

### Fixed
- Function table overflow: bumped stage1f from 128→256 fn slots, cc.cyr matched
- Hex literal underscores: removed (unsupported by stage1f lexer)
- Self-hosting: cc2==cc3 byte-identical verified with all extensions

### Changed
- cc.cyr: 1960 lines, 149 functions, 51 tests
- Phase 6/7 reordered: Prove the Language (build Linux binaries) before Kernel

## [1.0.0] - 2026-04-04

### Added
- cc.cyr — self-hosting compiler (1467 lines, 43504-byte binary)
  - Compiles itself byte-identical (cc2==cc3)
  - Full stage1f language: vars, arrays, fn/return/call, if/else, while,
    arithmetic with precedence, syscall, load8/store8, &var, strings,
    bitwise ops, shifts, modulo, hex literals, comments
- Benchmark suite: bootstrap 41ms, self-compile 9ms, asm 1.3M lines/sec

## [0.3.0] - 2026-04-04

### Added
- Self-hosting assembler: asm.cyr (1110 lines, 43 mnemonics, 11 byte-exact matches)
- Bootstrap binary: bootstrap/asm (29KB) + bootstrap.sh + verify.sh + SHA256
- stage1e (bitwise ops, 63 tests) + stage1f (token-scaled compiler)

### Removed
- upstream/ submodule (13GB) — removed
- Rust seed → archive/seed/ (verification only)

## [0.2.0] - 2026-04-03

### Added
- stage1a through stage1d: expression → control flow → syscalls → functions
- 120 tests across 4 stages

## [0.1.0] - 2026-04-03

### Added
- cyrius-seed (Rust, 69 mnemonics, 195 tests)
- Ark registry sovereignty patches (ADR-001)
- Project documentation
