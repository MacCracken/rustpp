# Cyrius Development Roadmap

> **v5.5.40.** cc5 compiler (507,136 B x86_64), x86_64 + aarch64
> cross + Windows PE cross + macOS aarch64 cross. IR + CFG.
> Self-hosts byte-identically on Linux x86_64, Linux aarch64 (Pi
> 4), Windows 11, and macOS arm64.
>
> **v5.5.x (closed, 40 patches)** — longest minor in cyrius
> history. Platform completion: Windows PE end-to-end (native
> self-host, struct-return + variadic + __chkstk, .reloc + ASLR),
> Apple Silicon toolchain completion (libSystem imports, argv via
> x28), aarch64 Linux shakedown + threading atomics, NSS/PAM
> end-to-end (musl-style `lib/pwd.cyr` + `lib/grp.cyr` +
> `lib/shadow.cyr` + `lib/pam.cyr`, `lib/fdlopen.cyr` foreign-
> dlopen), parser/lexer refactor via nested includes, legacy cc3
> retirement. Full per-patch summary lives in
> [completed-phases.md](completed-phases.md) and CHANGELOG.
>
> **What's next (v5.6.x–v5.12.x):**
> - **v5.6.0–v5.6.3**: small language polish — `#else`/`#elif`
>   preprocessor, explicit overflow operators (`+%`/`+|`/`+?`),
>   `#must_use` + `@unsafe` attributes, `#deprecated` attribute.
> - **v5.6.4–v5.6.9**: compiler-optimization arc (O1 instrumentation
>   + FNV-1a, O2 peephole, O3 IR-driven passes, O4 linear-scan
>   regalloc, O5 maximal-munch, O6 slab allocator — measurement-
>   gated, may skip).
> - **v5.6.10**: v5.6.x closeout + downstream ecosystem sweep gate
>   (agnos, kybernet, argonaut, agnosys, sigil, ark, nous, zugot,
>   agnova, takumi).
> - **v5.6.11**: shared-object (.so / .dll / .dylib) emission
>   completion.
> - **v5.7.0**: RISC-V rv64 port (inherits optimized compiler).
> - **v5.8.0**: bare-metal / AGNOS kernel target.
> - **v5.9.0–v5.9.7**: pure-cyrius TLS 1.3 arc + medium language
>   additions — first-class slices (`slice<T>` / `[T]`
>   generalizing `Str`) and per-fn effect annotations (`#pure`,
>   `#io`, `#alloc`) land first so TLS code adopts them; then
>   X25519 + ChaCha20-Poly1305 + record layer + handshake, retires
>   the `libssl.so.3` dynlib bridge.
> - **v5.10.x**: tagged unions (algebraic data types) +
>   exhaustive pattern match — own minor. Biggest single-
>   ergonomics language addition of the v5.x line.
> - **v5.11.x**: `Result<T,E>` + `?` propagation operator — own
>   minor, depends on v5.10 ADTs. Replaces -1/0/errno convention
>   across stdlib.
> - **v5.12.x**: allocators-as-parameter convention (Zig-style)
>   — own minor. Every allocating fn takes `Allocator`; failing
>   allocator harness falls out; retires `alloc_init()` global
>   singleton.
>
> aarch64 port remains fully online (`regression.tcyr` 102/102 on
> real Pi, native `cc5` self-hosts byte-identical, per-arch asm
> via `#ifdef CYRIUS_ARCH_{X86,AARCH64}` from v5.3.16). Apple
> Silicon Mach-O self-hosts byte-identically on M-series.
>
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5. Closure verified.
> **78+ test suites**, 14 benchmarks, 5 fuzz harnesses. **65 stdlib modules** (includes 6 deps).
> Caps: ident buffer 128KB, fn table 4096, fixup table 32768 (v5.5.37).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | Localized with `CYRIUS_SYMS`. Classic memory corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG now available for diagnosis (5.0.0 IR). Note: ark cyml_parse crash (SA-002) was NOT this bug — was calling wrong function signature (nous.cyr 1-arg vs cyml.cyr 2-arg). |
| HIGH_ENTROPY_VA deterministic cc5_win.exe stdin failure | Windows 11 64-bit ASLR | Investigation at v5.5.35: all 2043 MOVABS sites audited, 264 uncovered are data constants not pointers; simple programs work but cc5_win.exe stdin-read fails 5/5 under 64-bit ASLR. Root cause unknown. Shipping with 32-bit ASLR (DYNAMIC_BASE) only. Re-investigate in v5.6.x. |
| parse.cyr unguarded x86 emit sites | aarch64 cross-build correctness | v5.5.40 added aarch64 guard around `EB()` in `parse_fn.cyr`. Remaining direct-emit x86 paths in other parse_*.cyr files need the same guard-and-dispatch treatment. Pinned for v5.6.x cleanup (see §"v5.x — Language Refinements"). |

For shipped work see [CHANGELOG.md](../../CHANGELOG.md) (source of
truth) and the high-level phase summaries in
[completed-phases.md](completed-phases.md).

---

## v5.3.x / v5.4.x / v5.5.x — shipped

All detailed per-patch entries for v5.4.x (Windows PE foundation
arc) and v5.5.x (platform completion minor, 40 patches) have been
moved to [completed-phases.md](completed-phases.md). CHANGELOG
remains the source of truth.

v5.3.x "open items" (libro memory corruption, aarch64 x86-asm
leakage residue) were either closed during v5.5.x or moved to the
Active Bugs table above.

---

## v5.6.x — Language polish + compiler optimization + shared-object

The v5.6.x minor bundles three independent-but-related arcs
before v5.7.0 RISC-V opens:

