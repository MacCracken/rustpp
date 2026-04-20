# Cyrius Development Roadmap

> **v5.4.10.** cc5 compiler (467104 B x86_64), x86_64 + aarch64
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
> wake-flag fix** (majra unblocked). **v5.4.11 is claimed by
> aarch64 Linux syscall stdlib** (yukti blocker:
> `syscall(4, …)` is `pivot_root` on aarch64, not `stat`).
> **v5.4.12 is claimed by `lib/keccak.cyr`** (sigil 3.0 PQC
> enabler — pulled in from "remaining enablers" so sigil
> isn't blocked through the v5.5 cycle). **v5.4.13 is the
> v5.4.x closeout pass** (per CLAUDE.md §"Closeout Pass" —
> dead-code audit, doc sync, residual parse.cyr unguarded
> x86-emit cleanup, permanent `EW` alignment assert on
> aarch64); after v5.4.13 ships, the next tag is **v5.5.0**. **v5.4.x runs a parallel compiler-optimization
> track** (phases O1–O6: instrumentation + FNV-1a symbol table,
> peephole quick wins, IR passes, linear-scan regalloc,
> maximal-munch instruction selection) synthesized from vidya
> and external research (QBE / TCC / Poletto-Sarkar / Agner Fog). aarch64 port remains fully online (`regression.tcyr`
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

### v5.4.11 — aarch64 Linux syscall stdlib (yukti blocker)

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
shipping) and `lib/syscalls_windows.cyr` (queued for v5.4.12+).

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

**Companion (queued for v5.4.12+, not v5.4.11 scope):** audit
`src/frontend/parse.cyr` syscall rerouting — either cover the
full Linux table deterministically OR remove the subset
translation and require consumers to go through
`lib/syscalls*`. Pairs naturally with the existing v5.5.x
audit of unguarded x86-emit paths in shared parse.cyr.

### v5.4.12 — `lib/keccak.cyr` (sigil 3.0 PQC enabler)

Pulled in from "Sigil 3.0 enablers — remaining" — sibling of the
`ct_select` (v5.3.2), `mulh64` (v5.3.3), `secret var` (v5.3.5)
items already shipped from that cohort. Self-contained stdlib
work; no compiler changes.

**Why now:** sigil 3.0 PQC migration is calendar-pressured;
`lib/keccak.cyr` is the last toolchain-side block. Letting it
slip to v5.5.x means sigil stays blocked through the v5.5
release cycle. Small enough to fit comfortably as a v5.4.x
patch (~300 LOC for permutation + sponge; pure stdlib), and
v5.4.13 (closeout) is the natural wrap-up slot for the line.

**Scope:**
- **Keccak-f[1600] permutation** — the 24-round
  `theta / rho / pi / chi / iota` core. Bit-interleaved or
  64-bit-lane implementation; the cyrius `u64` arithmetic +
  rotate primitives already cover what's needed.
- **Sponge construction** with absorb / squeeze separation
  for SHAKE-128 (rate 1344 bits) and SHAKE-256 (rate 1088
  bits), per FIPS 202.
- **No external deps.** Self-contained `lib/keccak.cyr` —
  belongs alongside `lib/sha256.cyr` (already in stdlib).
- **Benchmark target:** 4 KB SHAKE-256 within 2× of sigil's
  existing `sha256_4kb` (~250 µs). Wire into `benches/` so
  regressions are visible.
- **`tests/tcyr/keccak.tcyr`** — at minimum the FIPS 202
  Appendix A.1 / A.2 NIST test vectors for SHAKE-128 and
  SHAKE-256 (empty input + a few short messages), plus a
  4 KB round-trip case for the bench-shape.

**Acceptance:**
1. `tests/tcyr/keccak.tcyr` PASS — NIST vectors match.
2. `benches/keccak.bcyr` lands within the 2× sha256 budget.
3. `sh scripts/check.sh` 9/9 (count stays at 10 once the
   keccak gate is wired — see below).
4. cc5 + cc5_aarch64 self-host byte-identical (lib-only
   change; should be trivial).
5. **sigil 3.0 unblock**: with the v5.4.12 toolchain, sigil's
   ML-DSA-65 XOF step can stop stubbing the SHAKE call and
   ship the real PQC path. Verified at sigil's pin-bump time,
   not in cyrius CI.

### v5.4.13 — v5.4.x closeout pass (then v5.5.0)

Per the closeout-pass procedure in `CLAUDE.md` (run before every
minor/major bump, ship as the last patch of the current minor —
e.g. 4.2.5 before 4.3.0). v5.4.13 is the v5.4.x closeout; tagging
it clears the path for v5.5.0 (Platform Targets — see §"v5.x —
Platform Targets" below).

**Closeout checklist (verbatim from CLAUDE.md §"Closeout Pass"):**
1. Self-host verify — cc5 compiles itself byte-identical.
2. Bootstrap closure — seed → cyrc → asm → cyrc byte-identical.
3. Dead code audit — check dead function count, remove dead
   source code (the standing 21-fn list at v5.4.10 is a good
   floor; trim what's reachable to drop).
4. Stale comment sweep — grep for old version refs, outdated
   TODOs.
5. Heap map verify — main.cyr heap map matches actual usage.
6. Downstream check — every `cyrius.cyml` `cyrius` field
   across the ecosystem repos points to the released v5.4.x
   tag, not a dev pin.
7. Security re-scan — quick grep for new `sys_system`,
   `READFILE`, unchecked writes (we haven't run a full audit
   since v5.0.1).
8. CHANGELOG / roadmap / vidya sync — all docs reflect current
   state.
9. Full `sh scripts/check.sh` — 10/10 PASS (gates at v5.4.12
   = 9 existing + keccak's NIST-vector regression).

**Scope:**
- Audit the parse.cyr unguarded x86-emit paths flagged in
  v5.4.10's memory (`feedback_unguarded_x86_emit.md`) — closure
  address @970, struct field byte/word/dword load 1777-1779,
  `#regalloc` callee-saved 3257/3403, x87 fallbacks. Fix what
  fires under any current downstream's exercise; queue what
  doesn't to v5.5.x.
- Permanent `EW` alignment assert in
  `src/backend/aarch64/emit.cyr` — the catch-everything net
  for any future RBP-shift / alignment regression on aarch64.
  Cheap; should have been there since v5.4.8.
- Audit `src/frontend/parse.cyr`'s opaque syscall rerouting
  (the partial translation that makes `syscall(1)` and
  `syscall(60)` work on aarch64 today) — either complete the
  table deterministically or remove the subset and require
  consumers to go through `lib/syscalls*` (now per-arch as of
  v5.4.11).
- `cyrius build --strict` mode (escalate `undefined function`
  warnings to hard errors) if it can land cheaply — closes
  the regression class that mabda Issue 2 represents. Otherwise
  defer to v5.5.x.
- Verify the post-v5.4.10 thread surface: TLS gap, atomics
  gap, and runtime thread-safety surface (alloc / freelist /
  hashmap under `CLONE_VM`) are all flagged but not yet on a
  minor. Closeout decides whether any of those need a v5.4.x
  patch slot or all push to v5.5.x.

After v5.4.13 ships, the next tag is **v5.5.0** — which is
itself claimed by the PE correctness completion below. The new
minor opens with the same Windows arc that closed v5.4.x: ship
the `fncall*` Win64 ABI rework + the remaining `syscall(n)`
mappings + `lib/syscalls_windows.cyr` + `lib/alloc_windows.cyr`
+ `cc5_win.cyr` cross-entry + RW-split as v5.5.0, then v5.5.x
patch releases follow with the aarch64 native-syscall
self-host (currently x86-cross only) and any other platform
gaps surfaced during the closeout.

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

### v5.4.x Queue — Compiler Optimization (parallel track)

Phased plan synthesized from vidya
(`content/optimization_passes`, `content/code_generation`,
`content/allocators`) and external research (QBE, TCC, QBE arm64
peephole — Brian Callahan, Poletto/Sarkar linear scan, Agner Fog
x86_64 microarchitecture notes). Runs alongside the Windows
correctness queue above; phases are independently shippable as
patch releases. **Non-negotiable across every phase**: byte-identical
self-host must hold; every pass must be deterministic.

**Guardrails (both research tracks converged on these "don't"s):**
- No graph-coloring register allocation (3–5× the code of linear
  scan for ~10 % marginal quality on our function sizes).
- No iterated register coalescing (Appel) — nondeterminism risk.
- No static instruction scheduling on x86_64 (OoO hardware hides it).
- No SCCP / GVN / polyhedral (out of scope for a ~450 KB compiler).
- No PEXT/PDEP/BMI2 opportunistic (pre-Haswell portability trap).
- No multi-arena heap restructuring (the 21 MB flat heap map is
  auditable state; lifetime partitioning is already static).

#### Phase O1 — Instrumentation + symbol-table upgrade
Baseline before tuning anything. Without per-phase numbers we
can't tell which optimization actually moved the needle.
- Per-phase `rdtsc` counters (`lex` / `preprocess` / `parse` /
  `ir-lower` / `emit` / `fixup`) gated behind a compile-time
  flag, written to a static buffer, dumped at exit. ~40 LOC.
- **Symbol-table hash upgrade**: current `fn_names[4096]` /
  `struct_names` / identifier-pool use linear scan (O(N) per
  identifier touch). Replace with FNV-1a open-addressing hash
  (load factor ≤ 0.7) keyed by offset-into-pool. Expected win:
  10–25 % compile-throughput on self-host once `fn_count > ~200`.
  ~200 LOC.
- Gate: baseline numbers in `docs/development/benchmarks.md`;
  self-hosting byte-identical.

#### Phase O2 — Peephole quick wins (x86_64 + aarch64)
All deterministic, small, bang-for-buck. Vidya and external
research both called these out as first-wave.
- **Strength reduction**: `x * 2^n` → `shl/lsl`, `x / 2^n` →
  `shr/lsr`/`asr`, `x * 0` → `xor`, `x * 1` → copy, `x ± 0`
  → copy. Pattern detection via `(n & (n - 1)) == 0`. ~60 LOC
  across both backends.
- **Flag-result reuse**: track a "last flags producer" slot in
  emit state; invalidate on any flag-clobber; skip redundant
  `cmp` / `cmn` when preceding arithmetic already set flags.
  ~80 LOC.
- **Redundant-move / self-move elimination**: `mov rX, rX`;
  post-emit pass collapses no-ops from regalloc+inline
  interactions. ~100 LOC.
- **LEA combining** (x86_64): `mov rX, rA; add rX, rB; add rX, imm`
  → single `lea rX, [rA+rB+imm]`; avoid 3-operand LEA on RBP/R13
  base (port-1 latency trap per Agner Fog). ~120 LOC.
- **aarch64 fused ops**: `mul + add` → `madd`, `mul + sub` →
  `msub`, `and + lsr mask` → `ubfx`, signed variant → `sbfx`.
  ~150 LOC. Saves one instruction per site.

#### Phase O3 — IR-driven passes
Builds on the existing LASE / DBE / CFG infrastructure that's
already instrumented but not yet on every emit path.
- **Precondition**: finish IR instrumentation across the
  remaining ~50 direct emit sites (`EB` / `E2` / `E3` calls in
  `src/frontend/parse.cyr`). Without this, LASE codebuf patching
  is unsafe — same blocker the current v5.x IR plan noted.
- **Constant folding + propagation on IR**: promote the existing
  parse-time folding into a CFG-aware pass. Integer arithmetic,
  boolean, comparisons on constant operands. ~200 LOC.
- **Bitmap-based liveness + DCE**: one u64 = liveness for 64
  virtual registers; backward sweep; mark defs with no live
  uses as dead. Pattern lifted from
  `vidya/content/optimization_passes/cyrius.cyr`. ~60 LOC.
- **Copy propagation + dead-store elimination**: forward sweep
  with per-vreg "current copy-of" map; backward sweep marking
  live stores. ~300 LOC.
- **Fixed-point driver**: run fold → propagate → reduce → DCE
  in a loop until no-change. Essential because each pass
  enables the next. ~30 LOC.

#### Phase O4 — Linear-scan register allocation
The big investment. Replaces today's peephole `#regalloc`. Both
research tracks pointed at this as the highest-quality-per-LOC
single optimization.
- Sort live intervals by start point; greedy assignment with
  spill heuristic = furthest next use (Poletto & Sarkar).
  ~600–900 LOC for: live-range build, active-set management,
  spill slot assignment, parallel-move resolution at block
  boundaries.
- **Determinism guard**: keep hint-based preferences but skip
  iterated coalescing — byte-identical self-host must hold.
- Depends on Phase O3's completed IR coverage (live ranges
  need every def and use to be in IR).
- Expected output-code speedup: 2–3× over current stack-machine
  baseline on hot inner loops; 10–20 % quality gap vs.
  graph-coloring at a fraction of the code.

#### Phase O5 — Maximal-munch instruction selection
Formalize the existing ad-hoc tile patterns (mem-operand
`add`/`sub` on x86_64, aarch64 addressing modes) into a tile
pattern database. Walker traverses IR tree bottom-up, matching
largest subtree to a single machine instruction. Opens the door
for future target-specific tiles (RISC-V v5.5.0) without
touching the walker.
- ~300–500 LOC for the tiling infrastructure; per-target tile
  tables live in each backend's `emit.cyr`.

#### Phase O6 — Optional, measurement-gated
- **Slab allocator for IR node pools**: `vidya/content/allocators`
  documents 20–30× speedup over bump for fixed-size object
  churn. Only worth it if Phase O4's profiling shows bump
  allocation hot during live-range construction. ~150 LOC.

---

## Sigil 3.0 enablers — remaining

Downstream `sigil` items the Cyrius toolchain still owes. Shipped
enablers (`ct_select` v5.3.2, `mulh64` v5.3.3, `secret var` v5.3.5)
are in CHANGELOG.

- **`lib/keccak.cyr`** — Keccak-f[1600] permutation + sponge API
  (SHAKE-128 / SHAKE-256). NIST FIPS 202. Required for
  ML-DSA-65's XOF step in sigil 3.0 PQC. Self-contained, no
  external deps. Benchmark target: 4 KB SHAKE-256 within 2× of
  sigil's existing `sha256_4kb` (~250 µs). **Claimed by v5.4.12
  — see roadmap §v5.4.12.**

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
| **v5.5.0** | RISC-V rv64 | ELF | First-class RISC-V target |
| **v5.6.0** | Bare-metal | ELF (no-libc) | AGNOS kernel target |

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
| macOS aarch64 | Mach-O | **Done** (v5.3.13) — self-hosts byte-identically on Apple Silicon, 475 KB. Strings + globals v5.3.1. |
| Windows x86_64 | PE/COFF | **Structural done** (v5.4.2) — compiler emits valid PE32+ (1536 B, `file(1)` verified). Win64 ABI correctness + on-hardware gate queued for v5.4.3+. |
| RISC-V (rv64) | ELF | Queued — **v5.5.0** |
| Bare-metal | ELF (no-libc) | Queued — **v5.6.0** (AGNOS kernel target) |

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
