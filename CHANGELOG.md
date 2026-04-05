# Changelog

All notable changes to Cyrius are documented here.
This is the **source of truth** for all work done.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Dual-arch cyrb: `cyrb build --aarch64`, `cyrb test --aarch64`
- aarch64 codegen: refactored 14 arch-specific functions from parse.cyr to emit files
- aarch64 passes 29 feature tests (arithmetic, control flow, functions, structs, enums, strings, syscalls)
- AGNOS repo separation with dual-arch build/test scripts and CI
- VERSION file, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, CI/CD workflows

### Fixed
- aarch64 initial branch (x86 JMP → aarch64 B instruction)
- aarch64 RECFIX ordering (record before MOVZ, not after)
- aarch64 pop encoding (pre-indexed → post-indexed)
- aarch64 modulo (SDIV + MSUB with correct register encoding)
- aarch64 struct field access (refactored to EVADDR_X1 + EADDIMM_X1)
- aarch64 function ABI (STP/LDP frame, STUR/LDUR locals, BL calls)

## [0.9.0] — 2026-04-05

### Added — Language
- Comparison expressions in function arguments (`f(x == 1)` produces 0/1 via `setCC`)
- `PARSE_CMP_EXPR` + `ESETCC` codegen — comparisons as value-producing expressions
- `assert.cyr` test framework: `assert(cond, name)`, `assert_eq`, `assert_neq`, `assert_gt`, `assert_summary`
- 17 new compiler tests (8 comparison-in-args + 9 Phase 10 edge cases)

### Added — Ecosystem (Phase 11)
- **agnostik** — shared types: 6 modules (error, types, security, agent, audit, config), 54 tests
- **agnosys** — syscall bindings: 50 syscall numbers, 20+ wrappers (fork, execve, pipe, mount, epoll, timerfd, signalfd, sigset, wait macros)
- **kybernet** — PID 1 init: 7 modules (console, signals, reaper, privdrop, mount, cgroup, eventloop), 38 tests
- **nous** — dependency resolver: marketplace + system resolution, source detection, search, 26 tests
- **ark** — package manager CLI (44KB): install/remove/search/list/info/status/verify/history
- **cyrb** — build tool (29KB): compile, test, self-hosting check, suite runner

### Fixed — Compiler
- **Enum init ordering**: enum values were 0 inside functions — swapped init order in cc2.cyr
- **Comparison in fn args**: was "error at token N (type=17)" — added PARSE_CMP_EXPR

### Fixed — Kernel (Phase 10 Audit — 23 issues resolved)
- pmm_bitmap bounds check (`page >= 4096`)
- proc_table overflow guard (`proc_count >= 16`)
- proc_get/set_state bounds validation
- ISR full register save (9 regs: rax, rcx, rdx, rsi, rdi, r8-r11)
- Syscall write: clamp length to 4096, reject null pointer

### Added — Compiler Hardening
- Fixup table overflow guard (error at 512 entries)
- Token array bounds check (error at 32768 tokens)

### Metrics
- 168 tests (111 compiler + 57 programs), 0 failures
- 24 library modules, 150+ functions, 103 source files
- Kernel: 62KB (hardened), Compiler: 93KB, Ark: 44KB, Cyrb: 29KB

## [0.8.0] — 2026-04-04

### Added — Kernel (Phase 7)
- AGNOS kernel (58KB, 606 lines, 32 functions): multiboot1 boot, 32-to-64 shim, serial I/O, GDT, IDT, PIC, PIT timer (100Hz), keyboard (ring buffer), page tables (16MB), PMM (bitmap), VMM, process table, syscalls (exit/write/getpid)

### Added — Language (Phase 8 Tier 1)
- Enums (`enum E { A = 0; B = 42; }`), switch/match, function pointers (`&fn_name`)
- Type enforcement warnings, heap allocator (brk), String type (str.cyr), argc/argv (args.cyr)
- Standard library: 8 libs, 53 functions (string, alloc, str, vec, io, fmt, args, fnptr)

### Added — Multi-Architecture (Phase 9)
- aarch64 backend (61 emit functions), cross-compiler builds
- Codegen factored: shared frontend, per-arch backend

## [0.7.0] — 2026-04-03

### Added — Language Extensions (Phase 4-6)
- cc2 modular compiler (7 modules, 182 functions, 92KB)
- Structs, pointers, >6 params, load/store 16/32/64, include, inline asm (18 mnemonics)
- elif, break/continue, for loops (token replay), &&/|| (short-circuit)
- Typed pointers, nested structs, global initializers (two-pass scanning)
- Bare metal ELF (multiboot1), ISR pattern, bitfields
- 46 programs, 157 tests, 10-233x smaller than GNU

## [0.5.0] — 2026-03-28

### Added — Self-Hosting Bootstrap (Phase 3)
- asm.cyr (1110 lines, 43 mnemonics), bootstrap closure
- 29KB committed binary root of trust, Rust seed archived
- Zero external dependencies

## [0.3.0] — 2026-03-25

### Added — Assembly Foundation (Phase 2)
- Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e → stage1f
- stage1f: 16384 tokens, 256 functions, 63 tests

## [0.1.0] — 2026-03-20

### Added — Foundation (Phase 0-1)
- Forked rust-lang/rust, mapped cargo registry codepaths
- Ark registry sovereignty patches (ADR-001)
- cyrius-seed (Rust assembler, 69 mnemonics, 195 tests)