1. **v5.6.0–v5.6.3 — Small language polish.** Four single-patch
   additions that remove long-standing friction. Each is
   isolated, low-risk, and self-contained.
2. **v5.6.4–v5.6.9 — Compiler optimization arc (O1–O6).** The
   pinned optimization phases. Lands BEFORE RISC-V so the new
   port inherits an optimized compiler.
3. **v5.6.10–v5.6.11 — Closeout + shared-object.** Downstream
   gate, then the long-deferred `.so` emission fix.

**Pinned to concrete patch numbers** (per the
`feedback_pin_optimizations` discipline): small items ship
first because they're cheap, polish the language surface
before optimization touches backends, and give a quick-win
baseline before the bigger investments.

### v5.6.0 — `#else` / `#elif` preprocessor directives

Currently every stdlib OS/arch selector writes paired
`#ifdef CYRIUS_TARGET_LINUX` / `#ifdef CYRIUS_TARGET_WIN`
blocks because the preprocessor has `#ifdef` + `#endif` but
no `#else` or `#elif`. v5.4.19 shipped `#ifplat` which
helped, but the general conditional family is still absent.

**Scope:**
- Lex `#else` (existing-token repurpose if feasible), `#elif`,
  `#ifndef` in `src/frontend/lex_pp.cyr`.
- Extend `PP_IFDEF_PASS` state machine to track nesting depth
  and branch-taken status.
- Update stdlib selectors (`lib/syscalls.cyr`, `lib/alloc.cyr`,
  `lib/io.cyr`, `lib/args.cyr`, the per-arch dispatch in
  parse.cyr) to use the cleaner form.

**Gate:** existing paired `#ifdef` sites still compile
byte-identical; new form produces identical tokenstream.
Regression test: single module using all three forms.

**Tradeoff:** parser change; zero semantic risk. Small win
per site, large win in aggregate across 60+ stdlib files.

### v5.6.1 — Explicit overflow operators

50 years of C-family overflow UB / wrap-around footguns end
here. Zig's pattern is proven: three explicit operators +
keep bare `+` defined in release.

**Scope:**
- Lex `+%` / `-%` / `*%` (wrapping), `+|` / `-|` / `*|`
  (saturating), `+?` / `-?` / `*?` (checked — returns 0 or
  panics on overflow, TBD at impl time).
- Backend emit: wrapping = current bare-add encoding,
  saturating = conditional-move on overflow flag, checked =
  `jo panic` (x86) / `cbnz` (aarch64) after the arithmetic.
- Bare `+` stays as-is (defined wrap semantics in release, may
  warn in `--strict` mode).

**Gate:** `tests/tcyr/overflow_ops.tcyr` with all nine
operators across u32/i32/u64/i64 boundary cases (MAX,
MIN, MAX+1, MIN-1, product overflow).

**Tradeoff:** new lexer tokens (9 new op-tokens) + 3 opcodes
per backend. Self-contained.

### v5.6.2 — `#must_use` + `@unsafe` attributes

Two compiler-enforced annotations. `#must_use` on a fn
declaration makes unused-result a hard error at call sites —
kills the pervasive silent `-1` ignore. `@unsafe` marks a
block or fn as crossing a memory/FFI boundary; requires an
explicit acknowledgment comment or `unsafe { ... }` scope.

**Scope:**
- Parse `#must_use` as a fn-level decorator (mirrors
  `#derive(accessors)` shape).
- Parse `@unsafe` as a block-form keyword or fn-level
  decorator. Specific syntax TBD but aligned with existing
  `secret var` shape for consistency.
- Emit a diagnostic when a `#must_use` fn's result is
  discarded (not assigned, not used in expression context,
  not in a discard-explicitly form TBD — likely `_ = foo();`).
- `@unsafe` is advisory in v5.6.2 (warning if nested unsafe
  blocks exist; no runtime cost). Future hardening passes
  can tighten later.

**Gate:** attribute parsing regression + fn-marked-`#must_use`
sample whose result is dropped triggers the expected error.

**Tradeoff:** tiny parser addition + one diagnostic pass.
Enables stdlib to annotate `read`/`write`/`alloc` etc. —
catches real bugs.

### v5.6.3 — `#deprecated("reason / replacement")` attribute

Forces deprecation into the type system instead of
ecosystem-wide grep sweeps. Pays dividends at v6.0.0 when we
rename `cc5` → `cyc` — downstream consumers see
deprecations in their CI without needing to chase them.

**Scope:**
- Parse `#deprecated("use foo since v5.X")` as a fn-level
  decorator.
- Emit a compile-time warning (or hard-error under
  `--strict`) when a deprecated fn is called.
- Bundle with `#must_use` attribute pass (same diagnostic
  infrastructure from v5.6.2).

**Gate:** `tests/tcyr/deprecated.tcyr` — calling a
`#deprecated` fn triggers warning; `--strict` promotes it to
error.

**Tradeoff:** one decorator + one diagnostic site. Small.

---

## v5.6.x — Compiler optimization arc (v5.6.4–v5.6.9)

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
- No SCCP / GVN / polyhedral (out of scope for a ~500 KB compiler).
- No PEXT/PDEP/BMI2 opportunistic (pre-Haswell portability trap).
- No multi-arena heap restructuring (the 21.5 MB flat heap map is
  auditable state; lifetime partitioning is already static).

