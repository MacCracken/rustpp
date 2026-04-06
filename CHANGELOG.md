# Changelog

All notable changes to Cyrius are documented here.
This is the **source of truth** for all work done.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.5.1] — 2026-04-06

### Fixed — Tooling
- **cyrb empty environment**: all `execve` calls passed empty `envp`, breaking shell script
  subcommands (`cyrb port`, `cyrb coverage`, etc.) when run outside the repo root
  - Added `load_environ()` to read `/proc/self/environ` and pass through to child processes
  - cyrb binary: 58KB → 59KB (+832 bytes)
- **install.sh missing companion scripts**: only `cyrb-init.sh` was installed; `cyrb-port.sh`,
  `cyrb-coverage.sh`, `cyrb-doctest.sh`, `cyrb-repl.sh`, `cyrb-header.sh` were never copied
  - Install and version manager now dynamically pick up all `cyrb-*.sh` scripts
- **compiler.sh wrong default**: test suite defaulted to `./build/cc` (bridge compiler, 60KB)
  instead of `./build/cc2` (full compiler, 136KB), causing 115 false failures

### Metrics
- Compiler: 136KB (unchanged)
- cyrb: 59KB (was 58KB)
- 212 tests, 0 failures
- Self-hosting: byte-identical

## [1.5.0] — 2026-04-06

### Refactored — Compiler
- **EMITELF/EMITELF_SHARED dedup**: factored 95% duplicate ELF emission into `EMITELF_USER(S, etype)`
  - ET_EXEC (2) and ET_DYN (3) now share one code path with e_type parameter
  - Compiler shrunk from 138KB to 136KB

### Refactored — Standard Library
- **process.cyr**: extracted `_exec3(cmd, arg1, arg2)` helper — eliminated 3x copy-pasted argv building
- **bounds.cyr**: extracted `_bounds_fail()` and `_bounds_neg()` — eliminated 4x copy-pasted error reporting

### Fixed — Stale Comments
- lex.cyr preprocessor comment: updated 0x90000 → 0x222000 to match actual buffer location

### Removed — Dead Code
- tagged.cyr: removed commented-out `option_map()` (lines 80-85)
- cc_bridge.cyr: removed unused `GMJP()/SMJP()` accessors
- scripts/cyrb-cffi.sh: removed (not wired into cyrb dispatcher)
- scripts/cyrb-symbols.sh: removed (not wired into cyrb dispatcher)

### Fixed — Documentation
- benchmarks.md version updated from 0.9.0-pre to 1.5.0

### Metrics
- Compiler: 136KB (was 139KB — 3KB saved from dedup)
- 263 tests, 0 failures
- Self-hosting: byte-identical

## [1.4.0] — 2026-04-06

### Added — Tooling
- **cyrb.cyr**: full Cyrius replacement for shell dispatcher (58KB binary)
  - 25+ subcommands: build, run, test, bench, check, self, clean, init, package,
    publish, install, update, port, header, fmt, lint, doc, vet, deny, audit,
    coverage, doctest, repl, version, which, help
  - Tool discovery: finds cc2 via ~/.cyrius/bin/ or ./build/ dev mode
  - VERSION file reading, --aarch64 cross-compilation flag
  - Delegates to companion tools (cyrfmt, cyrlint, cyrdoc, cyrc) and shell scripts
- **`cyrb port`**: one-command Rust→Cyrius project scaffolding
  - Moves Rust to rust-old/, creates src/lib/programs/tests dirs
  - Vendors stdlib from installed Cyrius
  - Generates main.cyr skeleton, cyrb.toml, test script
  - Tested on vidhana (228 lines) — compiles and runs

### Fixed — Compiler
- **String data buffer overflow**: expanded str_data from 2KB to 32KB (0x69000 → 0x61000)
  - Programs with >2KB of string literals would silently corrupt str_pos/data_size
- **Preprocessor output buffer**: wired PREPROCESS to use 0x222000 (256KB) instead of 0x91000
  - Old buffer overlapped tok_types at 0xA2000 after ~68KB of expanded source
  - The 256KB buffer was allocated at brk but never connected to the preprocessor
- **Fixup table overflow**: relocated from 0x8A000 to 0x262000, expanded to 2048 entries
  - Old table had only ~528 usable entries before overlapping compiler state at 0x8C100
  - Programs with >500 function calls + string literals would corrupt compiler state
  - brk extended from 0x262000 to 0x26A000

