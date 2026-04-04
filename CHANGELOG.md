# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- cc2.cyr — modular compiler split into 7 files using include
  - cc2.cyr (entry), cc/util, cc/emit, cc/jump, cc/lex, cc/parse, cc/fixup
  - Self-hosting: cc2==cc3 byte-identical, 51/51 tests
- Error messages: `error at token N (type=T)` replaces bare "syntax error"
- Progressive type annotations: `var x: i64 = 42`, `fn f(a: i64, b: i64)` — parsed, no enforcement
- 10 real Linux programs: true, false, echo, cat, head, tee, yes, nl, wc, rev
  - 8 fully working, 2 with known data layout bugs (wc trailing byte, rev array ordering)
  - 168-1696 bytes, 108-233x smaller than GNU equivalents
  - 14 program tests (functionality + size checks)

### Fixed
- Global array data layout bug: VCNT was restored after function parsing, erasing globals created inside functions (arrays). String literal addresses overlapped with variable data. Fix: don't restore VCNT — arrays inside functions persist as globals.
- wc trailing byte: now outputs clean numbers
- Programs: 8→9 fully working (rev still has multi-global edge case)
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
