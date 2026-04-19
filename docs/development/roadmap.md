# Cyrius Development Roadmap

> **v5.4.2.** cc5 compiler (434736 B x86_64), x86_64 + aarch64
> cross. IR + CFG. **Windows arc — stage 3: `EMITPE` backend.**
> v5.4.0 + v5.4.1 shipped the PE byte-level floor: `pe_probe.cyr`
> (1536 B PE32+ exit-42, validated on Windows 11 Home, ERRORLEVEL=42)
> and `pe_probe_hello.cyr` (full Win64 ABI call path — GetStdHandle
> + WriteFile + ExitProcess with RCX/RDX/R8/R9 + 32 B shadow space,
> prints `hello\n` on Windows 11 Home). v5.4.2 teaches cc5 to
> emit PE directly, following the existing Mach-O pattern:
> `src/backend/pe/emit.cyr` (stubbed since v3.1+) gets fleshed
> out to mirror `src/backend/macho/emit.cyr`, a runtime
> `_TARGET_PE` flag on `src/backend/x86/emit.cyr` (analogous to
> `_TARGET_MACHO` on the aarch64 emitter) is set from
> `CYRIUS_TARGET_WIN=1`, and Win64-ABI-divergent call sites
> (fncall*, &fn, direct-`EB`) branch on `if (_TARGET_PE)` for
> RCX/RDX/R8/R9 + 32 B shadow space. `cc5_win.cyr` mirrors
> `main_aarch64_macho.cyr`'s swap-include-chain pattern. The
> "clean separation sweep later" refers to eventually hoisting
> inline format branches out of arch emitters, not
> restructuring the tree — which already has the split. aarch64 port remains fully online (`regression.tcyr`
> 102/102 on real Pi, native `cc5` self-hosts byte-identical,
> per-arch asm via `#ifdef CYRIUS_ARCH_{X86,AARCH64}` from v5.3.16).
> Apple Silicon Mach-O self-hosts byte-identically on M-series
> (v5.3.13, 475320 B). **Still deferred to v5.4.x / v5.5.x**:
> NSS/PAM end-to-end, libro layout corruption, `lib/hashmap_fast`
> / `u128` / `mabda` arch-gating, yukti `include` rename.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5. Closure verified.
> **64 test suites**, 14 benchmarks, 5 fuzz harnesses. **61 stdlib modules** (includes 6 deps).
> Caps: ident buffer 128KB (4.6.2), fn table 4096 (4.7.1).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | Localized with `CYRIUS_SYMS`. Classic memory corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG now available for diagnosis (5.0.0 IR). Note: ark cyml_parse crash (SA-002) was NOT this bug — was calling wrong function signature (nous.cyr 1-arg vs cyml.cyr 2-arg). |
| ~~aarch64 x86-asm leakage~~ — **CLOSED v5.3.18** | v5.3.18 adds aarch64 `EMIT_FLOAT_LIT` (scvtf+fdiv+fmov) and `PF64CMP` (fmov+fcmp+cset) paths. `regression.tcyr` on real Pi (agnosarm.local, Raspberry Pi aarch64) now **102/102 PASS** (was SIGILL-at-entry pre-v5.3.16, 100/102 post-v5.3.17). Native `cc5` self-hosts byte-identical. Three libs still contain ungated x86 asm blocks (`lib/hashmap_fast.cyr` / `lib/u128.cyr` / `lib/mabda.cyr`) — they'll never execute correctly on aarch64 but misalignment is already mitigated by v5.3.15's asm-block alignment padding, and no consumer currently depends on their aarch64 behavior. Downstream arch-gating on those three is a future cleanup, not a blocker. | Validated on real Pi through v5.3.18 closeout. |

---

## Shipped

<details>
<summary>Click to expand shipped v5.x items</summary>

### v5.0.0 — cc5 Generation Bump
- cc5 IR (812 lines, 40 opcodes), CFG edge builder, LASE analysis, dead block detection
- cyrius.cyml manifest, `cyrius version`, CLI tool integrations
- cc3→cc5 rename, patra 1.0.0, sankoch 1.2.0

