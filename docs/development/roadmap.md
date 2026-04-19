# Cyrius Development Roadmap

> **v5.4.8.** cc5 compiler (466560 B x86_64), x86_64 + aarch64
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
> `.data`, byte-cmp polish) is the v5.4.9+ queue. **v5.4.x runs a parallel compiler-optimization
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

### v5.4.9+ Queue — PE correctness (tracked, not hidden)

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
  sigil's existing `sha256_4kb` (~250 µs).

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