**Ordering constraints** (why the patches can't reorder):
- O1 first — without baseline numbers, quantitative claims for
  O2–O6 are vibes.
- O3 before O4 — linear-scan needs complete IR coverage.
- O6 gated on O4 — slab only matters if O4 profiling shows
  bump-alloc hot.

### v5.6.4 — Phase O1: instrumentation + FNV-1a symbol table

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

### v5.6.5 — Phase O2: peephole quick wins (x86_64 + aarch64)

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

### v5.6.6 — Phase O3: IR-driven passes

Builds on the existing LASE / DBE / CFG infrastructure. ~590 LOC.

- **Precondition**: finish IR instrumentation across the
  remaining ~50 direct emit sites (`EB` / `E2` / `E3` calls in
  `src/frontend/parse*.cyr`). Without this, LASE codebuf patching
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

### v5.6.7 — Phase O4: linear-scan register allocation

The big investment. Replaces today's peephole `#regalloc`.
~600–900 LOC.

- Sort live intervals by start point; greedy assignment with
  spill heuristic = furthest next use (Poletto & Sarkar).
  Covers: live-range build, active-set management, spill slot
  assignment, parallel-move resolution at block boundaries.
- **Determinism guard**: keep hint-based preferences but skip
  iterated coalescing — byte-identical self-host must hold.
- **Depends on v5.6.6's completed IR coverage** (live ranges
  need every def and use to be in IR).
- Expected output-code speedup: 2–3× over current stack-machine
  baseline on hot inner loops; 10–20 % quality gap vs.
  graph-coloring at a fraction of the code.

### v5.6.8 — Phase O5: maximal-munch instruction selection

~300–500 LOC.

- Formalize existing ad-hoc tile patterns (mem-operand `add`/`sub`
  on x86_64, aarch64 addressing modes) into a tile pattern
  database per backend. Walker traverses IR tree bottom-up,
  matching largest subtree to a single machine instruction.
- Opens the door for target-specific tiles (RISC-V v5.7.0) without
  touching the walker — v5.6.8 therefore SHIPS BEFORE v5.7.0 so
  the rv64 backend can land its tile table on day one instead of
  retrofitting.

### v5.6.9 — Phase O6: slab allocator for IR pools (measurement-gated)

~150 LOC. **Conditional release** — only ships if v5.6.7's profile
shows bump-allocation hot during live-range construction. If the
O4 benchmark says bump is fine, v5.6.9 is **explicitly skipped**
and the v5.6.x closeout ships at v5.6.9 directly (see below).

- `vidya/content/allocators` documents 20–30× speedup over bump
  for fixed-size churn. Applied to IR node pools during live-
  range build.
- If skipped, record the skip decision in CHANGELOG with the
  specific O4 bench numbers that triggered it.

### v5.6.10 — v5.6.x closeout (or v5.6.9 if O6 skipped)

Last patch before v5.6.11 (shared-object) and eventually
v5.7.0 (RISC-V). CLAUDE.md "Closeout Pass" 11-step checklist:
self-host verify, bootstrap closure, full check.sh, heap-map
audit, dead-code audit, refactor pass, code-review pass,
cleanup sweep, security re-scan, downstream dep-pointer check,
CHANGELOG/roadmap/vidya sync.

**Downstream gate.** This closeout is the opening signal for
genesis repo Phase 13B (arch-neutral boot pipeline —
`scripts/boot.cyr`, ISO Stages 1–4, `bootstrap-toolchain.sh`,
`build-order.txt`) and the ecosystem arch-neutral sweep: must-touch
(agnos, kybernet, argonaut, agnosys, sigil), should-touch (ark,
nous, zugot, agnova, takumi), may-touch (phylax, shakti,
ai-hwaccel, seema). All of them wait on v5.6.6 and must complete
before v5.7.0 RISC-V opens. Practical consequence: the closeout
carries extra rigor beyond the standard pass —

- **Heap-map cleanup** — not just verify; actively collapse any
  orphan allocations surfaced during the optimization arc. Leave
  no "temporary" arenas downstream would have to work around.
- **Refactor pass** — one targeted sweep for naming/API drift
  introduced across v5.6.0–v5.6.9. If a public function got
  reshaped mid-arc, this is the last chance to stabilize the name
  before downstream repos pin to it.
- **Audit pass** — dead code, stale comments, orphan tests,
  unused `#include` lines. Downstream sees this as the baseline
  they mirror in their own sweeps.
- **Downstream dep-pointer check** — walk every downstream repo's
  `cyrius.toml` / `cyrius.cyml` and verify they resolve cleanly
  against the v5.6.10 artifacts. Broken pins get fixed before
  v5.7.0 opens, not after.
- **Compiler surface freeze signal** — after v5.6.10 ships, public
  compiler API is frozen for the duration of the downstream sweep
  (approximately one minor cycle). v5.7.0 RISC-V can add, but not
  reshape, existing surface.

Rationale: downstream projects are batching their own arch-neutral
work against this closeout. If v5.6.10 ships with loose ends, each
downstream repo absorbs the cost and the sweep fragments. One
tight closeout here is cheaper than N downstream workarounds.

---

### v5.6.11 — Shared-object emission completion

Finish the `.so` path that has existed in partial form since v2.x
(`src/backend/x86/fixup.cyr` has `SYSV_HASH` + `EMITELF_SHARED`,
triggered on `kernel_mode == 2`). The hash-table emission isn't
wired up correctly — `EMITELF_SHARED` skips calling `SYSV_HASH`
when populating the `.hash` section chain. Surface was surfaced
during the v5.5.40 closeout dead-code audit: `SYSV_HASH` appears
as unreachable across every entry point, but the comment at its
definition explicitly says "Kept even though nbucket=1 makes the
hash irrelevant for bucket selection — chain lookup needs hash
comparison to pick the right entry." Either hash lookup against
this cyrius-emitted `.so` fails at load time, or the field is
tolerantly ignored by modern glibc — we haven't tested.

