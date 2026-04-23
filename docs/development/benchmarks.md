# Cyrius Compiler Benchmarks

Baseline measurements for the v5.6.x optimization arc (v5.6.5–v5.6.10).
Numbers gathered with `CYRIUS_PROF=1` in-compiler timing (monotonic
clock via `clock_gettime(CLOCK_MONOTONIC)` — syscall 228 on Linux
x86_64, 113 on Linux aarch64) and cross-checked with shell `time`.

Workload: self-host compile (`cc5 < src/main.cyr > /dev/null`). This
is the canonical benchmark because it exercises every phase of the
compiler against its own source — the largest, densest input the
compiler sees in practice. Measured from warm cache (3+ pre-runs
discarded, best-of-5 median reported).

Hardware: Linux 6.18.22-1-lts, x86_64. Precise chip omitted — what
matters is the relative delta between releases on the same machine.

## v5.6.x series — `src/main.cyr` self-host compile

| Release | Median (ms) | Δ vs v5.6.4 | Change |
|---------|-------------|-------------|--------|
| v5.6.4 (pre-O1 baseline) | 409 | — | — |
| v5.6.5 (O1: FNV-1a FINDFN + PROF scaffold) | 402 | −7 ms (−1.7 %) | FNV-1a hash table for fn-name lookup at 0x10C000 (16 KB, 8192 slots, load factor 0.5); open-addressing with linear probing; existing linear-scan fallback preserved for use-alias resolution. |
| v5.6.6 (CYRIUS_PROF cross-platform) | 402 | −7 ms (−1.7 %) | No Linux-path change; adds PE GetTickCount64 + Mach-O libSystem _clock_gettime_nsec_np for cross-platform parity. |
| v5.6.7 (O2 strength reduction: `x * 2^n → shl`) | 405 | −4 ms (−1.0 %) | Compile wall-clock ~flat (peephole check is O(1) at each multiply); **the win is on output-byte count**: cc5 itself shrinks 528,144 → 526,272 B (−1,872 B / −0.35 %) because cyrius hits `imul`-replaceable patterns in its own source. |
| v5.6.8 (O2 flag-reuse + `test rax, rax`) | 355 | −54 ms (−13.2 %) | Biggest single-patch win of the arc so far. Two peepholes combined: (1) `ECONDCMP`'s bare-value path was emitting `push/xor/movca/pop/cmp` (10 B) — replaced with `test rax, rax` (3 B), saving 7 B × every `if (x)` site; (2) `_flags_reflect_rax` tracker skips the `test` entirely when preceding arith already set ZF from rax — another 3 B per site where it fires. cc5 shrinks 526,272 → 504,416 B (−21,856 B / **−4.15 %**). |
| v5.6.9 (O2 redundant push/pop elim) | 355 | −54 ms (−13.2 %) | CP-tracking peephole: `EPUSHR`/`ESPILL` record `_last_push_cp = GCP(S)` after emitting the push; `EPOPR`/`EUNSPILL` check `GCP(S) == _last_push_cp` and rewind CP past the push (x86 −1 B; aarch64 −4 B) if nothing was emitted between the two. Most of the 381 adjacent `50 58` pairs in v5.6.8 came from v5.6.7's strength-reduction helper (`ESPILL; EUNSPILL` around single-identifier LHS subtrees). Wall-clock within noise; **cc5 shrinks 504,416 → 504,000 B (−416 B / −0.082 %)**; 381 `50 58` pairs → 0. aarch64 mirror: `advanced.tcyr` −488 B, `args.tcyr` −328 B. |
| v5.6.10 (O2 commutative combine-shuttle elim) | 360 | −49 ms (−12.0 %) | Scope retargeted from roadmap: `mov + add + add imm → lea` found 0 matches in cc5. The SAME combine path emits a 7-byte shuttle after binary ops: `mov rcx,rax; pop rax; op rax,rcx`. For commutative ops (ADD/AND/OR/XOR/IMUL) replacing with `pop rcx; op rax,rcx` (4 B) saves 3 B per site. Two trackers (`_last_emovca_cp`, `_last_movca_popr_cp`) + `_TRY_COMBINE_SHUTTLE` helper in x86 emit helpers. Wall-clock within noise; **cc5 shrinks 504,000 → 487,040 B (−16,960 B / −3.37 %)** — second-largest single-patch win of v5.6.x. 5861 shuttle sites → 0. Non-commutative SUB/CMP (+ the literal LEA combining originally scheduled) pinned for a later LEA-spirit patch. |

