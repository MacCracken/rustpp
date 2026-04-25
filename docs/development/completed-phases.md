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
Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e (63 tests) → cyrc (16384 tokens, 256 fns).

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

## v1.11.0–v1.11.1 — Enum Namespacing, Relaxed Ordering, Allocator, Bug Fixes

### Language Features
- Enum namespacing in expressions — `Enum.VARIANT` syntax (v1.11.0)
- Relaxed fn ordering — functions can appear after statements (v1.11.0)
- `continue` works correctly in all loop types — multiple continue patch array (v1.11.1, bug #13)

### Compiler Infrastructure
- Fixup table expanded 4096 to 8192 entries (v1.11.0)
- f64_atan builtin (v1.11.0)

### Standard Library
- lib/freelist.cyr — freelist allocator (free + reuse, O(1) alloc/free) (v1.11.0)
- lib/math.cyr — extended math functions (v1.11.0)

### Bug Fixes
- Bug #12: derive runtime segfault fix (v1.11.1)
- Bug #13: multiple continue patch array — continue in all loop types (v1.11.1)
- Bug #14: MAP_FAILED removal (v1.11.1)
- Bug #15: dual derive fix (v1.11.1)

## v3.x Compiler Completed

- Small function inlining — 2-param, 16-token body (v3.3.5)
- Dead store elimination — post-emit DSE pass (v3.3.2)
- Expanded constant folding — removed 16-bit limit (v3.3.1)
- `cc3 --version` (v3.3.0)
- `defer` statement — LIFO, max 8 per function (v3.2.0)
- PIC codegen partial — `object;` mode, LEA [rip+disp32] (v3.4.12)

## v3.x Stdlib Completed

- fncall3–fncall6 indirect calls (v3.4.3)
- dynlib.cyr — pure Cyrius ELF .so loader (v3.4.11)
- mmap.cyr — memory-mapped I/O (v3.4.3)
- yukti v1.2.0 — device abstraction, 470 tests (v3.4.12)

## v3.x Bug Fixes

- Bug #32: parser overflow at ~12K lines — tok_names 32→64KB (v3.3.17)
- Bug #33: LEXHEX wrong buffer (v3.3.17)
- Bug #34: #derive(Serialize) duplicate variable (v3.4.4)
- Bug #35: cc3 SIGSEGV on large multi-lib programs (v3.4.7)
- Bug #36: comparisons in function call args — cfo leak (v3.4.10)

## v3.x Downstream Blockers Resolved

- 1024→2048 function limit (v3.2.2)
- #derive(Serialize) Str fields (v3.2.3)
- Nested if/while/break codegen (v3.2.2)
- break in deeply nested while/if — linked-list (v3.3.15)
- #derive(Serialize) composable 2-arg form (v3.2.3)
- #derive(Deserialize) single-pass parser (v3.4.1)

## v5.0.0 — cc5 Generation Bump

- **cc5 IR** (`src/common/ir.cyr`, 812 lines) — 40 opcodes, BB construction, CFG edge builder (patch-offset matching), LASE analysis, dead block detection. Self-compile: 119K nodes, 8.7K BBs, 11K edges, 675 LASE candidates. 43 instrumented emit/jump functions. Analysis-only (transparent).
- **cyrius.cyml manifest** — replaces cyrius.toml. `cyrius update` auto-migrates.
- **`cyrius version`** — toolchain version. `--project` for project version.
- **CLI tool integrations** — `--cmtools=starship`.
- **cc3→cc5 rename** — binary, scripts, docs all updated.
- **Deps**: patra 1.0.0, sankoch 1.2.0.
- Heap extended 14.3MB → 21MB. 59 test suites. Compile-time: 0.26s normal, 1.59s with IR.

## v5.0.1 — Security Hardening

- **alloc() heap pointer overflow** (P0) — overflow guard rejects if `new_ptr < ptr`. Rejects negative/zero.
- **alloc() size cap** (P1) — `ALLOC_MAX` (256MB) rejects oversized single allocations.
- **vec_push() capacity overflow** (P1) — `VEC_CAP_MAX` (2^28) ceiling. Checks alloc return.
- **_map_grow() capacity overflow** (P1) — `MAP_CAP_MAX` (2^26) ceiling. Checks alloc return.
- **arena_alloc() overflow** (P2) — same overflow guard as global alloc.
- 60 test suites. `alloc_safety.tcyr` added (11 assertions).

## v5.0.2 — Preprocessor Fix

- **`#ref` bol tracking** — `PP_REF_PASS` now checks beginning-of-line before matching `#ref` directives, matching the pattern in `PP_PASS` and `PP_IFDEF_PASS`. Prevents false matches inside strings or mid-line.

## v5.0.3 — aarch64 Native + Version Tooling

- **`src/main_aarch64_native.cyr`** — native aarch64 compiler entry point with host syscall numbers (read=63, write=64, openat=56, close=57, brk=214, exit=93).
- **Version check openat-aware** — `main.cyr` branches on `SYS_OPEN == 2` for `/proc/self/cmdline`.
- **`version-bump.sh`** — fixed stale `cc3` pattern → `cc5`. Version string was stuck at `cc5 5.0.0` for two releases.

## v5.1.0 — macOS x86_64 (Mach-O)

- **`EMITMACHO_EXEC`** (`src/backend/macho/emit.cyr`) — Mach-O x86_64 executable emission. mach_header_64, __PAGEZERO (4GB null guard), __TEXT (RWX flat layout: code + vars + strings), LC_UNIXTHREAD (sets RIP to entry). Virtual base 0x100000000, code at page offset 4096. Triggered by `CYRIUS_MACHO=1` env var.
- **`_TARGET_MACHO` flag** — controls EEXIT (macOS exit = 0x2000001) and FIXUP base (0x100001000).
- **`lib/syscalls_macos.cyr`** — macOS BSD syscall constants with 0x2000000 prefix.
- **`lib/alloc_macos.cyr`** — mmap-based bump allocator (macOS has no brk). Drop-in alloc.cyr replacement.
- **`programs/macho_probe.cyr`** — format validation probe.
- Tested on 2018 MacBook Pro: exit(42), hello world, variables + functions + strings all pass.

## v5.1.1–v5.3.x — Mach-O to Apple Silicon Parity

- **v5.1.1–v5.2.x**: Mach-O hardening, preprocessor + format fixes.
- **v5.3.0–v5.3.18**: Apple Silicon (macOS aarch64). PIE-safe `adrp+add` for strings, `__cstring` + `__DATA` sections, 102/102 tcyr regression on real Pi 4 (Linux aarch64 cross-build byte-identical). Mach-O arm64 self-host byte-identical on M-series (narrow-scope; broad-scope runtime on M-series regressed on macOS Sequoia 15+ per v5.6.26 repair slot — platform drift, Mach-O bytes unchanged).

## v5.4.x — Middle-Minor Consolidation

- **v5.4.2–v5.4.8**: Windows PE32+ foundation (`EEXIT` Win64, IAT fixup, `#pe_import` directive, `syscall(1)→WriteFile`, PE data placement).
- **v5.4.9–v5.4.11**: `_cyrius_init` STB_GLOBAL (mabda C-launcher unblock), `lib/thread.cyr` post-clone fix, aarch64 Linux syscall stdlib split.
- **v5.4.12–v5.4.17**: tool-cleanup, release-scaffold hardening, fncall ceiling lift, hashmap Str-keys, keccak/SHAKE + sigil 2.9.0, stdlib perf pass, lib/toml.cyr multi-line array.
- **v5.4.18–v5.4.20**: `[release]` manifest, `#ifplat` directive + `--strict`, closeout.

## v5.5.0–v5.5.40 — Platform Completion Minor (longest minor in cyrius history, 40 patches)

- **v5.5.0–v5.5.10 — Windows PE end-to-end**: foundation (`cc5_win` cross-entry), 5 syscall reroutes (Read/Open/Close/Seek/Map), enum-constant sc_num folding, Win64 arg-register flip (≤4-arg), call-site completion (ECALLPOPS shuttle, ECALLCLEAN), `&fn` PE VA fixup, `fnptr.cyr` Win64 + shuttle ceiling extension, strict shadow-space compliance, heap bootstrap via SYS_MMAP, `#ifdef CYRIUS_TARGET_LINUX` gates, **native Windows narrow-scope byte-identical fixpoint** on real Win11 (EWRITE_PE 5-byte fix returning bytes-written not BOOL — md5 match on exit42 and multi-fn add). Cyrius exit42 PE = 1536 B vs Rust -O stripped = 344,856 B (225× smaller). Broad-scope runtime on the v5.5.10 Win11 build passed at the time; **regressed on Windows 11 24H2 (build 26200+)** per v5.6.27 repair slot — platform drift, PE bytes unchanged since v5.5.10.
- **v5.5.11–v5.5.17 — Apple Silicon toolchain completion**: libSystem probe (hand-emitted Mach-O arm64 LC_DYLD_INFO_ONLY classic binds), compiler-driven `__DATA_CONST + __got` emission, 1→6 `__got` slots (_exit/_write/_read/_malloc/_fopen/_pthread_create), whitelist soften, `CYRIUS_TARGET_MACOS` predefine, argv via x28 entry prologue. All 4 cyrius tool binaries (cyrfmt/cyrlint/cyrdoc/cyrc) do real work on macOS aarch64.
- **v5.5.18–v5.5.22 — aarch64 Linux shakedown + AES-NI unblock**: `lib/io.cyr` per-arch `sys_*` wrappers, inline-asm investigation, hashmap u64-key variant (SplitMix64, 16 B slot), **SSE m128 alignment fix** (arrays 16-byte aligned — root-caused sigil AES-NI bug), `cyrfmt --write`/`-w`.
- **v5.5.23–v5.5.28 — NSS/PAM arc**: locale bootstrap (`dynlib_bootstrap_locale`) + environ bootstrap (`dynlib_bootstrap_environ`); auxv-synthesis confirmed dead end; **pivoted to musl-style pure-cyrius `lib/pwd.cyr` + `lib/grp.cyr` + `lib/shadow.cyr`** (bypasses glibc NSS); `lib/pam.cyr` wrapping `/usr/sbin/unix_chkpwd`; `lib/fdlopen.cyr` primitives + C helper (Cosmopolitan/pfalcon foreign-dlopen pattern).
- **v5.5.29–v5.5.33 — Threading + tooling**: fdlopen orchestration (3-attempts-defer at .29), `lib/thread_local.cyr` (%fs / TPIDR_EL0 runtime slots), `lib/atomic.cyr` (load/store/cas/fetch_add/fence — x86 `lock cmpxchg` + aarch64 LL-SC + `dmb ish`), race-free mutex, thread-safety audit, `lib/flags.cyr` (getopt-long CLI parser).
- **v5.5.34 — fdlopen complete**: 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` == `syscall(SYS_GETPID)`. Root cause: ELF `PF_R/PF_X` bits swapped vs mmap `PROT_READ/PROT_EXEC`. Cross-repo symlink `mabda/lib → cyrius/lib` retired (closed the recurring lib/dynlib.cyr strip mystery).
- **v5.5.35 — PE .reloc + 32-bit ASLR**: `DYNAMIC_BASE` (0x0140) on; 1779 DIR64 entries emitted. `HIGH_ENTROPY_VA` deferred.
- **v5.5.36 — Win64 ABI completion bundle**: hidden-RCX struct-retptr (>8B) native on SysV (RDI) + Win64 (RCX); `__chkstk` stack probe using **R11** (not RCX); variadic float duplication. New syntax: `stack var p: Point;`, `var p: Point;`, `fn f(): Point`, `fn f(a, ...)`.
- **v5.5.37 — fixup cap raise**: 16384 → 32768; `fixup_tbl` moved 0xE4A000 → 0x150B000. Unblocks sigil 3.0.
- **v5.5.38 — parser/lexer refactor**: `parse.cyr` (4971 LOC) split via nested `include` into 6 files (parse.cyr itself reduced to 891 LOC). `lex.cyr` (2355 LOC) split with `lex_pp.cyr`. Byte-identical at each stage.
- **v5.5.39 — legacy cc3 retirement**: `src/cc/` + `src/compiler*.cyr` deleted (3,333 LOC). Fixed `cyrius self` subcommand (silently broken since v5.0.0).
- **v5.5.40 — real closeout**: `heapmap.sh` regex whitespace fix (`  +` → ` +`) — had been silently dropping 26/72 heap regions. Dead code removed (`EMITPE_OBJ`, `PARSE_ASSIGN`). aarch64 guard in `parse_fn.cyr` around raw x86 `EB()` emit. cc5 = 507,136 B. 19/19 gates on x86_64.

Deferred to v5.6.x+:
- HIGH_ENTROPY_VA investigation.
- Phase 3-full varargs (va_arg for structs-by-value + nested varargs + callee float dup).
- Phase 2b-aarch64 struct copy (LDRB/STRB loop).
- Shared-object emission (pinned v5.6.7).
- O1–O6 optimizations (pinned v5.6.0–v5.6.5).
- Dynamic fixup sizing.

## v5.6.0–v5.6.40 — Polish + Optimization Arc + Bug Fixes (closeout v5.6.41 active)

- **v5.6.0 — parse.cyr arch-guard cleanup**: PARSE_SWITCH x86 jump-table gating, PARSE_FIELD_LOAD sub-byte movzx aarch64 hard-error, closure address arch dispatch, x87/SSE intrinsic aarch64 hard-error. cc5 507,136 → 508,880 B.
- **v5.6.1 — `#else`/`#elif`/`#ifndef` preprocessor**: per-level state stack at heap 0x97F10 (4-state encoding: EMITTING/SEARCHING/DONE/OUTER_SKIP). cc5 → 515,344 B.
- **v5.6.2 — explicit overflow operators**: 9 tokens (`+%/-%/*%` wrap, `+|/-|/*|` saturate, `+?/-?/*?` checked). Sat/checked compile to `lib/overflow.cyr` calls; checked-panic exit=57. cc5 → 518,984 B.
- **v5.6.3 — `#must_use` + `@unsafe` attributes**: `fn_flags` table at 0xFC000. `#must_use` fires on bare-statement discard; `@unsafe` block-form with nested-warning. cc5 → 522,920 B.
- **v5.6.4 — `#deprecated("reason")`**: `fn_flags` bit 2 + `fn_deprecated_msg` at 0x104000. Diagnostic at every call site. Closes the v5.6.1–v5.6.4 polish arc (+16,464 B). cc5 → 525,344 B.
- **v5.6.5 — Phase O1: FNV-1a FINDFN + PROF baseline**: 16 KB hash at 0x10C000 (8192 slots, load factor 0.5). `CYRIUS_PROF=1` total-compile-time reporter (`clock_gettime` syscall). `docs/development/benchmarks.md` baseline (409 → 402 ms median, −1.7 %; FINDFN not the hot path). cc5 → 526,888 B.
- **v5.6.6 — CYRIUS_PROF cross-platform**: PE via `kernel32!GetTickCount64` (`EGETTICKS_PE`); macOS Mach-O via `libSystem._clock_gettime_nsec_np` (`__got` 6→7 slots). cc5 → 528,144 B.
- **v5.6.7 — Phase O2 cat 1/5: strength reduction**: `x * 2^n → shl/lsl`. `ESHLIMM`/`ESHRIMM` + `_TRY_MUL_BY_POW2`. **First optimizer that modifies generated bytes**; established 3-step fixpoint pattern. cc5 → 526,272 B (−1,872 B).
- **v5.6.8 — Phase O2 cat 2/5: flag-reuse + `test rax, rax`**: `_flags_reflect_rax` tracker; replaces ECONDCMP's 10-byte dance with 3-byte `test`. cc5 → **504,416 B (−21,856 B / −4.15 %)** — biggest single-patch optimizer win of v5.6.x. Self-host time 405 → 355 ms (−12 %).
- **v5.6.9 — Phase O2 cat 3/5: redundant push/pop elim**: `_last_push_cp` tracker. 381 adjacent `50 58` pairs → 0. cc5 → 504,000 B (−416 B).
- **v5.6.10 — Phase O2 cat 4/5: commutative combine-shuttle elim**: 7-byte `mov rcx,rax; pop rax; op rax,rcx` → 4-byte `pop rcx; op rax,rcx` for ADD/AND/OR/XOR/IMUL. 5,861 sites → 0. cc5 → **487,040 B (−16,960 B / −3.37 %)** — #2 single-patch win. Scope retargeted from dead-end LEA-literal pattern (0 matches in cc5).
- **v5.6.11 — Phase O2 cat 5/5: aarch64 combine-shuttle elim — closes Phase O2**: ported v5.6.10 to aarch64 (`parse.cyr`'s combine codegen is shared across backends). 4,419 sites → 0. Native aarch64 cc5 → **453,688 B (−17,672 B / −3.75 %)**; x86 cc5 unchanged. Surfaced 3 broad-scope failures (Pi native self-host `_TARGET_MACHO`, macOS Sequoia dyld drift, Windows 11 24H2 loader drift) — none codegen issues; pinned v5.6.25/26/27 repair slots.
- **v5.6.12 — Phase O3a: IR-instrument parse emits**: 15 `IR_RAW_EMIT` markers across `parse_*.cyr` covering every direct-emit block. LASE/DBE enable attempt surfaced a pre-existing correctness bug (811 candidates corrupted cc5); rolled back. Fix pinned v5.6.14.
- **v5.6.13 — `lib/sha1.cyr` extraction (quick-win)**: promoted `_wss_sha1` to first-class stdlib module with NIST-vector regression. Pulled forward from v5.6.21. Zero compiler change.
- **v5.6.14 — Phase O3a-fix: LASE correctness**: root-caused to `parse_ctrl.cyr`'s loop constructs missing IR_NOP landing-pad markers (4 sites) — `ir_build_bbs` didn't split at loop tops, letting LASE eliminate LOAD_LOCALs valid only on first entry. Also closed RAX-clobber coverage gap with new `IR_RAX_CLOBBER` opcode for EMULH/EIDIV/ELODC. LASE eliminations 811 → 564.
- **v5.6.15 — IR-emit-order audit fix**: 5-LOC fix in `ESETCC` — moved `_IR_REC1(IR_SETCC)` AFTER `ECMPR(S)` (which records `IR_CMP`). IR stream said SETCC→CMP, byte stream emitted cmp→setcc. Now agrees. Bytes unchanged at IR=0; SETCC→CMP IR adjacency 3,665 → 0; CMP→SETCC 0 → 3,665.
- **v5.6.16 — Phase O3b part 1/2: IR const-fold (DCE deferred)**: forward state-machine sweep over IR detects `LOAD_IMM(a), PUSH, LOAD_IMM(b), [POP_RCX | MOV_CA + POP_RAX], OP` patterns the parse-time `_cfo` fold missed. 130 folds / 774 B NOP-fill at IR=3 on cc5 self-compile (recon predicted 128). Both fixpoints clean (IR=0 b==c, IR=3 b==c at 497,696 B). DCE skeleton (`ir_dce`) shipped but commented out — two correctness attempts corrupted cc5 even after expanding `_ir_uses_rax`; deferred to v5.6.17 per quality-before-ops + STOP-and-ask rules. **v5.6.22 re-pinned** to codebuf compaction (NOP harvest with jump+fixup repair) — sweeps all per-pass NOP overhead in one pass for real binary shrinkage; old slab-allocator scope reclaimable as future v5.7.x slot if v5.6.19 regalloc benchmarks warrant.
- **v5.6.22 — Phase O4c (partial): picker correctness fix + auto-enable infra (disabled by default)**: shipped two pieces, deferred default-on under a "v5.5.21 array-alignment regression" framing (v5.6.23 traced the actual cause to inline-asm + regalloc stack-frame layout — not alignment). (1) **Picker correctness**: v5.6.20's time-sliced register reuse silently broke loops — when an active interval expired and its register was reassigned, JMP_BACK to a position INSIDE the earlier interval's CP range read the register expecting the earlier value but found the new one. Surfaced during v5.6.22 auto-enable bisection on `PP_ALREADY_INCLUDED`'s nested while loops. Fix: extend `interval.last_cp = ra_end` for every interval — picker can no longer time-share registers (effectively reverts to single-register-per-local-for-whole-fn = greedy-equivalent). Proper time-sharing needs cross-BB liveness analysis (extend last_cp through backward edges) — pinned future slot. (2) **Auto-enable infra**: `CYRIUS_REGALLOC_AUTO_CAP=N` env knob (caps how many fns get auto-regalloc; -1 = disabled by default; N>0 opts in for first N fns), `_ra_auto_cap` + `_ra_auto_count` globals, gating in PARSE_FN_DEF, x86-only guard. Bisection methodology (v5.6.17 saved pattern) worked perfectly: AUTO_CAP=303 clean, =304 broken (PP_ALREADY_INCLUDED culprit); PICKER_CAP=2 clean, =3 broken (time-share REUSE was the trigger). Both fixpoints clean (IR=0 b==c, IR=3 b==c at 521,216 B). check.sh 23/23. cc5 grew +712 B for cap knob + time-share fix. Patra 1.6.0 verified folding cleanly.
- **v5.6.25 — aarch64 push/pop-cancel completion (scope retargeted from fused ops)**: bytescan under v5.6.24 default-on regalloc found 0 `mul+add` / 0 `mul+sub` / 0 `lsr+and-imm` adjacent pairs across native aarch64 cc5 + math-heavy tcyr tests (bigint, u128, keccak, sha1, hashmap, vec, base64). Cyrius's stack-machine IR keeps a push between every sub-expression result and its consumer, so the fused-op window never opens without a separate IR-level push-elision pass (pinned future slot). Bytescan instead surfaced **2,569 adjacent `push x0; pop x0` pairs** in native aarch64 cc5 — a latent gap in v5.6.9's cancel mechanism. `EPOPR` checks `GCP == _last_push_cp` and rewinds past the push for no-op cases; `EPOPARG(S, n)` emits the SAME `ldr xN, [sp], #16` for N=0..7 (for N=0 the encoding is identical to EPOPR's 0xF84107E0) but never did the adjacency check. Every 1-arg call site (`EPUSHR; ECALLPOPS(1) → EPOPARG(S, 0)`) paid 8 bytes of redundant push+pop. **Fix**: 13-LOC addition in `src/backend/aarch64/emit.cyr::EPOPARG` mirroring EPOPR's rewind, gated on `n == 0`. Native aarch64 cc5 **517,376 → 497,008 B (−20,368 B / −3.94%)** — bigger than v5.6.11's aarch64 combine-shuttle shrinkage (−17,672 B). Residual push/pop adjacent pairs: **0**. x86 cc5 unchanged at 542,928 B (3-step fixpoint IR=0 and IR=3 clean). check.sh 23/23; Pi broad-scope `syscall(93, 42)` exits 42. No cascade — slot used as pinned.
- **v5.6.24 — Default-on regalloc + SysV ECALLPOPS callee-saved clobber fix**: shipped two pieces in one slot (consolidating v5.6.25 sandhi-reported live-across-calls — same root cause). (1) **The bug**: SysV `ECALLPOPS` for n>6 args used r12-r14 as scratch in the stack-arg shuttle (pop top extras to r11/r12/r13/r14, pop 6 reg args, re-push extras). r12-r14 are CALLEE-SAVED in SysV; pre-regalloc this was harmless because cyrius didn't emit r12-r14, but under v5.6.20+ regalloc the picker pinned caller's locals to those exact registers, so 8+ arg calls silently corrupted the locals. Surfaced as the `flags.tcyr test_str_short → test_defaults` bisection failure (AUTO_CAP=118; test_str_short's `_argv(3, ...)` 9-arg call clobbered r12 holding fs in test_defaults's frame) AND the sandhi-reported "live-across-calls" boxing workaround on `sandhi_http_response_parse` (var headers silently zeroed by downstream call). **Fix**: rewrote SysV `ECALLPOPS` n>6 path to use only r10 (caller-saved) via direct `[rsp+offset]` MOV addressing — no pops; load 6 reg args directly from stack; shift extras from `[rsp+0..(nextra-1)*8]` to `[rsp+48..]` via r10; `add rsp, 48` to drop reg-arg slots. Old/new positions never overlap for any nextra in [1, 5]. (2) **Default-on flip**: `_ra_auto_cap` default changed from -1 (disabled) to "uncapped". Every eligible fn (x86 + no asm body) now auto-regalloc'd. `CYRIUS_REGALLOC_AUTO_CAP=0` env var disables. cc5 522,624 → 542,928 B (+20,304 B for save/restore overhead), aarch64 cross 400,872 → 419,776 B, win cross 516,200 → 537,896 B. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 542,928 B). check.sh 23/23, all 84 .tcyr PASS. v5.6.25 sandhi-pinned `fdlopen_init_full` and `lib/tls.cyr` HTTPS infinite-loop deferred (no slot yet — orthogonal investigations). Cascade -1 (live-across-calls consolidated), closeout v5.6.36 → v5.6.35.
- **v5.6.23 — Misdiagnosis correction: inline-asm + regalloc stack-frame layout fix**: the v5.6.22 "alignment regression" was actually inline-asm + regalloc layout collision. Regalloc's prologue saves rbx/r12-r15 to `[rbp-8]..[rbp-40]`, and local-var disps are computed as `-(idx + 1 + _cur_fn_regalloc) * 8` — shifting every local (including spilled params) 40 B further from rbp. Inline asm blocks hardcode disps like `mov rdi, [rbp-0x08]` to read param 1 (standard cyrius prologue); under auto-enable they now dereference the saved RBX value and SIGSEGV. Alignment probe confirmed the array VA was 16-aligned; crash is inside the asm on layout mismatch. Fix: `parse_fn.cyr` body-scan lookahead for token 48 (`asm`). Auto-enable silently skips; opt-in `#regalloc` on an asm fn warns and skips (`'<fn>': #regalloc skipped — fn contains inline asm (hardcoded stack offsets)`). Stdlib callers protected: `lib/fnptr.cyr`, `lib/thread.cyr`, `lib/atomic.cyr`, `lib/hashmap_fast.cyr`, `lib/u128.cyr`, `lib/thread_local.cyr`, `lib/fdlopen.cyr`, `lib/args_macos.cyr`. Default-on flip attempt still fixpoints cleanly (542,416 B) but surfaces a SECOND picker bug — bisection `CYRIUS_REGALLOC_AUTO_CAP=117/118` → 118 = `test_str_short` (5 vars, 2 calls) regalloc-enabling corrupts the NEXT fn `test_defaults`'s 5-arg `flags_add_int(fs, 0, "count", 7, "")` call (default_val 7 → 0). Independent of asm-skip (present) and NOP-fill (attempted and reverted within v5.6.23). Different shape from v5.6.22 loop-back time-share; pinned v5.6.24. Consumer-surfaced live-across-calls ("every loop counter / pointer crossing a patra call needs boxing") pinned v5.6.25 for clean attribution. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 522,624 B). check.sh 23/23. `regression-inline-asm-discard.sh` PASS under `CYRIUS_REGALLOC_AUTO_CAP=99999`. cc5 grew +1,408 B (521,216 → 522,624) for the body-scan lookahead. Regression-stub pin labels cascade +2 (v5.6.30/31/32 → v5.6.32/33/34); roadmap closeout v5.6.34 → v5.6.36. Slot count 34 → 36.
- **v5.6.21 — Codegen bug fix: bare-truthy `if (r)` after fn-call (patra-blocking)**: a v5.6.x regression surfaced by user testing — `var r = helper(); if (r) {...}` took the FALSE branch even when `r == 1`. Confirmed broken on v5.6.10/5.6.18/5.6.19/5.6.20; works on v5.5.27/5.5.40/5.6.5. Workaround across `src/*.cyr` (rewrite all `if (r)` → `if (r != 0)`) kept cc5 self-host clean but downstream consumers using idiomatic `if (r)` were hit (`tbl_find` silently returned -1). Root cause: v5.6.8's `_flags_reflect_rax` global tracker (Phase O2 cat 2) was not reset by 4 emit fns — EFLLOAD (`mov rax, [rbp+disp]`), ECALLFIX, ECALLTO, ESYSCALL — leaving stale flags from inside the callee. ECONDCMP's `_flags_reflect_rax` skip then emitted bare-truthy branches reading the wrong flags. **Fix**: 4 `_flags_reflect_rax = 0;` resets in `src/backend/x86/emit.cyr`. cc5 grew 520,456 → 520,504 B (+48 B). New regression test `tests/regression-truthy-after-fncall.sh` wired as check.sh gate 4r (22 → 23). Repro `/tmp/cyrius_5.6_codegen_bug.cyr` exits 99 (was -1). Patra 1.6.0 (just bumped at v5.6.20 for `sit` blob support) unblocked — folds in cleanly without `!= 0` workaround. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 520,504 B). Slot count 32 → 33 (closeout cascaded v5.6.32 → v5.6.33; +1 for the bug-fix slot inserted ahead of Phase O4c).
- **v5.6.20 — Phase O4b: Poletto-Sarkar linear-scan picker**: replaces v4.8.4 greedy use-count picker with proper Poletto-Sarkar 1999 linear scan over the v5.6.19 intervals. Algorithm: build interval list (count >= 2), insertion-sort by `first_cp` ascending (deterministic tie-break by lidx), walk forward, expire active intervals whose `last < cur.first`, assign free reg or apply spill heuristic = furthest next use. Time-sliced patch pass rewrites disp32 matches ONLY within `[first, last]` per assigned interval — non-overlapping intervals can share a register cleanly. Time-sliced sharing safety: cyrius requires `var x = expr;` for every user local so every interval starts with a STORE (no LOAD-from-stack needed at interval start). Safety scan still full-fn (any non-mov access bars regalloc). `CYRIUS_REGALLOC_PICKER_CAP=N` knob from day 1 for v5.6.21 bisection. Verified on 8-hot-locals spill-pressure test: 5 assigned, 3 spilled, ret=204 matches hand-computed expected. **Observable change on cc5 self-build = none** — cyrius source has zero `#regalloc` directives, picker only fires on opt-in fns. Infrastructure proven correct; v5.6.21 auto-enable surfaces the actual win. cc5 grew +11,576 B for picker algorithm + sort + active-set + bisection knob. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 520,456 B). check.sh 22/22. Patra dep bumped 1.5.5 → 1.6.0 (blob support for `sit` consumer).
- **v5.6.19 — Phase O4a: per-fn live-interval infrastructure**: first of three Phase O4 sub-slots. Originally pinned as full Poletto-Sarkar linear-scan in one slot (~600-900 LOC); structural reality (no vreg layer, no cross-BB liveness, every emit fn hardcoded RAX/RCX) made one-slot infeasible. Split into v5.6.19 (live-interval infra) + v5.6.20 (Poletto-Sarkar picker) + v5.6.21 (time-sliced rewrite + auto-enable + bisection). v5.6.19 ships ~80 LOC: extends the existing v4.8.4 `#regalloc` peephole's codebuf scan to also build per-local `ra_first[2048]` + `ra_last[2048]` interval tables alongside `ra_counts[2048]`. Fixed pre-existing latent sizing bug — v4.8.4 declared `ra_counts[256]` (256 BYTES) but wrote 256 i64s = 2048 bytes; overflow landed in adjacent global memory; existing peephole tolerated it because high-idx use-counts default to 0; interval tracking can't tolerate stale values so all three arrays sized correctly. `CYRIUS_REGALLOC_DUMP=1` env knob prints per-fn header + per-local intervals for verification before v5.6.20 picker wires up. No codegen change yet — picker still greedy use-count. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 508,880 B). check.sh 22/22. cc5 grew +7,264 B for the two new arrays + dump path + properly-sized ra_counts. Slot count grew 30 → 32 (closeout cascaded v5.6.30 → v5.6.32; +2 for the Phase O4 split).
- **v5.6.18 — Phase O3c: dead-store elimination + fixed-point driver**: recon-driven scope split — copy-prop deferred to v5.6.19 (110 candidates / 0 B direct savings on cyrius's stack-machine IR; LOAD-for-LOAD rewrite is byte-equal; cascade-only value). DSE per-BB forward sweep: for each `STORE_LOCAL(x)`, scan forward in same BB; if another `STORE_LOCAL(x)` precedes any `LOAD_LOCAL(x)` or opaque op (CALL/SYSCALL/RAW_EMIT/&local), the first is dead. `CYRIUS_DSE_CAP=N` knob from day 1. Fixed-point driver: loop fold → DCE → DSE under `CYRIUS_IR=3` until no candidates fire (3 iterations on cc5 self-compile; const-fold count grew 132 → 135 as DCE+DSE removed wrapping ops). **15 DSE kills + 6,099 B total NOP-fill at IR=3** (135 folds + 678 DCE + 15 DSE + 567 LASE = 1,395 candidates). Both fixpoints clean (IR=0 b==c, IR=3 b==c at 501,616 B). cc5 grew +2,896 B for `ir_dead_store` + cap knob + fixpoint loop. Slot count grew 31 → 32 (closeout cascaded v5.6.30 → v5.6.31).
- **v5.6.17 — Phase O3b-fix: bitmap liveness + DCE**: ships the v5.6.16-deferred half alone; copy-prop + dead-store + fixed-point cascaded to v5.6.18. Per-BB backward sweep with u64 liveness bitmap (bit 0 = RAX, bit 1 = RCX). v5.6.16's hidden bug found via `CYRIUS_DCE_CAP=N` bisection (cap=2 OK, cap=3 broke) + per-kill IR context dump: kill #3 was a `MOV_CA` before a `CLBRA`-protected sequence. `IR_RAX_CLOBBER` (recorded by EMULH/EIDIV/ELODC) reads RCX as operand/divisor/address but v5.6.16 had it in `_ir_def_rcx_any` (treating it as a writer). Same misclassification for `IR_ADD_IMM_X1` and `IR_RAW_EMIT`. Three-line fix. **678 DCE kills, 2,010 B NOP-fill** at IR=3; combined with const-fold: 132 folds + 678 DCE + 566 LASE = 6,771 B total NOP-fill. Both fixpoints clean (IR=0 b==c, IR=3 b==c at 498,720 B). cc5 grew +1,024 B for DCE wiring + `CYRIUS_DCE_CAP` debug knob. Bisection methodology saved as a debug knob for future IR-walking-pass audits. Slot count grew 30 → 31 (closeout cascaded v5.6.29 → v5.6.30).
- **v5.6.26 — peephole refinement + v5.6.25 doc/CHANGELOG completion**: EPOPARG `n == 0` adjacency-cancel block landed cleanly. Phase O5 maximal-munch slot dropped from the optimization arc — recon found 0 fused-op candidates (cyrius's stack-machine IR keeps a push between sub-expression results and consumers); push-imm rewrite has rax-side-effect + forward-jump-target issues. Pinned long-term, no slot — needs an IR-level push-elision pass first.
- **v5.6.27 — Phase O6: codebuf compaction (NOP harvest with jump+fixup repair)**: per-fn pass after picker; sweeps the 4-byte `0F 1F 40 00` NOP-fills via explicit tracking at every NOP-emit + disp32-emit site (no byte-scan — that false-positives on data bytes; v5.6.26 burned 43/84 .tcyr that way). New heap regions at 0xA0000 (jump-source) + 0xA2010 (NOP runs) + 0xA6010 (fn-start fixup baseline). Hooks in EJCC/EJMP/EJMP0/ECALLTO + the picker's load/store rewrites. Compaction sorts NOPs by CP, walks the jump-source table to recompute disp32s, shifts fixup-table CPs + jump-target CPs, then compacts bytes. Gates: x86 only, kmode≤1, IR=0, no table overflow. **cc5 542,928 → 531,392 B (−11,536 B / −2.13%)**. check.sh 23/23. IR=3 NOP harvest pinned future slot.
- **v5.6.28 — `cyrius init` scaffold gaps (owl-surfaced) + audit-pass cleanup**: 5 ergonomic fixes — (1) write the advertised `src/test.cyr` stub (was ENOENT on `cyrius test`); (2) global `cyrius.toml` → `cyrius.cyml` in agent CLAUDE.md presets + src/main.cyr + tests/* headers; (3) dry-run output rebuilt to mirror the real writer set 1:1; (4) `--description=<str>` flag with `<name> — TODO` placeholder default; (5) "already exists" hint now points at `cd $NAME && cyrius init --language=none .`. Audit extras: bare `cyrius test` in CI workflow + README, dropped dead `lib/agnosys/` and `scripts/` empty mkdirs. No compiler change. check.sh 23/23, cc5 byte-identical.
- **v5.6.29 — sandhi-surfaced `lib/tls.cyr` HTTPS infinite-loop fix**: `_tls_init` now runs `dynlib_bootstrap_cpu_features()` + `_tls()` + `_stack_end(0)` before `dynlib_open("libcrypto.so.3")` / `libssl.so.3`, per `lib/dynlib.cyr:939-946`'s libc consumer requirement. Pre-fix symptom: `http-probe https://example.com/` prints "GET https://example.com/" hundreds of times per second until killed. tls.tcyr 22/22, check.sh 23/23, cc5 byte-identical. fdlopen half (sandhi misdiagnosis §1-2) split to v5.6.29-1 hotfix.
- **v5.6.29-1 — undef-fn call sites SIGILL (sandhi misdiagnosis hotfix)**: emergency hotfix for the sandhi-side fdlopen misdiagnosis. Sandhi's probes were missing `include "lib/dynlib.cyr"`; the undef `dynlib_open` call compiled to a placeholder disp32 that coincidentally landed at `0x400076` (two bytes before entry trampoline) → re-entered main → looked like an infinite ENTRY loop. Cyrius-side fix: undef-fn calls now patch the call site to `0F 0B 0F 0B 90` (ud2; ud2; nop) on x86, `UDF #0` on aarch64 → SIGILL instead of silent looping. fdlopen has been complete since v5.5.34 (tests/tcyr/fdlopen.tcyr 40/40 PASS verified). Sandhi's native UDP DNS resolver workaround was never necessary. cc5 +224 B.
- **v5.6.30 — preprocessor `#derive` past-cap phantom-byte fix (libro 2.0.5 unblocked)**: `PP_IFDEF_PASS` copies preprocessed content back to `S+0` capped at 524288 B (size of `input_buf`); the derive handlers (`PP_DERIVE_SERIALIZE`, `PP_DERIVE_DESER`, `PP_DERIVE_ACCESSORS`, shared `PP_PARSE_STRUCT_DEF`) read source from `S + ip`. Any `#derive` past offset 524288 read stale/zero bytes, wrote a corrupted struct definition to the preproc output buffer, and left a hole where the 0xff heap-state sentinel leaked through — LEX tripped on it as "non-ASCII byte (0xff)". Libro 2.0.5's `src/file_store.cyr:10` `#derive(accessors)` at offset ≈ 543565 was the first documented trigger. Fix: `src_base` parameter threaded through the derive helpers; PP_PASS passes `S` (source at S+0), PP_IFDEF_PASS passes `tmp` (full 1MB mmap buffer). `PP_DEFINE` / `PP_DEFINED` share the same latent read-cap bug; pinned for v5.6.40 closeout.
- **v5.6.31 — HIGH_ENTROPY_VA `cc5_win.exe` DWORD-into-qword post-call read fix**: 64-bit ASLR ships enabled. v5.5.35's MOVABS audit was a red herring. Real cause: `EREAD_PE` and `EWRITE_PE` post-call sequences used `mov rax, [rsp+0x28]` to load the bytes-read/written count from where ReadFile/WriteFile wrote a DWORD (4 bytes); 64-bit load picked up 4 bytes of stack garbage. Under DYNAMIC_BASE that garbage was reliably zero (Win loader pre-zeros stack); under HIGH_ENTROPY_VA the loader hands off a different stack region with non-zero garbage, so `n` came back as a 12-digit bogus number tripping `main.cyr:341`'s "input exceeds 512KB buffer" overflow check. Fix: 64-bit load → 32-bit `mov eax` (auto-zero-extends). HIGH_ENTROPY_VA now ships enabled by default in `_dllc = 0x0160`. 1779 DIR64 entries.
- **v5.6.32 — native aarch64 self-host on Pi 4 repaired**: `src/main_aarch64_native.cyr` was missing `include "src/common/ir.cyr"` that `src/main_aarch64.cyr` (the x86-hosted cross-compiler) received when v5.6.12 O3a shipped the `IR_RAW_EMIT` instrumentation markers. `parse_*.cyr` references `IR_RAW_EMIT` unconditionally; the native variant errored at parse time. Earlier `_TARGET_MACHO` framing was a stale symptom shape from pre-v5.6.12 source. 1-line fix. Native self-host fixpoint on Pi: `cc5_b == cc5_c` byte-identical at 463,768 B. `tests/regression-aarch64-native-selfhost.sh` flipped from skip-stub to active gate; wired into `check.sh` step 4o.
- **v5.6.33 — `regression-macho-exit` gate fixture rewrite (no compiler regression existed)**: premise was wrong; the slot was pinned on a `fn main() { syscall(60, 42); return 0; }` fixture exiting 1 not 42 on ssh ecb, attributed to "Sequoia dyld drift". Cyrius has no auto-invoked `main()` — top-level statements are the program entry. The argv prologue's branch-over-fn-bodies landed on the `EEXIT` tail (`movz x16,#1; svc #0x80` = BSD `_exit(x0)` on macOS) with `x0 = argc = 1` still resident from the prologue. Top-level `syscall(60, 42);` exits 42 cleanly. Gate rewritten with three tests covering `__got[0]=_exit`, `__got[1]=_write` (stdout bytes verified), and v5.6.11 peephole. Zero compiler change; cc5 byte-identical at 531,680 B. The v5.5.13 memory entry's "exit=42 verified" almost certainly used top-level syntax; the later-written fixture assumed an auto-call cyrius has never had.
- **v5.6.34 — stdlib `alloc` grow-undersize SIGSEGV fix (sit symptom 1 of 2)**: `lib/alloc.cyr` (Linux brk) + `lib/alloc_macos.cyr` (mmap) grew by a fixed `0x100000` step every time `_heap_ptr` crossed `_heap_end`, regardless of requested size. Any `alloc(size > 1 MB)` near the grow boundary returned a pointer past the brk/mmap — SIGSEGV on first tail-write. Filed by sit 2026-04-24 during S-33 triage of `sit status` SIGSEGV on 100-commit repo. Fix: Linux rounds new end up to next 1 MB grain; macOS loops 1 MB mmaps preserving the per-step contiguity guard. `lib/alloc_windows.cyr` separable. New gate `tests/tcyr/alloc_grow.tcyr` (10 assertions). cc5 byte-identical (uses raw `brk`, not stdlib).
- **v5.6.35 — sit symptom 2 closed via sankoch dep bump 2.0.1 → 2.0.3**: triage 2026-04-24 pinned the layer to sankoch's `zlib_compress` producing non-decompressible DEFLATE for sit-tree-shaped inputs (deterministic on input; reproduces from a 30-line standalone cyrius program). Eliminated: patra (1600+ standalone roundtrips clean), cyrius alloc (compressed buffer not mutated during patra_insert_row, pre/post checksums match for all 300 inserts), sit-side aliasing. 3 sankoch tags resolved it: 2.0.1 (53/300 bad) → 2.0.2 (51/53 fixed; 2 left) → 2.0.3 (0/300 bad). Cyrius v5.6.35 = `cyrius.cyml` sankoch pin 2.0.1 → 2.0.3 + active `tests/regression-sit-status.sh` gate. Zero compiler change; cc5 byte-identical at 531,680 B. Cyrius repro at `cyrius/docs/development/issues/repros/sankoch-2.0.1-deflate-non-roundtrip.{bin,cyr}`.
- **v5.6.36 — `regression-pe-exit` gate fixture rewrite (same v5.6.33 pattern, no Win11 24H2 regression)**: PE gate's `fn main() { syscall(60, 42); return 0; }` fixture never ran main(); entry prologue branched over the dead body to `EEXIT_PE` which calls `kernel32!ExitProcess(arg)` with whatever was in the arg-slot register on Win11 24H2 (= `0x40010080`, NTSTATUS-shape value). PowerShell reported `ApplicationFailedException` due to the 0x4 high-nibble (STATUS_SEVERITY_INFORMATIONAL). PE shape verified fine on Win11 24H2 (DllCharacteristics 0x0000 → 0x0160 byte-identical exit). Gate rewritten with three top-level-syntax tests. `CC_PE` retargeted from `build/cc5_win` (PE binary unrunnable on Linux) to `build/cc5_win_cross` (Linux ELF emitting PE). Zero compiler change; cc5 byte-identical at 531,680 B.
- **v5.6.37 — `SSL_connect` deadlock fix via fdlopen-based libssl loading**: sandhi M2 HTTPS unblocked. `dynlib_bootstrap_tls`'s zeroed TCB left libssl's recursive-mutex `__kind` field = 0 (non-recursive); `OPENSSL_init_ssl`'s same-thread re-entry deadlocked on futex at TCB+0x118 (CAS 0→1, CAS 1→2, futex(WAIT, 2) — no wakeup). Fix: `lib/tls.cyr::_tls_init` routes through `fdlopen_init_full` which runs ld-linux.so's full glibc init sequence (incl. `__libc_pthread_init`), then uses real `dlopen`/`dlsym` to load libssl. Verified end-to-end: handshake + HTTP round-trip to 1.1.1.1:443 → `HTTP/1.1 301 Moved Permanently`. New `tests/regression-tls-live.sh` gate. cc5 byte-identical at 531,680 B. **BREAKING for tls.cyr consumers:** must add `include "lib/fdlopen.cyr"` before `include "lib/tls.cyr"` (preprocessor 1 MB expanded-output cap prevents auto-include).
- **v5.6.38 — shared-object emission slot — premise check + dead `SYSV_HASH` removal**: verify-premise check (per v5.6.33/v5.6.36 lessons) showed `.so` emission already complete since v5.5.x. `tests/regression-shared.sh` (in check.sh as gate 4a) covers all four PIC surfaces (fn calls + string literal refs + mutable globals + DT_INIT) and continues to PASS. Roadmap framing was wrong — per glibc `dl-lookup.c`, chain-walk does pure strcmp, never hash compare; nbucket=1 makes `SYSV_HASH` genuinely unreachable. Slot deliverable: removed dead `SYSV_HASH` (14 LOC) + the misleading comment. cc5 −320 B (531,680 → 531,360); unreachable-fn count 25 → 24. `.gnu.hash` migration deferred to long-term considerations (no consumer needs faster lookup).
- **v5.6.39 — `cc5 --version` drift repair + hardcoded-literal removal**: starship-observation-caught regression: cyrius repo bumped to v5.6.38 but `cc5 --version` still said `5.6.29-1` — drifted across 9 consecutive releases. Root cause: `version-bump.sh`'s sed regex `[0-9]+\.[0-9]+\.[0-9]+\\n` didn't match the `-N` hotfix suffix; once 5.6.29-1 baked the literal in `src/main.cyr`, every subsequent bump silently failed. `src/main_win.cyr` had even worse drift — stuck at `5.5.0` since v5.5.0 (regex never swept it). Fix: removed the hardcoded-literal class entirely — new auto-generated `src/version_str.cyr` is the single source of truth; `main.cyr` + `main_win.cyr` `include` it and reference vars. version-bump.sh writes the file via heredoc — no regex, no per-file sweeping, no `-N` suffix vulnerability. cc5 rebuilt: 531,360 → 531,584 B (+224 B for include + var refs); 3-step self-host byte-identical; `cc5 --version` correctly reports v5.6.39. Closeout cascaded v5.6.39 → v5.6.40.
- **v5.6.40 — `lib/tls.cyr` ALPN/mTLS hook surface (sandhi-blocking)**: pinned 2026-04-24 by `sandhi/docs/issues/2026-04-24-stdlib-tls-alpn-hook.md`. `lib/tls.cyr` exposed `tls_connect(sock, host)` only; sandhi could not set ALPN protocols, install a custom verify callback, or pin a client cert without forking the stdlib module. Implemented Option A from the filing (fn-pointer hook). Three additions in `lib/tls.cyr`: (1) `_tls_libssl_handle` global, captured inside `_tls_init` from the `dlopen("libssl.so.3")` return; (2) `tls_dlsym(name)` resolves any libssl/libcrypto symbol via the existing fdlopen-managed handle (returns 0 if TLS not initialized or symbol missing — no new bootstrap on the call path); (3) `tls_connect_with_ctx_hook(sock, host, hook_fp, hook_ctx)` invokes `hook_fp(hook_ctx, ssl_ctx)` after `SSL_CTX_new` + the stdlib's verify defaults but BEFORE `SSL_new` (non-zero return aborts). `tls_connect` collapsed to a 1-line wrapper passing zeros — no behavior change for existing callers. End-to-end ALPN probe to Cloudflare 1.1.1.1:443 advertising `h2,http/1.1` via `SSL_CTX_set_alpn_protos` in the hook + reading `SSL_get0_alpn_selected` after handshake → server picked `h2`. `tests/tcyr/tls.tcyr` gained 4 assertions (`tls_dlsym` resolves the two ALPN syms, returns 0 for unknown sym, returns 0 when fdlopen helper absent). cc5 byte-identical at 531,584 B (no compiler change). check.sh 25/25.

- **v5.7.0 — THE SANDHI FOLD (clean-break consolidation)**: per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). `lib/sandhi.cyr` adds (vendored byte-identical from `sandhi/dist/sandhi.cyr` at v1.0.0 tag, 376,037 B / 9,649 lines / 469 fns covering M0–M5: HTTP client + server + HTTP/2 + streaming + JSON-RPC + service discovery + TLS policy); `lib/http_server.cyr` deletes (no alias, no passthrough); `tests/tcyr/http_server.tcyr` deletes with the lib (suite 68 → 67 files). 17 deprecated `http_*` fns confirmed 1:1-mapped to `sandhi_server_*` pre-fold. `scripts/lib/audit-walk.sh` extended to skip `cyrius distlib`-generated files (marker-based, complements symlink-based skip for `cyrius deps` deps; dep skip count 6 → 7). Acceptance gates 1, 2, 5, 6 ✅; gates 3 + 4 (downstream sweep across yantra/hoosh/ifran/daimon/mela/vidya/sit/ark — sit-remote and ark-remote turned out to be stale planning names) are separate user-organized work. Audit confirmed only **vidya** actually `include`s `lib/http_server.cyr`; yantra and sit have orphan pre-fold copies (cleanup-only); hoosh/ifran/daimon/mela/ark have no v5.7.0 work. Sandhi repo enters maintenance mode. Zero compiler change → cc5 byte-identical at 531,888 B; check.sh 26/26 PASS.

- **v5.7.1 — fixup-table cap bump 32K → 262K (sit-blocking ecosystem unblock)**: per [sit's proposal](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md). Hardcoded 32,768-entry fixup table overflowed when consumers added `"sandhi"` to `[deps].stdlib` — sandhi alone burns ~2,350 fixups (469 fns × ~5/fn). Affected all 8 named consumers (vidya/yantra/hoosh/ifran/daimon/mela/ark/sit). Wedged into v5.7.1 ahead of cyrius-ts foundational work (cascaded to v5.7.2) via git-rewind to v5.7.0 + fixup-cap commit + cherry-pick of preserved cyrius-ts P1 work from `wip/cyrius-ts-p1` branch. Cap bumped 32,768 → 262,144 (8×; 4 MiB table). 16 cap-check sites updated across 5 backend files (proposal listed 5; x86 backend was missing from proposal's grep + aarch64 had a variant string format `"/32768)"` we caught). Brk extended +3.5 MB across 4 main entry files. Pre-existing off-by-2x percentage math bug at `main.cyr:1073` (stale `/ 16384` divisor from a previous cap-bump generation) corrected in passing. cx backend cap bumped uniformly but cx's smaller heap layout left untouched. cc5 self-host fixpoint clean at 531,880 B (8 B smaller than v5.7.0 from constant-change byte-shift). check.sh 26/26 PASS.