### Improved — Documentation
- Inline assembly section added to cyrius-guide.md (stack layout, param offsets)
- Known limitations updated (removed fixed items, added gotchas)

### Metrics
- Compiler: 139KB (138,400 bytes)
- cyrb binary: 58KB (58,616 bytes)
- 263 tests (212 compiler + 51 programs) + 26 aarch64, 0 failures
- First repo scaffolded: vidhana (228 lines Rust → Cyrius skeleton)

## [1.2.0] — 2026-04-06

### Added — Language
- **Address-based operator overloading**: `Vec3{10,20,12} + Vec3{32,22,30}` works
  - Multi-field structs pass addresses to operator functions (can read all fields)
  - Single-field / type-annotated vars pass values (backward compatible)
  - Dispatch based on variable allocation size: >8 bytes = address, =8 bytes = value

### Fixed — Documentation
- Updated known limitations in FAQ (removed fixed items, added gotchas section)
- Updated vidya limitations entry (marked block scoping/var-in-loop as fixed)
- Added doc comments to all 50 functions in lib/syscalls.cyr
- Documented dynamic loop bound gotcha in FAQ, vidya, and roadmap

### Added — Tests
- 10 new tests: address-based operators, enum constructors, shared compile, stress tests

### Metrics
- Compiler: 139KB
- 263 tests (212 compiler + 51 programs) + 26 aarch64, 0 failures

## [1.1.0] — 2026-04-06

### Added — Language
- **For-in over collections**: `for item in vec { body }` iterates over vec elements
  - Desugars to `vec_len` + index loop + `vec_get` per iteration
  - Works alongside range for-in (`for i in 0..10`)
  - Item variable scoped to loop body

### Changed
- Removed `lib/cyrius-ref/` — agnostik, agnosys, kybernet, nous live in own repos
- Promoted `lib/syscalls.cyr` to stdlib (was agnosys/syscalls.cyr)
- Removed reference test programs (agnostik_test, kybernet_test, nous_test)
- Synced kernel to agnos repo (source of truth)

### Added — Language
- **Enum constructors (auto-generate)**: `enum Result { Ok(val) = 0; }` auto-generates `Ok(42)`
  - Constructor registered in pass 1, body emitted in pass 2 function section
  - Uses alloc(16) to heap-allocate {tag, payload}
  - Root cause of initial bug: constructor body was emitted in main code (after JMP)
    instead of function section (before JMP). Fixed by adding `emit_code == 2` pass.

### Added — Tooling
- **Shared library output**: `shared;` directive emits ET_DYN ELF (recognized by `file` as shared object)
  - First step toward dlopen/dlsym FFI
  - Normal programs unaffected (default remains ET_EXEC)
  - Full .so with symbol tables requires PIC codegen (post-v1.1)
- `cyrb cffi` — C FFI wrapper generator (subprocess bridge)

### Metrics
- Compiler: 137KB
- 253 tests (202 compiler + 51 programs) + 26 aarch64, 0 failures

## [1.0.0] — 2026-04-06

### v1.0 — Sovereign, Self-Hosting Systems Language

**Cyrius v1.0 ships.** A sovereign, self-hosting compiler built from a 29KB seed
binary. No Rust. No LLVM. No Python. No libc. Assembly up.

### Added — Language
- **Block body closures**: `|x| { var y = x * 2; return y; }` (inside functions)
- Collection iteration via library: `vec_fold`, `vec_map`, `for_each` with closures

### Language Features (cumulative v0.1–v1.0)
- Structs, enums, switch, pattern matching (`match`), for-in range
- Functions (>6 params, recursion), closures/lambdas
- Floating point (f64, SSE2, 10 builtins, literals)
- Methods on structs (convention dispatch)
- Trait impl blocks (`impl Trait for Type { }`)
- Module system (`mod`, `use`, `pub`)
- Operator overloading (`+` `-` `*` `/` dispatch to Type_op)
- String type with 16 methods via dot syntax
- Block scoping, feature flags (`#define`/`#ifdef`/`#endif`)
- Generics Phase 1 (syntax parsed), enum constructor syntax
- Error messages with line numbers

