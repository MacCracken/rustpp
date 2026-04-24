# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.6.18** (active minor: v5.6.x optimization arc)

## Compiler

- **cc5 (x86_64)**: 501,616 B
- **cc5_aarch64 (cross)**: 382,336 B
- **cc5_win (cross)**: 497,608 B
- **cc5 native aarch64** (Pi 4 self-host): ~453,688 B at v5.6.11
- **Self-host fixpoint**: 3-step (cc5_a → cc5_b → cc5_c, b == c) clean at both
  `IR_ENABLED == 0` and `IR_ENABLED == 3` (since v5.6.16).
- **IR=3 NOP-fill on cc5 self-compile** (v5.6.18): 135 folds + 678 DCE +
  15 DSE + 567 LASE = 1,395 candidates / **6,099 B** in 3 fixed-point
  iterations. Real binary shrinkage waits for v5.6.23 codebuf compaction.

## Suites

- **check.sh**: 22/22 PASS (Linux x86_64 daily-driver + cross-platform skip-stubs)
- **`tests/tcyr/*.tcyr`**: 68 files
- **`fuzz/*.fcyr`**: 5 harnesses
- **`benches/*.bcyr`**: 14 benchmarks
- **Stdlib**: 60 modules (54 first-party + 6 deps via `cyrius deps`:
  sakshi, patra, sigil, yukti, mabda, sankoch)

## In-flight (v5.6.x optimization arc)

- **v5.6.19** — Phase O4: linear-scan register allocation (~600–900 LOC).
- **v5.6.20** — aarch64 fused ops (`madd`/`msub`/`ubfx`/`sbfx`),
  precondition v5.6.19.
- **v5.6.21** — Phase O5: maximal-munch instruction selection (precedes
  RISC-V backend at v5.7.0).
- **v5.6.22** — Phase O6: codebuf compaction (NOP harvest with jump+fixup
  repair). Real binary shrinkage; sweeps all per-pass NOP overhead.
- **v5.6.23–v5.6.25** — consumer-surfaced tooling: `cyrius init` scaffold,
  libro layout corruption, `cc5_win.exe` HIGH_ENTROPY_VA stdin failure.
- **v5.6.26–v5.6.28** — broad-scope platform repair: aarch64 native
  self-host (`_TARGET_MACHO` undef), macOS arm64 Mach-O exit (Sequoia
  dyld drift), PE32+ Windows exit (Win11 24H2 loader drift).
- **v5.6.29** — shared-object emission.
- **v5.6.30** — closeout.

**Long-term considerations (no version pin)**: copy propagation +
cross-BB extended dead-store elimination — both recon-evaluated at
v5.6.18/v5.6.19, both bail (zero direct savings on stack-machine IR;
cross-BB versions need v5.6.19 regalloc liveness data first). See
`roadmap.md §Long-term considerations` for full recon data + revisit
criteria.

## Recent shipped (one-liner per release)

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
