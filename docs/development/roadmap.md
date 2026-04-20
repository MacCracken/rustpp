# Cyrius Development Roadmap

> **v5.5.11.** cc5 compiler (478608 B x86_64), x86_64 + aarch64
> cross. IR + CFG. **Windows arc — stages 3–9 shipped; first
> Cyrius program runs end-to-end on real Windows.** v5.4.2
> landed the structural `EMITPE_EXEC` backend. v5.4.3 added
> the PE fixup infrastructure + `EEXIT` Win64 branch. v5.4.4
> reroutes explicit `syscall(60, code)` through the same
> `ExitProcess` IAT path at parse time. v5.4.5 adds the
> on-hardware CI gate on `windows-latest`. v5.4.6 adds the
> `#pe_import("kernel32.dll", "Symbol")` directive. v5.4.7
> reroutes `syscall(1, fd, buf, len)` to
> `GetStdHandle + WriteFile` via the auto-registered IAT.
> **v5.4.8 adds the PE `.rdata` section + PE-aware
> `movabs rax, imm64` fixups** — gvars / string literals now
> land at real PE VAs (`ImageBase + _pe_rdata_rva + …`), so
> `syscall(1, 1, "hi\n", 3); syscall(60, 0);` compiled with
> `CYRIUS_TARGET_WIN=1` prints `hi` and exits 0 on
> `windows-latest`. Remaining correctness work (general Win64
> ABI at `fncall*`, `syscall(n)` for the rest,
> `lib/syscalls_windows.cyr` + `lib/alloc_windows.cyr`,
> `cc5_win.cyr` cross-entry, RW-split between `.rdata` and
> `.data`, byte-cmp polish) opens **v5.5.0** as its first
> item — the v5.5 minor begins with the Windows arc that
> v5.4.x didn't finish. **v5.4.9 ships the `_cyrius_init`
> GLOBAL fix + sigil 2.8.4 pin**. **v5.4.10 ships
> `lib/thread.cyr` post-`clone()` child trampoline + futex
> wake-flag fix** (majra unblocked). **v5.4.11 ships aarch64
> Linux syscall stdlib + aarch64 thread trampoline + sankoch
> 2.0.0** (yukti unblocked: `syscall(4, …)` no longer
> `pivot_root` on aarch64). **v5.4.12 ✅ tool-cleanup pass**
> — `cyriusly` extracted, pulsar/install.sh layout unified,
> cyrld shipping, cyrius.bak deleted, shell-migration plan
> recorded. **v5.4.12-1 ✅ release-lib.sh dep-tag drift
> hotfix** — hardcoded dep tags parallel to cyrius.cyml
> rot silently; fixed by awk-parsing the manifest directly.
> **v5.4.13 ✅ fncall ceiling lift** (mabda wgpu render-pass
> unblock — fncall7 / fncall8 in lib/fnptr.cyr + FFI
> struct-packing policy docs). **v5.4.14 ✅ hashmap
> Str-struct key fix** (marja-surfaced data loss, ~3%
> entry loss on str_from_int-keyed maps; additive
> map_new_str() + hash_str_v(), no API break). **v5.4.15 ✅
> `lib/keccak.cyr` + sigil 2.9.0** (sigil 3.0 PQC enabler:
> Keccak-f[1600] + SHAKE-128/256 sponge, NIST-verified on
> both arches, SHAKE-256 4KB at 329µs within 2× sha256_4kb
> budget). **v5.4.16 ✅ stdlib perf pass** — `_keccak_rotl64`
> inlined at 5 theta + 1 rho+pi sites; SHAKE-256 4KB 314µs →
> 262µs (−17%, within ~5% of sigil sha256_4kb parity). **The
> v5.4.x tail splits cleanup into four focused releases
> rather than one grab-bag closeout** (each single-issue so
> bisect stays trivial): **v5.4.17 `lib/toml.cyr` multi-line
> array fix** (shakti unblock), **v5.4.18 release-scaffold
> hardening** (tool-list → `[release]` cyrius.cyml table +
> install-snapshot refresh hook), **v5.4.19 `#ifplat` +
> compiler hardening** (lex directive + parse.cyr unguarded
> x86-emit audit + aarch64 `EW` alignment assert + optional
> `--strict` mode), **v5.4.20 TRUE closeout** (dead-code
> sweep, full vidya catch-up, CLAUDE.md §"Closeout Pass"
> 9-step checklist). After v5.4.20 ships, the next tag is
> **v5.5.0** opened the v5.5.x platform-rounding arc. Every
> remaining v5.5.x item now has a **concrete patch number** in
> the release table below (§"v5.5.x pillars") — v5.5.4 Win64 ABI
> call-site completion, v5.5.5 `&fn` PE VA fixup, v5.5.6
> `lib/fnptr.cyr` Win64 variants, v5.5.7 strict Win64 shadow-space
> compliance, v5.5.8 Windows heap bootstrap (SYS_MMAP), v5.5.9
> native Windows self-host, v5.5.10 PE output size + byte-identical
> fixpoint, v5.5.11 Apple Silicon libSystem probe, v5.5.12
> compiler-driven Mach-O libSystem emission, v5.5.13 aarch64
> native Linux self-host, v5.5.14 include-asm bug, v5.5.15 NSS/PAM,
> v5.5.16 TLS, v5.5.17 atomics, v5.5.18 thread-safety audit,
> v5.5.19 PE .reloc+ASLR, v5.5.20 PE struct-return+variadic+__chkstk
> tail, v5.5.21 closeout. No more "pillar N / parallel track"
> ambiguity.
> **After v5.5.x:**
> **v5.6.0–5.6.5 is the compiler-optimization arc** (pinned
> 2026-04-20; was a "parallel track" across v5.4.x/v5.5.x with no
> numbers). Each O-phase gets its own patch: v5.6.0 O1
> instrumentation+FNV-1a, v5.6.1 O2 peephole, v5.6.2 O3 IR-driven
> passes, v5.6.3 O4 linear-scan regalloc, v5.6.4 O5 maximal-munch,
> v5.6.5 O6 slab (measurement-gated, may skip). Synthesized from
> vidya and external research (QBE / TCC / Poletto-Sarkar / Agner
> Fog). **v5.6.6 closeout is a downstream gate** — genesis repo
> Phase 13B (arch-neutral boot pipeline) and the ecosystem sweep
> (agnos, kybernet, argonaut, agnosys, sigil, ark, nous, zugot,
> agnova, takumi) open on v5.6.6 ship and close before v5.7.0, so
> the closeout carries extra rigor (heap-map cleanup, refactor
> pass, security re-scan) to hand downstream a stable, clean
> base. **v5.7.0 is RISC-V rv64** (slid from v5.6.0 on 2026-04-20
> so the optimization arc lands first — new port inherits an
> optimized compiler, rv64 backend lands against v5.6.4's new
> tile walker on day one). **v5.8.0 is bare-metal / AGNOS kernel
> target** (slid with the optimization minor insert). aarch64
> port remains fully online (`regression.tcyr` 102/102 on real
> Pi, native `cc5` self-hosts byte-identical, per-arch asm via
> `#ifdef CYRIUS_ARCH_{X86,AARCH64}` from v5.3.16). Apple Silicon
> Mach-O self-hosts byte-identically on M-series (v5.3.13,
> 475320 B). **Still deferred to later v5.5.x patches**: libro
> layout corruption, `lib/hashmap_fast` / `u128` / `mabda`
> arch-gating, yukti `include` rename. **NSS/PAM end-to-end** is
> now pinned to **v5.5.15** (shakti 0.2.x is the downstream
> blocker; libpam SIGSEGV root cause = NSS dispatch + locale init
> bootstrap).
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