### Toolchain
- 20+ cyrb commands (build, test, bench, fmt, lint, doc, vet, deny, audit, ...)
- cyrb repl, cyrb doctest, cyrb coverage, cyrb docs --agent
- C FFI header generation (`cyrb header`)
- Subprocess bridge (exec_vec, exec_capture, exec_env)
- Installer + version manager + release pipeline
- 45 benchmarks with CSV regression tracking

### Architecture
- x86_64: self-hosting, byte-identical
- aarch64: self-hosting, byte-identical on Raspberry Pi
- Portable syscall constants (SYS_*) for cross-architecture

### Quality
- 253 tests (202 compiler + 51 programs) + 26 aarch64, 0 failures
- `cyrb audit` → 10/10
- 5 ADRs, threat model, 37 vidya entries
- Migration strategy for 107 repos (~980K lines)

### Metrics
- Compiler: 128KB (x86), 130KB (aarch64)
- 35 stdlib modules, 200+ functions
- 57 programs, AGNOS kernel (62KB)
- 5 crate rewrites completed (wave 0)
- 29KB seed → working OS in 128KB

## [0.10.0] — 2026-04-06

### Added — Tooling
- **C FFI header generation**: `cyrb header lib/mylib.cyr > mylib.h`
  - Scans for `pub fn` declarations, emits C prototypes with `cyr_val` (int64_t)
  - Enables C/Rust code to know Cyrius function signatures

### Added — Tests
- 34 new compiler tests across 8 categories:
  - Nested structs, deep scoping, preprocessor edge cases
  - Comparison edge cases, arithmetic edge cases
  - Function edge cases (recursion, early return, chained calls)
  - String/load/store, enum edge cases
  - Combined feature tests (match in for-in, impl chains, typed operators)
- **251 total tests (200 compiler + 51 programs), target of 250 achieved**

### Added — Documentation
- **Migration strategy** (docs/development/migration-strategy.md)
  - Full survey: 107 repos, ~980K lines, 6 migration waves
  - Per-repo sizing, dependency mapping, bridge strategies
  - Rust → Cyrius translation guide
  - Porting workflow template

### Improved — Libraries
- Hashmap: added `map_values()`, `map_clear()`, formatting cleaned
- Deep code audit: all encodings verified, tombstone logic confirmed correct
- Shared library (.so) deferred to post-v1.0 — subprocess bridge covers migration needs

### Fixed — aarch64
- **BYTE-IDENTICAL SELF-HOSTING ON REAL ARM HARDWARE**
  - cc3 == cc4 = 129,760 bytes on Raspberry Pi
  - Root cause: aarch64 `openat` (syscall 56) requires `AT_FDCWD` (-100) as first arg
  - Fix: READFILE detects architecture and passes correct args
- Write loop for large ELF output (both x86 and aarch64)

### Metrics
- Compiler: 128KB (x86), 130KB (aarch64)
- 251 tests (200 compiler + 51 programs) + 26 aarch64, 0 failures
- aarch64 self-hosting: byte-identical on Raspberry Pi
- `cyrb audit` → 10/10

## [0.9.12] — 2026-04-06

### Added — Libraries
- **Enhanced subprocess bridge** in process.cyr:
  - `exec_vec(args)` — run command with variable args via vec
  - `exec_capture(args, buf, buflen)` — capture stdout with variable args
  - `exec_env(args, env)` — run with custom environment variables
  - `exec_cmd(cmdline)` — split string and execute (convenience)
  - Enables calling external tools: `nvidia-smi`, `python3`, `node`, `cargo`, etc.

### Added — Roadmap
- Shared library output (.so) — emit ET_DYN ELF for FFI bridging
- C FFI header generation — call Cyrius from C/Rust/Python
- Migration strategy: subprocess (now), protocol (v1.x), FFI (v1.x)

### Improved — Libraries
- **Hashmap cleanup**: added `map_values()`, `map_clear()`, formatting fixed
- Deep code audit: all instruction encodings verified, tombstone logic confirmed correct

### Added — Tests
- 12 new edge case tests: closures in functions, nested match, match expressions,
  nested for-in, for-in with expressions, operator chaining, typed locals/globals

### Added — Documentation
- Vidya language docs updated through v0.9.12 (traits, closures, strings, operators, subprocess)
- ai-hwaccel repo prepared for Cyrius port (Rust moved to rust-old/)

### Metrics
- Compiler: 128KB
- 217 tests (166 compiler + 51 programs) + 26 aarch64, 0 failures
- `cyrb audit` → 10/10