**Scope:**

* Audit `EMITELF_SHARED`'s `.hash` / `.dynsym` / `.dynamic`
  emission against `ld-linux.so.2`'s expectations; wire `SYSV_HASH`
  where currently skipped.
* Add a regression test that builds a trivial `.so` via `kmode=2`
  (shared object mode), `dlopen`s it from a C host, resolves one
  symbol, compares the returned value. The test requires runtime
  `libc.so` interop so it's gated behind `HOST_HAS_LD_LINUX`.
* Confirm the `.gnu.hash` alternative isn't more appropriate
  today (modern linkers prefer it). If so, migrate and drop
  `SYSV_HASH` cleanly.

**Why this slot:** not blocking any active consumer, but the
partial state is a known audit rough edge. v5.6.10 closeout
surfaces the floor; v5.6.11 actually lands the fix before v5.7.0
opens RISC-V work. An alternate fit is v5.8.1 post-bare-metal,
but bare-metal doesn't exercise `.so` emission (kernel is static
all the way down), so slotting earlier is fine and clears the
audit item ahead of the downstream arch-neutral sweep.

**Downstream:** no current consumer requires `.so` output. Sigil /
mabda / yukti / kybernet all ship as static libraries or source
bundles. Unblocks any future "cyrius stdlib available as system
libc peer" work, which isn't on the roadmap yet.

---

## Sigil 3.0 enablers — remaining

Downstream `sigil` items the Cyrius toolchain still owes. Shipped
enablers (`ct_select` v5.3.2, `mulh64` v5.3.3, `secret var` v5.3.5,
`lib/keccak.cyr` v5.4.15, SSE m128 alignment fix v5.5.21 unblocking
AES-NI, fixup cap raise v5.5.37 unblocking sigil 3.0 parallel batch)
are in CHANGELOG.

The remaining sigil-side prerequisite for the pure-cyrius TLS 1.3
arc (v5.9.0+) is X25519. That's a sigil-internal addition; the
toolchain side is unblocked.

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
- **v5.6.4–5.6.9** — Compiler optimization arc. New port should
  inherit an optimized compiler, not one still queueing baseline
  optimization. v5.6.8 (maximal-munch) in particular matters —
  rv64 backend lands its tile table against the new walker on
  day one instead of retrofitting.
- **v5.6.10** — downstream ecosystem sweep gate complete.
- **v5.6.11** — shared-object emission landed (audit rough edge
  closed before new port opens).
- **v5.4.19 `#ifplat`** direction is live → RISC-V dispatch
  uses the new syntax from day one, no legacy `#ifdef
  CYRIUS_ARCH_RISCV64` sites to migrate.

Deliberately NOT bundling other items into v5.7.0 — a new
architecture port is plenty of work on its own, and mixing it
with runtime correctness fixes would obscure which changes
caused which regressions.

---

## v5.8.0 — Bare-metal / AGNOS kernel target

Bare-metal output (no libc, no syscalls, direct hardware). AGNOS
kernel is the concrete consumer. Slid with the optimization minor
insert (was v5.7.0 pre-v5.6.x pin). Details pinned closer to
landing — rough scope: ELF no-libc output format, interrupt-handler
emit conventions, kernel-mode syscall stubs stripped, boot pipeline
from `scripts/boot.cyr` landed in genesis Phase 13B (v5.6.6 gate).

---

## v5.9.0 — Pure-cyrius TLS 1.3 arc + medium language additions

Dedicated minor for (1) two medium language additions that
generalize patterns the TLS code would otherwise re-invent, and
(2) a pure-cyrius TLS 1.3 client + record layer replacing the
current `lib/tls.cyr` `libssl.so.3` dynlib bridge. The language
items land first so TLS code adopts them natively — they're not
post-hoc retrofits.

Slotted **after bare-metal (v5.8.0)** because the AGNOS kernel
target is the concrete consumer that needs this — bare-metal
can't `dlopen` libssl, so the sovereign-crypto story is a
prerequisite for secure networking in the kernel arc. **Pinned
to concrete patch numbers** so it can't drift into a "parallel
track" again (same discipline as O1–O6).

**Why this, why now:**

- `lib/tls.cyr` today is a thin shim over `libssl.so.3` via
  `lib/dynlib.cyr`. Works for userspace Linux targets that have
  OpenSSL installed, breaks the sovereign story (toolchain
  depends on a non-Cyrius crypto library), and **cannot run on
  bare-metal** (no dlopen, no libc). Any AGNOS kernel component
  that talks TLS (remote logging, update fetch, attestation)
  needs pure-cyrius crypto.