### v5.0.1 — Security Hardening
- alloc() overflow guard + size cap (256MB), negative/zero rejection
- vec/map capacity doubling overflow caps, alloc return checks
- arena_alloc overflow guard

### v5.0.2 — Preprocessor Fix
- `#ref` bol tracking — no longer matches inside strings or mid-line

### v5.0.3 — aarch64 Native + Version Tooling
- `main_aarch64_native.cyr` with host syscall numbers (openat, native read/write/brk/exit)
- Version check openat-aware, `version-bump.sh` cc3→cc5 fix

### v5.1.0 — macOS x86_64 (Mach-O)
- `CYRIUS_MACHO=1` triggers Mach-O output, tested on real hardware
- `lib/syscalls_macos.cyr`, `lib/alloc_macos.cyr` (mmap-based)

### v5.1.1 — Stdlib: sakshi + log.cyr
- sakshi 0.9.0 → 0.9.3 (SA-001 UDP fix, SK_FATAL, trace ID)
- log.cyr level mapping + output routing rewrite (delegates to sakshi)
- Removed duplicate sakshi symlinks, migrated to cyrius.cyml, CI cc3→cc5

### v5.1.2 — sakshi 1.0.0 + Release Pipeline
- sakshi 0.9.3 → 1.0.0 (first stable release)
- macOS Mach-O tarball in release pipeline (three-platform release)
- release.yml cc3→cc5, dep resolver prefers cyrius.cyml

### v5.1.3 — Codebase Cleanup
- Removed stale cyrius.toml, all cc2/cc3 refs in scripts + docs + programs
- cyrius-port.sh generates cyrius.cyml, read_manifest() prefers cyml
- CLAUDE.md recommended minimum → v5.0.0

### v5.1.4 — Starship + Dispatcher Fixes
- Starship detects cyrius.cyml, dispatcher manifest refs unified via find_manifest()
- Deep cc3→cc5 sweep: install.sh, ci.sh, dispatcher, regression tests, check.sh

### v5.1.5 — Script Inlining
- Native coverage, doctest, header in cyrius.cyr (115KB)
- Removed 3 shell scripts (237 lines)

### v5.1.6 — Modular Refactor
- Split cyrius.cyr into 7 modules (core, build, commands, project, quality, deps, main)
- cc3→cc5 in tool discovery

### v5.1.7 — cbt/ + Dep Fix
- Build tool → top-level `cbt/`, dep duplicate symlink fix, cyrc vet trust

### v5.1.8 — Native capacity, soak, pulsar
- `cyrius capacity/soak/pulsar` all native in cbt/, tool 129KB

### v5.1.9–v5.1.12 — Cleanup, fixes, closeout
- Stale refs swept, LSP cc3→cc5, starship fixed, cyriusly cmdtools
- toml_get cstring crash fixed, dep duplicates removed
- Shell dispatcher → 30-line shim, heapmap audit, benchmark baseline
- patra 1.1.0, capacity --check fixed

</details>

---

## v5.3.x — Open items (deferred)

Items from the v5.3.13 handoff doc's "v5.3.14 nice-to-haves"
scope that did NOT land in v5.3.14. Each is a multi-session
piece; shipping under a sloppy banner would have been
dishonest. Shipped v5.1.x / v5.2.x / v5.3.0–v5.3.14 detail
sections were pruned 2026-04-19 — CHANGELOG.md remains the
source of truth for completed work.

- **NSS/PAM end-to-end** (dynlib follow-up). Simple libc calls
  (`getpid`, `strlen`, `strcmp`, `memcmp`) work end-to-end today
  through `dynlib_open` + `dynlib_bootstrap_cpu_features` + TLS +
  `stack_end`. `getgrouplist` / `pam_authenticate` still SIGSEGV
  inside libc — locale init, nsswitch.conf parse, and NSS module
  dlopen state are missing. Scope: populate those. Reproducer +
  existing bootstrap infra live in `lib/dynlib.cyr` and
  `tests/tcyr/dynlib_init.tcyr`. Downstream blocker for shakti
  0.2.x.