## [0.9.11] — 2026-04-06

### Added — Language
- **Operator overloading**: `a + b` dispatches to `Type_add(a, b)` when `a` has struct type
  - Works for `+`, `-`, `*`, `/` operators
  - Type tracked via `expr_stype` from variable load
  - Works with type-annotated locals and struct-literal globals
- Auto enum constructor syntax parsing (from v0.9.6) retained

### Added — Tests
- 3 operator overloading tests (add, sub, mul)

### Metrics
- Compiler: 128KB
- 205 tests (154 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.10] — 2026-04-06

### Added — Language
- **Closures / lambdas**: `|x| x * 2`, `|a, b| a + b` expression closures
  - Generates anonymous `__clN` functions, returns function pointer
  - Multi-param, zero-param (`|_| expr`), expression bodies
- **String type with methods**: `var s: Str = str_from("hello"); s.len(); s.contains("x")`
  - Type annotation `: Str` on local vars enables dot-call method dispatch
  - 16 Str method wrappers: len, data, print, println, eq, cat, sub, clone, contains, starts_with, ends_with, index_of, from_int, to_int, trim, split
  - Works for any struct type annotated with `: TypeName`
- **Local variable struct type tracking**: `: TypeName` annotations on locals set struct ID for method dispatch

### Metrics
- Compiler: 128KB
- 202 tests (151 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.9] — 2026-04-05

### Added — Language
- **Trait impl blocks**: `impl Trait for Type { fn method(self) { } }`
  - Methods mangled to `TypeName_method` (reuses module name mangling)
  - Multiple impl blocks for same type supported

### Added — Compiler Infrastructure
- Expression type tracking (`expr_stype`) — struct type of last expression
- Operator dispatch helpers (`BUILD_OP_NAME`, `EMIT_OP_DISPATCH`) for future use

### Added — Tests
- 3 trait impl tests (basic, mutate, multi-impl)

### Metrics
- Compiler: 124KB
- 199 tests (148 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.8] — 2026-04-05

### Added — Language
- **Pattern matching**: `match expr { val => { } _ => { } }` with scoped arms
- **For-in range loops**: `for i in 0..10 { }` with exclusive end, block-scoped iterator

### Milestone — aarch64
- cc3_aarch64 runs natively on real Raspberry Pi hardware
- ESCPOPS rewritten: pop-through-x0 fixes register mapping
- Syscall translation layer (x86→aarch64) with corrected MOVZ encodings
- SYS_* enum constants replace hardcoded syscall numbers in all shared code

## [0.9.7] — 2026-04-05

### Added — Language
- **Module system**: `mod name;`, `use mod.fn;`, `pub fn` for namespace + visibility
  - Name mangling: `mod math; fn add()` → registered as `math_add`
  - Use aliases: `use math.add;` lets you call `add()` which resolves to `math_add`

### Added — Tooling
- `cyrb coverage` — file/function-level test coverage reports
- `cyrb doctest` — run doc examples (`# >>>` / `# ===`) from .cyr files
- `cyrb repl` — interactive expression evaluator
- `cyrb docs --agent` — markdown server for bots/agents

### Added — Tests
- 6 new compiler tests: pattern matching (3), for-in range (3)
- aarch64 test suite expanded: 12 → 26 tests (arithmetic, control flow, functions, bitwise, load/store)
- `tests/aarch64-hardware.sh` — standalone test script for real ARM hardware

### Fixed
- `match` keyword collision: renamed `match` vars in grep.cyr and cyrb.cyr
- CI aarch64 test output redirect (stdout was contaminating exit code capture)

### Metrics
- Compiler: 120KB (x86), 110KB (aarch64)
- 196 tests (145 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.6] — 2026-04-05

### Added — Language
- **Enum constructor syntax**: `enum Result { Ok(val) = 0; Err(code) = 1; }` parses payload syntax
- **Feature flags**: `#define`, `#ifdef`, `#endif` preprocessor directives
  - Hash-based flag table (32 flags), nested ifdef with skip depth tracking

### Added — Tooling
- `cyrb docs [--agent] [--port N]` — serve project docs (HTML default, markdown for agents)
- `cyrb.toml` parser: `toml_get` + `read_manifest` (replaces grep/sed)
- `scripts/version-bump.sh` — update VERSION + install.sh in one command
- cyrb version now reads from VERSION file (matches project version)

