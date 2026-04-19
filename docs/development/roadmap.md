# Cyrius Development Roadmap

> **v5.3.14.** cc5 compiler (423KB), x86_64 + aarch64 cross. IR + CFG.
> Apple Silicon BSD SVC whitelist + parse-time rejection of out-of-whitelist
> syscalls. **`src/main_aarch64_macho.cyr` self-hosts byte-identically on
> Apple Silicon** — Linux cross-compile == Mac round 1 == Mac round 2
> (475320 bytes, macOS 26.4.1). Root-caused and fixed an aarch64 EFLLOAD
> sign-bit typo + imm9 wrap bug affecting any function with ≥ 32 locals
> (see `docs/development/handoff-v5.3.13-mac-selfhost.md`). BSD carry-
> flag errno + cross-platform mmap fallback + x86-backend Mach-O-ARM
> refusal gate landed alongside. dynlib libc wrappers + `cyrius distlib
> [profile]` + `secret var` + `mulh64` + `ct_select`.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5 (423KB). Closure verified.
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
| aarch64 native FIXUP address mismatch | Cross-compiled binaries run on Pi (exit 42 PASS). Native cc5 compiles input but output has wrong MOVZ/MOVK data addresses (0x800120 vs expected 0x4000A8). Heap synced to 21MB. Likely a 64-bit arithmetic or heap corruption issue in the native binary. Cross-compiler is the shipping path. | Tested on real Pi (agnosarm.local, Raspberry Pi aarch64). |

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

## v5.1.x — Tooling Consolidation

Compiled `programs/cyrius.cyr` (105KB) replaces shell dispatcher as primary entry point.

### v5.1.5 — Inline shell scripts into cyrius.cyr (shipped) ✅
- Native `cmd_coverage()`, `cmd_doctest()`, `cmd_header()` in cyrius.cyr
- Removed 3 shell scripts (237 lines → 0), compiled tool handles all natively

### v5.1.6 — Refactor cyrius tool into modules (shipped) ✅
- Split 2249-line monolith into 7 modules: core, build, commands, project, quality, deps, cyrius
- cc3→cc5 in tool discovery, output helpers, --quiet flag

### v5.1.7 — Top-level cbt/, dep duplicate fix (shipped) ✅
- Build tool → `cbt/`, cyrc vet trusts cbt/, dep resolver no duplicate symlinks

### v5.1.8 — Native capacity, soak, pulsar (shipped) ✅
- `cyrius capacity` (--check, --json), `cyrius soak`, `cyrius pulsar`
- `cbt/pulsar.cyr` module (165 lines), tool 129KB

### v5.1.12 — Shell shim + cleanup audit (shipped) ✅
- Shell dispatcher 1620 → 30 lines (thin shim, execs compiled tool)
- Heapmap audit: 43 regions, 0 overlaps. Dead code: 19 fns (kept).
- Benchmark baseline captured. Capacity --check fixed.
- patra 1.0.0 → 1.1.0

---

## v5.2.x — Distribution & Packaging

### v5.2.0 — `cyrius build --distlib`
- Single-command library distribution: bundles `src/` modules into `dist/{name}.cyr`
- Respects `[build] modules` ordering from manifest
- Strips `include` directives (self-contained output)
- Reproducible: re-running produces byte-identical dist
- Replaces per-repo `scripts/bundle.sh` across all deps (sakshi, patra, sigil, yukti, mabda, sankoch)

### v5.2.1 — `cyrius publish` + dep integrity
- `cyrius publish` pushes tagged release with dist bundle
- SHA256 checksum in release assets for dep integrity verification
- `cyrius deps --verify` checks checksums against published hashes

### v5.2.3 — Apple Silicon Mach-O probes ✅
Validated on macOS 26.4.1 (MacBook Pro, Apple Silicon):
- `programs/macho_probe_arm.cyr` — exit-only arm64 Mach-O, runs
  byte-identical to clang's output, returns exit status 42
- `programs/macho_probe_arm_hello.cyr` — libSystem `_write` via
  chained-fixup GOT binding, prints "hello" + returns 42
