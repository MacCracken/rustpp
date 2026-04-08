# Changelog

All notable changes to Cyrius are documented here.
This is the **source of truth** for all work done.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.11.1] — 2026-04-07

### Fixed — Compiler
- **Bug #14: Silent compilation failure with thread.cyr**: `MAP_FAILED` constant was
  removed from enum but still referenced. Fixed: use `< 0` check instead.
- **Bug #15: Dual `#derive(Serialize)` + `#derive(Deserialize)`**: Two fixes —
  (a) PP_DERIVE_SERIALIZE now skips intervening `#derive(...)` lines before the struct.
  (b) PP_DERIVE_DESER is now a no-op (Serialize already emits `_from_json`).
  Both derives on same struct now compiles and runs correctly.

### Added — Language
- **Enum namespacing in expressions**: `Foo.BAR` now works in function call args,
  assignments, return values, and all expression contexts. The parser resolves the
  second identifier as a global variable (enum variant). Falls back to struct field
  access if not found as a global.
- **Relaxed fn ordering**: `fn` definitions may now appear after top-level statements.
  PARSE_PROG emits a `jmp` over the fn body, compiles it, then patches the jump.
  Enables patterns like `alloc_init(); fn helper() { ... } var x = helper();`.

## [1.11.0] — 2026-04-07

### Added — Standard Library
- **`lib/freelist.cyr`**: Segregated free-list allocator with `fl_free()`.
  9 size classes (16-4096), large allocs via mmap. `fl_alloc`/`fl_free`/`fl_calloc`.

### Fixed — Compiler
- **Bug #12: `#derive(Serialize)` empty output**: Was already fixed in 1.10.3.
- **Bug #13: Multiple `continue` in one loop**: Forward-patch array (up to 8) at
  S+0x8F858. Fixed in all three loop types (C-style, for-in range, for-in collection).

## [1.10.3] — 2026-04-07

### Fixed — Compiler
- **Bug #12: `#derive(Serialize)` runtime segfault**: Generated `_to_json` function took
  two args `(ptr, sb)` but callers passed one. Uninitialized `sb` → segfault. Fixed: function
  now takes `(ptr)`, creates its own `str_builder_new()`, returns `str_builder_build(sb)`.
  Nested struct fields use `str_builder_add(sb, Nested_to_json(ptr + offset))`.
  Derive now fully functional: `var j = Pt_to_json(&p);` returns valid JSON string.

## [1.10.2] — 2026-04-07

### Added — Compiler
- **Fixup table expanded**: 4096 → 8192 entries. Fn tables relocated from 0x2B2000 to
  0x2C2000. Unblocks ai-hwaccel and argonaut full test coverage without binary splitting.
- **`f64_atan(x)` builtin** (token 99): Arc tangent via x87 `fld1; fpatan`. Handled in
  PARSE_SIMD_EXT. PARSE_STMT range extended to 99.

### Added — Standard Library
- **`lib/math.cyr`**: Extended f64 math — `f64_sinh`, `f64_cosh`, `f64_tanh`, `f64_pow`,
  `f64_clamp`, `f64_min`, `f64_max`. Composed from existing f64 builtins (exp, ln, neg).

### Fixed — Compiler
- **Bug #11: `continue` in for-loops** (P1): `continue` inside C-style `for`, `for-in`
  range, and `for-in` collection loops now correctly jumps to the step/increment expression
  instead of the condition check. Uses forward-patch mechanism at S+0x8F850 — `continue`
  emits a placeholder jump, patched to the step code after the body is compiled.
- **Bug #8: `#derive(Serialize)` field name truncation** (P2): Field name buffer expanded
  from 16 to 32 bytes per field. Fields up to 31 characters now work correctly.

## [1.10.1] — 2026-04-07

### Added — Standard Library
- **`lib/thread.cyr`**: Thread creation, joining, mutex, and channels.
  - `thread_create(fp, arg)` — spawn thread via clone+mmap stack
  - `thread_join(t)` — futex-based wait for thread completion
  - `mutex_new/lock/unlock` — futex-based mutual exclusion
  - `chan_new/send/recv/close` — bounded MPSC channel with futex wait/wake
  - `mmap_stack/munmap_stack` — mmap-based thread stack allocation

### Added — Syscalls
- `SYS_CLONE`, `SYS_FUTEX`, `SYS_MUNMAP`, `SYS_GETTID`, `SYS_SET_TID_ADDRESS`, `SYS_EXIT_GROUP`
- `CloneFlag` enum: CLONE_VM, CLONE_FS, CLONE_FILES, CLONE_SIGHAND, CLONE_THREAD, etc.
- `MmapConst` enum: PROT_READ, PROT_WRITE, MAP_PRIVATE, MAP_ANONYMOUS
- `FutexOp` enum: FUTEX_WAIT, FUTEX_WAKE, FUTEX_PRIVATE_FLAG

### Added — Standard Library (continued)
- **`lib/async.cyr`**: Cooperative async runtime with epoll event loop.
  - `async_new()` / `async_spawn(rt, fp, arg)` / `async_run(rt)` — task scheduler
  - `async_sleep_ms(ms)` — timerfd-based sleep
  - `async_read(fd, buf, len)` — non-blocking read via O_NONBLOCK
  - `async_await_readable(fd)` — epoll wait for fd readability
  - `async_timeout(fp, arg, ms)` — run function with timeout via fork+epoll