### Added — Documentation
- 5 ADRs: assembly cornerstone, everything-is-i64, fixed heap, convention dispatch, two-step bootstrap
- Threat model (docs/development/threat-model.md)
- 10 vidya planned-feature implementation strategies

### Added — Tests
- Enum constructor tests (2), feature flag tests (3)

### Fixed — Compiler
- Self-hosting test: compares compiler.cyr output (was testing bridge compiler)

### Metrics
- Compiler: 110KB
- 186 tests (135 compiler + 51 programs) + 12 aarch64, 0 failures
- `cyrb audit` → 10/10, self-hosting verified, 14/14 vidya pass

## [0.9.5] — 2026-04-05

### Added — Language
- **Block scoping**: variables in if/while/for blocks don't leak to outer scope
  - Scope depth tracking, SCOPE_PUSH/SCOPE_POP, variable shadowing
- **f64 as statements**: f64 builtins now work in statement context

### Added — Tests
- 19 new compiler tests: float (12), methods (3), block scoping (4)
- 2 new test programs: floattest.cyr (13 assertions), hmtest.cyr (14 assertions)
- Float benchmark program (bench_float.cyr — 7 benchmarks)

### Metrics
- 181 tests (130 compiler + 51 programs) + 12 aarch64, 0 failures

## [0.9.4] — 2026-04-05

### Fixed — Compiler
- **Preprocessor**: string literals containing "include" no longer trigger file inclusion
  - Only checks for include directive at beginning of line (column 0)
- **Self-hosting test**: fixed to use `compiler.cyr | cc2 = cc3` comparison

### Added — Tooling
- `scripts/version-bump.sh` — update VERSION + install.sh in one command

### Added — Documentation
- Vidya: 9 new implementation entries (float SSE2, methods, line numbers, tok_names overflow, two-step bootstrap, preprocessor fix, hashmap tombstone, P-1 hardening pattern, self-hosting test)
- Vidya: f64 usage examples in type_systems, method dispatch in design_patterns
- Roadmap: added Completed section (v0.9.0–v0.9.4), cleared done items from active lists

### Metrics
- Compiler: 104KB, 222 functions
- 160 x86_64 + 12 aarch64 tests, 0 failures
- 14/14 vidya reference files pass

## [0.9.3] — 2026-04-05

### Fixed — Libraries (P-1 Hardening)
- **hashmap**: tombstone-based deletion (was breaking probe chains on delete)
- **vec**: `vec_remove` bounds check on index
- **alloc**: brk failure detection — returns 0 on OOM
- **json**: `json_get` null key/pairs guard

## [0.9.2] — 2026-04-05

### Added — Language
- **Floating point (f64)**: SSE2 codegen for double-precision math
  - `f64_from(int)`, `f64_to(f64)` — int/float conversion
  - `f64_add`, `f64_sub`, `f64_mul`, `f64_div` — arithmetic
  - `f64_eq`, `f64_lt`, `f64_gt` — comparison (returns 0/1)
  - `f64_neg(val)` — negation
  - Float literals: `3.14` lexed and converted at runtime
- **Methods on structs**: `point.scale(2)` dispatches to `Point_scale(&point, 2)`
  - Convention: `StructName_method(self, args)` — dot-call passes `&var` as first arg
  - Works in both expression and statement context
- **Error line numbers**: `error:3: unexpected token (type=5)` replaces `error at token 42`
  - Line tracking via `tok_lines` parallel array (65536 slots)
  - Warnings and duplicate-var errors also report line numbers

### Fixed — Compiler
- **tok_names buffer overflow**: expanded 32KB → 64KB, relocated var_noffs/var_sizes downstream
  - Root cause: ~48K bytes of identifiers overflowed 32K buffer into var_noffs at 0x58000
  - Manifested as "unexpected token" errors when adding >200 functions
  - Added bounds check in LEXID (error at 65000 bytes)
- **Token arrays expanded**: 32768 → 65536 slots (tok_types, tok_values, tok_lines)
- **Preprocessor output buffer relocated**: moved past token arrays to prevent overlap
- **f64 comparison flag bug**: `xor eax,eax` clobbers ZF from `ucomisd` — use `mov eax,0` instead
- **aarch64 brk sync**: matched x86 heap layout changes (brk, tok_lines, preprocessor)
- **aarch64 var_sizes fixup**: updated 0x58800 → 0x60800 in aarch64/fixup.cyr
- **aarch64 TOKVAL offset**: was reading tok_values from old 0xE2000 instead of new 0x122000