- `sigil` already ships the symmetric primitives (SHA-256/512,
  HMAC, HKDF, SHAKE-128/256, Ed25519, AES-NI fast-path via
  v5.5.21's SSE m128 alignment fix). What's missing for TLS 1.3
  is X25519 ECDH, ChaCha20-Poly1305 AEAD, and the TLS 1.3 record
  layer + handshake state machine.
- Cleanest shape is a dedicated multi-patch minor rather than
  squeezing into v5.8.x (bare-metal is already a large arc).

**Pinned sub-patches:**

- **v5.9.0** — **First-class slices** (`slice<T>` / `[T]`
  generalizing `Str`). A type carrying `(ptr, len)` with
  bounds-aware APIs. Every `read(buf, len)` /
  `memcpy(dst, src, n)` / `aead_encrypt(pt, pt_len, ct, ct_len,
  tag)` today is a ptr+len pair the compiler doesn't check —
  slices make bounds-aware APIs the default. Lands first so the
  TLS record layer + handshake use slices natively rather than
  ptr+len. Scope: lex `[T]` in type positions, parse slice
  literals and indexing, stdlib migration (`Str` → concrete
  instance of `slice<u8>`, `vec` / `hashmap` slice getters).
  Tradeoff: ecosystem-wide rebuild; pays for itself in every
  crypto/network fn that handles buffers.
- **v5.9.1** — **Per-fn effect/purity annotations** — `#pure`,
  `#io`, `#alloc` as compiler-checked tags. Catches helpers that
  silently allocate or touch I/O in "pure" crypto paths.
  Simpler than OCaml5 / Koka effects (no polymorphism, no row
  types) — just three decorators the compiler enforces.
  Annotate `lib/keccak.cyr`, X25519, AEAD as `#pure` so the
  compiler catches any accidental allocation regression.
  Tradeoff: annotation ramp; stdlib + sigil annotated
  gradually; no runtime cost.
- **v5.9.2** — X25519 scalar multiplication in pure cyrius.
  Curve25519 Montgomery ladder over GF(2^255 - 19). ~300 LoC,
  NIST/IETF test-vector gate. Lands in `sigil` first, re-exposed
  to stdlib via dep bump. Uses `slice<u8>` (v5.9.0) for key
  material; annotated `#pure` (v5.9.1).
- **v5.9.3** — ChaCha20 + Poly1305 + ChaCha20-Poly1305 AEAD.
  RFC 8439 test vectors. Constant-time primitives use `secret
  var` + `lib/ct.cyr` (shipped v5.3.5). `sigil` addition. Slice-
  based buffer API; `#pure` annotated.
- **v5.9.4** — `lib/tls.cyr` record layer: TLSPlaintext /
  TLSInnerPlaintext / TLSCiphertext shapes, AEAD wrap/unwrap,
  key schedule (HKDF-Expand-Label via sigil HKDF from v5.4.15).
  No handshake yet — record layer first so it can be tested in
  isolation against a recorded session transcript. Slice-based
  I/O boundary.
- **v5.9.5** — `lib/tls.cyr` handshake state machine: ClientHello
  / ServerHello / EncryptedExtensions / Certificate / CertificateVerify
  / Finished. X25519 key share only (no RSA, no secp256r1 in v1
  — ship-scope narrowing; can add curves later if a consumer
  needs them). Ed25519 cert verification via sigil.
- **v5.9.6** — Retire the `libssl.so.3` dynlib bridge from
  `lib/tls.cyr`. Consumer migration: any tool using `tls_*` APIs
  picks up the pure-cyrius implementation with zero source
  change. `lib/dynlib.cyr` retains the generic `.so` loading
  primitives — only the TLS-specific bridge gets removed.
- **v5.9.7** — v5.9.x closeout (CLAUDE.md §"Closeout Pass").
  Benchmark vs libssl baseline (expect ~2× slower handshakes,
  within 10% of libssl on bulk AEAD throughput once AVX2 is
  added in a later minor), security audit focused on timing
  side-channels + constant-time assertions, heap-map review
  (TLS session state is a new region), downstream ecosystem
  bump.

**Acceptance gates (per patch):**

1. Each patch self-contained: test vectors PASS, self-host
   byte-identical, no cross-patch dependencies that require the
   minor to land as a batch.
2. v5.9.0 gate: `slice<T>` regression test — ptr+len round-trip,
   bounds check on out-of-range index, `Str` still byte-
   identical as a slice specialization.
3. v5.9.1 gate: `#pure` fn that calls `alloc()` fails
   compilation; `#io` fn that's declared pure is diagnosed.
4. v5.9.5 gate: handshake succeeds against `google.com:443` and
   `github.com:443` via real TLS 1.3 (pure-cyrius client,
   real-world server).
5. v5.9.6 gate: `cyrius deps` of any consumer previously using
   `lib/tls.cyr` builds clean with the libssl bridge removed.
6. v5.9.7 gate: full benchmark + security re-scan checklist.

**Out of scope** (pin to v5.10.x or later if demand surfaces):

- TLS server (listener side) — consumer demand not yet present;
  AGNOS kernel talks outbound, not inbound.
- Older protocol versions (TLS 1.0, 1.1, 1.2). TLS 1.3 is the
  only version worth implementing in 2026+. Consumers needing
  legacy can fork.
- QUIC / HTTP/3 — separate protocol, separate minor.
- secp256r1 / secp384r1 / RSA key exchange — X25519 covers the
  modern cert / key-share path. If a legacy server needs
  secp256r1, add later.
- Post-quantum hybrid key-share (X25519+Kyber) — pinned to a
  future `sigil` PQC release; TLS arc lands classical crypto
  first, adds hybrid later without breaking API.

**Prerequisite:** `sigil` X25519 primitive lands as the sigil-side
gate before v5.9.0 opens.

**Downstream coordination:** AGNOS kernel + any consumer binary
that talks TLS (argonaut sync, ark package fetch, future shakti
remote-auth paths) picks up the swap transparently at v5.9.6.
No API break — the current `tls_connect` / `tls_read` /
`tls_write` / `tls_close` shape ports 1:1 to the pure-cyrius
backend.

---

## v5.10.x — Tagged unions + exhaustive pattern match

Own minor for algebraic data types. The single biggest language-
ergonomics addition of the v5.x line — every ad-hoc `int tag;
union { ... }` struct pattern across IR walkers, NSS-strategy
dispatch, fdlopen result codes, parser state machines, and
hashmap key-typing folds into first-class sum types. Pinned to
concrete patch numbers so it can't drift; slotted **after
v5.9.x** because the TLS arc closes the last platform-runtime
gap before language-surface evolution opens.

**Why this, why now:**

- `Result<T,E>` + `?` propagation (v5.11.x) requires sum types.
  Can't ship ergonomic error handling without this foundation.
- Every stdlib module that returns `(value, tag)` pairs —
  `hashmap.key_type` field, `dynlib` result codes, `json`/`toml`
  parse results — would collapse to a single `enum`.
- Exhaustive-check gives the compiler another correctness
  surface: adding a new variant forces every call-site `switch`
  to handle it or be explicit about `_ =>`.

**Pinned sub-patches:**

- **v5.10.0** — Sum-type syntax + constructor parsing. Likely
  `enum Result<T,E> { Ok(T), Err(E) }` or cyrius-flavored
  equivalent. Concrete syntax TBD at design time — aligned with
  existing `enum` / `struct` shape so lex / parse reuses
  existing infrastructure where possible.
- **v5.10.1** — Exhaustive pattern match in `switch`. Compiler
  verifies every variant is covered; missing variants → error;
  `_ =>` explicitly opts out.
- **v5.10.2** — Stdlib adoption pass 1: collapse ad-hoc tag+
  union patterns (hashmap `key_type`, dynlib error codes, json/
  toml parse state) into sum types. No API breakage yet —
  internal representation swap.
- **v5.10.3** — Stdlib adoption pass 2: public API migration
  for modules where the sum-typed form is visibly better (parse
  results, cross-boundary error returns).
- **v5.10.4** — v5.10.x closeout. Downstream dep-pointer check
  (sigil, mabda, yukti, kybernet, etc.) since the stdlib surface
  shifted. Full 11-step closeout.

**Acceptance gates:**

1. Byte-identical self-host at every patch.
2. v5.10.1 gate: `tests/tcyr/exhaustive_match.tcyr` — missing
   variant → compile error; `_ =>` accepted; added variant
   triggers diagnostic at every uncovered site.
3. v5.10.2 gate: `cyrius audit` passes with internal-migration-
   only changes visible.
4. v5.10.4 gate: every downstream consumer builds against the
   new stdlib without code changes or explicit migration notes
   where changes are required.

**Out of scope:** GADTs, higher-kinded types, type-level
computation. Keep the feature surface boringly orthogonal.

---

## v5.11.x — `Result<T,E>` + `?` propagation operator

Own minor, depends on v5.10.x sum types. Replaces the -1/0/
errno convention pervasive in stdlib with compiler-enforced
error handling.

**Why this, why now:**

- Every stdlib I/O / parse / syscall wrapper today returns -1
  on error with the caller checking (or silently ignoring —
  exactly what `#must_use` in v5.6.2 was designed to catch).
  `Result<T, Error>` makes the error value compiler-visible.
- `?` operator ergonomic: `var x = foo()?;` short-circuits on
  `Err`, unwraps `Ok`. Half the length of error-checking code
  in practice.
- Slots naturally after v5.10.x — the foundation is built,
  now use it.

**Pinned sub-patches:**

- **v5.11.0** — `Result<T,E>` type in stdlib. `lib/result.cyr`.
  Convenience constructors `Ok(v)` / `Err(e)`; pattern-match
  consumers. Use v5.10.x sum types directly.
- **v5.11.1** — `?` propagation operator. Parses as postfix
  operator on `Result`-typed expressions; desugars to
  pattern-match `Err` early-return. Requires the enclosing fn
  to also return `Result`.
- **v5.11.2** — Stdlib migration pass 1: `lib/io.cyr` (file_
  open / read / write), `lib/syscalls.cyr` wrappers, `lib/json.cyr`
  + `lib/toml.cyr` + `lib/cyml.cyr` parsers. Ad-hoc -1 return
  convention → `Result<T, IoError>` or similar per-module error
  types.
- **v5.11.3** — Stdlib migration pass 2: `lib/net.cyr`,
  `lib/http.cyr`, `lib/dynlib.cyr`, NSS identity modules
  (`lib/pwd.cyr` / `lib/grp.cyr` / `lib/shadow.cyr` /
  `lib/pam.cyr`). These modules had the most elaborate
  error-code conventions — cleanest win.
- **v5.11.4** — v5.11.x closeout. Full 11-step + downstream
  migration sweep.

**Acceptance gates:**

1. Byte-identical self-host at every patch.
2. v5.11.1 gate: `tests/tcyr/result_propagation.tcyr` — `?` on
   `Err` short-circuits; on `Ok` unwraps; used outside a
   `Result`-returning fn is a type error.
3. v5.11.3 gate: cross-repo downstream smoke test — sigil,
   mabda, yukti, ark compile against migrated stdlib.

**Migration policy:** modules migrate one at a time. `-1`-
return fns stay callable from non-migrated call sites through
v5.11.x. v6.0.0 closeout is when the old convention is fully
removed.

---

## v5.12.x — Allocators-as-parameter convention

Own minor. The largest ecosystem-churn item of the v5.x line
and the biggest modern-systems-language insight to absorb
(Zig's contribution). Every allocating fn takes an `Allocator`;
global `alloc_init()` singleton retires; per-request arenas
fall out naturally; failing-allocator test harness becomes a
one-liner.

**Why this, why now:**

- Current `alloc()` is a singleton bump allocator. Tests that
  want to verify OOM handling can't inject a failing allocator
  without global mutation.
- Per-request arenas (HTTP server, compiler passes, parser
  state) would drastically simplify lifetime management — but
  only if fns can accept an allocator parameter.
- Slotted last in the v5.x line because this ripples through
  every stdlib module that allocates. Rippling through after
  sum types + Result lands means the migration can use
  `Result<T, AllocError>` for failure returns — cleaner than
  doing it before v5.11.x.

**Pinned sub-patches:**

- **v5.12.0** — `Allocator` interface in `lib/alloc.cyr`.
  vtable shape: `alloc`, `realloc`, `free`, `reset`. Default
  implementations: `bump_allocator` (current behavior,
  process-global singleton), `arena_allocator` (scoped),
  `test_allocator` (tracks every allocation, fails on demand).
- **v5.12.1** — Failing-allocator test harness. `lib/assert.cyr`
  extension: `fail_after_n_allocs(n)` helper. Enables
  `tests/tcyr/oom_handling.tcyr` coverage for stdlib modules.
- **v5.12.2** — Stdlib migration pass 1 core modules:
  `lib/vec.cyr`, `lib/str.cyr`, `lib/hashmap.cyr`. Pass
  `Allocator` as first argument; default-allocator wrapper
  preserves current call-sites during migration.
- **v5.12.3** — Stdlib migration pass 2 peripheral modules:
  `lib/json.cyr`, `lib/toml.cyr`, `lib/cyml.cyr`, `lib/http.cyr`,
  `lib/http_server.cyr`. These benefit most from per-request
  arenas.
- **v5.12.4** — Retire `alloc_init()` global singleton.
  Backward compat through a default-allocator shim available as
  `lib/alloc.default()` for consumers not ready to migrate.
- **v5.12.5** — v5.12.x closeout. Downstream ecosystem sweep
  (every repo's allocator usage audited).

**Acceptance gates:**

1. Byte-identical self-host at every patch.
2. v5.12.1 gate: `tests/tcyr/oom_vec_push.tcyr` — `vec_push`
   gracefully returns `Err(OutOfMemory)` under `fail_after_n_
   allocs(1)`.
3. v5.12.4 gate: every internal compiler path uses an explicit
   allocator; `alloc_init()` returns the default-allocator shim
   for one more minor before removal at v6.0.0.

**Migration policy:** allocator parameter is opt-in during
v5.12.x. Default-allocator wrapper preserves existing
`vec_push(v, x)` shape as `vec_push(default_alloc(), v, x)`
syntactic sugar. v6.0.0 closeout is when the default-allocator
shim is removed and every fn requires explicit allocator.

**Why this is the last v5.x minor:** after v5.12.x closes, the
language has sum types, exhaustive match, Result+?, allocator-
parameter convention, slices, effect annotations, overflow
operators, `#must_use` / `#deprecated`. The surface is stable.
v6.0.0 opens with the `cc5` → `cyc` rename + the cleanup
sweep that's been accruing debt across the v5.x line.

---

## v5.x — Platform Targets

Each platform is one minor release. cc5 backend-table dispatch
enables adding new targets without touching the frontend.

| Release | Platform | Format | Status |
|---------|----------|--------|--------|
| **v5.1.0** | macOS x86_64 | Mach-O | **Done** |
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Done** — self-hosts byte-identically on M-series |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Done** — byte-identical native self-host on real Win11 |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | **Done** — all 4 cyrius tool binaries do real work on `ssh ecb` |
| **v5.5.18–v5.5.22** | aarch64 Linux shakedown + SSE alignment | ELF | **Done** — multi-thread + contended mutex on real Pi 4 |
| **v5.5.34** | fdlopen foreign-dlopen completion | ELF | **Done** — 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` |
| **v5.5.35** | Windows PE .reloc + 32-bit ASLR | PE/COFF | **Done** — `DYNAMIC_BASE` DLL Characteristic; HIGH_ENTROPY_VA deferred (see Active Bugs) |
| **v5.5.36** | Windows Win64 ABI completion | PE/COFF | **Done** — struct-return via hidden RCX retptr + __chkstk via R11 + variadic float dup |
| **v5.7.0** | RISC-V rv64 | ELF | Queued (slid from v5.6.0 so optimization minor lands first) |
| **v5.8.0** | Bare-metal | ELF (no-libc) | Queued — AGNOS kernel target |
| **v5.9.0–5.9.5** | Pure-cyrius TLS 1.3 | — | Queued — X25519 + ChaCha20-Poly1305 + record layer + handshake; retires the `libssl.so.3` dynlib bridge |

---

## v5.x — Toolchain Quality

| Feature | Effort | Description |
|---------|--------|-------------|
| `cyrius api-surface` | Medium | Snapshot-based API surface diffing. Scans `fn` declarations, tracks `mod::name/arity`, diffs against committed snapshot. Catches breaking removals/renames, allows additions. Pattern from agnosys `scripts/check-api-surface.sh`. |
| `cyrius api-surface --update` | Low | Regenerate snapshot after intentional API bump. |
| CI template with api-surface gate | Low | Standard downstream CI step: `cyrius api-surface` fails on breakage. |
| LSP semantic-tokens polish | Medium | Basic color-coding shipped. Extend to cross-file symbol resolution + go-to-def. |

---

## v5.x — Language Refinements

**Pinned arc** (2026-04-22):

| Feature | Pinned | Effort |
|---------|--------|--------|
| `#else` / `#elif` / `#ifndef` preprocessor | **v5.6.0** | Small |
| Explicit overflow operators (`+%` / `+\|` / `+?`) | **v5.6.1** | Small |
| `#must_use` + `@unsafe` attributes | **v5.6.2** | Small |
| `#deprecated("reason")` attribute | **v5.6.3** | Small |
| First-class slices (`slice<T>` / `[T]` generalizing `Str`) | **v5.9.0** | Medium |
| Per-fn effect annotations (`#pure` / `#io` / `#alloc`) | **v5.9.1** | Medium |
| Tagged unions + exhaustive pattern match (own minor) | **v5.10.x** | Large |
| `Result<T,E>` + `?` propagation (own minor) | **v5.11.x** | Large |
| Allocators-as-parameter (own minor) | **v5.12.x** | Large |

**Still unpinned / lower priority:**

| Feature | Effort | Votes |
|---------|--------|-------|
| cc5 per-block scoping | Medium | — |
| Incremental compilation | High | — |
| Generics / traits | High | 1 (kavach) |
| Closures capturing variables | High | gotcha #8 |
| Hardware 128-bit div-mod | Medium | — |
| parse_*.cyr x86-emit guard sweep | Low | Active Bug follow-up |
| Phase 3-full varargs (va_arg for structs-by-value + nested) | Medium | Phase 3-min shipped v5.5.36 |
| Phase 2b-aarch64 struct copy (LDRB/STRB loop) | Medium | x86 shipped v5.5.36 |

---

## Stdlib (65 modules + 6 deps)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr, flags |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, thread_local, atomic, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, linalg, bigint, u128 |
| Network | net, http, http_server, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, fdlopen, cffi |
| Identity | pwd, grp, shadow, pam |
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
| Linux x86_64 | ELF | **Done** — primary, cc5 507 KB self-hosting (v5.5.40) |
| Linux aarch64 | ELF | **Done** — cross + native self-host byte-identical on real Pi (v5.3.15+); `regression.tcyr` 102/102 (v5.3.18). v5.5.18 expanded to 5-sub-test regression (alloc/fs/mt/mutex). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **Done** (v5.1.0) |
| macOS aarch64 | Mach-O | **Done** — self-hosts byte-identically on Apple Silicon (v5.3.13, 475 KB); all 4 Cyrius tool binaries verified on `ssh ecb` (v5.5.17). |
| Windows x86_64 | PE/COFF | **Done** — full native self-host + byte-identical fixpoint achieved v5.5.10. `cc5_win.exe` on Windows 11 reads stdin, compiles, emits PE byte-identical to Linux cross-build. Win64 ABI complete (v5.5.36). .reloc + 32-bit ASLR (v5.5.35). Exit42 PE = 1,536 B (vs Rust stripped 344,856 B = 225× smaller). HIGH_ENTROPY_VA (64-bit ASLR) deferred — see Active Bugs. |
| Compiler optimization (O1–O6) | — | Queued — **v5.6.0–5.6.5** |
| RISC-V (rv64) | ELF | Queued — **v5.7.0** |
| Bare-metal | ELF (no-libc) | Queued — **v5.8.0** |
| Pure-cyrius TLS 1.3 | — | Queued — **v5.9.0–5.9.5** |

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
  `project_services_repo_plan.md`). Target window: after v5.6.x
  optimization arc and before v6.0.0 (the consolidation minor),
  so the extraction rides in with other `lib/` reshuffles.


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

- **Dead-code sweep.** Every `sh scripts/check.sh` run since
  v5.4.x has reported unreachable fns in cc5 itself. v5.5.40
  removed `EMITPE_OBJ` and `PARSE_ASSIGN`. Remaining candidates
  include `ELVRLOAD`/`ELVRSTORE`, `CLASSIFY_CF`/`CF_TARGET`, IR
  scaffolding `IR_NODE_FL`, `IR_BB_*`, `IR_EDGE_*`, `ir_emit2`,
  `ir_lower_all`, `ir_apply_lase`, `ir_dead_block_elim`,
  `_macho_wstr_pad`, `SYSV_HASH` (if v5.6.7 doesn't re-wire it).
  Audit which are speculative scaffolding for future work vs
  genuinely dead, and delete the latter.
- **`_TARGET_*` flag consolidation.** `_TARGET_MACHO`,
  `_TARGET_PE`, `CYRIUS_TARGET_LINUX/WIN/MACOS`,
  `_AARCH64_BACKEND`, plus per-arch `#ifdef CYRIUS_ARCH_{X86,
  AARCH64}` and per-arch `EWRITE_PE` / `_pe_pending_imp_add` /
  `EDISP32` shim families. Consolidate into a single backend-
  dispatch table keyed on `(arch, format)`.
- **Bridge-compiler retirement assessment.** `src/bridge.cyr`
  exists to bridge cyrc's feature set to cc5's. With cc5 long
  past cyrc's surface, audit whether bridge can be retired or
  collapsed into cyrc's path.
- **`cc3`-era residue.** Vidya entries, comments in source,
  test fixtures still reference `cc3 4.8.5` and earlier. v5.5.39
  retired `src/cc/` + `src/compiler*.cyr` (3,333 LOC); remaining
  residue is in vidya + docs comments.
- **Heap-map tightening.** v5.5.40 verified 72 regions. Audit
  which are still load-bearing post-optimization-arc; reclaim
  wasted address space; document post-v6.0.0 layout as new
  baseline.
- **Backend module collapse where viable.** `src/backend/x86/`
  and `src/backend/aarch64/` each have parallel `emit.cyr`,
  `jump.cyr`, `fixup.cyr`. Audit which helpers can move to
  `src/backend/common/` without entangling asm-byte tables.
- **`cyrius build --strict` mode** — escalate `undefined
  function` warnings to hard errors through the build wrapper
  (direct `cc5 --strict` shipped v5.4.19).

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