### Fixed — Standard Library
- **Bug #9: `getenv()` returns wrong values** (`lib/io.cyr`): Variables `eq` and `ci`
  declared inside while loop leaked scope across iterations, causing false matches.
  Moved declarations outside the loop. `getenv("HOME")` now returns `/home/macro`.
- **Bug #10: `exec_capture()` hangs/crashes** (`lib/process.cyr`): `var pipefd[2]` was
  only 2 bytes but `pipe()` writes two 32-bit ints (8 bytes). Buffer overflow corrupted
  stack. Fixed: `pipefd[16]` + `load32` for fd extraction. Also fixed in `run_capture()`.

## [1.10.0] — 2026-04-07

### Added — Compiler
- **Inline small functions**: Token replay inlining for 1-param functions with ≤6 body
  tokens. State accessors like `GCP(S)`, `GFLC(S)` are inlined at call sites, eliminating
  call/ret overhead (~20 bytes saved per call). New metadata tables at 0x2C8000-0x2D2000
  track body token ranges and inline eligibility. Tail call optimization disabled inside
  inline replay. Max inline depth 3.
- **`ret2(a, b)`**: Return two values in rax:rdx. Enables returning 2-field structs
  without heap allocation. Statement form — emits return jump after packing registers.
- **`rethi()`**: Read rdx from last function call. Expression form — `mov rax, rdx`.
  Must be called immediately after the function call before rdx is clobbered.
- **SIMD expand**: 4 new packed f64 operations:
  - `f64v_div(dst, a, b, n)` — SSE2 `divpd`, packed division
  - `f64v_sqrt(dst, src, n)` — SSE2 `sqrtpd`, packed square root
  - `f64v_abs(dst, src, n)` — SSE2 `andpd` with sign mask, packed absolute value
  - `f64v_fmadd(dst, a, b, c, n)` — `mulpd` + `addpd`, fused multiply-add (SSE2, no FMA3)
- **`LEXKW_EXT` helper**: Extended keyword checks (tokens 93-98) in separate function
  to avoid LEXID code size overflow.
- **`PARSE_SIMD_EXT` handler**: Dispatch for tokens 93-98 in separate function to keep
  PARSE_TERM within code generation limits.

