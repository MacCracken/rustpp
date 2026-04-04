# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-04-04

### Added
- cc.cyr — self-hosting compiler (1467 lines, 43504-byte binary)
  - Compiles itself byte-identical (cc → cc2, cmp cc cc2 passes)
  - Full language: vars, arrays, fn/return/call (6 params, locals, forward refs),
    if/else, while, expressions with precedence, syscall, load8/store8, &var,
    strings with escapes, bitwise ops, shifts, modulo, hex literals, comments
  - 12 byte-exact matches with stage1f reference compiler
- Benchmark suite:
  - Full bootstrap: 41ms
  - Self-compile (1467 lines): 9ms
  - Assembly (3983 lines): 3ms
  - Throughput: stage1f 367K lines/sec, cc 163K lines/sec, asm 1.3M lines/sec

### Changed
- Phase 4 item 1 (cc.cyr) and item 2 (self-hosting) complete
- Roadmap updated with Phase 5 (multi-arch), Phase 6 (kernel), Phase 7 (prove language), Phase 8 (full sovereignty)
- upstream/ submodule fully removed (git rm)

## [0.3.0] - 2026-04-04

### Added
- Self-hosting assembler: asm.cyr (1110 lines, 43 mnemonics)
  - Two-pass architecture: pass 0 collects labels, pass 1 encodes
  - Memory operand encoder with RSP/SIB and RBP/disp8 special cases
  - All instruction forms used by stage1a through stage1f
  - 11 byte-exact matches with Rust seed output
- Bootstrap binary: bootstrap/asm (29KB committed ELF)
- Bootstrap script: bootstrap/bootstrap.sh (zero external dependencies)
- Verification script: bootstrap/verify.sh (reproducibility proof)
- SHA256 manifest: bootstrap/SHA256SUMS
- stage1f — token-scaled compiler (16384 slots, up from 4096)
- stage1e — bitwise operators (% & | ^ ~ << >>), hex literals, comments, uppercase identifiers
  - 63 tests, all passing
- Test programs: stage1/examples/ (exit42, hello, mem, mem_rsp, mem_disp)

### Changed
- Bootstrap chain no longer requires Rust, LLVM, Python, or any external compiler
- Project status: Phase 3 complete, Phase 4 in progress

### Removed
- upstream/ submodule (13GB rust-lang/rust fork) — deinited and removed
- Rust seed moved from seed/ to archive/seed/ (kept for verification only)
- Stale committed binaries (stage1a, stage1b, stage1c) — rebuild from source via asm

## [0.2.0] - 2026-04-03

### Added
- stage1d — functions compiler (fn/return, 6-param System V ABI, stack locals, 28 tests)
- stage1c — memory + syscalls compiler (syscall, strings, &var, arrays, load8/store8, 37 tests)
- stage1b — control flow compiler (if/else, while, runtime codegen, 39 tests)
- stage1a — expression evaluator compiler (16 tests)
- Test suites: test_stage1a.sh through test_stage1d.sh

### Changed
- Each stage compiled by the seed assembler from .cyr assembly source

## [0.1.0] - 2026-04-03

### Added
- cyrius-seed — stage 0 assembler (Rust, 69 mnemonics, 195 tests, zero external crates)
- Ark registry sovereignty patches to cargo (ADR-001)
  - ARK_INDEX, ARK_HTTP_INDEX, ARK_REGISTRY, ARK_DOMAIN constants
  - Default registry changed from crates.io to Ark
  - Git/path deps allowed for non-crates.io registries
- rust-lang/rust fork as upstream submodule
- Project documentation: cyrius.md, cargo-codepaths.md, process-notes.md, roadmap.md
