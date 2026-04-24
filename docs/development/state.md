# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.6.23** (in progress — active minor: v5.6.x optimization arc)

## Compiler

- **cc5 (x86_64)**: 521,216 B
- **cc5_aarch64 (cross)**: 400,872 B
- **cc5_win (cross)**: 516,200 B
- **cc5 native aarch64** (Pi 4 self-host): ~453,688 B at v5.6.11
- **Self-host fixpoint**: 3-step (cc5_a → cc5_b → cc5_c, b == c) clean at both
  `IR_ENABLED == 0` and `IR_ENABLED == 3` (since v5.6.16).
- **IR=3 NOP-fill on cc5 self-compile** (v5.6.18 baseline carries forward;
  v5.6.19 adds infrastructure only, no codegen change): 135 folds + 678 DCE +
  15 DSE + 567 LASE = 1,395 candidates / **6,099 B** in 3 fixed-point
  iterations. Real binary shrinkage waits for v5.6.24 codebuf compaction.
- **Regalloc** (v5.6.20): per-fn live-interval tables (v5.6.19) +
  Poletto-Sarkar picker with time-sliced rewrite. Opt-in via
  `#regalloc`. `CYRIUS_REGALLOC_DUMP=1` prints intervals;
  `CYRIUS_REGALLOC_PICKER_CAP=N` caps assignments for bisection.
  v5.6.21 will auto-enable for every fn.

## Suites

- **check.sh**: 22/22 PASS (Linux x86_64 daily-driver + cross-platform skip-stubs)
- **`tests/tcyr/*.tcyr`**: 68 files
- **`fuzz/*.fcyr`**: 5 harnesses
- **`benches/*.bcyr`**: 14 benchmarks
- **Stdlib**: 60 modules (54 first-party + 6 deps via `cyrius deps`:
  sakshi, patra, sigil, yukti, mabda, sankoch)

## In-flight (v5.6.x optimization arc)

- **v5.6.23** — Phase O4c (re-attempt): default-on auto-enable +
  alignment investigation. v5.6.22 surfaced two bugs when default-on
  was attempted: (1) loop-back time-share corruption in picker
  (FIXED at v5.6.22 — extend interval.last_cp to ra_end so picker
  can't time-share across loops); (2) v5.5.21 global-array
  alignment regression — auto-enable's code-size growth shifts
  globals in a way the per-array padding misses, breaking SSE m128
  ops. v5.6.23 must investigate + fix the alignment interaction
  before flipping auto-enable default-on. `CYRIUS_REGALLOC_AUTO_CAP=N`
  env knob is already shipped and works for opt-in testing.
  (~250 LOC + bug-hunt budget). Multi-local-per-register packing + flip
  `#regalloc` from per-fn opt-in to automatic.
- **v5.6.22** — aarch64 fused ops (`madd`/`msub`/`ubfx`/`sbfx`),
  precondition v5.6.21.
- **v5.6.23** — Phase O5: maximal-munch instruction selection (precedes
  RISC-V backend at v5.7.0).
- **v5.6.24** — Phase O6: codebuf compaction (NOP harvest with jump+fixup
  repair). Real binary shrinkage; sweeps all per-pass NOP overhead.
- **v5.6.25–v5.6.27** — consumer-surfaced tooling: `cyrius init` scaffold,
  libro layout corruption, `cc5_win.exe` HIGH_ENTROPY_VA stdin failure.
- **v5.6.28–v5.6.30** — broad-scope platform repair: aarch64 native
  self-host (`_TARGET_MACHO` undef), macOS arm64 Mach-O exit (Sequoia
  dyld drift), PE32+ Windows exit (Win11 24H2 loader drift).
- **v5.6.31** — shared-object emission.
- **v5.6.32** — closeout.

**Long-term considerations (no version pin)**: copy propagation +
cross-BB extended dead-store elimination — both recon-evaluated at
v5.6.18/v5.6.19-attempt, both bail (zero direct savings on stack-machine
IR; cross-BB versions need v5.6.21 regalloc liveness data first). See
`roadmap.md §Long-term considerations` for full recon data + revisit
criteria.

## Recent shipped (one-liner per release)

- **v5.6.22** — Phase O4c (partial): picker correctness fix (loop-back
  time-share extend) + auto-enable infrastructure shipped DISABLED
  by default. `CYRIUS_REGALLOC_AUTO_CAP=N` opts in (per-fn count cap).
  Default-on auto-enable surfaced a v5.5.21 array-alignment regression
  that needs deeper investigation — pinned v5.6.23 with proper
  alignment-debug budget. Patra 1.6.0 verified folding cleanly.
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