- Kernel requirements captured: MH_PIE, MH_DYLDLINK, LC_MAIN (not
  LC_UNIXTHREAD), LC_LOAD_DYLINKER, LC_LOAD_DYLIB libSystem,
  LC_BUILD_VERSION, LC_DYLD_CHAINED_FIXUPS, __TEXT R|X (not RWX),
  16KB pages, ad-hoc `codesign -s -`
- Full emitter fold (replacing `EMITMACHO_ARM64`) deferred to v5.3.0

### v5.3.0 — Apple Silicon emitter (syscall-only) ✅
First Cyrius-compiled arm64 Mach-O binaries running on Apple Silicon.
- `EMITMACHO_ARM64` rewritten (15 LCs, code at page 1, __LINKEDIT
  at page 2). Matches Stage 2 probe layout byte-compatible.
- `ESYSCALL`/`ESYSXLAT`/`EEXIT` branch on `_TARGET_MACHO==2` —
  emit `svc #0x80` and BSD syscall numbers in x16.
- Probe finding exploited: raw `svc #0x80` works on Apple Silicon
  when binary has `LC_LOAD_DYLIB libSystem.B.dylib` in load graph,
  even without calling libSystem. No stubs needed for BSD whitelist.
- `programs/macho_probe_arm_rawsvc.cyr` validates _write on whitelist.
- Scope: programs using only `syscall(...)` (no strings, no globals).
- End-to-end: `syscall(60,42);` Cyrius → cc5_aarch64 with
  `CYRIUS_MACHO_ARM=1` → codesign → runs → exit=42.

### v5.3.1 — Apple Silicon strings + globals (hello-world) ✅
Cyrius programs with string literals and globals run on Apple Silicon.
Hardware-verified on macOS 26.4.1.
- `EADRP` / `EADD_IMM12` placeholder encoders + `FIXUP_ADRP_ADD` patch
  routine in the aarch64 backend. `EVADDR_X1`, `EVSTORE`, `EVLOAD`,
  `EVADDR`, `ESADDR` gated to emit the adrp+add pair (8 bytes) under
  `_TARGET_MACHO==2`, falling back to MOVZ/MOVK for Linux.
- `__cstring` section added to `__TEXT` when `spos > 0`
  (S_CSTRING_LITERALS, placed immediately after 4-byte aligned code).
- `__DATA` segment (R|W, 1 page) emitted when `totvar > 0`, vmaddr
  `TEXT_BASE + 0x8000`. Zero-initialised; `__LINKEDIT` shifts to
  page 3 when `__DATA` present.
- FIXUP dispatch computes string addr as `entry + acp + soff` and
  var addr as `0x100008000 + cumul` for Mach-O ARM.
- End-to-end: `var msg="hello\n"; syscall(1,1,msg,6); syscall(60,0);`
  compiles → codesigns → prints "hello" on-device → exit 0.

### v5.3.x — `lib/dynlib.cyr`: callable libc (NSS/PAM enablement)

**v5.3.7** shipped the IRELATIVE + DT_INIT walking infrastructure.
**v5.3.8** added `dynlib_bootstrap_cpu_features()` (zero-fill
`cpu_features` via `_dl_x86_get_cpu_features`). **v5.3.9** added
`dynlib_bootstrap_tls()` (arch_prctl ARCH_SET_FS) and
`dynlib_bootstrap_stack_end()`. Syscall-wrapper libc functions
(`getpid`, `getuid`) now work end-to-end from a static Cyrius binary.
**Remaining:** NSS dispatch (locale init, malloc arenas, NSS module
table) and string/memory IFUNCs (need non-zero HWCAP baseline in
`cpu_features`). Tracked as v5.3.11 after distlib multi-profile.

`dynlib_open` + `dynlib_sym` work today for trivial leaf functions
(verified: `getpid` resolves and returns the correct pid from a
statically-linked Cyrius binary), but calling anything that touches
libc internals SIGSEGVs. Existing TODO in `lib/dynlib.cyr:481` and
`:700` flags exactly this — IRELATIVE relocations and `DT_INIT_ARRAY`
init functions are skipped because the CPU-features struct glibc
expects isn't initialized in a static binary.

