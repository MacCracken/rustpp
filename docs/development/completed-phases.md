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