- **aarch64 x86-asm leakage** (Active Bug — supersedes the former
  "native FIXUP address mismatch"). Native self-host verified
  byte-identical on Pi in v5.3.15. Residual work is not native-
  specific: `src/frontend/parse.cyr` still has direct `EB(...)`
  opcode sequences for f64 compare, sub-8-byte struct field
  loads, and regalloc prologue/epilogue that only match x86.
  v5.3.15 closed the biggest surface (memcpy/memset asm removal +
  asm-block alignment padding). Next steps: implement
  aarch64-native `fncall0`–`fncall6` (needs per-arch lib or
  preprocessor gating — neither scaffolded yet), and add aarch64
  branches to the remaining direct-emit x86 paths in parse.cyr.

**libro layout corruption** (Active Bug, see table) is tracked
separately — it's an old, memory-corruption-signature bug where
each `println` shifts the crash site. Not in the v5.3.13 handoff
scope; isolated test binary works as a workaround.

---

## v5.4.x — Windows x86_64 (PE/COFF)

Fourth platform target after Linux ELF, Mach-O x86_64, and
Mach-O arm64. Arc mirrors the Apple Silicon enablement:
byte-level probe → compiler-driven structural emit → code
correctness → stdlib wrappers → native self-host.

### v5.4.0 — PE exit-42 probe ✅
- `programs/pe_probe.cyr` — 1536 B hand-crafted PE32+ image,
  `mov ecx,42; sub rsp,0x28; call [ExitProcess]; int3`,
  single-import IAT, `.text` + `.idata`. Validated on Windows
  11 Home (build 26200, `nejad@hp`): ERRORLEVEL=42 via
  `cmd /v:on /c "exit42.exe & echo !ERRORLEVEL!"`.
- Byte-level floor; no compiler involvement yet.

### v5.4.1 — PE hello-world probe ✅
- `programs/pe_probe_hello.cyr` — 1536 B PE32+ with three
  kernel32 imports (GetStdHandle, WriteFile, ExitProcess),
  full Win64 ABI: RCX/RDX/R8/R9 + 32 B shadow + 5th arg at
  `[RSP+32]` + `sub rsp, 40` for 16-byte RSP alignment. RW
  `.idata` so WriteFile's `bytes_written` DWORD has somewhere
  to land. Validated on Windows 11 Home: prints `hello\n`,
  exits 0.
- Exercises every piece `EMITPE_EXEC` needs: multi-symbol
  import dispatch, RIP-relative `call [rip+disp32]` to IAT,
  RIP-relative `lea` for static data, Win64 shadow+arg frame.

### v5.4.2 — `EMITPE_EXEC` structural backend (in progress)
- `CYRIUS_TARGET_WIN=1` env gate; runtime `_TARGET_PE` flag on
  `src/backend/x86/emit.cyr` (mirrors `_TARGET_MACHO` pattern).
- `src/backend/pe/emit.cyr` fleshed out from 35-line stub:
  byte writers (`_pe_w8/16/32/64/str/pad`), region globals,
  imports registry, two-pass layout (`_pe_layout` computes
  all RVAs/file offsets; `EMITPE_EXEC` walks and writes).
- Dispatch wire in `src/backend/x86/fixup.cyr` `EMITELF(S)`.
- **Scope explicitly limited to structural validity.**
  Success = `file(1)` identifies output as `PE32+ executable
  for MS Windows (console), x86-64`. No `cmp`-vs-reference
  byte gate, no on-hardware execution gate. Code-emission
  correctness (below) deferred to v5.4.3+.

### v5.4.3+ Queue — PE correctness (tracked, not hidden)

What v5.4.2 explicitly does NOT deliver. Each item is a
distinct patch or minor; shipping them as "v5.4.2 plus" would
conflate unrelated work.

- **`EEXIT` `_TARGET_PE` branch** (`src/backend/x86/emit.cyr`).
  Today `EEXIT` emits `mov eax,60; mov edi,42; syscall`
  (Linux). Under PE, must emit `mov ecx, <code>; sub rsp,
  0x28; call [rip+disp32 → ExitProcess IAT slot]; int3`.
  Single-site change; gates byte-level `cmp` against
  `pe_probe.cyr`.
