# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.6.37** (shipped — `SSL_connect` deadlock fix via
fdlopen-based libssl loading; full HTTPS handshake works now.
Active minor: v5.6.x optimization arc)

## Compiler

- **cc5 (x86_64)**: 531,680 B (unchanged — v5.6.37 is a
  `lib/tls.cyr` rewrite; cc5 doesn't include tls.cyr so no
  compiler byte change)
- **cc5_win (cross)**: 606,720 B (v5.6.31 re-enables HIGH_ENTROPY_VA and fixes
  the EREAD_PE/EWRITE_PE DWORD-in-qword bug)
- **cc5_aarch64 native (Pi)**: 463,768 B (was: did not build — v5.6.32 added
  the missing `include "src/common/ir.cyr"` to `main_aarch64_native.cyr` that
  had been orphaned since v5.6.12 O3a shipped the IR instrumentation
  references to `IR_RAW_EMIT`)
- **cc5_aarch64 (cross)**: 411,136 B (was 419,776 at v5.6.26; −8,640 B — same
  compaction; cross-compiler is x86)
- **cc5_win (cross)**: 526,376 B (was 537,896 at v5.6.26; −11,520 B)
- **cc5 native aarch64** (Pi 4 output): 503,328 B at v5.6.27 (+6,320 B vs
  v5.6.25's 497,008; the x86-only compaction code is dead-emitted on aarch64
  builds — `#ifdef CYRIUS_ARCH_X86` strip pinned as future cleanup)
- **Self-host fixpoint**: 3-step (cc5_a → cc5_b → cc5_c, b == c) clean at both
  `IR_ENABLED == 0` and `IR_ENABLED == 3` (since v5.6.16).
- **IR=3 NOP-fill on cc5 self-compile** (v5.6.18 baseline carries forward;
  v5.6.19 adds infrastructure only, no codegen change): 135 folds + 678 DCE +
  15 DSE + 567 LASE = 1,395 candidates / **6,099 B**. v5.6.27 compaction
  sweeps picker NOPs at IR=0 only; IR=3 NOP harvest (DSE/LASE/const-fold)
  pinned for a future slot — needs same-shape tracking added to those passes.
- **Regalloc** (v5.6.20–v5.6.24): per-fn live-interval tables (v5.6.19) +
  Poletto-Sarkar picker (v5.6.20) + asm-skip lookahead (v5.6.23) +
  fixed SysV stack-arg shuttle (v5.6.24). **Default-on as of v5.6.24**
  (`CYRIUS_REGALLOC_AUTO_CAP=0` to disable; previously opt-in via
  `#regalloc` only). Picker pins up to 5 locals to rbx/r12-r15.
  v5.6.24 fixed the SysV ECALLPOPS r12-r14 clobber that surfaced as
  the "live-across-calls" bug (sandhi-reported / flags-test
  test_str_short→test_defaults bisection). `CYRIUS_REGALLOC_DUMP=1`
  prints intervals; `CYRIUS_REGALLOC_PICKER_CAP=N` caps assignments
  for bisection.

## Suites

- **check.sh**: 22/22 PASS (Linux x86_64 daily-driver + cross-platform skip-stubs)
- **`tests/tcyr/*.tcyr`**: 68 files
- **`fuzz/*.fcyr`**: 5 harnesses
- **`benches/*.bcyr`**: 14 benchmarks
- **Stdlib**: 60 modules (54 first-party + 6 deps via `cyrius deps`:
  sakshi, patra, sigil, yukti, mabda, sankoch)

## In-flight (v5.6.x optimization arc)

Slots shifted +2 total across v5.6.34 / v5.6.35 to accommodate
sit's 2026-04-24 ticket (one issue, two symptoms; v5.6.34 fixed
symptom 1, v5.6.35 closed symptom 2 via sankoch 2.0.3 dep bump).
Both shipped 2026-04-24.

- **v5.6.38** — shared-object (.so / .dll / .dylib) emission
  completion.
- **v5.6.39** — v5.6.x closeout + downstream ecosystem sweep
  gate (LAST patch of v5.6.x).

**Long-term considerations (no version pin)**: copy propagation +
cross-BB extended dead-store elimination — both recon-evaluated at
v5.6.18/v5.6.19-attempt, both bail (zero direct savings on stack-machine
IR; cross-BB versions need v5.6.21 regalloc liveness data first). See
`roadmap.md §Long-term considerations` for full recon data + revisit
criteria.