### Added — Language
- **`#ref` directive (Phase 1)**: `#ref "file.toml"` loads TOML at compile time, emitting
  `var key = value;` for each key-value pair. Skips comments (#), sections ([]), blank lines.
  Runs as PP_REF_PASS before include/ifdef processing. Supports integer and string values.

### Added — Codegen
- **Register allocation (R12 spill)**: Expression temporaries use callee-saved R12
  instead of stack push/pop for the first nesting level. Counter-based ESPILL/EUNSPILL
  correctly handles nested expressions. Deeper levels fall back to push/pop.
  Prologue saves rbx+r12, epilogue restores. ETAILJMP updated to match.
  Stack parameter offset adjusted (+16) for the extra pushes.
  aarch64 has ESPILL/EUNSPILL stubs (stack-only, no register optimization).

### Fixed — Compiler
- **PARSE_STMT expression range**: Extended f64/SIMD builtin statement range from
  `typ <= 92` to `typ <= 98`, fixing "unexpected unknown" errors for new builtins
  used as statements.

### Fixed — aarch64
- **Missing `EMIT_F64V_LOOP` stub**: aarch64 cross-compiler failed with "undefined function"
  warning and segfaulted under qemu. Added stub alongside existing UNARY/FMADD stubs.
- **Native aarch64 segfault from inline metadata**: Writes to fn_body_start/fn_body_end/fn_inline
  tables (0x2C8000+) caused memory corruption on ARM. Fixed with `_INLINE_OK` flag — set to 1
  in x86 emit, 0 in aarch64 emit. Inline metadata only written on x86.

### Removed — Dead Code
- `src/cc/` (5 files) — superseded by modular `src/frontend/` + `src/backend/x86/` + `src/common/`.
- `src/cc_bridge.cyr` — identical copy of `src/bridge.cyr`.
- `src/compiler.cyr` — superseded by `src/main.cyr`.
- `src/compiler_aarch64.cyr` — superseded by `src/main_aarch64.cyr`.
- `src/arch/aarch64/` (3 files) — superseded by `src/backend/aarch64/`.

### Changed — Compiler
- Binary size: 194KB x86_64 (up from 189KB due to inline metadata + new builtins).
- Heap brk extended from 0x2C8000 to 0x2D2000 (inline metadata tables).
- 267 tests passing, self-hosting byte-identical.

### Changed — Standard Library
- **Hashmap simplified** (`lib/hashmap.cyr`): Removed enum indirection, extracted
  `_map_lookup()` helper, used `elif` in probe loop, inlined accessor calls in internals.
- Fixed `arena_free` documentation in `lib/alloc.cyr` (function doesn't exist).

## [1.9.5] — 2026-04-07

## [1.9.4] — 2026-04-07

### Added — Compiler
- **`f64_round(x)`**: SSE4.1 `roundsd` mode 0 (round to nearest, banker's rounding).
  Token 92. Completes the set: floor/ceil/round.

### Fixed — Compiler
- **`#derive(Serialize)` works inside included files**: Added derive handling to PP_IFDEF_PASS
  (the second preprocessor pass that processes included content). Previously only worked in
  the main source file, not in `include`d modules.

### Added — Standard Library
- **`fmt_float(val, decimals)` + `fmt_float_buf`** (`lib/fmt.cyr`): Format f64 as
  "integer.fraction" with configurable decimal places. Zero-padded fractional part.
  Handles negative values. `fmt_float(pi, 6)` → `3.141593`.
- **`getenv(name)`** (`lib/io.cyr`): Read environment variable by name. Parses
  `/proc/self/environ`. Returns heap-allocated C string or 0 if not found.
  Required for PATH lookup in ai-hwaccel hardware detection.

### Fixed — Documentation
- **json.cyr requires io.cyr**: Added to Requires comment (was undocumented dependency
  for `json_parse_file` → `file_read_all`).

## [1.9.3] — 2026-04-07

### Fixed — Compiler
- **SIMD frame slot collision**: `f64v_add/sub/mul` stored args at hardcoded frame slots 0,1,2
  which overwrote caller's local variables. Heap-allocated buffers produced zeros, chained
  operations produced wrong results. Fixed by using `GFLC()` for fresh slots and passing
  `vbase` to `EMIT_F64V_LOOP` for correct `[rbp-N]` offsets.

### Fixed — Release
- **Release tarball ships shell cyrb**: Workflow was compiling `programs/cyrb.cyr` (old binary
  without -D/deps/pulsar). Now copies `scripts/cyrb` (shell dispatcher with full feature set).

### Changed — Roadmap
- Marked Bug #5 (release cyrb -D) and #6 (naming ambiguity) as fixed.
- New perf item #7 from abaco: SIMD expand (f64v_div, f64v_sqrt, f64v_abs, fmadd for MAC).

## [1.9.2] — 2026-04-07

### Improved — Tooling
- **Dependency `modules` filter**: Path and git deps now support `modules = ["lib/syscalls.cyr"]`
  to include only specific files instead of the entire project. Without `modules`, all lib/ + src/
  are included (existing behavior). Prevents pulling in 20+ unused modules from large dependencies.
- **`cyrb pulsar` installs shell cyrb**: Was installing stale compiled binary (0.6.0). Now installs
  the shell script with deps/pulsar support. Nuking `~/.cyrius` and running `cyrb pulsar`
  reconstitutes a clean install.

## [1.9.1] — 2026-04-07

### Added — Tooling
- **Dependency management in `cyrb.toml`**: New `[deps]` section declares project dependencies.
  Three dependency types supported:
  - **stdlib**: `stdlib = ["string", "fmt", "alloc", "vec"]` — resolved from installed Cyrius
  - **path**: `[deps.agnosys] path = "../agnosys"` — local project dependencies
  - **git**: `[deps.kybernet] git = "https://github.com/MacCracken/kybernet" tag = "0.3.0"` —
    remote dependencies cloned to `~/.cyrius/deps/<name>/<tag>/`, supports GitHub/GitLab/any git
  `cyrb build` auto-resolves all deps and prepends includes before compilation.
  Include-once prevents duplicate processing when deps share stdlib modules.
- **`cyrb deps`**: Shows resolved dependency tree from cyrb.toml — stdlib modules, path deps,
  git deps with cache status, and the full resolved include list.

### Fixed — Tooling
- **`cyrb pulsar` now writes `~/.cyrius/current`**: Version manager and dep resolution
  use this file to find the active stdlib. Was stale after pulsar runs.

## [1.9.0] — 2026-04-07

### Added — Compiler
- **SIMD batch operations: `f64v_add`, `f64v_sub`, `f64v_mul`**: SSE2 packed f64 builtins
  that process 2 elements per iteration. `f64v_add(dst, a, b, n)` adds n f64 elements from
  arrays a+b into dst. 2x throughput for array operations vs scalar loop.

### Improved — Standard Library
- **Stack-allocated str_builder**: Replaced vec-of-Str design with direct buffer approach.
  64-byte inline buffer, single final `alloc` on build. Eliminates N heap allocations per
  string construction (one per `add_cstr`/`add_int` call).

### Added — Tooling
- **`cyrb pulsar`**: One command to rebuild cc2 + cc2_aarch64 + cc2-native-aarch64 + tools
  from source, install to ~/.cyrius, purge old versions, verify. Auto two-step bootstrap.
  Full toolchain rebuild in ~410ms.
- **`cyrb --aarch64 --native`**: Uses the native aarch64 compiler (runs under qemu on x86)
  instead of the cross-compiler. Three clear binaries: `cc2` (x86→x86), `cc2_aarch64`
  (x86→aarch64 cross), `cc2-native-aarch64` (aarch64→aarch64 native).

### Fixed — Tooling
- **install.sh stale fallback version**: 0.9.1 → 1.8.5. Added cc2-native-aarch64 to bin lists.
  Source bootstrap now copies all cyrb-*.sh scripts.
- **Scripts cleanup**: All scripts verified using correct paths (src/main.cyr, src/bridge.cyr).
  check.sh passes all 10 checks.

## [1.8.5] — 2026-04-07

### Verified — Tooling
- **cyrb `-D` flag confirmed working for aarch64**: Bug #4 reported `-D` not reaching
  cc2_aarch64, but this was from pre-v1.8.4 cyrb. Verified: `cyrb build --aarch64 -D X`
  produces correct ifdef-gated output. Size differs with/without flag (328 vs 0 bytes).

## [1.8.4] — 2026-04-07

### Fixed — Compiler
- **Codebuf expanded 192KB→256KB**: Moved tok_names from 0x50000 to 0x60000, codebuf now
  extends to 0x60000. Fixes aarch64 cross-compiler codebuf overflow that blocked native
  aarch64 binary generation. aarch64 tarball now ships native ARM ELF via two-step self-host.
- **aarch64 backend: ESETCC + float stubs**: Added comparison expression codegen (cmp + cset)
  and float function stubs to aarch64 emit.cyr. Required for PCMPE and f64 builtin references
  in shared parse.cyr.

### Fixed — Tooling
- **`cyrb build/run/test -D NAME` flag support**: `-D NAME` prepends `#define NAME` to source
  before compilation. Works with `--aarch64`. Supports multiple flags (`-D A -D B`).
  Both `-D NAME` (space) and `-DNAME` (attached) forms supported. Fixes AGNOS aarch64 kernel
  build (`cyrb build --aarch64 -D ARCH_AARCH64 agnos.cyr`).

### Changed — Release
- **aarch64 tarball ships native ARM binary**: Release workflow now self-hosts — x86 cc2 builds
  cross-compiler, cross-compiler builds native aarch64 ELF. Architecture verified via `file`.

## [1.8.3] — 2026-04-07

### Added — Standard Library
- **`lib/matrix.cyr` — dense matrix library**: `mat_new`, `mat_get`, `mat_set`, `mat_identity`,
  `mat_add`, `mat_sub`, `mat_scale`, `mat_mul`, `mat_transpose`, `mat_dot`, `mat_print`.
  Row-major f64 storage. Unblocks hisab DenseMatrix port. Const generics not needed —
  Cyrius runtime-sized alloc covers all bhava/hisab Matrix patterns.

- **Arena allocator** (`lib/alloc.cyr`): `arena_new(capacity)`, `arena_alloc(a, size)`,
  `arena_reset(a)`, `arena_used(a)`, `arena_remaining(a)`. Independent memory pools — resetting
  one arena doesn't invalidate pointers from others or the global allocator. Closes Bug #2.
- **`#derive(Serialize)` now generates both `_to_json` AND `_from_json`**: Single directive
  produces serialization and deserialization. `Name_from_json(pairs)` takes a vec of JSON
  key-value pairs (from `json_parse`) and populates a struct. Scalar values emitted as quoted
  strings for json roundtrip compatibility. DCE stubs whichever function isn't used.

### Fixed — Standard Library
- **`#derive(Serialize)` outputs quoted numeric values**: `{"x":"42"}` instead of `{"x":42}`.
  Ensures `json_parse` roundtrip works correctly (json_parse numeric value parsing has a
  known issue with unquoted numbers in some contexts).

### Added — Standard Library
- **Vidya content loader + search** (`lib/vidya.cyr`): Loads TOML content from vidya corpus
  directory. Supports both `[[entries]]` format (cyrius) and `concept.toml` format (topics).
  Registry with hashmap index by name. Full-text search across name, description, and content.
  Tested against full vidya corpus: 209 entries loaded, search working.

### Fixed — Standard Library
- **`str_ends_with` was comparing against Str fat pointer**: Used `strlen(suffix)` and raw
  `suffix` pointer instead of `str_len(suffix)` and `str_data(suffix)`. Caused `path_has_ext`
  and `find_files` to always return no matches.
- **`str_contains` used C string needle**: Changed to accept Str needle via `str_len`/`str_data`.

### Changed — Documentation
- **Roadmap cleaned up**: Collapsed 9 resolved bugs, updated header to v1.8.3/168KB,
  marked derive macros done, added vidya port progress, new perf items from abaco benchmarks.

## [1.8.2] — 2026-04-07

### Added — Standard Library
- **`lib/toml.cyr` — TOML parser**: Parses TOML files with string values (`key = "value"`),
  triple-quoted multi-line strings (`key = '''...'''`), arrays of tables (`[[section]]`),
  and comments. Returns vec of sections, each with name + pairs vec. Includes `toml_parse`,
  `toml_parse_file`, `toml_get`, `toml_get_sections`. Tested against vidya corpus: 108 entries
  across implementation.toml (59), ecosystem.toml (35), strings/concept.toml (14).
  Unblocks vidya port to Cyrius (TOML content loader + search + registry).

### Fixed — Compiler
- **VCNT expanded 2048→4096**: Relocated var_noffs/var_sizes from 0x60000/0x64000 to
  0x2B8000/0x2C0000 (after fn tables). Brk extended to 0x2C8000. agnosys 20 modules
  have ~3400 enum variants — now fits comfortably.
- **Parenthesized comparisons in conditions**: `while (x && (load8(p) == 32 || load8(p) == 9))`
  now works. PARSE_FACTOR's paren handler calls PCMPE (not PEXPR), allowing comparisons
  and `&&`/`||` inside parenthesized subexpressions. ECONDCMP handles boolean values
  without a comparison operator (treats non-zero as true via `cmp rax, 0; jne`).
- **agnosys `else if` → `elif`**: Fixed 1 instance in src/ima.cyr.

## [1.8.1] — 2026-04-07

### Fixed — Compiler
- **Preprocessor output buffer expanded 256KB→512KB**: agnosys 20 modules (262KB expanded)
  exceeded the 256KB limit. Buffer at 0x222000 now uses the full gap to 0x2A2000 (fixup table).
  Unblocks full-project compilation for large codebases.

### Changed — Documentation
- **README.md rewritten**: Updated to 164KB/267 tests, v1.8.0 architecture diagram, features
  list (20 f64 builtins, #derive, include-once, jump tables), new bootstrap chain.
- **Internal docs updated**: CLAUDE.md, cyrius-guide.md, benchmarks.md, roadmap — all stale
  references to 136KB/263 tests/src/cc/ paths corrected.
- **Vidya updated**: language.toml and implementation.toml synced to v1.8.0 with heap map,
  include-once, restructure, and transcendental entries.
- **Roadmap**: Added agnosys blocker items (#8 VCNT overflow, #9 256KB limit now fixed).
  New performance items from abaco benchmarks (u128, SIMD, compile-time perfect hash).

### Changed — Installation
- **~/.cyrius updated to 1.8.0**: cc2 (168KB) + 21 stdlib modules installed.

## [1.8.0] — 2026-04-07

### Changed — Compiler Structure
- **Directory restructure**: `src/cc/` → `src/frontend/` + `src/backend/x86/` + `src/common/`.
  `src/arch/aarch64/` → `src/backend/aarch64/`. Clear frontend/backend/common separation.
- **Entry point renames**: `compiler.cyr` → `main.cyr`, `compiler_aarch64.cyr` → `main_aarch64.cyr`,
  `cc_bridge.cyr` → `bridge.cyr`.
- **Float extraction**: SSE2/SSE4.1/x87 float ops extracted from `emit.cyr` into `float.cyr`.
  emit.cyr drops from 576 to 509 lines.
- **Include order**: `common/util → backend/emit → backend/float → backend/jump → frontend/lex → frontend/parse → backend/fixup`.
- Updated all references in: tests/compiler.sh, scripts/*, .github/workflows/*, docs/, CLAUDE.md.

### Added — Compiler
- **Include-once semantics**: Preprocessor tracks included filenames (up to 64). Duplicate
  `include "file.cyr"` directives are silently skipped. Prevents duplicate enum errors,
  wasted tokens/identifiers, and simplifies downstream project include management.
  Works in both PP_PASS and PP_IFDEF_PASS.

## [1.7.9] — 2026-04-07

### Improved — Standard Library
- **hashmap.cyr: enum constants for state values**: Replaced magic numbers 0/1/2 with
  `HASH_EMPTY`, `HASH_OCCUPIED`, `HASH_TOMBSTONE` enum. Clearer intent, grep-friendly.
- **hashmap.cyr: `map_iter(m, fp)`**: Zero-alloc iteration via function pointer callback.
  Calls `fncall2(fp, key, value)` for each occupied entry. No vec allocation needed.
- **hashmap.cyr: formatting cleanup**: Fixed `map_print` indentation, updated header docs.

### Changed — Compiler
- **PARSE_CMP_EXPR renamed to PCMPE**: Internal rename to reduce tok_names pressure.
  Freed ~90 bytes of identifier buffer for the dedup bootstrap chain.

## [1.7.8] — 2026-04-07

### Added — Compiler
- **f64 transcendentals: `f64_sin`, `f64_cos`, `f64_exp`, `f64_ln`, `f64_log2`, `f64_exp2`**:
  x87 FPU instructions via rax↔stack↔x87 bridge. sin/cos via `fsin`/`fcos`, ln via
  `fldln2; fyl2x`, log2 via `fld1; fyl2x`, exp via `fldl2e; fmulp; frndint; f2xm1; fscale`,
  exp2 via `frndint; f2xm1; fscale`. Unblocks abaco DSP (amplitude_to_db, midi_to_freq,
  constant_power_pan, filter coefficients).
- **Identifier deduplication in LEXID**: Before storing a new identifier in tok_names,
  scans for an existing identical string and reuses its offset. Reduces tok_names usage
  ~50% for the compiler source (65500→~30000 bytes). Required two-step bootstrap
  (rename PARSE_CMP_EXPR→PCMPE to fit within old limit, compile, then add dedup).

## [1.7.7] — 2026-04-07

### Added — Compiler
- **Constant folding for `+`, `-`, `&`, `|`, `^`**: Same proven SCP-rewind pattern as `*`/`/`/`<<`/`>>`.
  Folds at compile time when both operands and result are small positive (0 < v < 0x10000).
  Precedence-safe: checks right operand isn't followed by higher-precedence operator.
- **f64 builtins: `f64_sqrt`, `f64_abs`, `f64_floor`, `f64_ceil`**: Single-instruction
  transcendentals. sqrt via SSE2 `sqrtsd`, floor/ceil via SSE4.1 `roundsd`, abs via integer
  AND (clear sign bit). Unblocks abaco DSP functions (amplitude_to_db, midi_to_freq, filters).
- **Jump tables for dense switches**: When a switch has ≥4 cases with dense values
  (range ≤ 2×count), emits O(1) indirect jump via `lea rcx,[rip+table]; movsxd rax,[rcx+rax*4]; jmp rax`.
  Sparse switches still use compare-and-branch chain. Pre-scans case values in a separate pass.
- **`#derive(Serialize)`**: Preprocessor-level code generation. `#derive(Serialize)` before a
  struct auto-generates `Name_to_json(ptr, sb)` that serializes to JSON via str_builder.
  Supports nested structs (requires inner `#derive` first). Unblocks bhava/hisab serde migration.
- **Batch benchmark harness**: `bench_run_batch(b, &fn, batch_size, rounds)` in lib/bench.cyr.
  Wraps one `clock_gettime` pair around N iterations for accurate sub-100ns measurement.
  Also `bench_run_batch1`, `bench_run_batch2`, and inline `bench_batch_start`/`bench_batch_stop`.

### Improved — Compiler
- **VCNT overflow check**: Errors at 2048 with clear message instead of silent corruption.
- **Undefined function warning**: `warning: undefined function 'foo'` at compile time instead
  of silent segfault at runtime.
- **Non-ASCII byte error**: `error:N: non-ASCII byte (0xc3)` instead of silently splitting
  identifiers. UTF-8 in strings and comments still works.
- **Identifier buffer limit raised**: 65000 → 65500 bytes (struct_ftypes no longer overlaps).

### Fixed — Compiler
- **`_cfo` leak from function call arguments**: `pow2(5) + 10` folded to `15` instead of `42`
  because `_cfo=1` leaked from parsing the argument `5`. Fixed by clearing `_cfo` after
  PARSE_FNCALL, PARSE_FIELD_LOAD, and syscall builtins in PARSE_FACTOR.
- **`_cfo` leak from non-folding PARSE_TERM operations**: After `var * 8`, the `8` literal
  set `_cfo=1` which leaked to PARSE_EXPR, causing `var * 8 + 16` to fold as `8 + 16 = 24`.
  Fixed by clearing `_cfo` after all non-folding paths in PARSE_TERM (`*`, `/`, `%`, `<<`, `>>`).
- **agnosys bench_compare.cyr missing `#define LINUX`**: Not a compiler bug — platform define
  was missing, causing empty syscall bindings.

## [1.7.6] — 2026-04-06

### Fixed — Compiler
- **tok_names/struct_ftypes memory overlap (Bug #1)**: `tok_names` at 0x50000 (65536 bytes)
  overlapped with `struct_ftypes` at 0x59000 (4096 bytes). When programs with >36864 bytes
  of identifier data were compiled, identifier strings were stored in `struct_ftypes` space.
  Struct operations zeroed out those identifiers, causing `FINDVAR` to silently fail and
  produce "unexpected token" errors at random locations. Manifested as: including
  `assert.cyr` + `bench.cyr` + all 12 agnostik modules produces `unexpected '+'` at ~line 2556.
  **Fix**: relocated `struct_ftypes` from 0x59000 to 0x8A000 (free space after output_buf).
- **Fixup table overflow checks**: `ESADDR`, `ECALLFIX`, `ETAILJMP`, and `&fn` handler all
  wrote fixup entries without checking the table limit. Only `RECFIX` had the check. Added
  overflow check (4096 limit) to all four functions.
- **aarch64 ETAILJMP missing**: Tail call optimization only had x86_64 implementation.
  Added `ETAILJMP` to aarch64/emit.cyr: `mov sp, x29; ldp x29, x30, [sp], #16; B rel26`
  with fixup type 4 (B not BL).
- **aarch64 fixup stale offsets**: Three references to 0x262000 in aarch64/emit.cyr not
  updated when fixup table was relocated to 0x2A2000. All 26 CI aarch64 tests were failing.

### Changed — Compiler
- **Fixup table expanded 2048→4096**: Relocated fn_names/fn_offsets/fn_params from
  0x2AA000/0x2AC000/0x2AE000 to 0x2B2000/0x2B4000/0x2B6000. Brk increased from
  0x2B0000 to 0x2B8000. Prevents fixup overflow for large programs.

### Metrics
- Compiler: 141KB x86_64
- 267 tests (216 compiler + 51 programs), 0 failures
- Self-hosting: byte-identical
- agnostik: 58 tests, 0 failures (assert+bench+all 22 modules now compiles)

## [1.7.5] — 2026-04-06

### Fixed — Compiler
- **aarch64 ETAILJMP missing**: Tail call optimization only had x86_64 implementation.
  Added `ETAILJMP` to aarch64/emit.cyr with fixup type 4 (B not BL).
- **aarch64 fixup stale offsets**: Three references to 0x262000 in aarch64/emit.cyr not
  updated when fixup table was relocated to 0x2A2000. All 26 CI aarch64 tests were failing.
- **Allocator codegen regression**: PMM back to 1,276 cycles (was 2,044 in v1.7.4).
  Heap 32B back to 1,241 (was 2,065).

## [1.7.4] — 2026-04-06

### Fixed — Compiler
- **256 locals per function**: `fn_local_names` relocated from 0x8DC30 to 0x91000 with
  256 entries (was 64). 65th local previously overflowed into `var_types`.
- **Constant folding paren leak**: `_cfo` flag persisted from inside parenthesized
  subexpressions. `(n-6)*8` would fold `6*8=48` instead of computing `(n-6)*8`. Fixed
  by clearing `_cfo` after evaluating parenthesized expressions in `PARSE_FACTOR`.
- **aarch64 constant folding EMOVI size mismatch**: Tightened fold range from 0x80000000
  to 0x10000 to ensure same EMOVI size on both architectures (aarch64 EMOVI is variable-size).
- **Identifier buffer overflow**: Added error with count at 65000/65536 bytes in LEXID.

## [1.7.3] — 2026-04-06

### Added — Compiler
- **Constant folding for `*`, `/`, `<<`, `>>`**: Compile-time evaluation of integer
  expressions with literal operands. PARSE_TERM checks `_cfo` flag set by PARSE_FACTOR
  for small positive literals. Folds by SCP rewind + EMOVI with computed value.

### Changed — Compiler
- **Heap map reorganized**: Address-order format in compiler.cyr header for clarity.

## [1.7.2] — 2026-04-06

### Changed — Compiler
- **Input buffer expanded to 512KB**: Preprocessor output buffer at 0x222000 (524288 bytes).
  LEX reads directly from preprocess buffer, eliminating copy-back. No more source size limit
  below 512KB.
- **Tail call optimization**: `return fn(args)` emits epilogue + `jmp` instead of
  `call` + epilogue. PARSE_RETURN detects IDENT+LPAREN pattern, scans to matching RPAREN,
  verifies SEMI. x86: `mov rsp,rbp; pop rbp; jmp rel32` with type-2 fixup.
- **Fixup/fn tables relocated**: fixup_tbl to 0x2A2000, fn_names/offsets/params to
  0x2AA000/0x2AC000/0x2AE000 to accommodate larger preprocessor buffer.

## [1.7.1] — 2026-04-06

### Fixed — Compiler
- **`&&`/`||` as expression operators**: `return a > 0 && b > 0;` and `var r = a == b;`
  now work. PARSE_CMP_EXPR handles `&&`/`||` as AND/OR on 0/1 values. PARSE_VAR and
  assignment handler changed from PARSE_EXPR to PARSE_CMP_EXPR.

## [1.7.0] — 2026-04-06

### Fixed — Compiler
- **`return expr == expr`**: PARSE_RETURN now calls PARSE_CMP_EXPR. Comparisons in return statements work.
- **Input buffer 256KB**: expanded source safely overflows into codebuf (consumed before codegen)
- **Codebuf overflow check**: EB() errors at 196608 bytes with clear message
- **VCNT expanded to 2048**: var_noffs/var_sizes relocated to non-overlapping regions
  (var_sizes 0x60800→0x64000, str_data 0x62000→0x68000). Fixed overlap bug from v1.5.2.
- **Two-pass ifdef**: PP_IFDEF_PASS evaluates #ifdef/#define in included content after expansion
- **Dead code elimination**: unreachable functions get 3-byte stub (xor eax,eax; ret).
  Token scan with STREQ, skips module/mangled names. ~1.5KB saved on hello+stdlib.

### Metrics
- Compiler: 134KB x86_64
- 267 tests (216 compiler + 51 programs), 0 failures
- Self-hosting: byte-identical

## [1.6.6] — 2026-04-06

### Improved — Compiler
- **Human-readable error messages**: `error:5: unexpected token (type=17)` →
  `error:5: expected ';', got identifier 'foo'`. Token types replaced with names
  (`;`, `)`, `{`, `identifier`, `number`, `fn`, `return`, etc). Identifier values
  and numeric values shown in context. 142 parse errors upgraded to `ERR_EXPECT`
  with expected/got format. Added `TOKNAME`, `PRSTR`, `ERR_EXPECT`, `ERR_MSG` to util.cyr.

### Fixed — Compiler
- **Multi-pass preprocessor**: `include` inside `#ifdef` in included files now works.
  Preprocessor runs up to 16 passes until no more includes found. Each pass expands
  includes and evaluates `#ifdef`/`#define`. Fixes library-level platform dispatchers.

### Fixed — Tooling
- **`cyrb update` actually works**: syncs `lib/` from installed Cyrius stdlib
  (`~/.cyrius/versions/<current>/lib/`), falls back to `../cyrius/lib/`
- **`cyrb init` generates `cyrb.toml`**: includes `[deps]` section, vendors ALL stdlib
  modules (was hardcoded list of 13)
- **`cyrc vet` false positive on cyrb**: `cmd_check` contained `"include "` string literal
  that triggered dependency detection. Fixed: build needle at runtime with `store8`.

### Changed — Documentation
- **Vidya reorganization**: Cyrius reference moved from `compiler_bootstrapping/` to own
  `cyrius/` topic directory: `language.toml`, `ecosystem.toml`, `implementation.toml`, `types.toml`

## [1.6.5] — 2026-04-06

### Fixed — Compiler (aarch64)
- **cc2_aarch64 segfault on `kernel;` mode**: `EMITELF_KERNEL` was a placeholder that called
  `EMITELF` → infinite recursion → stack overflow → segfault. Implemented proper aarch64
  kernel ELF64 emission: base `0x40000000`, entry `0x40000078`, no multiboot (ARM uses
  device tree). Fixup entry point also corrected (`0x100060` → `0x40000078`).
  Bootable via: `qemu-system-aarch64 -M virt -cpu cortex-a57 -kernel build/agnos_aarch64`

### Added — Tooling
- **`cyrb build -D NAME`**: preprocessor defines from the command line. Enables conditional
  compilation without modifying source files. Key use case: AGNOS multi-arch kernel builds
  (`cyrb build -D ARCH_X86_64 kernel/agnos.cyr build/agnos`). Multiple `-D` flags supported.

### Fixed — Tooling
- **cyrb aarch64 cross-compiler search**: `cyrb build --aarch64` now searches `./build/cc2_aarch64`
  as fallback when not found in `~/.cyrius/bin/`. Fixes CI and dev environments that build
  the cross-compiler locally.

### Updated — Roadmap
- Tooling issues #1 resolved (aarch64 search path)
- Tooling issue #4 clarified: >60KB source segfault was caused by function table overflow
  (>256 functions), now mitigated by 512-entry tables in v1.6.0. Programs with >512 functions
  still need splitting.

### Added — Tests
- **Nested for-loop regression tests**: 4 new tests (nested_for_var, nested_for_match,
  triple_for, for_in_for) confirming nested for-loops with var declarations work correctly.

### Metrics
- Compiler: 136KB x86_64, 127KB aarch64
- cyrb: 60KB
- 216 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.6.0] — 2026-04-06

### Fixed — Compiler
- **Function table overflow (segfault at >256 functions)**: `fn_names`, `fn_offsets`, `fn_params`
  had 256 entries each (2048 bytes at `0x8C200`/`0x8CA00`/`0x8D200`). The 257th function name
  overwrote `fn_offsets[0]`, corrupting jump targets and causing runtime segfaults.
  Relocated all three tables to `0x26A000`/`0x26B000`/`0x26C000` with 512 entries each.
  Confirmed: old compiler segfaults (exit 139) with 260 functions, new compiler runs clean.

### Added — Tooling
- **CI setup script**: `scripts/ci.sh` — pulls release tarball, extracts to `~/.cyrius`,
  symlinks binaries. For Ubuntu, AGNOS, Alpine, agnos-slim CI images.

### Metrics
- Compiler: 136KB (unchanged)
- 212 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.5.3] — 2026-04-06

### Added — Performance (agnosys)
- **Packed Result type**: Ok/Err encoded in a single i64 using bit 63 as discriminant.
  Zero heap allocations on success path (was 2 allocs per Result via tagged_new).
  Error path still allocates 24-byte syserr struct (cold path, acceptable).
- **Caller-provided buffers**: `query_sysinfo(out)`, `agnosys_hostname(out)`,
  `agnosys_kernel_release(out)`, `agnosys_machine(out)` now write into caller's
  stack buffer instead of heap-allocating + memcpy. Eliminates alloc+copy per call.
- **Packed errno errors**: `err_from_errno` encodes kind+errno in a single i64
  (`kind<<16|errno`) — zero heap allocation on error hot path.
  `syserr_kind`/`syserr_errno` auto-dispatch between packed integers and heap pointers.
- **Dropped unnecessary memset**: `query_sysinfo` and `agnosys_uname` no longer zero
  buffers before syscall — kernel overwrites the entire struct.
- **Single uname call**: `agnosys_uname(out)` replaces separate hostname/release/machine
  functions. One syscall, zero memcpy, callers read fields via offset accessors.

### Fixed — agnosys
- **Array size unit confusion**: `var buf[N]` allocates N bytes, not N i64 elements.
  `var buf[49]` (intended for 390-byte utsname struct) only allocated 56 bytes, causing
  runtime overflow into adjacent data (corrupted string literals).
  Fixed: `var buf[392]` for utsname, `var buf[120]` for sysinfo, `var allow[160]` for
  seccomp filter, `var beneath[16]` and `var prog[16]` for landlock/seccomp structs.

### Fixed — Roadmap
- **Nested for-loop P1 bug**: confirmed fixed (by block scoping in v0.9.5). Removed from P1.

### Metrics
- Compiler: 136KB (unchanged)
- 212 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.5.2] — 2026-04-06

### Fixed — Tooling
- **cyrb clean deletes itself**: `cyrb` was not in the preserve list, so `cyrb clean` removed
  its own binary from `build/` — added `cyrb` to skip list alongside cc2, stage1f, asm
- **cyrb clean output truncated**: byte count for the status message was 55, should be 57
  (UTF-8 em dash is 3 bytes not 1) — output showed "remove8 files" instead of "removed 8 files"
- **cyrb envp fix not in source**: the `load_environ()` / `_envp` passthrough from 1.5.1 was
  lost from source after a git stash — reapplied to `programs/cyrb.cyr`

### Added — Documentation
- **Module & manifest design doc**: `docs/development/module-manifest-design.md` —
  explicit dependency manifests without a resolver, `pub` enforcement, `use` imports
  with qualified access, migration path from `include` to `use`

### Fixed — Compiler
- **Variable table overflow corrupting string data**: `var_noffs` and `var_sizes` had 256 entries
  (2048 bytes each at `0x60000`/`0x60800`), overflowing into `str_data` at `0x61000` when total
  variable count exceeded 256. Since VCNT never resets between functions (arrays are globals),
  large programs silently corrupted string literals — `println` wrote backspace (0x08) instead
  of newline (0x0A)
  - Expanded both arrays to 512 entries (4096 bytes each)
  - Relocated `str_data` from `0x61000` to `0x62000`
  - Updated x86_64 and aarch64 backends (lex.cyr, fixup.cyr, arch/aarch64/fixup.cyr)
  - Triggered by agnosys port (379 variables across 14 included modules)

### Verified
- All 25+ cyrb subcommands tested and passing
- 212 compiler tests, 0 failures
- 51 program tests, 0 failures
- Self-hosting: byte-identical
- agnosys 119KB binary: all println output correct

### Metrics
- Compiler: 136KB (unchanged)
- cyrb: 59KB (was 58KB)

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