### Metrics
- Compiler: 104KB (was 96KB) — 222 functions across 7 modules + SSE2 emitters
- 160 x86_64 tests (111 compiler + 49 programs) + 12 aarch64 tests, 0 failures
- Self-hosting: byte-identical

## [0.9.1] — 2026-04-05

### Fixed — CI
- Program test suite stalling on system-dependent tests (fork/exec, apt-cache, python3)
- Moved 8 ecosystem tests (nous, ark, cyrb, kybernet, agnostik, kernel ELF) behind `--system` flag
- Added `timeout` guards to all system test executions
- Removed python3 dependency from CI (kernel ELF tests now in `--system` only)
- Program test count: 46 (was 57) in CI, full 57 available via `--system`

### Added — Benchmarks
- 3-tier benchmark suite: 38 benchmarks across stdlib, data structures, compiler/toolchain
- 6 benchmark programs: bench_string, bench_alloc, bench_vec, bench_hashmap, bench_fmt, bench_tagged
- `scripts/bench-history.sh` — automated CSV recording + BENCHMARKS.md trend generation
- `bench-history.csv` — persistent regression tracking (matches bhava/hisab pattern)
- `cyrb bench` — run full suite, tier (`--tier1`, `--tier2`), or single file
- CI benchmark job with artifact upload (tier 1+2, 90-day retention)
- v0.9.0 baseline established: self-compile 9ms, strlen 418ns, alloc 428ns, hashmap lookup 650ns

### Improved — Installer & Release
- Rewritten `scripts/install.sh` to match python/ruby/rust installer patterns
- Single tarball download: `cyrius-$VERSION-$ARCH-linux.tar.gz` (bins + stdlib + scripts)
- SHA256 checksum verification on download
- Version-specific layout: `~/.cyrius/versions/$VERSION/bin/` + `lib/`
- Bootstrap from source fallback with self-hosting verification
- Version manager (`cyrius`): added `uninstall`, `update`, `ls` alias
- Release workflow: dual-arch tarballs (x86_64 + aarch64), parallel builds
- Clean summary output showing installed components

### Improved — Tooling
- `cyrb bench` now dispatches to `bench-history.sh` (no args = full suite)
- Roadmap updated: benchmark history tracking marked complete, bhava/hisab pillar gaps prioritized

### Improved — Documentation
- Roadmap restructured with AGNOS pillar port critical path (3 tiers, 18 features)
- Changelog consolidated: all v0.9.0 work merged into single release entry
- Article updated with v0.9.0 metrics (93KB compiler, 186 tests, 38 benchmarks, 5 crate rewrites)

### Metrics
- 38 benchmarks across 3 tiers, self-compile: 9ms
- 157 x86_64 tests (111 compiler + 46 programs) + 29 aarch64 tests, 0 failures
- 35 library modules, 199 functions
- `cyrb audit` → 10/10 green

## [0.9.0] — 2026-04-05

### Added — Language
- Comparison expressions in function arguments (`f(x == 1)` produces 0/1 via `setCC`)
- `PARSE_CMP_EXPR` + `ESETCC` codegen — comparisons as value-producing expressions
- Generics syntax: `fn foo<T>()`, `struct Bar<T>` (parsed, not enforced)
- Tagged unions: `tagged.cyr` with Option (Some/None), Result (Ok/Err), Either
- Traits: `trait.cyr` with vtable-based dispatch (Display, Eq, From, Default)
- HashMap: `hashmap.cyr` with FNV-1a hash, open addressing, auto-grow
- Callback library: `callback.cyr` with vec_map, vec_filter, vec_fold, fork_with_pre_exec
- String enhancements: contains, starts_with, split, join, trim, builder, from_int/to_int
- String formatting: `fmt_sprintf` with %d, %x, %s, %%
- Bounds checking: `bounds.cyr` with checked_load/store
- JSON parser: `json.cyr` with parse, get, build
- Process library: `process.cyr` with run, spawn, capture
- Filesystem: `fs.cyr` with path ops, dir listing, tree walk
- Network sockets: `net.cyr` with TCP/UDP via syscalls
- Pattern matching: `regex.cyr` with glob match, find/replace
- `assert.cyr` test framework: `assert(cond, name)`, `assert_eq`, `assert_neq`, `assert_gt`, `assert_summary`
- 17 new compiler tests (8 comparison-in-args + 9 Phase 10 edge cases)