## Recent shipped (one-liner per release)

- **v5.6.37** — `SSL_connect` deadlock fixed by routing libssl
  through `fdlopen`. Sandhi M2's HTTPS probe hung forever on
  `futex(FUTEX_WAIT_PRIVATE, 2, NULL)` at TCB+0x118 after TCP
  connect succeeded — libssl's `OPENSSL_init_ssl` uses a
  pthread recursive mutex inside the TCB, and cyrius's
  `dynlib_bootstrap_tls` stub zeroed that TCB so the mutex's
  `__kind` field reads 0 (= non-recursive). Same-thread
  re-entry deadlocked (CAS 0→1, CAS 1→2, futex(WAIT, 2)).
  Fix: `lib/tls.cyr::_tls_init` now calls `fdlopen_init_full`
  which invokes `ld-linux.so` to run a shim through real
  `__libc_start_main` + `__libc_pthread_init`; subsequent
  `dlopen("libssl.so.3")` loads against a fully-initialised
  glibc TCB and all pthread primitives work correctly.
  Verified end-to-end: `https://1.1.1.1/` handshake + HTTP
  GET + response read round-trips cleanly ("HTTP/1.1 301
  Moved Permanently"). New gate
  `tests/regression-tls-live.sh` wired into check.sh (4q''),
  skips if `~/.cyrius/dlopen-helper` missing or network
  unreachable. Zero compiler change; cc5 byte-identical at
  531,680 B.
- **v5.6.36** — `tests/regression-pe-exit.sh` rewritten. Same
  exact misdiagnosis pattern as v5.6.33's Mach-O slot — the
  PE gate's `fn main() { syscall(60, 42); return 0; }` fixture
  never entered `main()` (cyrius has no auto-call); entry
  prologue branched over the dead body to `EEXIT_PE` which
  called `kernel32!ExitProcess(arg)` with whatever was in the
  arg-slot register on Win11 24H2 (= `0x40010080`, the roadmap's
  reported "regression"). PowerShell reported
  `ApplicationFailedException` because the high nibble is an
  NTSTATUS-shape informational code. **None of this was a
  Win11 24H2 issue.** Verified by patching the PE's
  `DllCharacteristics` from `0x0000` → `0x0160` and observing
  byte-identical exit behavior; both forms exit 42 with correct
  top-level syntax. Gate rewritten: top-level
  `syscall(60, 42)` (proves IAT + ExitProcess) + write+exit
  (kernel32!WriteFile reroute) + user-fn arithmetic (v5.6.10
  peephole on PE codegen). `CYRIUS_V5634_SHIPPED` guard
  dropped; `CC_PE` retargeted from `build/cc5_win` (PE binary
  that can't run on Linux) to `build/cc5_win_cross` (Linux ELF
  emitting PE; auto-builds from `cc5 < src/main_win.cyr`).
  CR-strip added for cmd.exe CRLF output. Zero compiler change;
  cc5 byte-identical at 531,680 B. check.sh 24/24 with PE gate
  ACTIVE. End-to-end on cass (Win11 24H2 build 26200,
  Microsoft Windows 10.0.26200.8246): all three tests exit 42.
- **v5.6.35** — sit symptom 2 of 2 closed via sankoch dep bump
  2.0.1 → 2.0.3. Triage on the same 100-commit fixture pinned
  the layer to sankoch's `zlib_compress` producing
  non-decompressible DEFLATE on sit-tree-shaped inputs
  (1600+ patra roundtrips clean, 1600+ sankoch synthetic
  roundtrips clean, in-process zlib_decompress fails 50/300
  in same lock window — bug upstream of patra, deterministic
  on input). sankoch 2.0.2 fixed 51/53; 2.0.3 fixed remaining
  2 (~1.5 KB and ~2 KB inputs with a distinct mid-stream
  zero-run). Cyrius v5.6.35 = `cyrius.cyml` `[deps.sankoch]`
  pin 2.0.1 → 2.0.3 + new `tests/regression-sit-status.sh`
  active gate. Zero compiler change; cc5 byte-identical at
  531,680 B. check.sh 24/24. End-to-end sit `fsck` reports
  `checked 300 objects, 0 bad`.
- **v5.6.34** — stdlib `alloc` grow-undersize SIGSEGV fixed
  (`lib/alloc.cyr` Linux brk + `lib/alloc_macos.cyr` mmap).
  Both paths grew by a fixed `0x100000` step every time
  `_heap_ptr` crossed `_heap_end` — any single
  `alloc(size > 1 MB)` near the boundary returned a pointer
  past the new end, SIGSEGV on first tail-write. Filed by sit
  2026-04-24 during S-33 triage of `sit status` SIGSEGV on
  100-commit repo (16 MiB zlib retry buffer in
  `object_db.cyr:read_object`). Verified across v5.6.25 → v5.6.33.
  Fix: Linux rounds the new end up to the next 1 MB grain;
  macOS loops 1 MB mmaps to preserve the per-step contiguity
  guard. New gate `tests/tcyr/alloc_grow.tcyr` (10 assertions
  covering 4 MB / 16 MB / 1000×64 B / 128 MB shapes). Windows
  path separable — `lib/alloc_windows.cyr` doesn't grow, fails
  cleanly. cc5 byte-identical at 531,680 B (uses raw `brk`,
  not `lib/alloc.cyr`). check.sh 23/23.
- **v5.6.33** — `tests/regression-macho-exit.sh` rewritten.
  Slot's premise was wrong: the `fn main() { syscall(60, 42); }`
  fixture never actually entered `main()` — cyrius has no
  auto-invoked `main`; top-level stmts are the entry point. The
  argv prologue's branch-over-fn-bodies landed on the `EEXIT`
  tail with `x0 = argc = 1` still resident, hence rc=1 on ecb.
  Top-level `syscall(60, 42);` exits 42 cleanly under macOS
  26.4.1 on unchanged v5.6.33 cross-compiler. Gate expanded to
  three tests: `__got[0]=_exit` + `__got[1]=_write` (bytes
  verified) + v5.6.11 peephole round-trip. `CYRIUS_V5633_SHIPPED`
  guard dropped; gate runs whenever `build/cc5_aarch64` exists
  and `ssh ecb` is reachable. No compiler code changed. cc5
  byte-identical at 531,680 B. check.sh 23/23.
- **v5.6.32** — native aarch64 self-host on Pi 4 repaired.
  `src/main_aarch64_native.cyr` was missing
  `include "src/common/ir.cyr"` that `main_aarch64.cyr` received
  when v5.6.12 O3a shipped the `IR_RAW_EMIT` instrumentation
  markers (shared `parse_*.cyr` references the opcode enum
  unconditionally). 1-line fix. Native-on-Pi fixpoint now
  byte-identical: cc5_b == cc5_c at 463,768 B.
  `regression-aarch64-native-selfhost.sh` flipped from a
  wrong-shape skip-stub (md5-against-cross-build) to the correct
  2-step native fixpoint and wired into `check.sh`. The earlier
  roadmap framing cited `_TARGET_MACHO` undef — stale symptom
  shape from a pre-v5.6.12 source tree; same root cause class
  (include missing from the native variant), same 1-line fix.
- **v5.6.29** — sandhi-surfaced `lib/tls.cyr` HTTPS infinite-loop
  fix. `_tls_init` now runs the documented libc-consumer bootstrap
  (`dynlib_bootstrap_cpu_features` + `_tls` + `_stack_end`) before
  `dynlib_open("libcrypto.so.3")` / `libssl.so.3`. Without it,
  IFUNC-resolved cipher selection in libcrypto + `%fs:N` accesses
  in libssl session setup faulted; `_tls_init` returned 0
  (looked-success) but `SSL_connect` entered a tight retry loop —
  the http-probe "GET ... GET ... GET ..." flood symptom in the
  sandhi M2 design report. fdlopen half (symptom §1-2) split to
  v5.6.29-1 hotfix-style slot; the investigation may or may not
  yield in one sitting and the suffix lets it ship-or-defer
  cleanly. tls.tcyr 22/22, check.sh 23/23, cc5 byte-identical.
- **v5.6.28** — `cyrius init` scaffold gaps (owl-surfaced, 5 fixes)
  + audit-pass cleanup. (1) Write the advertised `src/test.cyr` stub
  (was ENOENT on `cyrius test`). (2) Global `cyrius.toml` →
  `cyrius.cyml` in agent CLAUDE.md presets + src/main.cyr +
  tests/* headers. (3) Dry-run output rebuilt to mirror the real
  writer set 1:1 (was advertising CONTRIBUTING.md / SECURITY.md /
  CODE_OF_CONDUCT.md / docs-content that no writer ever produces).
  (4) `--description=<str>` flag with `<name> — TODO` placeholder
  default (was always empty). (5) "already exists" hint now points
  at `cd $NAME && cyrius init --language=none .` (was the same
  command that failed). Audit extras: bare `cyrius test` in CI
  workflow + README, dropped dead `lib/agnosys/` and `scripts/`
  empty mkdirs, consolidated tests/ mkdir into the structure block.
  No compiler change. check.sh 23/23, cc5 byte-identical.
- **v5.6.27** — Phase O6 codebuf compaction (NOP harvest with jump+fixup
  repair). Per-fn pass after picker; sweeps the 4-byte `0F 1F 40 00`
  NOP-fills via explicit tracking at every NOP-emit + disp32-emit
  site (no byte-scan — that false-positives on data bytes). New heap
  regions at 0xA0000 (jump-source) + 0xA2010 (NOP runs) + 0xA6010
  (fn-start fixup baseline). Hooks in EJCC/EJMP/EJMP0/ECALLTO + the
  picker's load/store rewrites. Compaction sorts NOPs by CP, walks
  the jump-source table to recompute disp32s, shifts fixup-table CPs
  + jump-target CPs, then compacts bytes. Gates: x86 only, kmode≤1,
  IR=0, no table overflow. **cc5 542,928 → 531,392 B (−11,536 B /
  −2.13%)**, cross-compilers see similar gains. check.sh 23/23, both
  fixpoints clean. IR=3 NOP harvest (DSE/LASE/const-fold passes)
  pinned for a future slot.
- **v5.6.26** — peephole refinement + v5.6.25 doc/CHANGELOG completion
  (the EPOPARG `n == 0` adjacency-cancel block landed cleanly, plus
  full CHANGELOG/roadmap/state.md entry for v5.6.25's 13-LOC fix).
  Phase O5 maximal-munch slot dropped from the optimization arc:
  recon found 0 fused-op candidates (cyrius's stack-machine IR keeps
  a push between sub-expression results and consumers); push-imm
  rewrite has rax-side-effect + forward-jump-target issues. Pinned
  long-term, no slot — needs an IR-level push-elision pass first.
- **v5.6.25** — aarch64 push/pop cancel completion (scope retargeted
  from "aarch64 fused ops" after bytescan found 0 `mul+add` / 0
  `lsr+and` matches). v5.6.9's push/pop cancel had a latent gap:
  `EPOPARG(S, n)` bypassed the adjacency check for every `n`, so
  1-arg call sites (`EPUSHR; EPOPARG(S, 0)`) emitted a redundant
  8-byte push+pop pair. Pre-fix cc5_native_arm carried **2,569**
  such pairs. 13-LOC fix in `src/backend/aarch64/emit.cyr::EPOPARG`.
  Native aarch64 cc5 **517,376 → 497,008 B (−20,368 B / −3.94%)** —
  larger than v5.6.11's aarch64 combine-shuttle shrinkage. x86
  cc5 unchanged at 542,928 B. check.sh 23/23. Pi exit42 OK.
- **v5.6.24** — **Default-on regalloc**, two-bug fix. (1) SysV
  ECALLPOPS for n>6 args used r12-r14 as scratch. Under v5.6.20+
  regalloc the picker pinned caller's locals to those callee-saved
  regs → silent corruption (sandhi-reported "live-across-calls"
  boxing workaround / flags-test test_str_short→test_defaults
  bisection at AUTO_CAP=118). Rewrote shuttle to use only r10
  (caller-saved) via direct `[rsp+offset]` addressing. (2) Flipped
  `_ra_auto_cap` default from -1 (disabled) to "uncapped" — every
  eligible fn gets auto-regalloc'd unless it has inline asm.
  cc5 522,624 → 542,928 B (+20,304 B for save/restore overhead;
  perf gain visible only in downstream consumers). check.sh 23/23,
  all 84 .tcyr PASS, both fixpoints clean. v5.6.25 sandhi
  pre-existing fdlopen + TLS bugs pinned for future investigation.
  Cascade -1 (v5.6.25 picker-bug consolidated into v5.6.24);
  closeout v5.6.36 → v5.6.35.
- **v5.6.23** — Misdiagnosis correction: the v5.6.22 "alignment
  regression" was actually inline-asm + regalloc stack-frame layout
  collision. Asm hardcodes `[rbp-N]` disps; regalloc's callee-save
  block shifts every local slot by `_cur_fn_regalloc * 8`. Fix:
  body-scan lookahead in `parse_fn.cyr` for token 48 (`asm`); auto-
  enable silently skips, opt-in `#regalloc` warns and skips. Default-
  on flip surfaced a SECOND picker bug — fixed at v5.6.24.
  Cascade +2: closeout v5.6.34 → v5.6.36.
- **v5.6.22** — Phase O4c (partial): picker correctness fix (loop-back
  time-share extend) + auto-enable infrastructure shipped DISABLED
  by default. `CYRIUS_REGALLOC_AUTO_CAP=N` opts in (per-fn count cap).
  Default-on auto-enable surfaced what was framed as a v5.5.21
  array-alignment regression — v5.6.23 traced it to inline-asm
  layout, not alignment. Patra 1.6.0 verified folding cleanly.
- **v5.6.21** — Codegen bug fix: bare-truthy `if (r)` after fn-call.
  Root cause: v5.6.8 `_flags_reflect_rax` not reset by EFLLOAD,
  ECALLFIX, ECALLTO, ESYSCALL. 4-line fix. Patra 1.6.0 unblocked.
  New regression gate 4r (check.sh 22 → 23). Repro
  `/tmp/cyrius_5.6_codegen_bug.cyr` now exits 99 (was -1).
- **v5.6.20** — Phase O4b: Poletto-Sarkar linear-scan picker (replaces
  greedy use-count) + time-sliced rewrite. Opt-in `#regalloc` only.
  Picker proven correct on 8-local spill-pressure test (5 assigned, 3
  spilled). cc5 self-build observable change = none (no `#regalloc`
  in cyrius source); v5.6.21 auto-enable surfaces the win. Patra dep
  bumped 1.5.5 → 1.6.0 (blob support for `sit` consumer).
- **v5.6.19** — Phase O4a: per-fn live-interval infrastructure. Foundation
  for v5.6.20 Poletto-Sarkar picker. Pre-existing `ra_counts[256]` sizing
  bug fixed (256 bytes → 256 i64 slots). `CYRIUS_REGALLOC_DUMP=1` env knob
  for inspection. No codegen change yet.
- **v5.6.18** — Phase O3c: dead-store elimination + fixed-point driver.
  Recon-driven scope split: copy-prop deferred to v5.6.19 (zero direct
  savings on stack-machine IR — cascade-only value). **15 DSE / 6,099 B
  NOP-fill at IR=3 in 3 fixpoint iterations** (cascade caught 3 more folds).
- **v5.6.17** — Phase O3b-fix: bitmap liveness + DCE (the v5.6.16-deferred
  half). Bug fixed via `CYRIUS_DCE_CAP` bisection — `IR_RAX_CLOBBER` reads
  RCX, not writes it. **678 DCE kills / 2,010 B NOP-fill** at IR=3.
- **v5.6.16** — Phase O3b part 1/2: IR const-fold (130 folds, 774 B NOP-fill
  at IR=3); DCE deferred to v5.6.17 per quality-before-ops; v5.6.22
  re-pinned to codebuf compaction (real shrinkage).
- **v5.6.15** — IR-emit-order audit fix: 5-LOC `ESETCC` reorder; SETCC→CMP
  IR adjacency 3,665 → 0; bytes unchanged at IR=0.
- **v5.6.14** — Phase O3a-fix: LASE correctness (`parse_ctrl.cyr` loop_top
  IR_NOP landing pads) + `IR_RAX_CLOBBER` for EMULH/EIDIV/ELODC.
- **v5.6.13** — `lib/sha1.cyr` extraction (quick-win, promoted from
  `_wss_sha1`).

(Older releases: see `completed-phases.md`.)

## Consumers

AGNOS kernel, agnostik (58 tests), agnosys (20 modules), argonaut (424
tests), sakshi, sigil (206 tests), libro (240 tests), shravan (audio),
cyrius-doom, bsp, mabda, kybernet (140 tests), hadara (329 tests),
ai-hwaccel (491 tests).

All AGNOS ecosystem projects depend on the compiler and stdlib.

## Verification hosts

- `ssh pi` — Pi 4 (Linux aarch64 native runtime)
- `ssh ecb` — Apple Silicon MBP (Mach-O arm64 runtime)
- `ssh cass` — Windows 11 24H2 (PE32+ runtime)

## Bootstrap chain

```
bootstrap/asm (29 KB committed binary — root of trust)
  → cyrc (12 KB compiler)
    → bridge.cyr (bridge compiler)
      → cc5 (modular compiler + IR, 9 modules)
        → cc5_aarch64 (cross-compiler)
        → cc5_win (cross-compiler)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```