**Downstream impact**: shakti 0.2.x cannot restore NSS group resolution
(`getgrouplist`) or real PAM authentication (`pam_start` /
`pam_authenticate`) without this. Two open regressions vs. the Rust
0.1.x build are currently parked on it (see shakti
`docs/development/roadmap.md` "Cyrius port regressions"). Other
downstream consumers needing any libc beyond bare syscalls will hit
the same wall.

Reproducer (segfaults at step 5):
```
var h  = dynlib_open("libc.so.6");           # OK
var fp = dynlib_sym(h, "getpid");            # OK
var pid = fncall0(fp);                       # OK, matches sys_getpid()
var ggl = dynlib_sym(h, "getgrouplist");     # OK (resolves)
fncall4(ggl, "root", 0, buf, ngroups_ptr);   # SIGSEGV
```

Scope:
- Bootstrap glibc's `__cpu_features` struct (or equivalent CPUID-fed
  state) so IRELATIVE resolvers can pick a baseline IFUNC impl on
  x86_64 (SSE2 baseline is universally safe).
- Process Phase 3 IRELATIVE relocations in `_dynlib_process_rela`
  (resolver invocation; result written back at `bias + r_offset`).
- Run `DT_INIT` and walk `DT_INIT_ARRAY` after relocations are
  finalized, so libc's per-loaded-object constructors set up locale,
  malloc state, the NSS module table, etc.
- Smoke probe added to test suite: dlopen libc, call `getgrouplist`
  for `root`, assert non-segfault and non-empty result.
- aarch64 IFUNC story (`STT_GNU_IFUNC` + AT_HWCAP feeding) — defer
  to a follow-up (x86_64 covers shakti's immediate need).

Once landed, shakti can drop `src/identity.cyr` for the supp-GIDs path
and replace the `/usr/bin/su` shim in `src/auth.cyr` with a real PAM
conversation, closing both port regressions.

### v5.3.10 — `cyrius distlib` multi-profile (yukti dual-mode enabler) ✅

Additive to `cmd_distlib()` in `cbt/commands.cyr`. Current callers
unaffected; downstream libs that need more than one bundle per
package (kernel-safe core + full userland) can opt in.

- **`cyrius distlib [profile]`** — optional positional arg
  - No arg (today's behaviour): read `[build] modules` or `[lib] modules`,
    write `dist/{name}.cyr`
  - With `profile=X`: read `[lib.X] modules`, write `dist/{name}-X.cyr`
- Header line gets a `# Profile: X` row for traceability when non-default
- Compile-check still runs against the emitted bundle
- Reject profile names with `/`, `..`, or shell metachars; restrict to
  `[a-zA-Z0-9_-]+` (output path safety)

**Downstream driver — yukti 1.3.0 dual-mode split** (verified blocked
today; distlib silently ignores `[lib.core]` and positional args):

1. Split `src/device.cyr` → `src/core.cyr` (enums, struct layout,
   accessors — pure data, no syscalls) + `src/device.cyr` keeps
   `query_permissions` / `query_device_health`
2. New `src/pci.cyr` — PCI class/subclass + vendor/device ID tables,
   pure table lookups, **zero heap** (kernel-safe)
3. Kernel-facing API restricted to non-allocating lookups
   (`pci_class_to_device_type`, `pci_vendor_name`,
   `pci_device_name`) — avoids exporting yukti's bump allocator
4. Second bundle via `cyrius distlib core` →
   `dist/yukti-core.cyr` for AGNOS kernel bare-metal PCI ID
5. Add kernel-style smoke test: compile a no-libc, no-alloc
   program importing only `yukti-core.cyr` with 0 undefined refs

Item (4) is the only piece that lives in cyrius — the rest ships in
yukti once distlib profiles are available.

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
| **v5.4.0** | Windows x86_64 | PE/COFF | Stubs scaffolded (v3.1) |
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

* Book - PDF writen using Vidya and Documentation to Flesh out what the Lanaguage looks
like at 6.0 - publish and amazon / packt

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