### v5.6.5 finding vs v5.6.4 prediction

The v5.6.5 roadmap entry predicted "10–25 % compile-throughput" from
the FNV-1a hash. Observed: 1.7 %. Actual FINDFN is not the hot path —
the compiler's ~500 fn-count stays in a regime where linear scan +
early-exit STREQ on mismatched prefixes is already fast enough that
the hash lookup's FNV-1a loop + probe comparison doesn't dominate.

Implication for v5.6.6 peephole work: the parse / emit / fixup
phases must be the real time sinks. Per-phase instrumentation (which
v5.6.5 intentionally scoped to just total compile time) is a natural
v5.6.6 refinement if we need to pick between peephole candidates.

The FNV-1a delta IS real and byte-identical-self-host-safe, so v5.6.5
ships it. The 1.7 % number just sets expectations: optimization
predictions are upper bounds, and the O-arc total (10–60 % expected
per roadmap §v5.6.x) should be re-verified patch-by-patch rather
than assumed.

## v5.6.x series — regression.tcyr

Smaller workload (~200 LOC, ~40 fns in scope) for sensitivity check.

| Release | Median (ms) | Δ vs v5.6.4 | Notes |
|---------|-------------|-------------|-------|
| v5.6.4 (pre-O1 baseline) | 53 | — | Dominated by stdlib-include expansion, not compile-core. |
| v5.6.5 (O1: FNV-1a FINDFN) | 51 | −2 ms (−3.8 %) | Slightly better relative scaling — smaller fn count means FINDFN weight is proportionally larger. |

## v5.6.x series — output-byte count on cc5 itself

When a peephole shrinks generated code, the cc5 binary (which is
generated by cyrius compiling its own source) shrinks too. This is
a more stable signal than compile wall-clock.