- **Win64 ABI arm at general call sites**
  (`src/backend/x86/emit.cyr` `fncall0`–`fncall6`, `&fn`,
  direct-`EB` sequences in `src/frontend/parse.cyr`).
  First four args in RCX/RDX/R8/R9 (not RDI/RSI/RDX/RCX);
  32 B shadow space below return address; 5th+ args at
  `[RSP+32+]`; `sub rsp, N` sized so RSP is 16-aligned at
  each `call` site; caller preserves R10/R11/RAX (not RDI/RSI
  per SysV). Every `if (_TARGET_PE)` branch we add here is a
  candidate for the "clean separation sweep later" — hoist
  to pe/emit.cyr once the pattern stabilises.
- **Import-registration mechanism.** v5.4.2 hardcodes
  `ExitProcess` in `_pe_layout`. Real programs need
  GetStdHandle/WriteFile/ReadFile/CloseHandle/CreateFileW/
  VirtualAlloc/VirtualFree/GetModuleHandleW/GetProcAddress/
  GetLastError. Options: (a) directive at source level
  (`#pe_import("kernel32.dll", "WriteFile")`); (b) automatic
  discovery from `syscall_win(...)` / kernel32-wrapper calls
  in `lib/syscalls_windows.cyr`. Option (b) composes better
  with the existing `syscall(...)` idiom.
- **`lib/syscalls_windows.cyr`** — kernel32 stdio wrappers
  (`write_stdout`, `write_stderr`, `read_stdin`, `exit_process`,
  `open_file`, `close_handle`, `read_file`, `write_file`),
  routed via IAT. Shape matches `lib/syscalls_macos.cyr`.
- **`lib/alloc_windows.cyr`** — `VirtualAlloc` +
  `VirtualFree` heap. No `brk` on Windows; Cyrius's alloc
  primitives must branch by platform or ship a PE-only
  implementation. Shape matches `lib/alloc_macos.cyr` (mmap
  analogue).
- **`src/cc5_win.cyr`** — cross-compiler entry mirroring
  `src/main_aarch64_macho.cyr`: swap-include-chain style,
  sets `_TARGET_PE = 1` and includes the PE emit path by
  default. Lets `cyrius pulsar`-style scripts produce a
  Win-targeted compiler without `CYRIUS_TARGET_WIN=1` env
  dance.
- **On-hardware end-to-end gate.** Compile `programs/hello.cyr`
  or `programs/exit42.cyr` with `CYRIUS_TARGET_WIN=1`, scp to
  the Windows 11 host, run, verify stdout = `hello\n` and/or
  ERRORLEVEL = 42. Until this lands, "PE32+ valid per file(1)"
  is necessary but not sufficient.
- **Variadic float duplication.** Win64 ABI requires
  floating-point args to variadic functions (and unprototyped
  functions) to be loaded into BOTH the positional XMM
  register AND the corresponding integer register. Trivial
  to implement, easy to forget — breaks `printf("%f", x)`.
  Flag for when we add vararg support on the PE arm.
- **`.reloc` section + ASLR.** v5.4.2 sets
  `IMAGE_FILE_RELOCS_STRIPPED` (0x0001) so the binary loads
  at `ImageBase = 0x140000000`. Fine for a CLI exe; required
  for DLL output and for ASLR opt-in. Scope: emit
  `.reloc` section with `IMAGE_REL_BASED_DIR64` entries for
  every absolute 64-bit address in code/data; clear the
  RELOCS_STRIPPED flag; set `IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE`.
- **Struct return by value (>8 B).** Win64 inserts a hidden
  retptr in RCX; all other args shift right one slot
  (RDX/R8/R9/stack). Defer until aggregate-return is exercised
  by downstream programs.
- **Stack probing (`__chkstk` / `___chkstk_ms` equivalent).**
  Required for frames ≥ 4 KB (one guard page). Defer until a
  compiled program trips it.
