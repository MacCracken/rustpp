# Completed Phases

Historical record of all completed development phases.
For current work, see [roadmap.md](roadmap.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md) (source of truth).

---

## Phase 0 — Fork & Understand
Forked rust-lang/rust, built rustc from source, mapped cargo registry codepaths.

## Phase 1 — Registry Sovereignty
Ark as default registry, git/path deps first-class, publish validation relaxed. ADR-001 documented.

## Phase 2 — Assembly Foundation
Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e (63 tests) → stage1f (16384 tokens, 256 fns).

## Phase 3 — Self-Hosting Bootstrap
asm.cyr (1110 lines, 43 mnemonics), bootstrap closure, 29KB committed binary. Zero external dependencies. Byte-exact reproducibility.

## Phase 4 — Language Extensions
cc2 modular compiler (7 modules, 182 functions). Structs, pointers, >6 params, load/store 16/32/64, include, inline asm, elif, break/continue, for loops, &&/||, typed pointers, nested structs, global initializers.

## Phase 5 — Prove the Language
46 programs, 157 tests. 10-233x smaller than GNU. wc 2.4x faster.

## Phase 6 — Kernel Prerequisites
All 9 items: typed pointers, nested structs, global inits, for loops, inline asm (18 mnemonics), bare metal ELF, ISR pattern, bitfields, linker control.

## Phase 7 — Kernel (x86_64)
58KB kernel (hardened to 62KB in Phase 10): multiboot1 boot, 32-to-64 shim, serial, GDT, IDT, PIC, PIT timer, keyboard, page tables (16MB), PMM (bitmap), VMM, process table, syscalls.

## Phase 8 — Language Foundations (Tier 1)
7/8 complete: type enforcement (warnings), enums, switch/match, heap allocator, function pointers (&fn_name), argc/argv, String type. Block scoping deferred.
Standard library: 8 libs (string, alloc, str, vec, io, fmt, args, fnptr) — 53 functions.
Comparison-in-args fix: `PARSE_CMP_EXPR` + `setCC` codegen.
`assert.cyr` test framework library.

## Phase 9 — Multi-Architecture (aarch64) — Partial
Done: codegen factored into backends, aarch64 emit (61 fns), cross-compiler builds.
Remaining: instruction correctness, self-hosting on ARM, kernel port, cross-compilation.

## Phase 10 — Audit, Refactor, Stabilize — Partial
Done: kernel audit (23 issues fixed), compiler hardening (fixup + token guards), 17 new edge case tests.
Deferred: error message line numbers, performance pass, block scoping.

## Phase 11 ��� Prove at Scale (Crate Rewrites)
5 AGNOS crate rewrites in Cyrius:
- **agnostik** — 6 modules (error, types, security, agent, audit, config), 54 tests
- **agnosys** — syscall bindings (50 numbers, 20+ wrappers, sigset, epoll, timerfd)
- **kybernet** — 7 modules (console, signals, reaper, privdrop, mount, cgroup, eventloop), 38 tests
- **nous** — dependency resolver (marketplace + system), 26 tests
- **ark** — package manager CLI (44KB, 8 commands)
- **cyrb** — build tool (29KB, compile/test/self-host)
- Benchmarks and documentation updated

## v0.9.0–v0.9.7 — Language, Tooling, Infrastructure

### Language Features
- Floating point f64 — SSE2 codegen, 10 builtins, float literals (v0.9.2)
- Methods on structs — convention dispatch `point.scale(2)` (v0.9.2)
- Error line numbers — `error:3: unexpected token` (v0.9.2)
- Block scoping — variables in if/while/for don't leak (v0.9.5)
- Enum constructor syntax — `Ok(val)` parsed (v0.9.6)
- Feature flags — `#define`/`#ifdef`/`#endif` (v0.9.6)
- Module system — `mod name;` + `use mod.fn;` + `pub fn` (v0.9.7)
- Comparison in function args — `f(x == 1)` via setCC (v0.9.0)
- Generics Phase 1 — syntax parsed, not enforced (v0.9.0)
- Preprocessor fix — strings with "include" safe (v0.9.4)

### Compiler Infrastructure
- Token arrays 32K → 64K, tok_names 32K → 64K (v0.9.2)
- Fixup table 512 → 1024 entries (v0.9.0)
- Preprocessor buffer relocation (v0.9.2)
- Dead code removal: src/arch/x86_64/ (v0.9.6)

### Tooling
- cyrb shell dispatcher — 20+ commands (v0.9.0)
- cyrfmt, cyrlint, cyrdoc, cyrc, ark — 8 tool binaries (v0.9.0)
- Benchmarks — 45 benchmarks, bench-history.sh, CSV tracking (v0.9.1)
- Installer — tarball download, version manager (v0.9.1)
- Release pipeline — dual-arch CI, SHA256, GitHub Releases (v0.9.1)
- `cyrb docs --agent` — markdown server for bots (v0.9.6)
- `cyrb.toml` parser — replaces grep/sed (v0.9.6)
- `cyrb coverage` — file/function test coverage (v0.9.7)
- `cyrb doctest` — runnable doc examples (v0.9.7)
- `cyrb repl` — interactive evaluator (v0.9.7)
- Version bump script + version sync (v0.9.4/v0.9.6)