| Release | cc5 size (B) | Δ vs v5.6.4 | Note |
|---------|--------------|-------------|------|
| v5.6.4 | 525,344 | — | Pre-O1 baseline. |
| v5.6.5 | 526,888 | +1,544 | FNV-1a code added, no generated-output change. |
| v5.6.6 | 528,144 | +2,800 | PE GetTickCount64 + Mach-O __got growth code. |
| v5.6.7 | 526,272 | +928 | Peephole CODE adds ~660 B, but peephole APPLIED to cc5's own compilation saves ~2,540 B, net −1,872 B vs v5.6.6. |
| v5.6.8 | 504,416 | −20,928 | Flag-reuse + `test rax, rax` replaces `push/xor/movca/pop/cmp` dance. New peephole CODE adds ~430 B but saves ~22,280 B when applied to cc5 compiling itself. **Biggest single-patch shrinkage** of v5.6.x so far. |
| v5.6.9 | 504,000 | −21,344 | Redundant push/pop elim. New peephole CODE adds ~346 B but cancels 381 adjacent `push rax; pop rax` pairs in cc5 (762 B), net −416 B. Smaller per-site win than v5.6.8 (2 B vs 7 B), but similar hot-helper targeting: the dance was generated by v5.6.7's strength-reduction helper spilling across single-identifier LHS subtrees where nothing needed preserving. |
| v5.6.10 | 487,040 | −38,304 | Commutative combine-shuttle elim. Replaces `mov rcx,rax; pop rax; op rax,rcx` (7 B) with `pop rcx; op rax,rcx` (4 B) for ADD/AND/OR/XOR/IMUL. 5861 sites (5399 ADD + 340 AND + 66 OR + 3 XOR + 53 IMUL); 17,583 B raw savings minus ~623 B new peephole code = −16,960 B net. Second-largest single-patch shrinkage of v5.6.x (v5.6.8's flag-reuse remains #1 at −21,856 B). Scope retargeted from the originally-slotted LEA combining, which found 0 matches in cc5 output — the real shuttle cost was hiding under what v5.6.8's lesson predicted: hot helpers. |

The v5.6.8 delta is an order of magnitude larger than v5.6.7
because `ECONDCMP` is a hot helper — every `if (x)`, `while (x)`,
`for (; x; ...)`, etc. condition without an explicit comparator
ran through the 10-byte dance. Shrinking that dance to 3 B (or
0 B with flag reuse) cascades across thousands of sites in cc5's
own source.

The v5.6.5 prediction of "10–25 % compile-throughput" has now
partially materialized — v5.6.8 alone delivered −13.2 % compile
time (which also scales the output-bytes win). Future patches
(v5.6.9 move-elim, v5.6.10 LEA combining, v5.6.11 aarch64 fused
ops) measure against the 504 KB / 355 ms baseline.

## 3-step fixpoint verification (new in v5.6.7)

Starting with v5.6.7 (the first patch that modifies generated
bytes), the standard "build cc5; rebuild with cc5; compare" check
doesn't hold across the compiler-upgrade step. The correct pattern
is:

```sh
cat src/main.cyr | build/cc5 > /tmp/cc5_a; chmod +x /tmp/cc5_a
cat src/main.cyr | /tmp/cc5_a > /tmp/cc5_b;  chmod +x /tmp/cc5_b
cat src/main.cyr | /tmp/cc5_b > /tmp/cc5_c
cmp /tmp/cc5_b /tmp/cc5_c   # MUST be byte-identical
```

Steps a→b introduce the optimization; steps b→c are the fixpoint
check. All subsequent O-arc patches should follow this shape.

## Methodology / tooling

### `CYRIUS_PROF=1` environment flag

v5.6.5 adds `CYRIUS_PROF=1` as an opt-in runtime flag. When set,
cc5 records `clock_gettime(CLOCK_MONOTONIC)` at entry (after env
predefines land, before `PREPROCESS`) and again just before
`syscall(SYS_EXIT, 0)`, printing `prof: compile <ms> ms` to stderr.

Usage:

```sh
CYRIUS_PROF=1 build/cc5 < src/main.cyr > /tmp/cc5_out 2> /tmp/cc5.prof
cat /tmp/cc5.prof
# → prof: compile 400 ms
```

Costs when CYRIUS_PROF is unset: one env-var lookup (3 syscalls
against /proc/self/environ, already in init path for other envs) +
a single `load8` comparison. ~µs, unmeasurable in compile-time deltas.

Costs when CYRIUS_PROF=1: add two `clock_gettime` calls (~100 ns
each) + a handful of `syscall(SYS_WRITE)` calls at exit. Also <1 ms.

### Per-phase breakdown — deferred

v5.6.5 reports total compile time only. Per-phase counters (lex /
preprocess / parse / emit / fixup) are a natural extension if a
specific optimization patch needs to choose between candidates by
measured phase weight. Not speculatively added — no current patch
demands it.

### Cross-compiler profiling

`cc5_aarch64` uses syscall 113 (aarch64 Linux generic table number for
`clock_gettime`); x86 uses 228. Windows PE and macOS Mach-O cross
outputs fall through to `return 0` in `_prof_clock_ns` since those
syscall numbers mean something different on those OSes. Profiling
data on PE / Mach-O is not meaningful for v5.6.5 (prints `0 ms`);
shell-level timing (`time cc5_win.exe < ...`) is the recommendation
for those targets until per-target clock wrappers land.

## Notes for v5.6.6 (peephole) and later

- **Don't re-predict 10–25 %** without evidence. The v5.6.5 result
  shows backend-phase cost dominates, not FINDFN. Peephole wins
  should fall on emit-phase bytes, and the measurement should be
  byte-count of generated code rather than (or in addition to)
  compile wall-clock.
- **Add per-phase counters when they pay off.** If v5.6.6's
  strength-reduction / flag-reuse / move-elim produce outputs whose
  size delta is visible but compile-time delta is noisy, split the
  prof dump into `lex / parse / emit / fixup` segments at that point
  and re-measure.
- **Don't measure on a busy host.** Variance between runs is 2–3 %
  even on an idle machine; median-of-5 is the floor for reporting.