- **`.pdata` / `.xdata` — deferred indefinitely.** Not needed
  for CLI .exe execution. Only matters for SEH, C++
  exceptions, debugger stack walks, ETW profiling. Tracked
  here for completeness; no v5.4.x release targets this.

---

## v5.2.x / v5.3.x — Sigil 3.0 enablers

Items the downstream `sigil` crate needs in the Cyrius toolchain to
unlock its v3.0 scope (PQC + parallel batch verify + cleaner
crypto primitives). Sigil will track these as "blocked on Cyrius"
in its own roadmap; landing them here removes the block.

### v5.2.x — stdlib crypto extensions (non-breaking)

- **`lib/keccak.cyr`** — Keccak-f[1600] permutation + sponge API
  (SHAKE-128 / SHAKE-256). NIST FIPS 202. Required for
  ML-DSA-65's XOF step in sigil 3.0 PQC. Self-contained, no
  external deps. Benchmark target: 4 KB SHAKE-256 within 2× of
  sigil's existing `sha256_4kb` (~250 µs).
- ✅ **`ct_select(cond, a, b)` in `lib/ct.cyr`** (shipped v5.3.2).
  Branchless select returning `a` if `cond == 0`, `b` if
  `cond == 1`. Implemented as `a ^ ((0 - cond) & (a ^ b))`;
  x86-64 disasm confirms only `sub`/`xor`/`and` — no `jcc`.
  Sigil can drop its inline mask-xor at `ge_cmov`,
  `_ge_table_select`, and the canonical-S reject path.

### v5.3.x — language-level security primitives (may be breaking)

- ✅ **`secret var name[N];`** (shipped v5.3.5). Zeroise-on-return
  for local arrays: each declaration injects a synthetic entry
  into the function's defer chain that writes zero across the
  buffer before the epilogue exits. Matches Rust's
  `Zeroizing<T>`. Sigil's 8 manual `memset(sk, 0, N)` call sites
  can be deleted once the downstream port lands. Scoped to
  arrays (not scalars) and tied to function exit (not inner
  lexical block) — deliberately narrower than the Rust analogue
  but sufficient for the crypto patterns that prompted it.
- ✅ **`mulh64(a, b) → u64` builtin** (shipped v5.3.3). High 64 bits
  of unsigned 64×64 multiply. x86-64 emits `mul rcx; mov rax, rdx`;
  aarch64 emits the single `umulh x0, x1, x0` instruction. Sigil's
  `_mul64_full` can be replaced by a direct `mulh64` call at each
  site (~20 lines saved per multiply, expected ~15 % win on
  `fp_mul`).

Release targeting: SHAKE + `ct_select` are additive and fit in the
v5.2.x patch train. The `secret` keyword is a language change and
wants v5.3.0 as the natural bump.

---

## v5.x — Platform Targets

Each platform is one minor release. cc5 backend-table dispatch
enables adding new targets without touching the frontend.

| Release | Platform | Format | Status |
|---------|----------|--------|--------|
| **v5.1.0** | macOS x86_64 | Mach-O | **Done** — CYRIUS_MACHO=1, tested on hardware |
| **v5.2.3** | macOS aarch64 | Mach-O | Probes validated on hardware; emitter fold v5.3.0 |
| **v5.3.0** | macOS aarch64 (syscall-only) | Mach-O | EMITMACHO_ARM64 full rewrite; raw BSD svc #0x80 |
| **v5.3.1** | macOS aarch64 strings+globals | Mach-O | **Done** — PIE-safe adrp+add; __cstring + __DATA, hardware-verified |
| **v5.4.0** | Windows x86_64 (exit-42 probe) | PE/COFF | **Done** — 1536 B PE32+, hardware-verified (Windows 11, ERRORLEVEL=42) |
| **v5.4.1** | Windows x86_64 (hello-world probe) | PE/COFF | **Done** — full Win64 ABI call path, prints `hello\n` on hardware |
| **v5.4.2** | Windows x86_64 (`EMITPE_EXEC` structural) | PE/COFF | In progress — compiler emits valid PE32+; correctness queued for v5.4.3+ |
| **v5.4.3+** | Windows x86_64 (PE correctness) | PE/COFF | Queued — EEXIT Win32 branch, Win64 ABI at fncall*, import registry, stdlib wrappers, cc5_win.cyr, on-hardware gate |
| **v5.5.0** | RISC-V rv64 | ELF | First-class RISC-V target |
| **v5.6.0** | Bare-metal | ELF (no-libc) | AGNOS kernel target |

