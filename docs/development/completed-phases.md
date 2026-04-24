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

## v5.6.0–v5.6.16 — Polish + Optimization Arc (in progress)

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
- **v5.6.16 — Phase O3b part 1/2: IR const-fold (DCE deferred)**: forward state-machine sweep over IR detects `LOAD_IMM(a), PUSH, LOAD_IMM(b), [POP_RCX | MOV_CA + POP_RAX], OP` patterns the parse-time `_cfo` fold missed. 130 folds / 774 B NOP-fill at IR=3 on cc5 self-compile (recon predicted 128). Both fixpoints clean (IR=0 b==c, IR=3 b==c at 497,696 B). DCE skeleton (`ir_dce`) shipped but commented out — two correctness attempts corrupted cc5 even after expanding `_ir_uses_rax`; deferred to v5.6.17 per quality-before-ops + STOP-and-ask rules. **v5.6.21 re-pinned** to codebuf compaction (NOP harvest with jump+fixup repair) — sweeps all per-pass NOP overhead in one pass for real binary shrinkage; old slab-allocator scope reclaimable as future v5.7.x slot if v5.6.18 regalloc benchmarks warrant.