For shipped work see [CHANGELOG.md](../../CHANGELOG.md) (source of
truth) and the high-level phase summaries in
[completed-phases.md](completed-phases.md).

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
  0.2.x (today shakti's `pam_authenticate` is a stub returning
  `SHK_ERR_PAM_UNAVAILABLE`; the caller falls through to
  `/usr/bin/su` — works but isn't the long-term shape).
  **Pinned to v5.5.15** — see the numbered release table in the
  §"v5.5.x pillars" section below. Carrying forward the full v5.3.x
  context (reproducer + SIGSEGV root cause) verbatim here so it
  doesn't get amputated when the work begins.
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

### v5.4.2 — `EMITPE_EXEC` structural backend ✅
- `CYRIUS_TARGET_WIN=1` env gate; runtime `_TARGET_PE` flag on
  `src/backend/x86/emit.cyr` (mirrors `_TARGET_MACHO` pattern).
- `src/backend/pe/emit.cyr` fleshed out from 35-line stub:
  byte writers (`_pe_w8/16/32/64/wstr/wpad`), region globals,
  imports registry, two-pass layout (`_pe_layout` computes
  all RVAs/file offsets; `EMITPE_EXEC` walks and writes).
- Dispatch wire in `src/backend/x86/fixup.cyr` `EMITELF(S)`.
- **Scope limited to structural validity.** Gate passed:
  `echo 'syscall(60,42);' | CYRIUS_TARGET_WIN=1 build/cc5 > out.exe`
  → `PE32+ executable for MS Windows 6.00 (console), x86-64,
  2 sections`, 1536 B (byte-count match with `pe_probe.cyr`).
  Code-emission correctness (below) queued for v5.4.3+.

### v5.4.4 — `syscall(60, code)` → `ExitProcess` rerouting ✅
- **`_TARGET_PE` branch in `src/frontend/parse.cyr`'s syscall
  handler.** When `sc_num == 60` under `CYRIUS_TARGET_WIN=1`,
  the parser pops the exit code to `rax`, discards the
  syscall-number slot (`add rsp, 8`), and calls `EEXIT(S)`
  which emits the Win64 `ExitProcess` call sequence from
  v5.4.3. Non-60 syscalls under `_TARGET_PE` still fall
  through to the Linux emission and emit a stderr warning.
- **Gate**: compiled `syscall(60, 42);` `.text` contains
  zero `0F 05` bytes (Linux syscall absent). Binary remains
  1536 B `file(1)`-valid PE32+. On-hardware execution gate
  untested but should now work (deferred to v5.4.5+ alongside
  other kernel32 mappings).
- **Still held for byte-cmp vs `pe_probe.cyr`**: initial
  `jmp +0` prelude removal + implicit-EEXIT suppression when
  source already exited. Polish, not correctness.

### v5.4.8 — PE data placement (`.rdata` + PE-VA fixups) ✅
- **Third PE section `.rdata`** (`src/backend/pe/emit.cyr`)
  holds gvar storage + string literal bytes. Sub-layout: gvars
  first (zero-filled, `totvar` bytes) then strings
  (`GSPOS(S)` bytes, copied from `S + 0x14A000`).
  `_pe_rdata_rva / _pe_rdata_str_off / _pe_rdata_gvar_off`
  globals published for `fixup.cyr` to consume.
- **`NumberOfSections` 2 → 3**, `hdr_raw` 408 → 448 (extra
  40-byte section header, still rounds to `FileAlignment`=512),
  `SizeOfInitializedData` now covers `.idata + .rdata`.
- **PE-aware `FIXUP(S)` branches** in
  `src/backend/x86/fixup.cyr` for `ftype == 1` (string) and
  `ftype == 0` (gvar): target = `0x140000000 + _pe_rdata_rva +
  rdata_offset`. Patched as the full 8-byte `imm64` in the
  already-emitted `movabs rax, imm64` encoding; no changes to
  emitter instruction selection.
- **CI hello-world gate**. `windows-cross` compiles
  `syscall(1, 1, "hi\n", 3); syscall(60, 0);`, asserts the
  PE output has 3 sections AND that the compiled `movabs`
  targets `0x140000000..0x200000000` (regression gate — catches
  any future emit path that reintroduces the pre-v5.4.8 ELF-VA
  bug). `windows-native` runs the resulting `hello.exe` on
  `windows-latest`, captures stdout, and asserts
  `stdout == "hi"`, `ExitCode == 0`.
- **Gate on hardware**: first Cyrius-compiled program that
  exercises a real kernel32 I/O call end-to-end. `hello.exe`
  (2048 B, 3 sections) runs clean.
- cc5: 464224 → 466560 B; self-host byte-identical;
  `sh scripts/check.sh` 8/8.
- **Also fixed: cc5_aarch64 cross-compile `&local` x86 leak.**
  `src/frontend/parse.cyr` ~line 670 unconditionally emitted x86
  `LEA rax, [rbp+disp32]` (3+4 = 7 bytes ≡ 3 mod 4) for the
  address-of-local factor; with multiple `&local` uses across the
  auto-prepended stdlib, the misalignment compounded to +1 byte by
  ELF entry, which landed the entry branch on the last byte of a
  trailing RET (decoded as `0x800000d6`, unallocated → SIGILL).
  Filed as the cc5_aarch64 SIGILL blocker in yukti's
  `docs/development/issues/2026-04-19-cc5-aarch64-repro.md`. Fix
  arch-dispatches the emit: aarch64 path now emits `SUB X0, X29,
  #|disp|` (1 instruction = 4 bytes, aligned), with MOVZ+MOVK+SUB
  fallback for displacements outside imm12 range. Verified on real
  Pi 4 (`runner@agnosarm.local`): `core_smoke-aarch64` PASS exit 0,
  yukti main CLI exits 0. Other unguarded x86-emit paths in
  `parse.cyr` (closure address ~970, struct field byte/word/dword
  load 1777-1779, `#regalloc` callee-saved 3257/3403, x87) are
  audited in v5.4.10+ along with a permanent `EW` alignment assert
  in aarch64 emit.


### v5.4.7 — `syscall(1)` → `GetStdHandle + WriteFile` ✅
- **`EWRITE_PE(S)` in `src/backend/x86/emit.cyr`** consumes the
  `[len][buf][fd][sc_nr=1]` stack layout left by parse.cyr's
  generic push loop and emits the Win64 call sequence against
  an auto-registered IAT: `pop/mov` into `r8/rdx/rcx`, a
  two-instruction `fd → nStdHandle` transform (`neg rax;
  sub rax, 10`), a 64-B stack frame (`sub rsp, 0x40`) that
  keeps RSP 16-aligned and leaves room for shadow + 5th arg +
  scratch, a save of `rdx`/`r8` across `GetStdHandle`, and a
  reload + `WriteFile(hFile, buf, len, &n, NULL)` with
  `lpOverlapped = NULL` at `[rsp+0x20]`.
- **`_pe_ensure_stdio(S)` in `src/backend/pe/emit.cyr`**
  lazily registers `GetStdHandle` + `WriteFile` in the
  `_pe_pending_imp_*` queue on first `syscall(1)` use and
  records their future `imp_idx`s so `EWRITE_PE` can encode
  the correct `ftype=4` IAT-reference fixups. `ExitProcess`
  stays at `imp_idx=0` unconditionally so `EEXIT` (v5.4.3)
  keeps working.
- **`src/frontend/parse.cyr`** — new
  `_TARGET_PE && sc_num == 1 && argc == 4` branch sibling to
  the v5.4.4 `sc_num == 60` branch; calls `EWRITE_PE(S)` and
  returns before falling into `ESCPOPS`.
- **aarch64 shim** (`src/backend/aarch64/emit.cyr`) for
  `EWRITE_PE`, following the v5.4.4 / v5.4.6 arch-flag lesson.
- **Gate**: `echo 'syscall(1, 1, "hi\n", 3); syscall(60, 0);'
  | CYRIUS_TARGET_WIN=1 build/cc5 > out.exe` →
  - 1536 B PE32+, `file(1)`-valid.
  - IAT has 4 thunks in order `[ExitProcess, GetStdHandle,
    WriteFile, NULL]`; `.text` disassembly shows all 4 call
    sites resolving to the right slots (GetStdHandle=1,
    WriteFile=2, explicit exit=0, implicit trailing EEXIT=0).
  - Zero `0F 05` syscall bytes.
  - `sh scripts/check.sh` 8/8 pass; self-host byte-identical;
    cc5: 461880 → 464224 B.
- **On-hardware print gate deferred**. Today the buffer pointer
  passed to WriteFile comes from `movabs rax, imm64` with an
  ELF-style ImageBase (`0x400…`), so the pointer is unmapped
  under PE's `0x140000000` ImageBase and WriteFile returns
  `FALSE` without writing. Structural correctness is the
  v5.4.7 scope; the native CI job can grow a `hello.exe →
  "hi\n" → exit 0` assertion once PE-aware gvar / string
  placement lands (v5.4.8+).

### v5.4.6 — `#pe_import` directive ✅
- Source-level directive `#pe_import("dll", "symbol");` registers
  a kernel32 IAT import at parse time. Mirrors `#assert` /
  `#regalloc` prefix style. Parser hands the symbol bytes
  (from `str_data`) to a new pending-imports buffer in
  `src/backend/pe/emit.cyr`; `_pe_layout` appends them to the
  real imports registry after `ExitProcess` (which stays at
  imp_idx=0 so `EEXIT`'s slot is untouched).
- **Gate**: `echo '#pe_import("kernel32.dll", "WriteFile")
  syscall(60, 0);' | CYRIUS_TARGET_WIN=1 build/cc5 > out.exe`
  produces a PE32+ with 2 real IAT thunks + null terminator;
  `strings` shows `ExitProcess` / `WriteFile` / `kernel32.dll`.
- aarch64 shim added in `backend/aarch64/emit.cyr` per the
  v5.4.4 arch-flag lesson — `#pe_import` on aarch64 targets
  is a no-op (Windows PE is x86_64 only).

### v5.4.5 — On-hardware Windows CI gate ✅
- **`windows-cross` + `windows-native` jobs** in
  `.github/workflows/ci.yml`. Cross-compiles exit-code programs
  under `CYRIUS_TARGET_WIN=1` on ubuntu-latest, validates the
  structural signature (MZ / PE\0\0 / `Machine = 0x8664`) and
  zero `0F 05` bytes, uploads `.exe` artifacts, then runs each
  on a real `windows-latest` runner via PowerShell and verifies
  `ExitCode` matches.
- Tests: `syscall(60, N);` for N ∈ {0, 1, 42, 255}. Closes the
  "on-hardware execution gate" queue item from v5.4.4's CHANGELOG.
- No compiler source change; validates the existing v5.4.2 +
  v5.4.3 + v5.4.4 work end-to-end against the Windows loader.

### v5.4.3 — PE fixup infrastructure + `EEXIT` Win64 branch ✅
- **`ftype=4` IAT-reference fixup** added to the existing
  `fixup_tbl` at `0xE4A000`. `_pe_iat_fixup_add(S, coff, imp_idx)`
  registers; `FIXUP` patches
  `disp32 = (_pe_idata_rva + _pe_iat_sub_off + idx*8) -
           (_pe_text_rva + coff + 4)`.
- **`_pe_layout(S)` call moved from `EMITELF` to early in
  `FIXUP(S)`** so ftype=4 fixups resolve against populated RVAs
  before the patch loop runs.
- **`EEXIT` `_TARGET_PE` branch** in `src/backend/x86/emit.cyr`
  emits 13 bytes:
  `mov ecx, eax; sub rsp, 0x28; call [rip+ExitProcess]; int3`.
- Disassembly-verified: disp32 resolves to the correct RVA
  delta (0x0FDF for the exit-42 test case), IAT slot at file
  offset 0x400 holds the Hint/Name entry RVA for `ExitProcess`.
- Byte-for-byte `cmp` against `pe_probe.cyr` deferred to the
  general-`syscall(...)`-rerouting patch (v5.4.4+) — today an
  explicit `syscall(60, 42)` in source still emits the Linux
  syscall instructions alongside the implicit `EEXIT`.

### v5.4.9 — `_cyrius_init` GLOBAL in `object;` mode (mabda blocker) ✅

Regression filed by mabda
(`mabda/docs/issues/2026-04-19-phase0-build-broken.md`,
"Issue 1"). cc5 currently emits the compiler-generated
`_cyrius_init` symbol with `STB_LOCAL` (`src/backend/x86/fixup.cyr`
~line 1080). That's correct for cyrld's multi-object link model
(each `.o` carries its own `_cyrius_init`; cyrld stitches them
into a `_start` chain — see `programs/cyrld.cyr:1038-1105`), but
breaks the case where a cyrius `.o` is linked into a C-entry-point
binary by the system linker. The C launcher calls
`_cyrius_init()` before `mabda_main()`; with `STB_LOCAL` the
symbol isn't visible and `ld` fails with `undefined reference to
_cyrius_init`.

Fixed at v3.4.14, regressed at v4.6.0 alpha2 (per the comment at
`fixup.cyr:1073-1075`); confirmed against v5.4.7+. Affects every
downstream that links a cyrius-compiled `.o` into a non-cyrld
binary: today **mabda** (`programs/phase0.cyr` + the upcoming
`compute_e2e.cyr` / `render_e2e.cyr`); next-up **soorat / rasa /
ranga / bijli / aethersafta / kiran** the moment they bump their
toolchain pin to 5.4.x.

**Scope:**
- `src/backend/x86/fixup.cyr` `EMITELF_OBJ` (the `object;` path):
  emit `_cyrius_init` with `STB_GLOBAL` binding so `ld` can resolve
  external references. Today the byte at `init_symp + 4` is
  hard-coded `0x02` (STT_FUNC | STB_LOCAL); should be `0x12`
  (STT_FUNC | STB_GLOBAL).
- **Coordinate with cyrld.** cyrld merges multiple `.o` each with
  a `_cyrius_init`; if all are GLOBAL the standard collision rule
  triggers. Either (a) cyrld renames per-module (`_cyrius_init` →
  `_cyrius_init_<mod>`) before merging and synthesises the
  call-chain, or (b) cyrld strips the global binding back to local
  on its inputs. Option (a) is the cleaner direction and lines up
  with the multi-CU work already on the cy5 branch.
- **Regression test.** Add `tests/regression-object-init.sh`:
  compile a one-line `object;` program, `readelf -s` the result,
  assert `_cyrius_init` shows `GLOBAL` binding. Wire into
  `scripts/check.sh` so this can't silently regress again.

**Queued (not in v5.4.9 scope, queued for v5.4.10+):**
- **Hard-error mode for `undefined function` warnings.** Mabda's
  Issue 2 was a missing `include "lib/str.cyr"` that cc5 caught
  at parse time as a warning but still produced an object — the
  link failed downstream. A `--strict` flag (or a build-mode that
  treats those warnings as errors) would fail the compile at the
  source-of-truth point. Mabda proposes a CI-only `make
  build-gpu-programs` target that compiles-but-doesn't-link and
  fails on any cc5 warning; we can offer a first-class
  `cyrius build --strict` (or an env-gate) so every downstream
  gets it for free. Issue 2 itself is mabda-side; the toolchain
  enhancement here closes the regression class.

### v5.4.10 — `lib/thread.cyr` post-clone child path (majra blocker) ✅

Filed 2026-04-19 in
`docs/development/issues/majra-cbarrier-arrive-and-wait-crash.md`
as a futex/barrier SIGSEGV, investigated during v5.4.9, and found
to be a deeper structural bug in `lib/thread.cyr`: every
`thread_create(&fn, arg); thread_join(t);` call crashes today,
with or without a barrier. The repro strips to two lines:

```cyr
var t = thread_create(&worker, 0);
thread_join(t);   # → exit 139, child thread SIGSEGVs
```

**Root cause.** `lib/thread.cyr:62-72` runs the post-`clone()`
child branch as plain cyrius code:

```cyr
if (r == 0) {
    var child_fp = load64(child_stack);
    var child_arg = load64(child_stack + 8);
    fncall1(child_fp, child_arg);
    syscall(SYS_EXIT, 0);
}
```

After `clone(CLONE_VM)` the child has a new `rsp` (the mmap'd
stack we passed) but **inherits `rbp` pointing into the parent's
frame**. cc5-emitted code reads/writes locals as `[rbp-N]`, so
the child's reads/stores for `child_fp` / `child_arg` land in
the parent's stack slots — which the parent has already
overwritten on its way through `store64(t, r); return t;`. The
race is consistent enough to crash every run; coredump shows the
faulting PC inside the heap (corrupted function pointer loaded
from garbage locals). The comment at thread.cyr:65 already calls
this out — "We need inline asm to pop and call" — then takes
the shortcut that's broken.

**Why this never surfaced in CI.** `tests/tcyr/` has zero thread
tests today. Downstream users (majra) hit it first; cyrius CI
never exercised the surface.

**Scope:**
- `lib/thread.cyr` post-clone child branch rewritten as inline
  `asm { ... }` that reads `fp` and `arg` from the new stack
  (`[rsp]` and `[rsp+8]`) and calls through them without any
  cyrius local-variable emission. Per-arch via
  `#ifdef CYRIUS_ARCH_{X86,AARCH64}` — x86 uses `call rax` after
  loading from the new stack, aarch64 uses `blr x9`.
- Add `tests/tcyr/threads.tcyr` covering: spawn+join, two
  threads + shared counter under mutex, futex wait/wake
  roundtrip, a barrier arrive+wait (the original majra repro,
  reduced). Expect to land 5–10 assertions.
- `scripts/check.sh` picks the new `threads.tcyr` up
  automatically via the `tests/tcyr/*.tcyr` glob (already wired).
- `.github/workflows/ci.yml` — threading already rides inside
  the test-ubuntu `.tcyr` loop; no new step needed.
- Memory: `feedback_thread_post_clone.md` so the next RBP-
  inheritance-after-clone surprise can cite the rule.

**Queued (not in v5.4.10 scope; future work):**
- **Thread-local storage.** majra's `_aaw_result_state` global
  pattern (the "promote cross-call state to globals" dodge) is
  fundamentally not thread-safe; the post-clone fix doesn't
  help that. A real fix is TLS via `arch_prctl(ARCH_SET_FS)`
  or `%fs:`-relative addressing. Bigger than v5.4.10.
- **Atomic operations / memory barriers.** cyrius has no
  `atomic_add` / `atomic_cas` / `mfence` today. Concurrent
  stdlib code (hashmap mutation under threads, freelist across
  threads) is exposed to data races.
- **Runtime thread-safety audit.** alloc/freelist/hashmap/
  vec all make single-thread assumptions that break under
  `CLONE_VM`. Separate investigation + likely per-thread
  arenas.

### v5.4.11 — aarch64 Linux syscall stdlib (yukti blocker) ✅

Filed 2026-04-19 in
`docs/proposals/2026-04-19-aarch64-syscall-stdlib.md`,
acceptance pulled in from the proposal's original v5.5.x target
because yukti is actively broken on aarch64 today.

**The bug.** `lib/syscalls.cyr` is hardcoded to Linux x86_64
syscall numbers (`SYS_OPEN = 2`, `SYS_STAT = 4`,
`SYS_MKDIR = 83`, …). aarch64 uses the generic syscall table
(`include/uapi/asm-generic/unistd.h`), which is completely
different (`openat = 56`, `newfstatat = 79`, `mkdirat = 34`,
no bare `stat`/`open`/`mkdir`). Cross-built binaries today
include the x86_64 enum verbatim, so every `SYS_*` lookup on
real aarch64 hardware hits the wrong kernel entry point. Yukti
2.1.0 reproduces: `core_smoke` passes on the Pi (no `SYS_*`
calls), but `yukti-test-aarch64` segfaults at
`test_query_permissions_dev_null` because `syscall(4, …)`
invokes `pivot_root` on aarch64 instead of `stat`.

**Why it's stdlib, not compiler.** `parse.cyr` already does
some opaque syscall-number rerouting for aarch64 (`syscall(1)`
and `syscall(60)` work because main CLI's write+exit calls
ran clean on the Pi), but the translation is incomplete and
hidden inside the emitter. Expanding the table further hides
the platform dispatch in code emission. The stdlib is the
honest seam — same pattern as `lib/syscalls_macos.cyr` (already
shipping) and `lib/syscalls_windows.cyr` (queued for v5.4.13+).

**Scope:**
- New `lib/syscalls_aarch64_linux.cyr` peer with the aarch64
  generic-table numbers (~40 enum entries) + at-family wrappers
  (`sys_open` → `openat(AT_FDCWD, …)`, `sys_stat` →
  `newfstatat(AT_FDCWD, …)`, `sys_mkdir` → `mkdirat`, etc.).
- `lib/syscalls.cyr` becomes a 4-line selector: `#ifdef
  CYRIUS_ARCH_AARCH64` → include the aarch64 peer; `#ifdef
  CYRIUS_ARCH_X86` → include `lib/syscalls_x86_64_linux.cyr`
  (renamed from today's `lib/syscalls.cyr` content,
  byte-identical move).
- `struct stat` layout helper. **Decision deferred to
  implementation time** (proposal §3): either keep arch-
  dispatched offset constants, OR route x86_64 through
  `newfstatat` too so both arches share the generic-stat layout.
  Vote: route both for consistency. Decide after auditing
  yukti's `device.cyr:157-159` and `storage.cyr:568` for
  latent dependence on the 144-byte x86 layout.
- `sys_fstat` on aarch64 maps to `fstatat(fd, "",
  AT_EMPTY_PATH)` (or unified via the consistency route above).
- New `tests/regression-aarch64-syscalls.sh`: cross-build a
  one-line program calling `sys_open`/`sys_stat`/`sys_mkdir`,
  scp to `runner@agnosarm.local`, assert exit 0 + correct
  errno on a missing path. Wired into `scripts/check.sh` (gate
  10) but skipped in CI environments without ssh access to
  the Pi (matching the existing yukti `retest-aarch64.sh`
  pattern).

**Acceptance criteria** (from the proposal, tightened):
1. `cyrius build --aarch64 lib/syscalls.cyr /tmp/null` clean
   on x86 host AND aarch64 native.
2. Every `.tcyr` in `tests/tcyr/` plus `regression.tcyr` passes
   when cross-built and run on real Pi.
3. yukti's `scripts/retest-aarch64.sh` runs every target to
   exit 0 (the current `yukti-test-aarch64` regression goes
   green).
4. cc5 + cc5_aarch64 self-host byte-identical.
5. `lib/syscalls.cyr` header line 1 reads "Linux
   (arch-dispatched)", not "Linux x86_64".

**Open questions** (resolved at implementation time, captured
here so they aren't forgotten):
- The `SYS_FORK` translation: `clone(SIGCHLD, 0, 0, 0, 0)` is
  the right POSIX-fork-equivalent (proposal's original
  `CLONE_CHILD|SIGCHLD` was wrong — `CLONE_CHILD` isn't a
  real Linux clone flag). Verify against libro's fork tests
  before landing.
- Two-arm `#ifdef` vs `#ifdef`/`#else` in cyrius preprocessor.
  Only `#ifdef` (no `#else`) is verified in-tree today
  (`lib/fnptr.cyr`); check `src/frontend/lex.cyr` for `#else`
  support before betting on it.
- Downstream pin-bump strategy. Consensus: don't gate cyrius
  CI on downstream retests — keep cyrius CI hermetic. When a
  downstream bumps to v5.4.11+, its own CI reports green.

**Companion (queued for v5.4.13+, not v5.4.11 scope):** audit
`src/frontend/parse.cyr` syscall rerouting — either cover the
full Linux table deterministically OR remove the subset
translation and require consumers to go through
`lib/syscalls*`. Pairs naturally with the existing v5.5.x
audit of unguarded x86-emit paths in shared parse.cyr.

### v5.4.12 — tool-cleanup pass (install / pulsar / release unification)

Reclaims the v5.4.12 slot for a focused tooling housekeeping
release after v5.4.11's yukti-unblock landed. Surfaced while
investigating a "cyriusly missing" report: the native `cyrius
pulsar` install path never shipped the version manager, and
its on-disk layout (`versions/$V/` flat) disagreed with
`install.sh`'s layout (`versions/$V/bin/` subdir) — whichever
ran second dangled symlinks. Scoped small enough to ship a
week after v5.4.11 without deferring the mabda / sigil
unblocks; all three (fncall ceiling, keccak, closeout) just
bump by one.

**Scope:**
- **`cyriusly` extracted** to `scripts/cyriusly` (committed
  source of truth). `install.sh` no longer heredocs it.
  `release.yml` copies it into every tarball bin/ (x86_64,
  aarch64, macos, macos-arm64). `cbt/pulsar.cyr` copies it
  into `versions/$V/bin/cyriusly`.
- **Layout unification.** `cbt/pulsar.cyr` now builds
  `versions/$V/bin/` and `versions/$V/lib/` subdirs
  (matching `install.sh`). Binaries go into `bin/`, not
  flat at the version root. Symlink points
  `$HOME/.cyrius/bin → versions/$V/bin`. Users who want
  `cyriusly use <older-version>` on a pre-5.4.12 flat
  install must reinstall that version via the release
  tarball.
- **`cyrld` in the tarball.** Was built by CI but missing
  from release tarballs + pulsar's bins array. Wired into
  `release.yml` tool loop, tarball bin-copy list,
  `install.sh` source-bootstrap tool list, and pulsar's
  bins array.
- **`scripts/cyrius.bak` deleted** (61KB legacy monolithic
  dispatcher, superseded by the 31-line shim; no references
  outside CHANGELOG).
- **`install.sh` hardcoded version fallback removed.** The
  `VERSION="5.4.11"` default-on-GitHub-API-fail was destined
  to rot. Replaced with a live
  `raw.githubusercontent.com/$REPO/main/VERSION` fetch; if
  both GitHub API and raw fail, hard-error with a
  `CYRIUS_VERSION=<tag>` hint. `version-bump.sh`'s sed for
  this fallback becomes a no-op (the `|| true` tolerates
  that).
- **Stale `/tmp/cc2_verify*` cleanup line** deleted from
  `install.sh` — pre-cc3-rename residue.
- **Shell-script migration plan recorded** (see
  §"Shell-script migration plan" below).

**Acceptance:**
1. `sh scripts/check.sh` 10/10 (unchanged gate count; pure
   tooling release).
2. `cc5` and `cc5_aarch64` self-host byte-identical
   (compiler untouched).
3. Fresh `cyrius pulsar` on a clean `~/.cyrius` produces a
   `versions/$V/bin/` subdir with all 8 binaries (cc5,
   cc5_aarch64, cyrius, cyrfmt, cyrlint, cyrdoc, cyrc,
   cyrld) + cyriusly + `cyrius-*.sh` scripts.
4. `cyriusly list` / `use` / `version` all work after both
   `install.sh` and `cyrius pulsar` paths.
5. Release tarballs for x86_64/aarch64/macos/macos-arm64
   all include `bin/cyriusly`.

### Shell-script migration plan (scripts/ → native cyrius)

Recorded at v5.4.12 so future cleanup work (likely
v5.4.17 closeout or v5.5.x) has an authoritative list.

**Bootstrap-bound (stay shell forever):**
- `scripts/install.sh` — curl-piped entry point; can't
  require cyrius binary.
- `scripts/cyriusly` — manages which cc5 is active;
  chicken-and-egg.
- `scripts/cyrius` — thin dispatch shim; retire once the
  compiled `cbt/cyrius.cyr` binary is universally
  deployed.
- `scripts/mac-selfhost.sh` — maintainer-only manual
  verification on mac hardware; not worth migrating.

**Migration candidates (native target exists or is cheap):**
| Script                   | LOC | Native target                           |
|--------------------------|-----|-----------------------------------------|
| `cyrius-init.sh`         | 549 | `cbt/project.cyr` → new `init_impl`    |
| `cyrius-port.sh`         | 351 | `cbt/project.cyr` → new `port_impl`    |
| `bench-history.sh`       | 300 | `cyrius bench --history`                |
| `check.sh`               | 181 | `cyrius audit` in `cbt/quality.cyr`    |
| `cyrius-repl.sh`         |  98 | `cyrius repl` or standalone `cyrl`     |
| `version-bump.sh`        |  73 | `cyrius version bump <semver>`         |
| `lib/audit-walk.sh`      |  60 | folds into `cyrius audit`              |
| `ci.sh`                  |  57 | `cyrius ci` — fold into `quality.cyr` |
| `release-lib.sh`         |  45 | `cyrius release-lib`                   |
| `mac-diagnose.sh`        |  43 | debug tool — deprioritize             |
| `cyrius-watch.sh`        |  37 | `cyrius watch` (needs inotify)         |

Net migration: ~1900 LOC shell → native cyrius, leaving
~570 LOC bootstrap-bound. Sequencing decided at v5.4.17
closeout; individual migrations can land across v5.5.x
patches without blocking the pillars.

### v5.4.13 — fncall ceiling lift / render-pass FFI unblock (mabda blocker)

Filed by mabda
(`mabda/docs/proposals/2026-04-19-render-pass-ffi.md`). mabda
v2.4.2 closeout is blocked on FFI slots that don't exist in
the current `deps/wgpu_main.c` fn-table — render-pass encoding,
draw-call dispatch, texture-to-buffer copy. The proposal walks
through ~7 new slots + 2 C struct-packing shims; **most of the
work is mabda-side** (their `deps/wgpu_main.c`, their
`src/wgpu_ffi.cyr` wrappers, their `programs/render_e2e.cyr`).
The cyrius-side scope is sharper than the proposal implies.

**The real cyrius issue:** cyrius's `lib/fnptr.cyr` exposes
`fncall0` through `fncall6` only. mabda hits a documented
crash with `fncall6 + wgpu-native` (their
`feedback_fncall6_wgpu` memory) and a hard ceiling at 6 args
(their `feedback_cyrius_param_ceiling` memory), so they're
forced to pack args into structs and call via `fncall2(_fp,
enc, args_ptr)`. Every new wgpu surface they need adds another
C-side struct-packing shim. That's a workaround for cyrius's
fncall ceiling, not mabda-native architecture.

**Scope (cyrius v5.4.13):**
- **Root-cause the fncall6 + wgpu-native crash.** First
  question is whether it's a fncall6 bug (in `lib/fnptr.cyr`'s
  per-arch inline asm — the SysV/AAPCS register-loading
  sequence at the 6th arg) or a wgpu-native ABI quirk that
  cyrius's calling convention happens to violate. Reproduce
  in isolation (cyrius-only, no wgpu) before deciding fix
  shape.
- **Lift the fncall ceiling.** Add `fncall7` and `fncall8` to
  `lib/fnptr.cyr` (and the per-arch inline asm bodies). x86_64
  SysV passes args 7+ on the stack; aarch64 AAPCS64 puts args
  9+ on the stack (so 7 and 8 are still register-passed,
  trivial). Stack-passed args need careful frame setup +
  16-byte SP alignment (per `feedback_aarch64_sp_alignment`).
  ~80-120 LOC across both arches.
- **Document the struct-packing pattern as a fallback.** Even
  with the ceiling lifted to 8, complex C APIs with deeply
  nested structs (the `WGPURenderPassDescriptor` colour-
  attachment array case) still benefit from C-side packing.
  Write `docs/ffi/struct-packing.md` with the WgpuMapArgs /
  WgpuCopyArgs / new WgpuBeginPassArgs / WgpuCopyTexToBufArgs
  worked examples copy-pasteable.
- **Stays mabda-side** (NOT cyrius v5.4.13): the C shims, the
  wgpu_ffi.cyr wrappers, render_e2e.cyr, the per-mabda tests.
  mabda owns its rendering arc; we just remove the toolchain
  ceiling that's forcing the workaround.

**Acceptance:**
1. fncall6+wgpu crash reproduced in isolation, root cause
   documented in a new `feedback_fncall6_root_cause` memory
   (or merged into the existing mabda one).
2. `lib/fnptr.cyr` exposes `fncall7` + `fncall8` for both
   x86_64 and aarch64, with inline-asm bodies tested by a
   new `tests/tcyr/fncall_ceiling.tcyr` that calls a 7-arg
   and 8-arg fn pointer (sum the args, verify result).
3. `docs/ffi/struct-packing.md` published with mabda's
   existing args-struct examples as the canonical pattern.
4. `sh scripts/check.sh` 11/11 (gates 10 + new ceiling-test
   gate).
5. cc5 + cc5_aarch64 self-host byte-identical.
6. mabda-side gate: their pin-bump to v5.4.13 lets them
   replace their 7-arg cases with direct `fncall7` (vs the
   args-struct workaround); the workaround stays in place
   for genuinely-nested struct cases.

**Companion (queued for v5.4.17 closeout):** audit the
ceiling on every fncall consumer in stdlib + downstreams to
identify which `fncall2(...args_struct...)` paths can flatten
to direct `fncallN` once 7 and 8 are available.

### v5.4.14 — `lib/hashmap.cyr` Str-struct key fix (marja) ✅

Shipped 2026-04-20. Marja's soak tests surfaced ~3% entry loss
on Str-struct-keyed maps: `hash_str` was byte-walking the Str
struct as if it were a cstr, producing address-derived hashes.
Fix shipped additive (no API break) — new `map_new_str()`
constructor + `hash_str_v()` + `key_type` tag in the map header
(24→32 bytes). `_map_find` + `map_print` branch on the tag.
Existing cstr-keyed maps work unchanged. See CHANGELOG [5.4.14]
for the full entry.

### v5.4.15 — `lib/keccak.cyr` + sigil 2.9.0 (sigil 3.0 PQC enabler) ✅

Shipped 2026-04-20. Keccak-f[1600] + SHAKE-128 / SHAKE-256
sponge landed in `lib/keccak.cyr`; 7 NIST vectors verified via
Python hashlib on both x86_64 and aarch64. `benches/bench_keccak.bcyr`
measured SHAKE-256 4 KB at **329 µs avg** (target ≤ 500 µs /
2× sha256_4kb; actual 1.3× ratio — within budget). `cyrius.cyml`
sigil pin bumped 2.8.4 → 2.9.0 alongside the keccak landing;
sigil 2.9.0 ships HKDF live, AES-NI deferred to 2.9.1 pending
the include-boundary inline-asm bug (pinned to v5.5.14).
See CHANGELOG [5.4.15] for the full entry.

### v5.4.16 — stdlib perf pass

Small, focused optimization release before the bulk closeout at
v5.4.17. Measurable wins that don't fit alongside broader
cleanup work.

**Scope:**
- **Inline `_keccak_rotl64` at each call site in
  `lib/keccak.cyr`** — the permutation's inner loop calls
  `_keccak_rotl64` ~29 times per round × 24 rounds × 30 blocks
  ≈ 20 k function calls per 4 KB SHAKE-256 hash. On x86_64
  each call is prologue/epilogue + 1 conditional branch (the
  `n == 0` guard). Inlining should remove 15-25 % from the
  329 µs we measured at v5.4.15 — pulls the SHAKE-256 4 KB
  ratio from 1.3× down toward parity with sha256_4kb. Gate:
  `benches/bench_keccak.bcyr` numbers improve; NIST vectors
  still match; self-host byte-identical (lib-only).
- **Audit adjacent stdlib hot paths for the same pattern** —
  `lib/u128.cyr` multiplication, `lib/sha256.cyr` schedule
  (if it exists), any fn whose inner loop makes >1000 calls
  into a single-line helper. One round of inlining per
  identified hot path, each gated by a bench number.
- **No compiler changes.** This is a mechanical
  inline-the-helper pass, not a compiler optimization. The
  compiler's own perf track (phases O1–O6 in the v5.4.x
  optimization arc per the top-of-file banner) stays
  separate.

**Acceptance:**
1. `sh scripts/check.sh` 10/10 PASS (no new gates; existing
   correctness regressions hold).
2. `benches/bench_keccak.bcyr` SHAKE-256 4 KB **≤ 270 µs avg**
   (20 % improvement target; will accept any measurable win).
3. cc5 + cc5_aarch64 self-host byte-identical.
4. Bench-history CSV (`benches/bench-history.csv`) gains a
   v5.4.16 row with the new numbers so we can see the trend.

**Out of scope** (push to v5.4.17 closeout or later):
- Compiler-side optimization (regalloc, peephole, IR passes —
  the O1–O6 track).
- Non-crypto stdlib perf (e.g. vec grow strategy, hashmap load
  factor tuning).
- Any change that alters observable API.

### v5.4.17 — `lib/toml.cyr` multi-line array fix (shakti unblock)

Narrow single-issue release. `lib/toml.cyr:192` terminates
unquoted values at the first `\n`, so a TOML value starting
with `[` truncates to just `"["` when the array spans multiple
lines. Same bug-class as shakti's own local parser; user
observation 2026-04-19: migrating shakti to `lib/toml.cyr`
would not have fixed anything because the bug is in both
parsers. Dormant in cyrius-side consumers today (cyrius.cyml,
vidya TOML content all use single-line arrays) but shakti's
sudoers schema wants multi-line arrays for operator
reviewability.

**Scope:**
- In `lib/toml.cyr`'s value-extract block, detect `[` as the
  first non-space char after `=`. If present, scan forward
  tracking quote + bracket state (quotes toggle in_quote,
  brackets bump depth) and ignore `\n` inside the array body.
  Set the value end to the position after the matching `]`
  (plus optional trailing `\n`).
- Otherwise the old single-line scan applies unchanged.
- ~20 LOC in `lib/toml.cyr`, no new dependencies.

**Tests:**
- `tests/tcyr/toml_multiline.tcyr` — new regression. Parse a
  TOML input with a multi-line `commands = [ "a", "b", "c" ]`
  array and assert `vec_len(... )` == 3 (not 0). Add a
  quoted-`]` edge case (`["weird]path"]`) and a trailing-comma
  edge case. Existing `tests/tcyr/toml.tcyr` continues to pass.

**Acceptance:**
1. `tests/tcyr/toml_multiline.tcyr` PASS — multi-line arrays
   parse to the full list.
2. `tests/tcyr/toml.tcyr` continues to pass (legacy single-line
   arrays + scalar values unchanged).
3. `sh scripts/check.sh` 10/10 (existing gates).
4. cc5 + cc5_aarch64 self-host byte-identical (pure stdlib
   change).
5. **Shakti unblock**: shakti-agent copies the canonical
   algorithm into `src/policy.cyr` and tags shakti 0.2.1 after
   v5.4.17 ships. No cyrius CI gate on shakti (stays hermetic).

**Why its own release:** shakti is waiting. Bundling with
release-scaffold hardening (v5.4.18) or the compiler-side
cleanup (v5.4.19) would delay an operator-facing ergonomic
fix behind larger, higher-risk surface-area changes. Single-
issue diff = cleanest bisect if something regresses.

### v5.4.18 — release-scaffold hardening (packaging cleanup)

Packaging / data-hygiene pass. Two related items, both
surfaced during earlier releases but deferred because they
touch the release pipeline itself and we didn't want to mix
them with correctness fixes.

**Scope:**

- **Tool-list multi-ref collapse.** Surfaced at v5.4.12-1 as
  the sibling of the release-lib.sh dep-tag drift. Today the
  toolchain binary list is duplicated 6 times:
  `.github/workflows/release.yml` (tool-build loop at :47 and
  bin-copy loop at :69), `scripts/install.sh` (source-
  bootstrap tool loop at :137, bin-copy loop at :151, summary
  display at :482), and `cbt/pulsar.cyr` (bins array at
  :129-137). Adding a tool — `cyrld` at v5.4.12 is the recent
  case — requires six synchronized edits; missing any one
  silently drops the tool from a codepath (CI built cyrld but
  release.yml didn't ship it for months). **Fix shape**: new
  `[release]` table in `cyrius.cyml`
  (`bins = [...]`, `cross_bins = [...]`, `scripts = [...]`).
  `release.yml` + `install.sh` parse it with the same awk
  pattern `release-lib.sh` uses; `cbt/pulsar.cyr` extends its
  existing CYML parser to populate the bins/scripts arrays at
  runtime. ~100 LOC net across four files.
- **Install-snapshot refresh hook.** Discovered during
  v5.4.11 Chunk B work. `~/.cyrius/versions/<ver>/{lib,bin}/`
  is created/refreshed by `install.sh`, which copies stdlib
  + canonical binaries (dereferenced) at install time and
  never auto-updates. When `cyrius.cyml` bumps a dep tag
  (e.g. sigil 2.8.3 → 2.8.4 in v5.4.9) and `cyrius deps`
  updates the repo's local `lib/{dep}.cyr` symlink, the
  install snapshot stays at the old content. `version-bump.sh`
  doesn't run `install.sh` either, so binaries also rot.
  Audit snapshot at the time of discovery: 4 lib files + 7
  binaries out of sync. **Fix shape**: `version-bump.sh`
  post-bump hook runs `install.sh --refresh-only` to re-copy
  `lib/` + `bin/` from current repo state. Skips the
  bootstrap-from-source phase. Adds ~2s to a version bump;
  eliminates the silent-rot class entirely.

**Acceptance:**
1. `[release]` table in `cyrius.cyml` is the single source of
   truth for all binary and script lists; `release.yml`,
   `install.sh`, and `cbt/pulsar.cyr` all read from it. A new
   tool is added with one `cyrius.cyml` edit.
2. `version-bump.sh <version>` runs `install.sh --refresh-only`
   at the end; drift audit afterwards shows 0 stale files in
   `~/.cyrius/versions/<version>/{lib,bin}/`.
3. `sh scripts/check.sh` 10/10.
4. cc5 self-host byte-identical.
5. **Pulsar round-trip**: a clean `rm -rf ~/.cyrius && cyrius
   pulsar` installs a working toolchain, verified by running
   `cyriusly list` + `cyrius --version` + a trivial program
   compile.

**Why bundled together:** both items are about the release
pipeline's correctness under change. Fixing one without the
other leaves drift-prone layering (bumping a tool's version
refreshes the snapshot but not its appearance in `release.yml`;
or vice versa). Shipped together gives the release pipeline
one consistent audit boundary.

**Why its own release:** touches `release.yml` and `pulsar.cyr`.
Bundling with the compiler-side cleanup (v5.4.19) would mix
a release-mechanism change with a compiler-internal change —
if the release pipeline breaks, bisecting becomes harder.

### v5.4.19 — `#ifplat` + compiler hardening (frontend/backend)

Compiler-side cleanup pass. All items touch `src/` frontend
or backend; shipping them together keeps the self-host risk
concentrated in one release.

**Scope:**

- **`#ifplat` preprocessor directive.** Replaces the verbose
  `#ifdef CYRIUS_ARCH_X86` / `#ifdef CYRIUS_ARCH_AARCH64`
  pattern with `#ifplat x86` / `#ifplat aarch64` plus proper
  `#elseplat` / `#endplat` family. Captures the (arch, format)
  dimension that today is split between `#ifdef CYRIUS_ARCH_*`
  (preprocessor) and `_TARGET_MACHO` / `_TARGET_PE` (runtime
  flags) — `#ifplat aarch64-macho`, `#ifplat x86-pe` work
  uniformly. Lex/preprocessor change in `src/frontend/lex.cyr`
  (~80-150 LOC), plus migration of the ~3 existing call sites
  (`lib/fnptr.cyr`, `lib/thread.cyr`, the v5.4.11
  `lib/syscalls.cyr` selector). **Why before v6.0.0**: v5.5.0
  is about to add many more dispatch sites (PE syscalls,
  `lib/syscalls_windows.cyr`, `cc5_win.cyr` cross-entry);
  landing the convention before v5.5.x prevents another wave
  of `_TARGET_PE == 1` runtime branches that v6.0.0 would
  then need to clean up. Migration cost stays small (3 sites)
  if we do it now; balloons if deferred.
- **`parse.cyr` unguarded x86-emit audit.** Flagged in
  v5.4.10's memory (`feedback_unguarded_x86_emit.md`) —
  closure address @970, struct field byte/word/dword load
  1777-1779, `#regalloc` callee-saved 3257/3403, x87
  fallbacks. Fix what fires under any current downstream's
  exercise; queue what doesn't to v5.5.x.
- **Permanent `EW` alignment assert** in
  `src/backend/aarch64/emit.cyr` — the catch-everything net
  for any future RBP-shift / alignment regression on aarch64.
  Cheap; should have been there since v5.4.8.
- **Audit `src/frontend/parse.cyr`'s opaque syscall
  rerouting** (the partial translation that makes `syscall(1)`
  and `syscall(60)` work on aarch64 today) — either complete
  the table deterministically or remove the subset and
  require consumers to go through `lib/syscalls*` (now per-arch
  as of v5.4.11).
- **`cyrius build --strict` mode** (escalate `undefined
  function` warnings to hard errors) if it can land cheaply —
  closes the regression class that mabda Issue 2 represents
  and that v5.4.15's `bench_print_all` typo demonstrated.
  Otherwise defer to v5.5.x.

**Acceptance:**
1. `#ifplat` + `#elseplat` + `#endplat` parse correctly in
   `src/frontend/lex.cyr`; 3 existing dispatch sites migrated
   and work identically.
2. `tests/tcyr/ifplat.tcyr` new regression gating arch
   dispatch under both the old `#ifdef` form (backward-compat)
   and the new `#ifplat` form (equivalence check).
3. No new unguarded x86-emit sites remain in the cross-built
   aarch64 compiler output (audit loop clean).
4. aarch64 `EW` alignment assert fires under a synthetic
   misalignment (test) and not under normal compile (existing
   tests pass).
5. `cyrius build --strict` with an undefined-function program
   exits non-zero with a clear error.
6. `sh scripts/check.sh` 11/11 (adds the `#ifplat`
   equivalence gate).
7. cc5 + cc5_aarch64 self-host byte-identical under the new
   conventions.

**Why its own release:** all compiler-internal surface. Self-
host is the critical path — a regression here means cc5 won't
compile itself. Isolating to one release lets us verify the
self-host hold after EACH item and bisect cleanly if
something breaks.

### v5.4.20 — v5.4.x closeout pass (then v5.5.0)

Per the closeout-pass procedure in `CLAUDE.md` (run before every
minor/major bump, ship as the last patch of the current minor —
e.g. 4.2.5 before 4.3.0). v5.4.20 is the v5.4.x closeout; tagging
it clears the path for v5.5.0 (Platform Targets — see §"v5.x —
Platform Targets" below).

**Scope** — mechanical pass, no new features:
- Dead-code audit (remove any unreachable fns; the standing
  21-fn list at v5.4.10 is a good floor).
- Stale comment sweep (grep for old version refs, outdated
  TODOs, references to renamed fns).
- Heap map verify (main.cyr heap map matches actual usage).
- Downstream check (every `cyrius.cyml` `cyrius` field across
  ecosystem repos points at the released v5.4.x tag).
- Security re-scan (quick grep for new `sys_system`,
  `READFILE`, unchecked writes — last full audit was v5.0.1).
- CHANGELOG / roadmap / vidya sync (vidya is the silent-rot
  one; per-file checklist below).
- Full `sh scripts/check.sh` — 11/11 PASS (accumulated gates
  through v5.4.19).
- Post-v5.4.10 thread-surface verification (TLS gap, atomics
  gap, runtime thread-safety under `CLONE_VM`): decide whether
  any of those need a v5.4.x patch slot or all push to v5.5.x.

**Closeout checklist** (verbatim from CLAUDE.md §"Closeout Pass"):

1. Self-host verify — cc5 compiles itself byte-identical.
2. Bootstrap closure — seed → cyrc → asm → cyrc byte-identical.
3. Dead code audit (see bullet above).
4. Stale comment sweep.
5. Heap map verify.
6. Downstream check.
7. Security re-scan.
8. CHANGELOG / roadmap / vidya sync — per-file vidya
   breakdown in `feedback_vidya_closeout.md` memory; at
   closeout, walk through every vidya file referenced there
   and bring it current with what shipped across v5.4.x.
9. Full `sh scripts/check.sh` — 11/11 PASS.

After v5.4.20 ships, the next tag is **v5.5.0** — which is
itself claimed by the PE correctness completion below. The new
minor opens with the same Windows arc that closed v5.4.x: ship
the `fncall*` Win64 ABI rework + the remaining `syscall(n)`
mappings + `lib/syscalls_windows.cyr` + `lib/alloc_windows.cyr`
+ `cc5_win.cyr` cross-entry + RW-split as v5.5.0.

**v5.5.x release sequence — every item has a concrete patch
number.** No more "pillar N / parallel track" ambiguity.
Previously-deferred items that kept accreting "soon" notes are
pinned below. Reordering requires an explicit roadmap edit
documented in CHANGELOG.

Platform-rounding first (Windows + Apple Silicon finish their
arcs), then Linux runtime correctness, then the PE correctness
tail. Compiler optimization (O1–O6) is its own minor at
**v5.6.x** — see §"v5.6.0 — Compiler optimization arc"
below. Optimization claims v5.6.x **before** RISC-V (v5.7.0) —
the phases have slipped across v5.4.x and v5.5.x as a "parallel
track" with no numbers; landing them in v5.6.x closes that drift
before opening the next platform port.

| Release | Item | Notes |
|---------|------|-------|
| **v5.5.0** ✅ | PE correctness foundation | `cc5_win` cross-entry + `lib/syscalls_windows.cyr` + `lib/alloc_windows.cyr` + CYRIUS_TARGET_WIN/LINUX selectors |
| **v5.5.1** ✅ | 5 kernel32 syscall reroutes | Read/Open/Close/Seek/VirtualAlloc via IAT |
| **v5.5.2** ✅ | Enum-constant sc_num fold | `syscall(SYS_WRITE, …)` wrappers route cleanly |
| **v5.5.3** ✅ | Win64 arg-register flip (≤4 args) | EPOPARG + ESTOREREGPARM under `_TARGET_PE` |
| **v5.5.4** | Win64 ABI call-site completion | Shadow space at cyrius-to-cyrius call sites + >4-arg stack shuttle in `ECALLPOPS`/`ECALLCLEAN` + `ESTOREPARM` dispatch boundary + `ESTORESTACKPARM` shadow offset. Compiler-backend concern. |
| **v5.5.5** | `&fn` PE VA fixup | Prerequisite for v5.5.6 (fnptr.cyr) surfaced during testing: `fixup.cyr` ftype=3 (fn-address) computed `entry + fn_offset` using the ELF entry point, not the PE `ImageBase + .text RVA + fn_offset`. `&fn` under `CYRIUS_TARGET_WIN=1` emits an ELF-style VA that Windows rejects with error 216 ("not compatible"). 3-line patch mirroring the existing ftype=1 string-address PE branch. |
| **v5.5.6** | `lib/fnptr.cyr` Win64 `fncallN` variants | Indirect fn-pointer calls need Win64 arg-register mapping + 32 B shadow allocation before the indirect `call`. 9 `#ifdef CYRIUS_TARGET_WIN` parallel asm blocks. Stdlib concern (distinct surface from v5.5.4's backend work). Depends on v5.5.5. |
| **v5.5.7** | Strict Win64 shadow-space compliance | Retroactively adds 32 B shadow at cyrius-to-cyrius call sites (ECALLPOPS) + shifts ESTORESTACKPARM to `[rbp+16+32+(pidx-4)*8]` + adds shadow to `lib/fnptr.cyr` Win64 `fncallN` blocks. Closes the C-FFI-via-fnptr gap v5.5.4/5.5.6 deferred. After v5.5.7, a cyrius fn can be called through fnptr by a Win64 C function (and vice versa) without shim. Pinned here rather than left as a "documented limitation" per the pin-everything roadmap discipline. |
| **v5.5.8** | Windows heap bootstrap (SYS_MMAP) | `main_win.cyr` was using `syscall(SYS_BRK)` for heap init — Windows has no brk; PE backend doesn't reroute `syscall(12)`. v5.5.8 switches to `syscall(SYS_MMAP, 0, 32MB, 3, 0x22, -1, 0)` which works on both Linux (sensible mmap flags) and Windows (v5.5.1 routes syscall(9) → VirtualAlloc, ignoring prot/flags). Fixes STATUS_ACCESS_VIOLATION at heap-init time. Necessary but not sufficient for native self-host; cc5_win.exe still crashes later at startup (suspected Linux-ism in /proc/self/* readback). |
| **v5.5.9** ✅ | Native Windows self-compilation (Linux-ism gates) | Three `/proc/self/*` readback blocks gated behind `#ifdef CYRIUS_TARGET_LINUX` so cc5_win.exe skips them on Windows: /proc/self/cmdline (--version/--strict parse in main_win.cyr), `_init_cyrius_lib()` /proc/self/environ HOME read (lex.cyr), `_read_env()` /proc/self/environ env-var scan (fixup.cyr). After gating, cc5_win.exe reads source from stdin, compiles, writes valid PE to stdout. 2/2 matrix PASS on `nejad@hp` (simple exit42 + multi-fn add). Known bug: output PE is ~1.18 MB vs 1.5 KB from Linux cross-build (size bloat in `_pe_image_file_size`); byte-identical fixpoint pinned to v5.5.10. |
| **v5.5.10** | PE output size bloat + byte-identical self-host fixpoint | cc5_win.exe emits ~1.18 MB PE for any input; Linux cross-build emits ~1.5 KB for the same. Mostly trailing zero padding. `_pe_image_file_size` calculation in `src/backend/pe/emit.cyr` diverges when running on Windows vs Linux — some state read differs between platforms. Once fixed, byte-identical fixpoint (cc5_win.exe compiling main_win.cyr on Windows producing an output matching the Linux cross-build byte-for-byte) becomes testable — the true native-self-host gate. Also: .tcyr suite on windows-latest. |
| **v5.5.11** ✅ | Apple Silicon libSystem probe | Hand-emitted Mach-O arm64 binary (`programs/macho_libsystem_probe.cyr`) calls `_exit(42)` through a `__got` slot dyld-bound to libSystem. Proves the LC_DYLD_INFO_ONLY classic-bind path works on real Apple Silicon (`ssh ecb` — codesign + exec = 42). Pinned separately from the compiler-driven emission (v5.5.12) because the probe is a stand-alone reference file with no compiler diff; shipping it alone locks in the layout before we graft it into the emitter. |
| **v5.5.12** | Compiler-driven Mach-O libSystem emission | Promote the v5.5.11 probe's layout into the arm64-darwin backend. `syscall(SYS_WRITE, ...)` on arm64-darwin routes through the Mach-O import table (mirror of the PE `syscall_win` reroutes landed in v5.4.7/v5.5.1). After this, `cyrfmt`/`cyrlint`/`cyrdoc`/`cyrc` can be built for arm64 macOS — each tool pulls its own surface of libSystem symbols (`malloc`, `fopen`, `getopt`, `pthread_*`). Drops `scripts/macos-arm64-README.md`'s "Not yet available" section to empty. |
| **v5.5.13** | aarch64 native Linux self-host | Wider stdlib pass on real Pi hardware — alloc, fs, threading, mutex chains under `CLONE_VM`. `regression.tcyr` 102/102 already holds from v5.3.18; this completes the consumer-facing modules. |
| **v5.5.14** | `include`-boundary inline-asm bug fix | Filed v5.4.15 (sigil 2.9.0 AES-NI blocker). Stores through caller-pointer from `include`d fn with big asm block no-op silently; byte-identical objdump either way. Speculative causes: fixup-table pressure on disp32 forward refs, DCE over-stripping in include context, prologue/epilogue clobber of pointer register. Sigil 2.9.1 unblocked. |
| **v5.5.15** | NSS/PAM end-to-end | `pam_authenticate` / `getgrouplist` SIGSEGV in libc today because nsswitch + locale init + NSS-module dlopen graph aren't bootstrapped. shakti 0.2.x is the downstream blocker; currently stubs `pam_authenticate` to UNAVAILABLE and falls through to `/usr/bin/su`. |
| **v5.5.16** | TLS via `arch_prctl(ARCH_SET_FS)` | `%fs:`-relative addressing for thread-local globals. Queued from v5.4.10 thread work — majra's `_aaw_result_state` global needs TLS to be thread-safe. |
| **v5.5.17** | Atomics + memory barriers | `atomic_add` / `atomic_cas` / `mfence` builtins. Today concurrent stdlib code (hashmap mutation under threads, freelist) is exposed to data races. Queued from v5.4.10. |
| **v5.5.18** | Runtime thread-safety audit | Sweep alloc / freelist / hashmap / vec for single-thread assumptions that break under `CLONE_VM`. May bundle into v5.5.16 if scope stays small. |
| **v5.5.19** | PE `.reloc` section + ASLR | `IMAGE_REL_BASED_DIR64` entries for every absolute 64-bit address. Enables DLL output and `IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE`. ~6-9 KB of .reloc for a ~475 KB PE. See `vidya :: plan_pe_correctness_tail_v555plus` for block format. |
| **v5.5.20** | PE struct-return + variadic + __chkstk tail | Hidden RCX retptr for >8-byte structs, variadic float duplication to XMM + GP, `__chkstk` stack-probe for frames ≥ 4 KB. All three are defer-until-triggered today; v5.5.19 groups the pre-emptive fixes. |
| **v5.5.21** | v5.5.x closeout | Last patch before v5.6.0. Full CLAUDE.md §"Closeout Pass" 11-step checklist with v5.5.x-specific scope: heap-map AUDIT (not just verify — regions added during v5.5.x include the enum-const table at 0xD8000 from v5.5.2), REFACTOR pass on the accumulated `_TARGET_PE` branch surface (EPOPARG / ESTOREREGPARM / ECALLPOPS / ECALLCLEAN / ESTOREPARM / ESTORESTACKPARM + EEXIT / EWRITE_PE + fnptr.cyr fncallN Win64 variants — consolidate if the dispatch pattern stabilizes), CODE REVIEW of every v5.5.0–v5.5.20 diff for Win64/SysV ABI leaks, cleanup sweep, benchmark refresh vs v5.5.0 baseline. See §"v5.5.20" below. |

**Why this sequence:**
- v5.5.4–5.5.5 finish the Windows arc (Win64 ABI + native
  self-host). v5.3.x/v5.4.x started Windows; v5.5.x honest-closes
  it.
- v5.5.11 + v5.5.12 finish the Apple Silicon arc (same shape —
  libSystem imports are arm64's last missing ingredient, like
  IAT was for PE). Split: the probe (v5.5.11) pins the layout
  against a standalone hand-emitted reference binary; the
  compiler emission (v5.5.12) promotes that layout into the
  backend so `syscall(...)` on arm64-darwin routes through
  `__got`.
- v5.5.13–5.5.18 are Linux runtime correctness — items that have
  been carrying forward across multiple minors with shifting
  release targets. Pinning them to concrete patch numbers means
  they can't slip silently.
- v5.5.19–5.5.20 are the PE correctness tail — defer-able but
  recorded so they don't get forgotten.
- v5.5.21 is the formal closeout before v5.6.0 (optimization arc).

**After v5.5.x:**
- **v5.6.0–5.6.5** — Compiler optimization arc (§"v5.6.0 —
  Compiler optimization arc" below). O1 through O6 each get a
  patch number. **THIS IS THE PIN** — the optimization phases
  have slipped across v5.4.x and v5.5.x as a "parallel track"
  with no concrete numbers. v5.6.x claims them explicitly and
  lands them BEFORE RISC-V so the new port inherits an
  optimized compiler, not one still queueing optimization
  "soon".
- **v5.7.0** — RISC-V rv64 (§"v5.7.0 — RISC-V rv64" below).
  Slid one minor from v5.6.0 so the optimization arc lands
  first. A new platform should inherit an optimized compiler.
- **v5.8.0** — Bare-metal / AGNOS kernel target.

### v5.5.0 — PE correctness completion

What v5.4.2–v5.4.8 explicitly do NOT deliver. Each item is a
distinct patch or minor; shipping them as "v5.4.x plus" would
conflate unrelated work.

- ✅ **`EEXIT` `_TARGET_PE` branch + PE fixup infrastructure**
  (shipped v5.4.3). `EEXIT` emits the Win64 ExitProcess call
  sequence; new `ftype=4` IAT-reference fixup in the existing
  `fixup_tbl`; `_pe_layout` runs early in `FIXUP` so disp32
  fixups resolve. Disassembly-verified. Byte-level `cmp`
  against `pe_probe.cyr` deferred until general `syscall(...)`
  rerouting lands (next item).
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

### v5.5.3 — Win64 arg-register flip (≤4 args) ✅

First slice of the Win64 ABI lift. `EPOPARG` and `ESTOREREGPARM`
flip to the Win64 tuple (RCX/RDX/R8/R9) under `_TARGET_PE` for
cyrius-to-cyrius fn calls with ≤4 args. Caller pops into Win64
registers; callee spills them symmetrically into [rbp+disp] local
slots. Scope deliberately narrow per "one change at a time"
principle — the full ABI story (shadow space, >4-arg stack
shuttle, fnptr.cyr Win64 variants) splits into v5.5.4.

**Verified** (2026-04-20) on real Windows 11 (`nejad@hp`, build
26200): 5/5 fncall matrix PASS (`w_arg1` through `w_arg4` plus
`w_nested`, all exit 42). `hello.exe` still runs (no regression
in v5.4.x reroutes). Linux `check.sh` 10/10 green. Self-host
byte-identical (479440 B, +832 B over v5.5.2 for the new
branches). CI gate added to both `windows-cross` (byte-level
Win64 spill-quartet assertion) and `windows-native` (ERRORLEVEL
check on windows-latest).

**Out of scope (unbundled across v5.5.4 + v5.5.5 + v5.5.6):**
- v5.5.4 = shadow-space enforcement at cyrius-to-cyrius call sites
  + >4-arg stack shuttle (backend concern, in `src/backend/x86/emit.cyr`).
- v5.5.5 = `&fn` PE VA fixup (fixup.cyr ftype=3 PE branch —
  prerequisite for any indirect-fn-pointer testing on Windows).
- v5.5.6 = `lib/fnptr.cyr` Win64 `fncallN` variants (stdlib concern,
  distinct surface — split for single-concern bisect signal).

Programs using >4-arg fns under `CYRIUS_TARGET_WIN=1` mis-compile
silently in v5.5.3 (they emit wrong register encodings for args 5+)
— v5.5.4 is the fix.

### v5.5.4 — Win64 ABI call-site completion (planned next)

Closes the cyrius-to-cyrius call-site half of the Win64 ABI lift.
After v5.5.4, cyrius programs of any arity compile correctly on
Windows at the compiler-backend level. Indirect fn-pointer calls
through `lib/fnptr.cyr` still use SysV register mappings — that's
v5.5.6's scope (via v5.5.5's `&fn` PE VA prerequisite).

**Scope** — all `_TARGET_PE`-guarded; Linux/Mach-O paths
untouched:

- **Shadow space at every cyrius-to-cyrius call site.** Generalize
  the `sub rsp, 32` pattern the kernel32 reroutes already use
  (EEXIT/EWRITE_PE/v5.5.1 bundle) to `ECALLPOPS` + `ECALLCLEAN`.
  RSP must be 16-aligned at each `call`; pad by 8 when the
  total allocation is 8-off from align (same logic as EEXIT's
  `sub rsp, 0x28`).
- **`ECALLPOPS` / `ECALLCLEAN` stack-arg shuttle for N>4.**
  Mirror of the existing SysV N>6 shuttle: pop the top (N-4)
  extras into scratch r10/r11/r14/r15, pop the register-bound
  args (0..3) into RCX/RDX/R8/R9, allocate `32 + (N-4)*8 + pad`,
  `mov` the extras into `[rsp+32..]`.
- **`ESTORESTACKPARM` disp32 shift.** Under `_TARGET_PE` and
  pidx≥4, the incoming stack-arg address is `[rbp+16+32+(pidx-4)*8]`
  instead of SysV's `[rbp+16+8*i]` (the +32 accounts for the
  caller's shadow space below the return address).
- **`ESTOREPARM` dispatch boundary.** Under `_TARGET_PE`:
  pidx<4 → register path (via `ESTOREREGPARM`, already Win64 from
  v5.5.3); pidx≥4 → stack path (via the newly-shifted
  `ESTORESTACKPARM`).
- **Callee-save set flip.** Win64 adds RDI/RSI as callee-saved.
  Cyrius's codegen does NOT use RDI/RSI inside fn bodies (only as
  arg-pass registers at the boundary), so EFNPRO/EFNEPI changes
  are expected to be a NO-OP today. Verify via disasm; add guard
  comment. XMM6-XMM15 flip is similarly no-op until SSE codegen.

**Self-host fixpoint is the authoritative gate** — Linux
`cc5 → cc5b` byte-identical stays green (code guarded by
`_TARGET_PE`). Windows-native fixpoint (cc5_win compiling itself
ON Windows) is v5.5.8.

**CLAUDE.md "3 failed attempts = defer" still applies.** If
fixpoint fails three distinct v5.5.4 attempts, split further —
e.g. ship shadow space alone as v5.5.4, defer stack shuttle to
its own patch.

### v5.5.5 — `&fn` PE VA fixup (planned next)

Small prerequisite patch surfaced while preparing v5.5.6 (the
lib/fnptr.cyr Win64 variants). `src/backend/x86/fixup.cyr` at
ftype=3 (fn-address) computed the target as `entry + fn_offset`
using the ELF entry point, which is correct for ELF output but
wrong for PE. Under `CYRIUS_TARGET_WIN=1`, `&fn` therefore emits
a `movabs rax, imm64` with an ELF-style VA (e.g. 0x4000d8) instead
of the PE VA (`0x140000000 + _pe_text_rva + fn_offset`), causing
Windows to reject the resulting .exe with error 216 ("not
compatible").

**Scope** — 3-line patch at the ftype=3 branch in `fixup.cyr`
mirroring the existing ftype=1 (string-address) PE guard at
line 203–205. No other files touched; no ABI change.

**Why split from v5.5.6:** `&fn` PE VA fixup is a compiler-
backend concern in `fixup.cyr`; fnptr.cyr Win64 variants is a
stdlib-runtime concern. Different file, different invariant,
independent bisect signal. Without v5.5.5, v5.5.6 can't be
tested because every indirect call starts with `&fn` and
crashes the PE before reaching fncallN.

**Verification** — compile a program that takes a fn's address
under CYRIUS_TARGET_WIN=1, scp to nejad@hp, confirm it no longer
trips Windows' load-time rejection. Byte-level gate: the
`movabs rax, 0x140…` immediate must land in the PE VA range
[0x140000000, 0x200000000) — same regression gate v5.4.8 used
for string-address PE VAs.

### v5.5.6 — `lib/fnptr.cyr` Win64 `fncallN` variants (planned after v5.5.5)

Indirect fn-pointer calls go through `lib/fnptr.cyr`'s
`fncall0..fncall8` — 9 hand-rolled x86 asm blocks that load args
from `[rbp-disp]` into RDI/RSI/.../R9. v5.5.6 adds
`#ifdef CYRIUS_TARGET_WIN` parallel blocks so indirect calls on
Windows use the Win64 register tuple + 32 B shadow + 5th-plus
stack slots at `[rsp+32+]`.

Splits from v5.5.4 because it touches a different file
(`lib/fnptr.cyr` vs `src/backend/x86/emit.cyr`), a different
invariant (runtime helper ABI vs compiler-emitted ABI), and
has independent bisect signal. Depends on v5.5.5's `&fn` PE VA
fixup — without it, the fn-pointer value passed into fncallN
is an invalid VA and crashes before the indirect call.

**Scope** — all `_TARGET_PE`-guarded; SysV blocks stay active on
Linux/Mach-O:

- **fncall0** — trivial, just shadow.
- **fncall1..fncall4** — Win64 arg-reg mapping.
- **fncall5..fncall8** — shadow + stack-arg slots for args 5–8.
  Mirrors v5.5.4's backend shuttle pattern, but hand-coded in
  inline asm instead of emitter-generated.

Lines affected: 9 blocks across lines 43–322 of `lib/fnptr.cyr`.

### v5.5.7 — Strict Win64 shadow-space compliance (planned next)

Retrofit: v5.5.4 shipped cyrius-to-cyrius calls with **no shadow
space** as an intentional shortcut ("callee spills to its own
locals, doesn't need home slots"). v5.5.6's `lib/fnptr.cyr` Win64
variants followed the same convention for consistency. But the
no-shadow convention breaks **C-FFI-via-fnptr**: a Win64 C function
called through fncallN expects the 32 B home area to spill its
arg regs into, and the cyrius caller hasn't allocated it.

v5.5.7 closes the gap by lifting strict Win64 ABI compliance to
every cyrius-emitted call site. Same scope shape as v5.5.4 but
adds (not replaces) the shadow allocation.

**Scope** — all `_TARGET_PE`-guarded; Linux/Mach-O paths
untouched:

- **`ECALLPOPS` under `_TARGET_PE`:** after popping arg regs,
  allocate 32 B shadow. For N≤4: `sub rsp, 32`. For N>4: total
  frame = `32 + (N-4)*8` rounded up to 16 for alignment;
  register-bound args still get popped into RCX/RDX/R8/R9, but
  the shuttle writes extras at `[rsp+32..]` (above shadow)
  instead of `[rsp+0..]`.
- **`ECALLCLEAN` under `_TARGET_PE`:** add the same total frame
  size after the call. For N≤4: `add rsp, 32`. For N>4:
  `add rsp, 32 + round_up_16((N-4)*8)`.
- **`ESTORESTACKPARM` Win64 branch:** stack-arg read shifts to
  `[rbp+16+32+(pidx-4)*8]` — the +32 accounts for the caller's
  shadow below the return address.
- **`lib/fnptr.cyr` `fncallN` Win64 blocks:** each of fncall0..8
  adds `sub rsp, 0x20` (shadow) — fncall0..fncall4 just allocate
  the shadow; fncall5..fncall8 allocate shadow + stack-arg slots
  and write args at `[rsp+32..]`. Restore `add rsp, N` after the
  call.

**Why retroactively and not deferred:** leaving it as a
"documented limitation" pushes the C-FFI hole into every future
Windows-port downstream. Fixing it once, while the PE arc is
active and the verification loop is hot, is cheaper than debugging
it later across N consumer repos.

**Self-host gate** — Linux byte-identical (unchanged by
`_TARGET_PE` code); Windows fncall matrix + fnptr matrix from
v5.5.4/v5.5.6 continues to pass (shadow is transparent to cyrius
callees); fresh test exercises a minimal C-from-cyrius-via-fnptr
scenario if possible (else just documents the now-correct shape
in `docs/ffi/fncall-abi.md`).

### v5.5.8 — Windows heap bootstrap (SYS_MMAP, planned next)

Small focused fix surfaced during the native-self-host probe.
`src/main_win.cyr`'s heap init (lines 206-207) used
`syscall(SYS_BRK, 0)` + `syscall(SYS_BRK, S + heap_size)` — the
Linux-style brk pattern. Windows has no brk; the PE backend
doesn't reroute `syscall(12)`. Result: cc5_win.exe crashed with
STATUS_ACCESS_VIOLATION at startup trying to execute the raw
Linux `0F 05` syscall bytes the backend emitted for the fall-
through path.

**Fix:** swap to `syscall(SYS_MMAP, 0, 0x2000000, 3, 0x22, -1, 0)`
— works on both paths of the main_win.cyr build chain:
- `cc5` (Linux) compiles `main_win.cyr` → `cc5_win_linux` (ELF):
  heap init runs on Linux as
  `mmap(0, 32MB, PROT_RW, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)`
  → valid 32 MB region.
- `cc5_win_linux` compiles `main_win.cyr` → `cc5_win.exe` (PE):
  heap init runs on Windows; the PE backend's `EMMAP_PE` reroute
  (v5.5.1) routes to `VirtualAlloc(0, 32MB, MEM_COMMIT|MEM_RESERVE,
  PAGE_READWRITE)` — the prot/flags from mmap are dropped by
  EMMAP_PE, so the Linux-sensible flags don't hurt the Windows
  path.

32 MB covers the 21 MB compiler heap with margin and rounds to a
page-aligned size.

**Verification:** standalone test
`syscall(SYS_MMAP, 0, 32MB, 3, 0x22, -1, 0); store64/load64; exit`
runs on real Windows 11 (`nejad@hp`) and exits with the stored
value — confirms the mmap reroute produces a writable region.
Linux self-host byte-identical (main.cyr untouched; only
main_win.cyr + the affected enum line changed). check.sh 10/10.

**Necessary but not sufficient for v5.5.9 native self-host.**
After the heap-bootstrap fix, `cc5_win.exe` STILL crashes at
startup before writing any output (ERRORLEVEL -1073741819 =
STATUS_ACCESS_VIOLATION, 0 bytes to stdout, 0 bytes to stderr).
The next blocker is further into startup — likely the
`_init_cyrius_lib()` call's `/proc/self/environ` readback, or
some other Linux-ism we haven't surfaced yet. v5.5.9 picks up
from here.

### v5.5.9 — Native Windows self-host (planned after v5.5.8)

`cc5_win` compiling itself on a real `windows-latest` runner,
byte-identical to the ubuntu-cross build. Depends on v5.5.4 +
v5.5.5 + v5.5.6 + v5.5.7 + v5.5.8 (cc5's own source + stdlib
have >4-arg fns, indirect fn-pointer calls via `&fn`, strict
shadow compliance, and non-brk heap init). Full plan in vidya
`implementation.toml :: plan_windows_self_host_v554` (filename
retained; content keyed to v5.5.9 now).

**Starting state inherited from v5.5.8:** `cc5_win.exe` is a
structurally valid PE32+ (553 KB, 3 sections) that crashes at
startup — 0 bytes stdout, 0 bytes stderr, ERRORLEVEL
-1073741819 = STATUS_ACCESS_VIOLATION. Crash happens BEFORE any
compile work. Standalone Cyrius programs compiled via `cc5 +
CYRIUS_TARGET_WIN=1` run fine; the crash is specific to running
the full compiler (cc5_win.exe) on Windows.

**Probe-first debugging plan** (mirrors the v5.3.0 Apple Silicon
methodology that avoided weeks of blind iteration):

1. **Isolate the crashing stage.** Rebuild cc5_win.exe with a
   `syscall(SYS_WRITE, 2, "STAGE_N\n", 8)` breadcrumb inserted
   after each major init step in main_win.cyr:
   - After `_strict_mode = 0; _vbuf[256];` var inits
   - After `/proc/self/cmdline` syscall chain (lines 172-175)
   - After the /proc/self/cmdline loop exits
   - After heap mmap (line 218)
   - After state init block (lines 219-260)
   - After `_init_cyrius_lib()` call
   Last breadcrumb printed narrows down the crash location.
2. **Check for /proc/self/environ dependency** (`src/frontend/lex.cyr
   :: _init_cyrius_lib`). Same pattern as /proc/self/cmdline —
   opens a Linux-only path. CreateFileW returns INVALID_HANDLE_VALUE
   on Windows; subsequent ReadFile with bad handle MIGHT SIGSEGV
   if `lpNumberOfBytesRead` pointer is invalid. Verify
   `EREAD_PE`'s output-count buffer setup.
3. **Structural validation of cc5_win.exe.** Compare sections
   and bytes against a known-good PE32+ (e.g. windows-latest's
   own cmd.exe or a small MSVC-compiled test). Catches any
   PE-header invariant we're violating that our exit42/hello
   tests didn't exercise (because they're much simpler).
4. **Run under Windows debugger** (if breadcrumbs aren't
   enough). `ssh nejad@hp` then attach WinDbg or cdb to
   cc5_win.exe's child process.

**Key infra beats (once self-host clears):**
- `shell: cmd` for binary stdin→stdout pipe on windows-latest
  (PowerShell `>` corrupts binary streams — UTF-16/UTF-8 BOM).
- Two-step bootstrap shape: Linux cross → cc5_win_v1 artifact,
  downloaded on windows-latest, runs against src/main_win.cyr,
  produces cc5_win_v2, `fc /b` asserts byte-identity.
- `.tcyr` suite on windows-latest, gated on syscalls covered by
  v5.5.1/v5.5.2 reroutes; tests needing fork/clone/futex tagged
  `# platform: linux`.

**Scope NOT included** (carries to v5.5.10+):
- `.reloc` section + ASLR (needed for DLL output).
- `__chkstk` / stack-probe for frames ≥ 4 KB (no Cyrius fn
  currently trips this).
- Struct-return-by-value via hidden RCX retptr.
- Variadic float duplication (`xmm0` + `rdx` for `printf("%f", x)`).
- SEH `.pdata`/`.xdata` (indefinite — CLI .exe doesn't need it).

### v5.5.21 — v5.5.x closeout pass (then v5.6.0)

Last patch of the v5.5.x minor. Full CLAUDE.md §"Closeout Pass"
11-step checklist run with v5.5.x-specific scope — this minor
added substantial `_TARGET_PE` surface area, a new heap region
(v5.5.2's enum-const table at 0xD8000), and enough ABI parallel
paths that a dedicated refactor + code review window is earned.

**Mechanical (CLAUDE.md steps 1-3):**
- Self-host verify — cc5 compiles itself byte-identical (Linux).
- Bootstrap closure — seed → cyrc → asm → cyrc byte-identical.
- Full `sh scripts/check.sh` — 10+/10+ PASS (gates accumulated
  through v5.5.20; exact count depends on what v5.5.9 native
  self-host adds).

**Judgment-call passes (CLAUDE.md steps 4-8):**
- **Heap map audit** — v5.5.x added at least one named region
  (enum-const table, 0xD8000, 8 KB). Verify no collisions with
  the free gap it consumed. Walk every region in `src/main.cyr`'s
  heap map: confirm it's used, sized correctly, at a stable
  offset. Flag caps that got close to exhaustion across v5.5.x
  (fn table at 4096, fixup table at 16384, ident buffer at 128KB
  — did any approach limits?). Look for consolidation: adjacent
  regions owned by the same subsystem might merge.
- **Dead code audit** — the standing 21-unreachable-fn list from
  v5.4.10 is the floor. Did v5.5.x add new dead entries? Remove
  them. Record the new floor.
- **Refactor pass** — v5.5.x added _TARGET_PE branches in:
  EPOPARG (v5.5.3), ESTOREREGPARM (v5.5.3), ECALLPOPS + ECALLCLEAN
  (v5.5.4), ESTOREPARM + ESTORESTACKPARM (v5.5.4), plus EEXIT /
  EWRITE_PE / v5.5.1-syscall-reroute-bundle (v5.5.0/1), plus
  `lib/fnptr.cyr` fncallN Win64 variants (v5.5.5). That's a LOT
  of `if (_TARGET_PE == 1) { … }` blocks. Evaluate whether the
  dispatch pattern has stabilized enough to factor into a single
  "abi_kind" switch or helpers. Land consolidation IF self-host
  stays byte-identical; otherwise file as v5.6.x first-patch work
  with a concrete patch number, not "queued for later".
- **Code review pass** — walk every v5.5.0–v5.5.20 diff end-to-end.
  Specifically look for:
  - Unguarded x86 encodings on non-x86 paths (pattern from v5.4.19
    aarch64 `&local` leak; the `EW` alignment assert should have
    caught any new one, but verify).
  - SysV leaks on `_TARGET_PE` paths (pattern from v5.5.3's
    EPOPARG fallthrough that v5.5.4 fixed). Are there other
    `if (_TARGET_PE) { … } /* fallthrough to SysV */` shapes where
    the fallthrough is wrong?
  - Byte-order typos in hand-rolled hex literals (pattern from
    v5.5.4-alpha's `0xC24989` that should have been `0xC28949`).
    Cross-check every `E3(S, 0x…89…)` literal against a disasm
    verification.
  - Silently-ignored error returns from new kernel32 reroute
    helpers (`_pe_ensure_*`).
  - Off-by-one in fixup arithmetic (pattern from v5.4.8-alpha
    cc5_aarch64 `&local` leak).
- **Cleanup sweep** — stale comments referencing pre-v5.5.x state
  (e.g. "queued for v5.5.x pillar N" phrasing, now superseded by
  pinned patch numbers). Dead `#ifdef` branches. Orphaned files.

**Compliance (CLAUDE.md steps 9-10):**
- **Security re-scan** — last full audit was v5.0.1. If no v5.5.x
  patch added `sys_system`, `READFILE`, or unchecked writes, the
  quick grep is enough; else schedule a full audit for v5.6.x.
- **Downstream check** — every ecosystem repo's `cyrius.cyml`
  `cyrius` field points at v5.5.x tag. With 15 patches in this
  minor, downstream drift is likely — bump each repo to the
  final v5.5.x tag before v5.6.0 opens.

**Docs (CLAUDE.md step 11):**
- **Vidya full pass** per `feedback_vidya_closeout.md` memory —
  language.toml overview entry version/size, compiler.toml new
  gotcha entries (shadow-space-skip decision at v5.5.4, byte-order
  trap from v5.5.4-alpha, PowerShell `>` binary corruption from
  v5.5.6), implementation.toml heap-map changes (enum-const
  table), dependencies.toml dep bumps.
- Roadmap: verify every v5.5.x row in the release table has the
  ✅ marker and matches what actually shipped. Any patch that
  slipped scope gets a note explaining the slip.
- CHANGELOG: entries present for v5.5.0 through v5.5.20. Cross-
  check the dates.

**Benchmark refresh:**
- `cyrius bench` at v5.5.18, comparing v5.5.0 baseline. Record in
  `bench-history.csv`. Expected trend: compiler size grew (~2.5%
  per Win64-branch patch); runtime for most benchmarks flat
  (optimizer arc is v5.6.x, not v5.5.x). Any unexpected slowdown
  points at a v5.5.x regression the other passes missed.

After v5.5.18 ships, the next tag is **v5.6.0** — Phase O1 of the
compiler-optimization arc.

---

## v5.6.0 — Compiler optimization arc

Dedicated minor for the compiler-optimization phases O1–O6.
**Pinned to concrete patch numbers** because they've slipped as
a "parallel track" across v5.4.x and v5.5.x with no numbers,
and the drift pattern stops here. Lands BEFORE RISC-V (v5.7.0)
so the new port inherits an optimized compiler, not one still
queueing optimization.

Phased plan synthesized from vidya (`content/optimization_passes`,
`content/code_generation`, `content/allocators`) and external
research (QBE, TCC, QBE arm64 peephole — Brian Callahan,
Poletto/Sarkar linear scan, Agner Fog x86_64 microarchitecture
notes). **Non-negotiable across every phase**: byte-identical
self-host must hold; every pass must be deterministic.

**Guardrails** (both research tracks converged on these "don't"s):
- No graph-coloring register allocation (3–5× the code of linear
  scan for ~10 % marginal quality on our function sizes).
- No iterated register coalescing (Appel) — nondeterminism risk.
- No static instruction scheduling on x86_64 (OoO hardware hides it).
- No SCCP / GVN / polyhedral (out of scope for a ~450 KB compiler).
- No PEXT/PDEP/BMI2 opportunistic (pre-Haswell portability trap).
- No multi-arena heap restructuring (the 21 MB flat heap map is
  auditable state; lifetime partitioning is already static).

**Ordering constraints** (why the patches can't reorder):
- O1 first — without baseline numbers, quantitative claims for
  O2–O6 are vibes.
- O3 before O4 — linear-scan needs complete IR coverage.
- O6 gated on O4 — slab only matters if O4 profiling shows
  bump-alloc hot.

### v5.6.0 — Phase O1: instrumentation + FNV-1a symbol table

Baseline before tuning anything. ~240 LOC.

- **Per-phase `rdtsc` counters** (`lex` / `preprocess` / `parse`
  / `ir-lower` / `emit` / `fixup`) gated behind a compile-time
  flag, written to a static buffer, dumped at exit. ~40 LOC.
- **Symbol-table hash upgrade**: current `fn_names[4096]` /
  `struct_names` / identifier-pool use linear scan (O(N) per
  identifier touch). Replace with FNV-1a open-addressing hash
  (load factor ≤ 0.7) keyed by offset-into-pool. Expected win:
  10–25 % compile-throughput on self-host once `fn_count > ~200`.
  ~200 LOC.
- **Gate**: baseline numbers committed to
  `docs/development/benchmarks.md`; self-hosting byte-identical.

### v5.6.1 — Phase O2: peephole quick wins (x86_64 + aarch64)

All deterministic, small, bang-for-buck. ~510 LOC.

- **Strength reduction**: `x * 2^n` → `shl/lsl`, `x / 2^n` →
  `shr/lsr`/`asr`, `x * 0` → `xor`, `x * 1` → copy, `x ± 0` →
  copy. Pattern detection via `(n & (n - 1)) == 0`. ~60 LOC
  across both backends.
- **Flag-result reuse**: track a "last flags producer" slot in
  emit state; invalidate on any flag-clobber; skip redundant
  `cmp` / `cmn` when preceding arithmetic already set flags.
  ~80 LOC.
- **Redundant-move / self-move elimination**: `mov rX, rX`;
  post-emit pass collapses no-ops from regalloc+inline
  interactions. ~100 LOC.
- **LEA combining** (x86_64): `mov rX, rA; add rX, rB; add rX,
  imm` → single `lea rX, [rA+rB+imm]`; avoid 3-operand LEA on
  RBP/R13 base (port-1 latency trap per Agner Fog). ~120 LOC.
- **aarch64 fused ops**: `mul + add` → `madd`, `mul + sub` →
  `msub`, `and + lsr mask` → `ubfx`, signed variant → `sbfx`.
  ~150 LOC.

### v5.6.2 — Phase O3: IR-driven passes

Builds on the existing LASE / DBE / CFG infrastructure. ~590 LOC.

- **Precondition**: finish IR instrumentation across the
  remaining ~50 direct emit sites (`EB` / `E2` / `E3` calls in
  `src/frontend/parse.cyr`). Without this, LASE codebuf patching
  is unsafe — same blocker the current v5.x IR plan noted.
- **Constant folding + propagation on IR**: promote the existing
  parse-time folding into a CFG-aware pass. Integer arithmetic,
  boolean, comparisons on constant operands. ~200 LOC.
- **Bitmap-based liveness + DCE**: one u64 = liveness for 64
  virtual registers; backward sweep; mark defs with no live uses
  as dead. Pattern lifted from
  `vidya/content/optimization_passes/cyrius.cyr`. ~60 LOC.
- **Copy propagation + dead-store elimination**: forward sweep
  with per-vreg "current copy-of" map; backward sweep marking
  live stores. ~300 LOC.
- **Fixed-point driver**: run fold → propagate → reduce → DCE
  in a loop until no-change. ~30 LOC.

### v5.6.3 — Phase O4: linear-scan register allocation

The big investment. Replaces today's peephole `#regalloc`.
~600–900 LOC.

- Sort live intervals by start point; greedy assignment with
  spill heuristic = furthest next use (Poletto & Sarkar).
  Covers: live-range build, active-set management, spill slot
  assignment, parallel-move resolution at block boundaries.
- **Determinism guard**: keep hint-based preferences but skip
  iterated coalescing — byte-identical self-host must hold.
- **Depends on v5.6.2's completed IR coverage** (live ranges
  need every def and use to be in IR).
- Expected output-code speedup: 2–3× over current stack-machine
  baseline on hot inner loops; 10–20 % quality gap vs.
  graph-coloring at a fraction of the code.

### v5.6.4 — Phase O5: maximal-munch instruction selection

~300–500 LOC.

- Formalize existing ad-hoc tile patterns (mem-operand `add`/`sub`
  on x86_64, aarch64 addressing modes) into a tile pattern
  database per backend. Walker traverses IR tree bottom-up,
  matching largest subtree to a single machine instruction.
- Opens the door for target-specific tiles (RISC-V v5.7.0) without
  touching the walker — v5.6.4 therefore SHIPS BEFORE v5.7.0 so
  the rv64 backend can land its tile table on day one instead of
  retrofitting.

### v5.6.5 — Phase O6: slab allocator for IR pools (measurement-gated)

~150 LOC. **Conditional release** — only ships if v5.6.3's profile
shows bump-allocation hot during live-range construction. If the
O4 benchmark says bump is fine, v5.6.5 is **explicitly skipped**
and the v5.6.x closeout ships at v5.6.5 directly (see below).

- `vidya/content/allocators` documents 20–30× speedup over bump
  for fixed-size churn. Applied to IR node pools during live-
  range build.
- If skipped, record the skip decision in CHANGELOG with the
  specific O4 bench numbers that triggered it.

### v5.6.6 — v5.6.x closeout (or v5.6.5 if O6 skipped)

Last patch before v5.7.0 (RISC-V). CLAUDE.md "Closeout Pass"
9-step checklist: self-host verify, bootstrap closure, dead-code
audit, stale-comment sweep, heap-map verify, downstream
dep-pointer check, security re-scan, CHANGELOG/roadmap/vidya sync.

**Downstream gate.** This closeout is the opening signal for
genesis repo Phase 13B (arch-neutral boot pipeline —
`scripts/boot.cyr`, ISO Stages 1–4, `bootstrap-toolchain.sh`,
`build-order.txt`) and the ecosystem arch-neutral sweep: must-touch
(agnos, kybernet, argonaut, agnosys, sigil), should-touch (ark,
nous, zugot, agnova, takumi), may-touch (phylax, shakti,
ai-hwaccel, seema). All of them wait on v5.6.6 and must complete
before v5.7.0 RISC-V opens. Practical consequence: the closeout
carries extra rigor beyond the standard 9-step pass —

- **Heap-map cleanup** — not just verify; actively collapse any
  orphan allocations surfaced during the optimization arc. Leave
  no "temporary" arenas downstream would have to work around.
- **Refactor pass** — one targeted sweep for naming/API drift
  introduced across v5.6.0–v5.6.5. If a public function got
  reshaped mid-arc, this is the last chance to stabilize the name
  before downstream repos pin to it.
- **Audit pass** — dead code, stale comments, orphan tests,
  unused `#include` lines. Downstream sees this as the baseline
  they mirror in their own sweeps.
- **Downstream dep-pointer check** — walk every downstream repo's
  `cyrius.toml` / `cyrius.cyml` and verify they resolve cleanly
  against the v5.6.6 artifacts. Broken pins get fixed before
  v5.7.0 opens, not after.
- **Compiler surface freeze signal** — after v5.6.6 ships, public
  compiler API is frozen for the duration of the downstream sweep
  (approximately one minor cycle). v5.7.0 RISC-V can add, but not
  reshape, existing surface.

Rationale: downstream projects are batching their own arch-neutral
work against this closeout. If v5.6.6 ships with loose ends, each
downstream repo absorbs the cost and the sweep fragments. One
tight closeout here is cheaper than N downstream workarounds.

---

## Sigil 3.0 enablers — remaining

Downstream `sigil` items the Cyrius toolchain still owes. Shipped
enablers (`ct_select` v5.3.2, `mulh64` v5.3.3, `secret var` v5.3.5)
are in CHANGELOG.

- **`lib/keccak.cyr`** — Keccak-f[1600] permutation + sponge API
  (SHAKE-128 / SHAKE-256). NIST FIPS 202. Required for
  ML-DSA-65's XOF step in sigil 3.0 PQC. Self-contained, no
  external deps. Benchmark target: 4 KB SHAKE-256 within 2× of
  sigil's existing `sha256_4kb` (~250 µs). **Claimed by v5.4.14
  — see roadmap §v5.4.14.**

---

## v5.7.0 — RISC-V rv64

First-class RISC-V 64-bit target. Elevated from the v5.5.x
pillar list to its own minor on 2026-04-20, then slid from v5.6.0
to v5.7.0 on 2026-04-20 (same day) so the compiler-optimization
arc (v5.6.x) lands first — no point opening a new port against a
compiler still queueing baseline optimizations. Rationale: a new
architecture is structurally different from v5.5.x's items
(which are correctness / completion / runtime work on existing
platforms). RISC-V needs:

- **New backend module** — `src/backend/riscv64/` with its own
  `emit.cyr`, `jump.cyr`, `fixup.cyr` mirroring x86/aarch64.
- **New stdlib syscall peer** — `lib/syscalls_riscv64_linux.cyr`
  with the Linux rv64 generic-table numbers (different from
  aarch64's even though both use the generic table — numbers
  match aarch64 for most syscalls but rv64 drops `renameat`,
  `link`, `unlink` which means the at-family wrappers need
  review). Selector in `lib/syscalls.cyr` gains an `#ifplat
  riscv64` arm (the v5.4.19 directive extends naturally here).
- **New cross-entry** — `src/main_riscv64.cyr` mirroring
  `main_aarch64.cyr`'s arch-include swap.
- **New test runner** — QEMU or real hardware (HiFive Unmatched
  or equivalent) for self-host verification.
- **New CI matrix** — `linux/riscv64` runners via qemu-user-
  static, analogous to the aarch64 cross-test flow.
- **ABI** — RISC-V Linux ELF psABI (different register names:
  `a0–a7` for args, `sp` for stack, no frame pointer by default
  but we'll use `s0` for parity with aarch64's `x29`).

**Acceptance gates:**
1. Cross-compiler (`build/cc5_riscv64`) emits valid rv64 ELF
   that `file(1)` identifies correctly.
2. A single-syscall "exit 42" probe runs under `qemu-riscv64-
   static` and exits 42.
3. Hello-world probe via `sys_write` + `sys_exit` runs under
   QEMU.
4. `regression.tcyr` 102/102 via QEMU cross-test.
5. Native self-host byte-identical on real rv64 hardware (not
   QEMU — hardware-gated like the aarch64 ssh-pi check).
6. Tarball includes `cc5_riscv64` alongside `cc5_aarch64`.
7. `[release]` table in `cyrius.cyml` gets a `cross_bins`
   entry for `cc5_riscv64`.

**Prerequisites that must ship before v5.7.0 starts:**
- **v5.5.5** — Native Windows self-host. Proves the PE arc
  honestly closed before we open another.
- **v5.5.6** — Apple Silicon toolchain completion. Same reason.
- **v5.6.0–5.6.5** — Compiler optimization arc. New port should
  inherit an optimized compiler, not one still queueing baseline
  optimization. v5.6.4 (maximal-munch) in particular matters —
  rv64 backend lands its tile table against the new walker on
  day one instead of retrofitting.
- **v5.4.19 `#ifplat`** direction is live → RISC-V dispatch
  uses the new syntax from day one, no legacy `#ifdef
  CYRIUS_ARCH_RISCV64` sites to migrate.

Deliberately NOT bundling v5.5.x items into v5.7.0 — a new
architecture port is plenty of work on its own, and mixing it
with runtime correctness fixes would obscure which changes
caused which regressions.

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
| **v5.4.2** | Windows x86_64 (`EMITPE_EXEC` structural) | PE/COFF | **Done** — compiler emits valid PE32+ (1536 B, `file(1)` verified); correctness queued for v5.4.3+ |
| **v5.4.3** | Windows x86_64 (PE fixup + EEXIT Win32) | PE/COFF | **Done** — `EEXIT` emits Win64 ExitProcess call; `ftype=4` IAT-ref fixups resolve; disassembly-verified |
| **v5.4.4** | Windows x86_64 (syscall(60) rerouting) | PE/COFF | **Done** — explicit `syscall(60, N)` routes to `ExitProcess`; Linux `0F 05` absent from compiled `.text` |
| **v5.4.5** | Windows x86_64 (on-hardware CI gate) | PE/COFF | **Done** — `windows-cross` + `windows-native` CI jobs validate ExitProcess path end-to-end on `windows-latest`; ERRORLEVEL verified for N ∈ {0, 1, 42, 255} |
| **v5.4.6** | Windows x86_64 (`#pe_import` directive) | PE/COFF | **Done** — declarative kernel32 symbol registration; compiler emits IAT with arbitrary imports beyond the hardcoded `ExitProcess` |
| **v5.4.7** | Windows x86_64 (`syscall(1)` → WriteFile) | PE/COFF | **Done** — `EWRITE_PE` emits GetStdHandle + WriteFile call sequence via auto-registered IAT; structural scope |
| **v5.4.8** | Windows x86_64 (PE data placement) | PE/COFF | **Done** — `.rdata` section holds gvars + strings; `movabs rax, imm64` fixups resolve to `ImageBase + _pe_rdata_rva + …`; `hello.exe` prints `hi\n` and exits 0 on real Windows |
| **v5.4.9+** | Windows x86_64 (remaining PE correctness) | PE/COFF | Queued — Win64 ABI at fncall*, remaining `syscall(n)` mappings, `lib/syscalls_windows.cyr` wrappers, `lib/alloc_windows.cyr`, `cc5_win.cyr`, RW-split between `.rdata` and `.data`, byte-cmp polish |
| **v5.5.x** | Linux aarch64 stdlib syscall table | ELF | Queued — `lib/syscalls.cyr` is Linux x86_64 only today; aarch64 cross-builds inherit wrong numbers (yukti `test_query_permissions_dev_null` segfaults on Pi because `syscall(4)` is `pivot_root` on aarch64, not `stat`). Split into `syscalls_x86_64_linux.cyr` + `syscalls_aarch64_linux.cyr`, dispatch via `#ifdef CYRIUS_ARCH_AARCH64`. Design doc: [`docs/proposals/2026-04-19-aarch64-syscall-stdlib.md`](../proposals/2026-04-19-aarch64-syscall-stdlib.md). Unblocks every first-party aarch64 consumer (yukti, sigil, sakshi, libro, agnosys, mabda). |
| **v5.7.0** | RISC-V rv64 | ELF | First-class RISC-V target (reassigned from v5.6.0 on 2026-04-20 so v5.6.x optimization lands first; new port inherits optimized compiler) |
| **v5.8.0** | Bare-metal | ELF (no-libc) | AGNOS kernel target (slid from v5.7.0 with the optimization minor insert) |

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
| Linux x86_64 | ELF | **Done** — primary, cc5 451 KB self-hosting |
| Linux aarch64 | ELF | **Done** — cross + native self-host byte-identical on real Pi (v5.3.15+); `regression.tcyr` 102/102 (v5.3.18). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **Done** (v5.1.0) — CYRIUS_MACHO=1, tested on 2018 MacBook Pro |
| macOS aarch64 | Mach-O | **Partial** — self-hosts byte-identically on Apple Silicon (v5.3.13, 475 KB). Full toolchain (`cyrfmt`/`cyrlint`/`cyrdoc`) NOT yet shipped for arm64 — blocked on libSystem imports. Pinned to **v5.5.6** (Apple Silicon toolchain completion). |
| Windows x86_64 | PE/COFF | **Partial** — `hello\n` runs end-to-end on `windows-latest` (v5.4.8). v5.5.0–5.5.2 landed the PE foundation; v5.5.3 shipped Win64 arg-register flip. Remaining: v5.5.4 Win64 ABI completion, v5.5.5 native Windows self-host. |
| Compiler optimization (O1–O6) | — | Queued — **v5.6.0–5.6.5** (pinned 2026-04-20; each phase gets its own patch number — no more "parallel track" drift) |
| RISC-V (rv64) | ELF | Queued — **v5.7.0** (slid from v5.6.0 on 2026-04-20 so the optimization minor lands first) |
| Bare-metal | ELF (no-libc) | Queued — **v5.8.0** (AGNOS kernel target; slid with the optimization minor insert) |

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
| **In progress** | **bote** — MCP core service (JSON-RPC 2.0, tool registry, schema validation). Active port; unblocks vidya MCP. |
| **Blocked** | vidya MCP (needs bote) |

### Downstream server-stack arc

10-layer hardened-server stack is consumer of the Cyrius toolchain.
Current status: **kavach is the last port blocking completion**
(memory: `project_server_stack.md`). Once kavach lands, the server
OS stack is feature-complete at the consumer layer. No direct
Cyrius-compiler release targets this — progress is tracked in
consumer repos. Listed here so it's not forgotten across account
switches.

### Deferred consumer projects

- **CYIM** — postponed until the server base OS is wrapped
  (memory: `project_cyim_deferred.md`). No Cyrius release target;
  resumes when the server-stack arc above closes.
- **Services repo extraction** — `lib/http_server.cyr` is
  currently interim stdlib; planned to extract to a dedicated
  `services` repo as a tagged dep (memory:
  `project_services_repo_plan.md`). Target window: after v5.5.x
  platform-rounding closes and before v6.0.0 (the consolidation
  minor), so the extraction rides in with other `lib/` reshuffles.
  Not pinned to a specific patch because the trigger is "services
  repo scaffolded", not a compiler capability.


## Future 6.0

v6.0.0 is the major-version bump after the v5.x platform-targets
arc closes. Scope is **refactoring and cleanup** that's been
accumulating debt across the v5.x line and that's risky or
disruptive to land mid-minor (rename, dead-code removal,
consolidation of `_TARGET_*` shim layers). Major bump gives
downstreams an explicit signal to re-pin and re-verify rather
than discovering breakage at random patch boundaries.

### v6.0.0 — first item: rename `cc5` → `cyc`

The `cc5` name was meaningful when the major-version digit
identified the compiler-line lineage (`cc` for cyrius compiler,
`5` for the cc5-era IR / module split that landed in v5.0.0).
With `cc5 --version` reporting the actual semver since v5.0.x —
and version baked into the build output — the trailing `5`
duplicates information now carried in `VERSION`, every binary's
`--version`, every `cyrius.cyml` `cyrius` field, and every
release tag.

**Rename:** `cc5` → `cyc` (canonical name) everywhere:
- `build/cc5` → `build/cyc`
- `build/cc5_aarch64` → `build/cyc_aarch64`
- `~/.cyrius/bin/cc5` → `~/.cyrius/bin/cyc` (install.sh, deps.cyr)
- `src/main.cyr` self-name in `cyc --version` output
- All `bootstrap/`, `scripts/`, `cbt/`, `programs/` references
- All `tests/`, `benches/`, `fuzz/` references
- All vidya `cc?` mentions (closeout-pass step 8 covers the
  ongoing per-minor refresh; v6.0.0 is the bulk pass)
- Downstream `cyrius.cyml` files don't change (`cyrius` build
  field already names the tool, not the binary), but downstream
  CI scripts that hard-coded `cc5` (e.g. yukti's
  `retest-aarch64.sh`) need a sweep — track which projects via
  the v6.0.0 closeout downstream-check step.
- Bootstrap chain comment chain: `cyrc → bridge → cc5` becomes
  `cyrc → bridge → cyc`. The seed binary path doesn't change
  (`bootstrap/asm` is an assembler, not the compiler).

**Compatibility:** v6.0.0 install ships a `cc5` symlink → `cyc`
for one minor (v6.0.x) so downstream toolchain scripts have a
window to migrate. v6.1.0 drops the symlink.

**Why a major bump:**
- Renaming the binary breaks every shell script and CI that
  invokes `cc5` directly. SemVer's whole point.
- Bootstrap chain touch — even for a rename — deserves the
  ceremony of a major.
- Bundles cleanly with the rest of the v6.0.0 cleanup so
  downstreams take one breakage hit, not many.

**Why `cyc` and not `cc6` / `cc7` / etc. — clean break, one-time
cost, forevermore source-of-truth:**
- The `cc<N>` scheme couples the binary name to the major
  version. Every major bump (v6 → v7 → v8 …) would otherwise
  trigger another rename + downstream churn. We did this once
  already (cc3 → cc5 with v5.0.0 — see CHANGELOG, vidya, and
  every `cc3 4.8.5` residue we're still cleaning up).
- `cyc` is **version-agnostic, permanently**. The binary stays
  `cyc` from v6.0.0 onward — through v7, v8, v∞. Version
  surfaces only via `cyc --version` and the `VERSION` file.
  Future major bumps run `version-bump.sh` and ship; no
  rename, no downstream sweep, no vidya `cc?` residue.
- **Anti-pattern that this rename explicitly forecloses:**
  the temptation at v7.0.0 to "match the cc3 → cc5 → cyc → cc7
  cadence." Don't. v6.0.0 is the *last* name change the
  compiler binary ever takes. If a future session is reading
  this and wondering whether to bump `cyc` → `cc7` at v7.0.0
  or `cc8` at v8.0.0 or whatever — the answer is **no**. The
  whole point of paying the v6.0.0 rename cost is that the
  pattern stops there. `VERSION` file + `cyc --version` output
  are the only sources of truth for "what version is this?"
- Cleanup-cost asymmetry: this rename is easier than cc3 → cc5
  was (smaller surface, fewer downstream consumers at the time,
  more discipline now via `version-bump.sh` + closeout pass) —
  so the one-time cost is small and it buys the property of
  *no more rename passes ever*. That's the load-bearing reason
  to spend the major-bump ceremony on it.
- **Same rule applies to every other binary in the toolchain.**
  `cyrc` (bootstrap compiler) stays `cyrc`. `asm` stays `asm`.
  `cyrius` (build tool) stays `cyrius`. `cyrld` (linker) stays
  `cyrld`. `cyrfmt` / `cyrlint` / `cyrdoc` / `cyrc` / `ark`
  stay as-is. No version digits anywhere in the binary
  name-space, ever. This is now a Key Principle in CLAUDE.md.

### v6.0.0 — accompanying refactor / cleanup

Items that have been queued or accreted across v5.x and that
benefit from landing in the rename pass rather than as scattered
patches:

- **Dead-code sweep on the standing reachability list.** Every
  `sh scripts/check.sh` run since v5.4.x has reported ~21
  unreachable fns in cc5 itself (`ELVRLOAD`/`ELVRSTORE`,
  `CLASSIFY_CF`/`CF_TARGET`, IR scaffolding `IR_NODE_FL`,
  `IR_BB_*`, `IR_EDGE_*`, `ir_emit2`, `ir_lower_all`,
  `ir_apply_lase`, `ir_dead_block_elim`, `PARSE_ASSIGN`,
  `_macho_wstr_pad`, `EMITMACHO_ARM64`, `EMITPE_OBJ`,
  `SYSV_HASH`). Audit which are speculative scaffolding for
  future work vs genuinely dead, and delete the latter. Mid-minor
  removal is risky if any downstream calls into these via dynlib
  bootstrap; major bump is the right slot.
- **`_TARGET_*` flag consolidation.** v5.4.x accumulated
  `_TARGET_MACHO`, `_TARGET_PE`, `_AARCH64_BACKEND`, plus
  per-arch `#ifdef CYRIUS_ARCH_{X86,AARCH64}` and per-arch
  `EWRITE_PE` / `_pe_pending_imp_add` / `EDISP32` shim families.
  Each was added as a tactical fix; collectively they're hard
  to reason about. Consolidate into a single backend-dispatch
  table keyed on `(arch, format)` — the same shape v5.x
  Platform Targets section anticipated when it said "cc5
  backend-table dispatch enables adding new targets without
  touching the frontend." Land the dispatch table at v6.0.0;
  delete the ad-hoc shims one by one in v6.0.x patches.
- **Bridge-compiler retirement assessment.** `src/bridge.cyr`
  exists to bridge cyrc's feature set to cc5's. With cc5 long
  past cyrc's surface, audit whether bridge can be retired or
  collapsed into cyrc's path — fewer compiler binaries in the
  bootstrap chain = less to verify byte-identical at every
  cycle.
- **`cc3`-era residue.** Vidya entries, comments in source,
  test fixtures still reference `cc3 4.8.5` and earlier. Sweep
  pass: anything mentioning a pre-cc5 binary either gets
  updated to `cyc` or moved to a `vidya/content/cyrius/history/`
  folder if the entry is genuinely about the historical lineage.
- **Heap-map tightening.** `src/main.cyr`'s heap map has
  accumulated regions across v5.x (the v5.4.6.2 ident-buffer
  bump, IR region added then unused on aarch64, etc.). Audit
  which regions are still load-bearing; reclaim wasted address
  space; document the post-v6.0.0 layout as the new baseline.
- **Backend module collapse where viable.** `src/backend/x86/`
  and `src/backend/aarch64/` each have parallel `emit.cyr`,
  `jump.cyr`, `fixup.cyr`. Some of the per-arch fixup logic is
  identical (e.g. function-call rel32 patching). Audit which
  helpers can move to `src/backend/common/` without entangling
  the asm-byte tables.
- **`cyrius build --strict` mode** — escalate `undefined
  function` warnings to hard errors. Drafted as a v5.4.13+
  follow-up after mabda Issue 2; lands cleanly with the v6.0.0
  rename pass since `--strict` is a flag-surface change that's
  major-bump-friendly.

### v6.0.0 — closeout

Same closeout checklist as every minor (CLAUDE.md §"Closeout
Pass") plus:
- Verify the `cc5` symlink works end-to-end on a clean install
  before tagging. Downstream CI failure on day-one of v6.0.0 is
  exactly the breakage-hit we're trying to avoid.
- Bulk vidya refresh — the rename touches every `cc?` mention,
  not just the version line. Use the closeout's vidya checklist
  as the audit list.

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