### Documentation
- 5 ADRs, threat model (v0.9.6)
- 32 vidya implementation entries (v0.9.4–v0.9.6)
- 14/14 runnable vidya reference files (v0.9.4)

### Ecosystem
- P-1 hardening: hashmap tombstones, vec bounds, alloc OOM (v0.9.3)

## v0.9.7–v0.9.8 — Language + Architecture

### Language (v0.9.7–v0.9.8)
- Module system — `mod name;` + `use mod.fn;` + `pub fn` (v0.9.7)
- Pattern matching — `match expr { val => { } _ => { } }` with scoped arms (v0.9.8)
- For-in range loops — `for i in 0..10 { }` with exclusive end (v0.9.8)
- Enum constructor syntax — `Ok(val)` parsed (v0.9.6)
- Feature flags — `#define`/`#ifdef`/`#endif` (v0.9.6)

### aarch64 (v0.9.8)
- cc3_aarch64 runs natively on real Raspberry Pi hardware
- 26 qemu tests, 30/31 hardware tests pass
- ESCPOPS rewritten: pop-through-x0 approach fixes register mapping
- Syscall translation layer: x86→aarch64 MOVZ encodings
- SYS_* enum constants replace hardcoded syscall numbers in all shared code
- Fixed MOVZ encoding errors for read(63) and write(64)

### Tooling (v0.9.7)
- `cyrb coverage` — file/function test coverage reports
- `cyrb doctest` — runnable doc examples (# >>> / # ===)
- `cyrb repl` — interactive expression evaluator
- `cyrb docs --agent` — markdown server for bots
- `cyrb.toml` parser replaces grep/sed
- 5 ADRs, threat model (v0.9.6)

## v1.7–v1.9 — Compiler Hardening, Optimizations, Ecosystem

### Bugs Fixed
- Bump allocator no arena → arena_new/arena_alloc/arena_reset in lib/alloc.cyr (v1.8.3)
- aarch64 tarball ships x86 binary → architecture verification in CI (v1.8.3)
- cyrb --aarch64 -D flag → shell cyrb supports all flags (v1.8.4)
- Release tarball cyrb ignores -D → ships shell scripts/cyrb (v1.9.3)
- Cross-compiler naming ambiguity → cc2 / cc2_aarch64 / cc2-native-aarch64 (v1.9.0)
- `#derive(Serialize)` not processed in included files → derive hooks in PP_PASS (v1.9.5)

### Keystone Ports
- Const generics → not needed; runtime-sized alloc + var buf[N] covers patterns (v1.8.3)
- Derive macros → `#derive(Serialize)` for JSON (v1.7.7)
- TOML parser → lib/toml.cyr (v1.8.2)
- Vidya content loader → lib/vidya.cyr with registry and search (v1.9.1)

### Performance
- Stack-allocated small strings → str_builder direct buffer, 64-byte inline (v1.8.x)
- Arena allocator → arena_new, arena_alloc, arena_reset (v1.8.3)

## v1.10.0–v1.10.1 — Codegen, Concurrency, Bug Fixes

### Compiler — Codegen
- Inline small functions → token replay inlining, 1-param ≤6 tokens (v1.10.0)
- Register allocation → R12 spill for first expression temp, ESPILL/EUNSPILL (v1.10.0)
- Return-by-value → ret2(a,b) returns rax:rdx, rethi() reads rdx (v1.10.0)
- SIMD expand → f64v_div, f64v_sqrt, f64v_abs, f64v_fmadd (v1.9.5/v1.10.0)
- `#ref` TOML → PP_REF_PASS pre-pass, var key = value emission (v1.10.0)
- LEXKW_EXT + PARSE_SIMD_EXT → overflow helpers for large functions (v1.10.0)
- PARSE_STMT range extended → 62-98 for new builtins (v1.10.0)
- _INLINE_OK flag → disables inline metadata on aarch64 (v1.10.0)

### Standard Library
- lib/thread.cyr → threads (clone+mmap), mutex (futex), MPSC channels (v1.10.1)
- Syscalls: SYS_CLONE, SYS_FUTEX, SYS_MUNMAP + CloneFlag, MmapConst, FutexOp enums (v1.10.1)
- Hashmap simplified → _map_lookup helper, elif in probe, reduced indirection (v1.10.0)

### Bug Fixes
- Bug #9: getenv() scoping fix → variables outside while loop (v1.10.1)
- Bug #10: exec_capture pipe fix → pipefd[16] + load32 for 32-bit fds (v1.10.1)
- aarch64 native self-host → _INLINE_OK=0 prevents metadata writes on ARM (v1.10.0)
- Missing EMIT_F64V_LOOP aarch64 stub (v1.10.0)

### Dead Code Removal
- 11 stale files: src/cc/ (5), src/cc_bridge.cyr, src/compiler.cyr, src/compiler_aarch64.cyr, src/arch/aarch64/ (3)