### Added — Tooling
- cyrb shell dispatcher (18 commands — build, run, test, bench, check, self, clean, init, package, publish, install, update, audit, fmt, lint, doc, vet, deny)
- cyrfmt (18KB) — code formatter
- cyrlint (26KB) — linter (trailing whitespace, tabs, line length, braces)
- cyrdoc (29KB) — documentation generator + `--check` coverage mode
- cyrc (22KB) — dependency audit + policy enforcement (vet/deny)
- `cyrb audit` — 10-check full project validation
- `cyrb-init.sh` — project scaffolding with vendored stdlib
- `install.sh` — curl-pipe installer with version manager
- `cyrius` version manager (version, list, use, install, which)
- `.ark` package format (manifest.json + binary tarball)
- `cyrb.toml` project manifest
- zugot recipes: cyrius.toml, kybernet.toml, agnos-kernel.toml

### Added — Benchmarks
- 3-tier benchmark suite: stdlib (17), data structures (12), compiler/toolchain (9)
- `bench.cyr` framework with nanosecond timing (clock_gettime MONOTONIC_RAW)
- `scripts/bench-history.sh` — automated CSV recording + BENCHMARKS.md trend generation
- `bench-history.csv` — persistent regression tracking (matches bhava/hisab pattern)
- `cyrb bench` — run full suite, tier, or single file
- CI benchmark job with artifact upload

### Added — aarch64
- 29 feature tests passing (arithmetic, control flow, functions, structs, enums, strings, syscalls)
- Refactored 14 arch-specific functions from parse.cyr to emit files
- Dual-arch cyrb: `cyrb build --aarch64`, `cyrb test --aarch64`

### Added — Ecosystem
- **agnostik** — shared types: 6 modules (error, types, security, agent, audit, config), 54 tests
- **agnosys** — syscall bindings: 50 syscall numbers, 20+ wrappers
- **kybernet** — PID 1 init: 7 modules, 38 tests. Rewritten from 1649 lines Rust to 727 lines Cyrius
- **nous** — dependency resolver: marketplace + system resolution, 26 tests
- **ark** — package manager CLI (44KB): install/remove/search/list/info/status/verify/history
- AGNOS repo with dual-arch build/test scripts and CI
- All stdlib functions documented (cyrdoc --check passes)
- 14 vidya reference files (runnable, tested)

### Added — Infrastructure
- Repo restructured: stage1/ → src/, lib/, programs/, tests/
- VERSION, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE
- CI/CD: 8 parallel jobs (build, check, supply-chain, security, test, test-agnos, aarch64, doc)
- Release workflow: CI gate → version verify → bootstrap cc2 → tools → SHA256SUMS → GitHub Release
- docs: tutorial, stdlib-reference, FAQ, benchmarks, package-format, roadmap

### Fixed — Compiler
- **Enum init ordering**: enum values were 0 inside functions — swapped init order
- **Comparison in fn args**: was "error at token N (type=17)" — added PARSE_CMP_EXPR
- Fixup table expanded 512 → 1024 entries (relocated fixup_cnt/last_var)
- Generics skip in pass 1 fn-skip and pass 2 struct-skip
- Token array bounds check (error at 32768 tokens)

### Fixed — aarch64
- Initial branch (x86 JMP → aarch64 B)
- RECFIX ordering (before MOVZ, not after)
- Pop encoding (pre-indexed → post-indexed)
- Modulo (SDIV + MSUB with correct Rn register)
- Struct field access (EVADDR_X1 + EADDIMM_X1)
- Function ABI (STP/LDP frame, STUR/LDUR locals, BL calls)

### Fixed — Kernel (Phase 10 Audit — 23 issues resolved)
- pmm_bitmap bounds check, proc_table overflow guard
- ISR full register save (9 regs), syscall write clamping

### Metrics
- 35 library modules, 150+ documented functions
- 157 x86_64 tests (111 compiler + 46 programs) + 29 aarch64 tests, 0 failures
- 38 benchmarks across 3 tiers, self-compile: 9ms
- 8 tool binaries + shell dispatcher
- `cyrb audit` → 10/10 green
- Compiler: 93KB, Kernel: 62KB, Toolchain: 162KB total

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