---

## v5.x — IR-Driven Optimization (when complete emit coverage)

LASE and DBE analysis is proven but codebuf patching is unsafe until
all emit paths go through IR. The path:

1. Instrument remaining ~50 emit calls (direct EB/E2/E3 from parse.cyr)
2. LASE codebuf patching becomes safe → redundant load elimination
3. DBE becomes safe → dead block NOP-fill
4. Sound multi-register allocation on IR (replaces peephole #regalloc)
5. Constant folding, strength reduction

---

## v5.x — Toolchain Quality

| Feature | Effort | Description |
|---------|--------|-------------|
| `cyrius api-surface` | Medium | Snapshot-based API surface diffing. Scans `fn` declarations, tracks `mod::name/arity`, diffs against committed snapshot. Catches breaking removals/renames, allows additions. Pattern from agnosys `scripts/check-api-surface.sh`. |
| `cyrius api-surface --update` | Low | Regenerate snapshot after intentional API bump. |
| CI template with api-surface gate | Low | Standard downstream CI step: `cyrius api-surface` fails on breakage. |

---

## v5.x — Language Refinements

| Feature | Effort | Votes |
|---------|--------|-------|
| cc5 per-block scoping | Medium | — |
| Incremental compilation | High | — |
| Stack slices | High | — |
| Generics / traits | High | 1 (kavach) |
| Pattern-match destructuring | Medium | 1 (kavach) |
| Enum exhaustiveness checking | Low | 1 (kavach) |
| Closures capturing variables | High | gotcha #8 |
| Hardware 128-bit div-mod | Medium | — |

---

## Stdlib (60 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, linalg, bigint, u128 |
| Network | net, http, http_server, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, cffi |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda |
| Compression (dep) | sankoch |

---

## Platform Status

| Platform | Format | Status |
|----------|--------|--------|
| Linux x86_64 | ELF | **Done** — primary, cc5 408KB self-hosting |
| Linux aarch64 | ELF | **Partial** — cross-compiler works, native entry point ready (v5.0.3, needs ARM hardware validation) |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **Done** (v5.1.0) — CYRIUS_MACHO=1, tested on 2018 MacBook Pro |
| macOS aarch64 | Mach-O | **Syscall-only Done** (v5.3.0) — EMITMACHO_ARM64 emits 15-LC Stage 2 layout, runs on macOS 26.4.1 Apple Silicon. Strings + globals = v5.3.1. |
| Windows x86_64 | PE/COFF | Stub — **v5.4.0** |
| RISC-V (rv64) | ELF | **v5.5.0** |
| Bare-metal | ELF (no-libc) | **v5.6.0** |

---

## Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik, agnosys, argonaut, kybernet, nous, ark |
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda, hadara |
| **Done** | sigil, patra, libro, shravan, tarang, yukti |
| **Done** | avatara, ai-hwaccel, hoosh, itihas, sankoch |
| **Done** | hisab |
| **In progress** | bhava |
| **Blocked** | vidya MCP (needs bote) |


## Future 6.0

*(TBD — book deferred to the public release cycle, see below.)*

## Public Release (~v7.0) — "Cyrius ONE"

* **Cyrius ONE** — first book, written from Vidya + documentation, published
  alongside the public release (Amazon / Packt). Kicked back from v6 so the
  language surface is stable before the manuscript lands. Exact version TBD
  — lands with whatever version the public release cuts on (current guess: v7).

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Test after EVERY change, not after the feature is done
- **Never use raw `cat | cc5` for projects** — always `cyrius build`
- **v5.0.0 recommended minimum** — cc5 IR, cyrius.cyml, patra 1.0.0, sankoch 1.2.0
