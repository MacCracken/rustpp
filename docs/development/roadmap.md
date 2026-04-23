# Cyrius Development Roadmap

> **v5.6.14.** cc5 compiler (487,040 B x86_64), x86_64 + aarch64
> cross + Windows PE cross + macOS aarch64 cross. IR + CFG.
> **Narrow-scope byte-identity** (the 3-step fixpoint
> `cc5_a → cc5_b → cc5_c; b == c`) holds on every target —
> this is the load-bearing invariant and check.sh verifies it on
> every commit. **Broad-scope self-host** (target binary runs +
> reproduces itself on native hardware) currently holds on Linux
> x86_64 + Linux aarch64 cross-built-runs-on-Pi; it is broken on
> Linux aarch64 native-self-host-on-Pi (pinned **v5.6.24**),
> macOS arm64 Mach-O (pinned **v5.6.25** — platform drift, bytes
> unchanged since v5.5.13), and Windows 11 24H2 PE
> (pinned **v5.6.26** — platform drift, bytes unchanged since
> v5.5.10). See `docs/architecture/cyrius.md` §"Self-hosting: two
> scopes of byte-identity" for the full definition. **v5.6.8 is the biggest
> single-patch optimizer win of v5.6.x so far**: Phase O2 category
> 2/5 (flag-result reuse + `test rax, rax` replacing the 10-byte
> push/xor/movca/pop/cmp dance in ECONDCMP's bare-value path).
> cc5 shrank 526,272 → 504,416 B (**−21,856 B / −4.15 %**);
> self-host compile time dropped 405 → 355 ms (**−12 %**). v5.6.9
> added CP-tracking push/pop cancel (381 → 0 pairs, −416 B).
> v5.6.10 collapsed the commutative combine shuttle
> (`mov rcx,rax; pop rax; op rax,rcx` → `pop rcx; op rax,rcx`
> for ADD/AND/OR/XOR/IMUL; 5861 sites; cc5 504,000 → 487,040 B,
> **−16,960 B / −3.37 %** — second-largest single-patch shrinkage
> of v5.6.x). Scope retargeted from literal LEA combining, which
> found 0 matches in cc5 output; non-commutative SUB/CMP flip and
> the LEA-literal pattern are pinned for a later LEA-spirit patch.
> O2 closes at v5.6.11 (aarch64 port of v5.6.10's combine-
> shuttle elim; scope retargeted after bytescan found the
> originally-planned `mul+add→madd` / `and+lsr→ubfx` patterns
> 0× in cc5_aarch64 because the combine shuttle separates the
> pair; porting v5.6.10 instead closes 4419 shuttle sites).
> O3 spans v5.6.12 + v5.6.14–v5.6.16 (v5.6.13 is the sha1 quick
> win, pulled forward between v5.6.12's LASE-bug discovery and
> v5.6.14's LASE fix). O3 split: O3a (precondition, ✅ shipped) /
> O3a-fix (LASE correctness) / O3b (fold+liveness+DCE) / O3c
> (copy-prop+fixpoint). O4–O6 at v5.6.17, v5.6.19, v5.6.20. The
> originally-slotted aarch64 fused ops (`madd`/`msub`/`ubfx`/
> `sbfx`) are re-pinned to v5.6.18, behind v5.6.17 linear-scan
> regalloc — the precondition that lets the patterns actually
> appear in the codebuf (intermediate values in regs, not stack).
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
> - **v5.6.0**: ✅ shipped — `parse.cyr` arch-guard cleanup
>   (closes the v5.5.40 carry-over Active Bug).
> - **v5.6.1**: ✅ shipped — `#else` / `#elif` / `#ifndef`
>   preprocessor directives (per-level state stack at 0x97F10).
> - **v5.6.2**: ✅ shipped — explicit overflow operators
>   (9 tokens; `lib/overflow.cyr`).
> - **v5.6.3**: ✅ shipped — `#must_use` + `@unsafe` attributes
>   (fn_flags table at 0xFC000).
> - **v5.6.4**: ✅ shipped — `#deprecated("msg")` attribute
>   (fn_flags bit 2 + string side-table at 0x104000). Closes the
>   v5.6.x small-language-polish arc.
> - **v5.6.5**: ✅ shipped — Phase O1 (FNV-1a FINDFN +
>   CYRIUS_PROF Linux + benchmarks baseline).
> - **v5.6.6**: ✅ shipped — CYRIUS_PROF cross-platform
>   (Windows PE GetTickCount64 + macOS Mach-O
>   _clock_gettime_nsec_np via __got grown 6 → 7 slots).
> - **v5.6.7**: ✅ shipped — Phase O2 category 1/5 — strength
>   reduction (`x * 2^n → shl`). cc5 −1,872 B.
> - **v5.6.8**: ✅ shipped — Phase O2 category 2/5 — flag-result
>   reuse + `test rax, rax` replacing ECONDCMP's 10-byte dance.
>   cc5 **−21,856 B**, self-host **−50 ms**.
> - **v5.6.9**: ✅ shipped — Phase O2 category 3/5 — redundant
>   push/pop elim (CP-tracking cancel; 381 → 0 adjacent `50 58`
>   pairs in cc5; −416 B).
> - **v5.6.10**: ✅ shipped — Phase O2 category 4/5 — commutative
>   combine-shuttle elim (`mov rcx,rax; pop rax; op rax,rcx` →
>   `pop rcx; op rax,rcx` for ADD/AND/OR/XOR/IMUL; 5861 sites;
>   **cc5 −16,960 B / −3.37 %**). Scope retargeted from literal
>   LEA combining (0 matches in cc5). LEA-literal pattern +
>   non-commutative SUB/CMP flip are pinned for a later
>   LEA-spirit patch within the v5.6.x minor.
> - **v5.6.11**: Phase O2 category 5/5 — aarch64 port of
>   v5.6.10's combine-shuttle elim (scope retargeted after
>   bytescan; 4419 sites, 12 B → 8 B per site). Closes Phase O2.
> - **v5.6.12** ✅ shipped: Phase O3a — IR-instrumented 76 parse
>   emit sites with `IR_RAW_EMIT` markers; enable-LASE/DBE attempt
>   surfaced a pre-existing correctness bug (see v5.6.13). cc5
>   488,088 B with default IR_ENABLED=0. Instrumentation is the
>   load-bearing deliverable.
> - **v5.6.13**: `lib/sha1.cyr` extraction (quick win — promote
>   `_wss_sha1` from private in `lib/ws_server.cyr` to first-class
>   stdlib module; pulled forward from v5.6.21 at user request as
>   a confidence-build between v5.6.12's LASE-bug discovery and
>   v5.6.14's LASE fix).
> - **v5.6.14**: Phase O3a-fix — root-cause and repair
>   `ir_lase` / `ir_apply_lase` so LASE + DBE actually produce
>   correct output. See §v5.6.14 for the three suspects.
> - **v5.6.15**: Phase O3b — IR constant folding + propagation
>   + bitmap liveness + DCE. ~260 LOC. Bails cleanly if byte
>   savings are 0.
> - **v5.6.16**: Phase O3c — copy propagation + dead-store elim
>   + fixed-point driver. ~330 LOC. Bails cleanly if 0.
> - **v5.6.17**: Phase O4 — linear-scan register allocation.
> - **v5.6.18**: aarch64 fused ops (`madd` / `msub` / `ubfx` /
>   `sbfx`) — post-emit codebuf peephole. Re-pinned from v5.6.11
>   after bytescan found 0× matches there; v5.6.17 regalloc is
>   the precondition that lets intermediate values stay in
>   registers so `mul+add` / `lsr+and-mask` pairs become adjacent.
> - **v5.6.19**: Phase O5 — maximal-munch instruction selection.
> - **v5.6.20**: Phase O6 — slab allocator for IR pools
>   (conditional on O4 measurements).
> - **v5.6.21**: `cyrius init` scaffold gaps (owl-surfaced — 5 fixes
>   in `cyrius-init.sh`).
> - **v5.6.22**: libro layout-dependent memory corruption
>   investigation.
> - **v5.6.23**: HIGH_ENTROPY_VA `cc5_win.exe` stdin-read failure
>   re-investigation.
> - **v5.6.24**: native aarch64 runtime capability gap (Pi) — the
>   native aarch64 cc5 fails to parse its own source with
>   `error:292: undefined variable '_TARGET_MACHO'`. Narrow-scope
>   byte-identity (`cc5_a → cc5_b` on x86) is unaffected;
>   broad-scope "aarch64 binary self-hosts on Pi" is broken.
>   Likely a feature gap in the aarch64 runtime path (envvar
>   reading / include resolution) that the x86 cross-compiler
>   doesn't hit. Caught during v5.6.11 verification.
> - **v5.6.25**: macOS arm64 Mach-O platform drift (ecb) —
>   cross-built `syscall(60, 42)` exits 1 instead of 42. **Our
>   Mach-O bytes are unchanged since v5.5.13** (byte-identical
>   v5.6.10 ↔ v5.6.11 for this shape); what regressed is macOS
>   dyld's tolerance for the LC_DYLD_INFO bind opcodes / `__got`
>   alignment we emit. Sequoia 15+ enforces stricter than Sonoma
>   14.x that v5.5.13 was tested on.
> - **v5.6.26**: Windows 11 24H2 PE platform drift (cass) — PE
>   `syscall(60, 42)` exits 0x40010080 (NTSTATUS informational /
>   DBG_-class) on Windows 11 24H2 (build 26200) instead of 42.
>   **Our PE bytes are unchanged since v5.5.10** (byte-identical
>   v5.6.10 ↔ v5.6.11); 24H2 tightened CET shadow-stack / CFG /
>   loader heuristic checks that our bare PE shape doesn't meet.
>   cc5_win.exe itself fails with PS `ApplicationFailedException`.
> - **v5.6.27**: shared-object (.so / .dll / .dylib) emission
>   completion.
> - **v5.6.28**: v5.6.x closeout + downstream ecosystem sweep gate
>   (agnos, kybernet, argonaut, agnosys, sigil, ark, nous, zugot,
>   agnova, takumi). **Last patch of v5.6.x.**
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
> aarch64 port remains fully online at the narrow-scope level
> (cross-build byte-identity; `regression.tcyr` 102/102 on real
> Pi; per-arch asm via `#ifdef CYRIUS_ARCH_{X86,AARCH64}` from
> v5.3.16). Broad-scope native self-host on Pi was last verified
> at v5.3.15 and is currently broken (pinned v5.6.24). Apple
> Silicon Mach-O broad-scope self-host was last verified at
> v5.3.13–v5.5.17 (per-minor exit=42 checks in v5.5.13–v5.5.17)
> and regressed on macOS Sequoia 15+ (pinned v5.6.25) — the
> emitted Mach-O bytes are unchanged since verification.
>
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5. Closure verified.
> **78+ test suites**, 14 benchmarks, 5 fuzz harnesses. **65 stdlib modules** (includes 6 deps).
> Caps: ident buffer 128KB, fn table 4096, fixup table 32768 (v5.5.37).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

Each row pinned to a concrete v5.6.x slot. No "investigate" / "future
work" phrasing without a patch number. If an investigation doesn't
yield, STOP and ask — never slip, defer, or re-slot unilaterally.

| Bug | Impact | Pinned slot |
|-----|--------|-------------|
| `lib/sha1.cyr` missing (owl) | stdlib layout | **v5.6.13** — promote `_wss_sha1` from private in `lib/ws_server.cyr` to first-class `lib/sha1.cyr` module so consumers (owl, sit, majra) don't vendor-copy. Pulled forward from v5.6.21 as a quick-win release between v5.6.12 and the v5.6.14 LASE audit. See `docs/development/issues/owl-lib-sha1-extraction-2026-04-22.md`. |
| `ir_lase` / `ir_apply_lase` correctness bug | LASE/DBE unsafe to enable | **v5.6.14** — surfaced during v5.6.12 when flipping LASE+DBE enabled produced a cc5 binary that parse-errored on trivial input. 811 candidates / 5,692 B "savings" are actually 5,692 B of corruption. Three suspects: (a) `_ir_clobbers_rax` coverage gap, (b) `ir_apply_lase`'s next-node-CP heuristic overreach, (c) `ir_dead_block_elim`'s `all_nop==1` check passing vacuously on zero-IR-node BBs. See §v5.6.14. |
| `cyrius init` scaffold gaps (owl) | `cyrius init` consumer UX | **v5.6.21** — ergonomic fixes (5 issues) surfaced during owl bootstrap. See `docs/development/issues/owl-init-scaffold-gaps-2026-04-22.md`. |
| Layout-dependent memory corruption | Libro PatraStore tests | **v5.6.22** — investigation patch. Localized with `CYRIUS_SYMS`. Classic memory-corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG available for diagnosis (5.0.0 IR). Note: ark cyml_parse crash (SA-002) was NOT this bug (wrong fn signature, fixed). If stuck after attempts, STOP and ask — never slip unilaterally. |
| HIGH_ENTROPY_VA deterministic `cc5_win.exe` stdin failure | Windows 11 64-bit ASLR | **v5.6.23** — re-investigation patch. v5.5.35 audited all 2043 MOVABS sites; 264 uncovered turned out to be data constants, not pointers. Simple programs work but `cc5_win.exe` stdin-read fails 5/5 under 64-bit ASLR. Currently shipping with 32-bit ASLR (DYNAMIC_BASE) only. v5.6.23 re-tries because the PE backend changed since (struct-return + varargs + `__chkstk` from v5.5.36 + cap raises from v5.5.37 + parser refactor from v5.5.38) — any of those may have shifted the failure surface. |
| Native aarch64 self-host on Pi fails at parse time | `cc5_aarch64_native` can't self-host on real Pi 4 | **v5.6.24** — fix the `error:292: undefined variable '_TARGET_MACHO'` when the native aarch64 cc5 (built by cross-compiler, running on Pi) parses its own `src/main_aarch64.cyr`. `_TARGET_MACHO` IS declared in `src/backend/aarch64/emit.cyr:37` and included before main_aarch64.cyr's reference, so this is likely a scope / forward-ref difference between the cross-compiler's include handling and the native binary's. Pre-existing (v5.6.10 native cc5 hits the exact same error; surfaced during v5.6.11 aarch64-runtime verification). The CLAUDE.md "native aarch64 self-hosts byte-identical on Pi" claim does NOT currently hold — add `tests/regression-aarch64-native-selfhost.sh` gate to catch it. |
| macOS arm64 runtime regression (syscall(60) reroute) | Apple Silicon deploys | **v5.6.25** — cross-built `syscall(60, 42)` Mach-O binary exits 1 on ssh ecb instead of 42. v5.5.13 memory entry explicitly verified exit=42; regressed somewhere in v5.5.14–v5.6.10. v5.6.11 output is byte-identical to v5.6.10 for this shape, so NOT a v5.6.11 regression — investigation starts by bisecting v5.5.14 → v5.6.10 Mach-O output changes. `__got[0]` (`_exit`) reroute is the suspect. Add `tests/regression-macho-exit.sh` gate. |
| Windows 11 runtime regression (PE exit code) | Windows 11 24H2+ deploys | **v5.6.26** — cross-built `syscall(60, 42)` PE binary exits 0x40010080 on ssh cass (Windows 11 24H2, build 10.0.26200) instead of 42. PowerShell reports `ApplicationFailedException` on cc5_win.exe itself. v5.6.11 output byte-identical to v5.6.10 so NOT a v5.6.11 regression. Likely 24H2 loader behavior change since v5.5.10 verification. Test on multiple Windows 11 builds to identify the loader threshold. Add `tests/regression-pe-exit.sh` gate. |

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

The v5.6.x minor bundles six arcs before v5.7.0 RISC-V opens:

1. **v5.6.0 — `parse.cyr` arch-guard cleanup (✅ shipped).** Closes
   the v5.5.40-discovered Active Bug.
2. **v5.6.1–v5.6.4 — Small language polish (✅ shipped).** Four
   single-patch additions that remove long-standing friction.
3. **v5.6.5 — Phase O1 (✅ shipped).** FNV-1a FINDFN + CYRIUS_PROF
   Linux + benchmarks baseline.
4. **v5.6.6 — CYRIUS_PROF cross-platform (✅ shipped).** Windows
   PE GetTickCount64 + macOS Mach-O _clock_gettime_nsec_np.
5. **v5.6.7–v5.6.20 — Compiler optimization arc continues (O2 split
   across 5 slots; O3 split across 4 slots after recon +
   LASE-bug discovery, interleaved with v5.6.13 sha1 quick-win;
   O4–O6 each their own slot; aarch64 fused-ops peephole slotted
   at v5.6.18 behind regalloc).**
   Peephole, IR-driven passes, linear-scan regalloc, maximal-munch,
   slab allocator. Lands BEFORE RISC-V so the new port inherits an
   optimized compiler. v5.6.11 was retargeted to port v5.6.10's
   combine-shuttle elim to aarch64 (4419 shuttle sites; 12 B → 8 B
   per site) after bytescan found the originally-planned `madd` /
   `msub` / `ubfx` / `sbfx` patterns 0× in cc5_aarch64 (the
   combine shuttle separates the pair); fused-ops work re-pinned
   to v5.6.18, post-regalloc. O3 recon (v5.6.12 kickoff) also
   surfaced a 590 LOC bundle that would have been too big for one
   slot — split into v5.6.12 (precondition + instrumentation; ✅
   shipped), v5.6.14 (LASE correctness fix — surfaced by the
   v5.6.12 enable attempt), v5.6.15 (fold + liveness+DCE), v5.6.16
   (copy-prop + fixpoint driver). Each sub-slot bails cleanly if
   measured byte savings are 0. v5.6.13 slots the `lib/sha1.cyr`
   extraction between v5.6.12 and v5.6.14 as a quick-win release
   (stdlib addition, zero compiler change) — momentum between the
   LASE-bug discovery and the harder correctness audit.
6. **v5.6.21 — Consumer-surfaced tooling fix.** `cyrius init`
   scaffold gaps (owl-surfaced). `lib/sha1.cyr` was the second
   item in this group until pulled forward to v5.6.13.
7. **v5.6.22–v5.6.23 — Pre-existing active-bug investigations.**
   Libro layout corruption + `cc5_win.exe` HIGH_ENTROPY_VA stdin
   failure.
8. **v5.6.24–v5.6.26 — Broad-scope platform-runtime repairs.**
   Three broad-scope failures surfaced during v5.6.11 verification.
   Important framing: **the narrow-scope byte-identity invariant
   (`cc5_a → cc5_b; cc5_a == cc5_b`) holds on every target** — v5.6.11
   output is byte-identical to v5.6.10 for each of these failure
   shapes. What's broken is the *broad-scope* claim that a cyrius-
   emitted binary can (a) run its own source through itself on
   native hardware, or (b) survive current-gen OS loader
   enforcement. Two distinct root-cause categories:
   - **Native-runtime capability gap (v5.6.24).** The native
     aarch64 cc5 binary fails to parse its own source on a Pi
     because something the x86 cross-compiler does at startup
     (envvar read / include resolution) doesn't work on the
     aarch64 runtime path. A *feature gap in our aarch64 binary*,
     not a codegen bug.
   - **External platform drift (v5.6.25 + v5.6.26).** The Mach-O
     and PE binaries we emit are **identical** to what was verified
     in v5.5.13 / v5.5.10. What changed is the host OS's tolerance
     for our output: macOS Sequoia 15+ dyld enforces LC_DYLD_INFO /
     `__got` alignment more strictly, and Windows 11 24H2 tightened
     CET / CFG / ASLR loader checks. *Our bytes didn't move — the
     goalposts did.*
   **Each slot mandates a regression-test gate** (`tests/regression-
   aarch64-native-selfhost.sh` / `regression-macho-exit.sh` /
   `regression-pe-exit.sh`) that ships as a SKIP-stub pre-fix and
   flips to PASS as part of the slot's closeout. Wired into
   `scripts/check.sh` to prevent silent re-regression (and to
   catch future platform-drift the same way).
   If an investigation doesn't yield, STOP and ask — never defer
   or slip unilaterally.
9. **v5.6.27 — Shared-object (.so / .dll / .dylib) emission.**
10. **v5.6.28 — v5.6.x closeout + downstream ecosystem sweep gate.**
    Last patch of v5.6.x.

### v5.6.0 — `parse.cyr` arch-guard cleanup ✅ shipped

Closes the v5.5.40-discovered carry-over Active Bug. v5.5.40
guarded `parse_fn.cyr`'s struct-return path; v5.6.0 finishes the
audit across the rest of `parse_*.cyr` and fixes four real
findings:

- **`PARSE_SWITCH` jump-table path** — `use_table = 1` emitted
  the full x86 dispatch (`lea rcx, [rip+disp]`, `movsxd`, `add`,
  `jmp rax`, raw 4-byte table) without `_AARCH64_BACKEND` gate.
  Fix: force `use_table = 0` on aarch64; falls through to existing
  linear-comparison path.
- **`PARSE_FIELD_LOAD` sub-byte struct field load** — emitted
  `movzx rax, byte/word [rcx]` for `fld_sz ∈ {1, 2, 4}` without
  guard. Fix: hard-error on aarch64 with "sub-8-byte struct field
  load is x86-only for v5.6.0; aarch64 LDRB/LDRH/LDR pending"
  matching v5.5.40 discipline.
- **Closure literal `|x| body` address emit** — only had the two
  x86 branches; mirror site `&fn_name` had full three-way
  dispatch. Fix: ported the dispatch verbatim — aarch64 closures
  emit MOVZ/MOVK/MOVK with fixup-table entry.
- **`PARSE_TERM` x87/SSE intrinsics silent corruption** — eight
  intrinsics (`f64_neg`, `f64_sin/cos/exp/ln/log2/exp2`,
  `f64_atan` in `PARSE_SIMD_EXT`) emitted raw `EB(S, …)` x87/SSE
  bytes intermixed with helpers stubbed to `return 0;` on
  aarch64. Helpers silently emitted nothing, raw bytes still
  emitted — worst class of corruption. Fix: hard-error on aarch64
  for each `ptyp` with intrinsic-specific message flagging that
  aarch64 has no native trig / exp / log / fpatan.

**Mechanical:** self-host byte-identical, 19/19 check.sh, cc5
507,136 → 508,880 B (+1,744 B). cc5_aarch64 cross still emits
`e_machine` 0xB7. cc5_win cross still produces valid PE32+.

### v5.6.1 — `#else` / `#elif` / `#ifndef` preprocessor ✅ shipped

Closes the long-standing gap where every stdlib selector wrote
paired `#ifdef CYRIUS_TARGET_LINUX` / `#ifdef CYRIUS_TARGET_WIN`
blocks. The preprocessor now has the full C-family conditional
family.

**What landed:**
- `ISIFNDEF` (`#ifndef NAME`), `ISELSE` (`#else`, whitespace-
  terminated), `ISELIF` (`#elif COND`) detectors in
  `src/frontend/lex_pp.cyr`.
- Per-level state stack at heap `0x97F10` (64 bytes, 1 byte per
  level, cap 64 levels — same cap as defer/continue tables).
  Four-state encoding: 0=EMITTING, 1=SEARCHING, 2=DONE,
  3=OUTER_SKIP. Invariant: `skip_depth == count of levels with
  state ≠ 0`.
- Dispatch wired in both `PP_PASS` and `PP_IFDEF_PASS`. The
  earlier single-counter `skip_depth` is preserved as the "should
  this byte emit?" gate; the new stack is consulted only on
  `#else`/`#elif` state transitions and `#endif` pops.
- Detector ordering documented inline — ISIFDEF/ISIFNDEF may
  appear in either order (byte-3 `d` vs `n`), ISIFPLAT before
  ISIF (byte-3 `p` vs space), ISELIF+ISELSE after the push block
  and before ISENDIF.

**Mechanical:** self-host byte-identical, 19/19 check.sh, 7
inline scenarios passed (ifndef defined/undefined, ifdef+else
both branches, if/elif/else chain middle-match + else-match,
nested ifdef+else inside true-outer and false-outer). cc5 size
508,880 → 515,344 B (+6,464 / +1.27 %).

**Deferred (not bundled):** converting the 60+ stdlib
paired-`#ifdef` sites to the new `#ifdef/#else/#endif` form is a
byte-identical mechanical migration that rides individual stdlib
patches — bundling would make this release diff noisy without
functional value.

### v5.6.2 — Explicit overflow operators ✅ shipped

Nine new operator tokens land; `lib/overflow.cyr` hosts the
saturating / checked helpers. Scope diverges slightly from the
v5.6.0 pin in favor of a cleaner, backend-agnostic impl:

**What landed (vs original scope):**
- Lexer: single-byte lookahead after `+` / `-` / `*` produces nine
  tokens (IDs 113–121). Wrapping-`%` variants fold back to the bare
  `+ - *` token at dispatch entry so the existing codegen handles
  them with zero extra bytes.
- Backend emit: saturating / checked dispatch via a new `EMIT_OVF_CALL`
  helper in `parse_expr.cyr` that emits a 2-arg call to a named
  stdlib fn. NOT the original inline `jo panic` / `cmov` plan — the
  call approach is backend-agnostic (cc5_aarch64 and cc5_win pick
  it up for free via existing `ECALLPOPS` / `ECALLTO`) and keeps
  the compiler size delta to +3,640 B instead of the duplicated
  per-arch encoding it would otherwise need.
- Stdlib: `lib/overflow.cyr` with six i64 helpers (`_sat_{add,sub,mul}_i64`
  + `_chk_{add,sub,mul}_i64`) using the `(a^r) & (b^r) & sign_bit`
  identity for add, its subtraction variant, and divide-back for
  mul (with the `INT64_MIN * -1` pathological-case guard).
- Checked-panic: `syscall(60, 57)` — exit code 57 chosen to avoid
  POSIX `128+N` signal codes and the `assert_summary` 0/1
  convention. Future v5.11.x `Result<T,E>` work may replace panic
  with Err propagation; the helper API stays stable.
- Bare `+ - *` unchanged (wrap on 2's-complement; a `--strict`-mode
  warning is a natural v5.6.4+ extension).

**Gate:** `tests/tcyr/overflow_ops.tcyr` ships with 18 assertions
across all three families (MAX/MIN edges, wrap check, clamp check,
on-the-edge checked). Overflow-panic cases can't run inside the
assert harness (would exit 57); covered by 5 standalone scenarios
confirmed during dev.

**Mechanical:** self-host byte-identical, 19/19 check.sh, cc5
515,344 → 518,984 B (+3,640 / +0.71 %). cc5_aarch64 emits
`e_machine 0xB7`; cc5_win valid PE32+.

**Deferred:** unsigned i64 variants, narrower widths (i32/u32),
`/?` / `/|` (checked/saturating divide) — all slot in as follow-ups
without lexer changes.

### v5.6.3 — `#must_use` + `@unsafe` attributes ✅ shipped

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
- `@unsafe` is advisory in v5.6.3 (warning if nested unsafe
  blocks exist; no runtime cost). Future hardening passes
  can tighten later.

**Gate:** attribute parsing regression + fn-marked-`#must_use`
sample whose result is dropped triggers the expected error.

**Tradeoff:** tiny parser addition + one diagnostic pass.
Enables stdlib to annotate `read`/`write`/`alloc` etc. —
catches real bugs.

### v5.6.4 — `#deprecated("reason / replacement")` attribute ✅ shipped

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
  infrastructure from v5.6.3).

**Gate:** `tests/tcyr/deprecated.tcyr` — calling a
`#deprecated` fn triggers warning; `--strict` promotes it to
error.

**Tradeoff:** one decorator + one diagnostic site. Small.

---

## v5.6.x — Compiler optimization arc (v5.6.5 ✅ + v5.6.7 ✅ + v5.6.8–v5.6.20, v5.6.13 interleaved sha1 quick-win)

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
  bump-alloc hot. "Measurement-gated" is a data question for the
  user to decide after the O4 numbers land — not a unilateral
  skip.

### v5.6.5 — Phase O1: instrumentation + FNV-1a symbol table ✅ shipped

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

### v5.6.6 — CYRIUS_PROF cross-platform ✅ shipped

v5.6.5 shipped profiling on Linux only (x86_64 + aarch64); this
patch fills in the remaining two active cyrius targets so the
instrumentation works everywhere cc5 runs. No Linux paths touched;
code size +1,256 B.

- **Windows PE (`kernel32!GetTickCount64`).** New
  `_pe_ensure_gettick` / `_pe_gettick_get` lazy-import pair in
  `src/backend/pe/emit.cyr`, matching the existing
  `_pe_ensure_stdio` / `_pe_ensure_readf` scaffolding. New
  `EGETTICKS_PE` emit fn (Win64 shadow-aware: drop 3 stacked values,
  `sub rsp, 0x28`, `call [rip+IAT]`, `add rsp, 0x28`; result u64 ms
  in rax). `_prof_clock_ns` gets a `CYRIUS_TARGET_WIN` branch that
  scales ms → ns.
- **macOS Mach-O arm64 (`_clock_gettime_nsec_np` via
  `__got[6]`).** Grows `__DATA_CONST.__got` from 6 → 7 slots:
  `GOT_SIZE` 48→56, `BIND_SIZE` 72→96, `SYMTAB_COUNT` 8→9,
  `STRTAB_SIZE` 80→104, `INDIRECT_SIZE` 24→28, nundefsym 6→7.
  New `EMACHO_CLOCK_ARM` uses the shared `_EMACHO_BLR_GOT(S, 6)`
  helper from v5.5.14; returns u64 ns directly (no timespec
  dance). BSD whitelist in `parse_expr.cyr` extended to include
  syscall 228.
- **Reroute in `parse_expr.cyr`:** `_TARGET_PE==1 && sc_num==228`
  → `EGETTICKS_PE`; `_TARGET_MACHO==2 && sc_num==228` →
  `EMACHO_CLOCK_ARM`. Shape: `syscall(228, clock_id, &ts)` —
  matches the Linux call site, arg2 discarded on PE, arg2 repurposed
  as clock_id on Mach-O.

cc5 526,888 → 528,144 B (+1,256 B / +0.24 %); 19/19 check.sh;
byte-identical self-host.

### v5.6.7 — Phase O2 category 1/5: strength reduction ✅ shipped

`x * 2^n` → `shl` (x86) / `lsl` (aarch64). `ESHLIMM` / `ESHRIMM`
emit helpers on both backends; `_TRY_MUL_BY_POW2` helper in
`parse_expr.cyr` wired into the 3 multiply fallback paths in
`PARSE_TERM`. cc5 528,144 → 526,272 B (−1,872 B). First optimizer
patch modifying generated bytes — established the 3-step
fixpoint pattern (see `docs/development/benchmarks.md`).

Deferred within this category (moved to future slots if a
benchmark demands them): signed `x / 2^n` strength reduction needs
the Hacker's Delight adjust-then-shift trick because straight
`asr` doesn't round toward zero like `idiv` does. `x * 0` / `x * 1`
/ `x ± 0` are already handled by the existing constant-fold path.

### v5.6.8 — Phase O2 category 2/5: flag-result reuse ✅ shipped

Two peepholes bundled, both touching the bare-value boolean-
conversion path in `ECONDCMP`:

1. **ECONDCMP dance → `test rax, rax`.** Pre-v5.6.8, `if (x) { ... }`
   (no explicit comparator) emitted `push / xor-eax / mov rcx,rax
   / pop / cmp rax, rcx` — 5 instructions, ~10 bytes. `test rax,
   rax` (3 bytes) is semantically identical and already in the
   emit library (`ETESTAZ`). Swapped in; 7 B saved per site.

2. **Flag-result reuse.** New `_flags_reflect_rax` tracker in
   `src/backend/x86/emit.cyr`. Set by arith helpers that leave ZF
   reflecting rax==0 (`EADDR`, `ESUBR`, `EANDR`, `EORR`, `EXORR`,
   `EXORAA`, `EMOVI(0)`, `ETESTAZ`, `ESHLIMM(n>0)`, `ESHRIMM(n>0)`).
   Cleared by helpers that modify rax without a matching ZF
   update (`EPOPR`, `EUNSPILL`, `ELODC`, `ELOAD*`, `EMOVRA_RDX`,
   `EMOVDR`, `EMOVI(v != 0)`, `EIMUL`, `ESHLCL`, `ESHRCL`,
   `ECMPR`). `ECONDCMP` skips the `ETESTAZ` emit when the flag is
   already 1 — another 3 B saved per site on top of #1.

**aarch64:** arith emits currently use non-S variants (`add`,
`sub`, `and`) so the flag never goes true there — skip is a
no-op, `ETESTAZ` always fires, behavior unchanged vs pre-v5.6.8.
Future aarch64 peephole work (v5.6.11 fused ops) can switch
selected arith to `adds`/`subs` and start firing the reuse.

**Numbers:**
- cc5: 526,272 → **504,416 B** (**−21,856 B, −4.15 %**).
- Self-host compile time: 405 → **355 ms** (**−12 %**).
- 3-step fixpoint: a=526,704 (upgrade step) → b=504,416 (peephole
  applied) → c=504,416 (fixpoint). cc5_b == cc5_c ✓.
- 19/19 check.sh.

**Biggest single-patch optimizer win of v5.6.x** — the lesson is
that a well-placed peephole inside a hot helper (ECONDCMP runs
once per `if`/`while` condition) cascades across thousands of
call sites in a real compiler.

### v5.6.9 ✅ Phase O2 category 3/5: redundant push/pop elimination

**Shipped 2026-04-23.** CP-tracking peephole that cancels an
adjacent `push rax; pop rax` pair emitted at the same codebuf
cursor. Pre-scan identified 0 `mov rX, rX` pairs but 381 adjacent
`50 58` pairs — almost all introduced by v5.6.7's strength-reduction
helper (`_TRY_MUL_BY_POW2` calls `ESPILL/EUNSPILL` around the LHS
subtree; when the LHS is a single identifier there's nothing to
spill across). Implementation: `_last_push_cp` global recorded by
`EPUSHR`/`ESPILL` after emitting the push; `EPOPR`/`EUNSPILL` check
`GCP(S) == _last_push_cp` and rewind CP past the push (x86 −1 B;
aarch64 −4 B) instead of emitting the pop. cc5 shrank 504,416 →
504,000 B (−416 B); 381 adjacent pairs → 0. aarch64 mirror lands
in the same patch (shared parse.cyr pattern fires on both).
3-step fixpoint b=c=504,000 B ✓; 19/19 check.sh.

### v5.6.10 ✅ Phase O2 category 4/5: commutative combine-shuttle elim

**Shipped 2026-04-23.** Scope was retargeted from the originally-
slotted LEA combining (`mov + add + add imm → lea`) after a
pre-implementation bytescan of v5.6.9 cc5 found **0 matches**
for that pattern — cyrius doesn't emit `add rax, imm` at all.
The SAME combine path instead emits a 7-byte shuttle trailer
after binary ops: `mov rcx, rax; pop rax; op rax, rcx`.
For commutative ops (ADD/AND/OR/XOR/IMUL) popping directly into
rcx gives the same result in 4 bytes. Two-state tracker
(`_last_emovca_cp`, `_last_movca_popr_cp`) + `_TRY_COMBINE_SHUTTLE`
helper in `src/backend/x86/emit.cyr` rewinds the 4-byte shuttle
and drops in `pop rcx` at each commutative-op emit that detects
the signature. 5861 shuttle sites (5399 ADD + 340 AND + 66 OR
+ 3 XOR + 53 IMUL) collapsed in cc5; **cc5 −16,960 B / −3.37 %**
(second-largest single-patch win of v5.6.x). aarch64 stubs the
trackers — it encodes binary ops with explicit src/dst regs so
the shuttle has no counterpart. 3-step fixpoint b=c=487,040 B;
19/19 check.sh.

**Pinned for a later LEA-spirit patch within v5.6.x:** literal
`mov + add + add imm → lea` (once IR-aware work makes it fire),
non-commutative SUB as `neg + add`, and CMP flag-order flip
propagated to the subsequent conditional jump (3880 sites,
~5 KB additional if wired).

### v5.6.11 — Phase O2 category 5/5: aarch64 combine-shuttle elim

**Scope retargeted from the originally-planned aarch64 fused ops
(`madd`/`msub`/`ubfx`/`sbfx`)** after a pre-implementation bytescan
on cc5_aarch64 (470,872 B) found **0 matches** for `mul + add`,
`mul + sub`, or `lsr + and-imm` adjacency. The combine-shuttle
always separates the multiply result from the subsequent add in
cyrius's codegen (evaluate MUL → x0, push, evaluate rhs → x0, mov
x1,x0, pop x0, add — so MUL and ADD are never immediate
predecessors). The originally-planned patterns are re-pinned to
v5.6.18, post-regalloc, when intermediate values stay in registers.

**The real opportunity** is the same shuttle pattern v5.6.10 fixed
on x86, ported to aarch64. v5.6.10's CHANGELOG claimed aarch64
"encodes binary ops with explicit src/dst regs so the shuttle has
no counterpart" — that was wrong: `parse.cyr`'s combine codegen
is shared and emits the 12-byte trailer on BOTH backends
regardless of the op's own encoding:

```
AA 03 00 E1    mov x1, x0              (EMOVCA, 4 B)
E0 07 41 F8    ldr x0, [sp], #16       (EPOPR, 4 B)
00 00 01 8B    add x0, x0, x1          (EADDR — or AND/ORR/EOR/MUL)
```

For commutative ops, popping LHS directly into x1 (via the
already-present `EPOPC` encoding `0xF84107E1` = `ldr x1, [sp], #16`)
gives the same answer in 8 bytes total. Net: 12 B → 8 B per site.

**Projected savings (bytescan on v5.6.10 cc5_aarch64):**

| op | sites | savings |
|----|-------|---------|
| ADD | 4021 | 16,084 B |
| AND | 266  | 1,064 B  |
| ORR | 95   | 380 B    |
| MUL | 35   | 140 B    |
| EOR | 2    | 8 B      |
| **total commutative** | **4419** | **~17.7 KB raw** |

Non-commutative SUB (266 sites) skipped — operand-swap inverts
subtraction; same precedent as v5.6.10's ESUBR exclusion.

**Implementation** (mirror of v5.6.10 in `src/backend/aarch64/emit.cyr`):
- Wire the existing `_last_emovca_cp` / `_last_movca_popr_cp`
  tracker stubs. `EMOVCA` records GCP after its 4 B emit. `EPOPR`
  records GCP-after-EW iff the entry GCP matched `_last_emovca_cp`,
  AND the existing v5.6.9 push/pop-cancel path didn't fire.
- New `_TRY_COMBINE_SHUTTLE(S)` helper: if `GCP == _last_movca_popr_cp`,
  rewind 8 B past the mov+pop, emit `EPOPC` (0xF84107E1 — already
  defined at line 169). Fall through to the op's 4-byte encoding,
  which reads from x1 as before.
- Wire `EADDR` / `EANDR` / `EORR` / `EXORR` / `EIMUL` to call
  `_TRY_COMBINE_SHUTTLE` before their `EW(...)` op encoding.
  Non-commutative siblings (`ESUBR`, `ECMPR`, shifts) intentionally
  unchanged.

Expected: cc5_aarch64 shrinks by ~17 KB (from 470,872 B, ~3.6 %).
cc5 (x86) unchanged — this is an aarch64-codegen-only patch. 3-step
fixpoint on aarch64 cross-built cc5 via `ssh pi`. **Closes Phase O2.**

### v5.6.12 — Phase O3a: IR-instrument parse emits + surface LASE bug ✅ shipped

**Shipped 2026-04-23.** Ships as "precondition + measurement floor"
per Path B. Splits from original single-slot O3 plan.

**What shipped:**
- 15 `_IR_REC0(S, IR_RAW_EMIT)` markers across parse.cyr /
  parse_decl.cyr / parse_expr.cyr / parse_fn.cyr covering every
  direct-emit block (switch jump-table, inline asm, sub-byte field
  load, `&fn` / `&local` address-emit, closure-literal, f64
  compare, x87 intrinsics × 7, struct-return rep-movsb, regalloc
  spill+restore).
- New `IR_RAW_EMIT = 98` opcode in `src/common/ir.cyr` — no-op in
  lowering (raw bytes already emitted at record time), conservatively
  clobbers rax in `_ir_clobbers_rax`, entry in dump table.
- cc5: 487,040 → **488,088 B** (+1,048 B instrumentation call
  overhead with default `IR_ENABLED=0`). 3-step fixpoint
  `a = b = c = 488,088 B` ✓. 22/22 check.sh ✓.

**The LASE/DBE enable FAILED: pre-existing correctness bug found.**
Wiring `ir_apply_lase(S)` + `ir_dead_block_elim(S)` under
`CYRIUS_IR=3` produced a cc5 that PARSED ERRORS on even
`fn main() { return 42; }` (error: "expected '=', got string").
Ruled out as coverage-gap in the new IR_RAW_EMIT instrumentation —
LASE alone (without DBE) also broke the binary. Numbers observed
before rollback:
- LASE: 811 candidates, 5,692 B NOP-filled (avg 7 B per site —
  matches `mov rax, [rbp+disp32]` encoding size).
- DBE: 52,747 B "dead" (10.8% of cc5 — almost certainly false
  positives).
- Resulting cc5 binary: broken at first compile.

Root cause almost certainly a hole in `ir_lase`'s rax-tracking OR
an overreach in `ir_apply_lase`'s "next node CP" heuristic extending
past the eliminated instruction's actual encoded length. These
passes have been disabled since they were written and never
runtime-verified.

**Shipped with LASE/DBE commented out** in `main.cyr:830`. The
instrumentation IS the load-bearing deliverable — future O3 passes
can now rely on parse-emit IR markers. LASE correctness fix pinned
to **v5.6.14** (see below).

### v5.6.13 — `lib/sha1.cyr` extraction (quick win)

**Pulled forward** from v5.6.21 at user request as a quick
confidence-build between the v5.6.12 LASE-bug discovery and the
v5.6.14 LASE correctness audit. Small, contained, unblocks three
consumer repos — good momentum before the harder optimizer work.

SHA-1 is implemented in the stdlib but buried as private-by-
convention `_wss_sha1` inside `lib/ws_server.cyr`. Three consumers
already need it outside a websocket context (owl for git `.git/
index` integration, majra has a local copy, sit will need it for
git compat). Reference:
`docs/development/issues/owl-lib-sha1-extraction-2026-04-22.md`.

**Scope:**
- Create `lib/sha1.cyr` with a clear public API (`fn sha1(data,
  len, digest_out)`), FIPS 180-4 constants + round function,
  module header explicitly flagging "NOT a trust primitive — see
  `lib/sigil.cyr` for SHA-256/512 if you need collision resistance."
- Route `lib/ws_server.cyr`'s `_wss_sha1` through the new
  `sha1(...)` (preserve the `_wss_` wrapper at the call site for
  ws_server-internal readability; the body delegates).
- Add `"sha1"` to `cyrius deps`' known-stdlib list so
  `[deps].stdlib = ["sha1", ...]` resolves.
- `tests/tcyr/sha1.tcyr` — NIST FIPS 180-4 test vectors (`"abc"`,
  million-`a`, etc.).
- Downstream majra patch bump (out-of-tree, tracked separately)
  drops its local copy once `lib/sha1.cyr` ships.

**Gate:** byte-identical self-host (stdlib addition, zero compiler
change); `tests/tcyr/sha1.tcyr` passes; `lib/ws_server.cyr`
byte-identical after refactor; v5.6.13 check.sh exercises the new
test.

### v5.6.14 — Phase O3a-fix: ir_lase / ir_apply_lase correctness audit

**Scope expanded from planning** after v5.6.12 surfaced that LASE +
DBE corrupt cc5's own codegen when enabled. Dedicated slot for
root-causing and fixing — expected not trivial because:
- Neither pass has runtime history to bisect against.
- 5,692 B of "savings" turn into 5,692 B of corruption, suggesting
  ALL of them are wrong, not an edge case.

**Suspect #1 — `_ir_clobbers_rax` coverage gap.** Some IR op that
actually clobbers rax is missing from the table. Consequence:
`last_store_idx` stays valid across an rax-clobber, and LASE
eliminates a LOAD_LOCAL whose rax value was actually overwritten
in between. Audit plan: for every opcode handled in `ir_lower_all`,
check its emit helper in `x86/emit.cyr` and determine whether rax
survives. Add missing entries.

**Suspect #2 — `ir_apply_lase`'s cp_end heuristic.** Uses next IR
node's CP as the end boundary. If the eliminated instruction's
real encoded size is N bytes but the next IR node is M bytes later
(M > N) — because un-instrumented emits happened between — NOP-fill
clobbers the M−N bytes that belong to the next instruction's
leading prefix. Fix: record ENCODED SIZE per-IR-node at record
time (new 4-byte column in a side table, or fold into existing
CP table's high bits), use `cp_start + size` instead of next-node
CP.

**Suspect #3 — `ir_dead_block_elim`'s "dead BB" condition.** A BB
is declared dead when no edge targets it AND all its nodes are
NOP/ELIMINATED. But a BB that parse emitted raw into may have
zero IR nodes AT ALL, which passes the `all_nop == 1` check
vacuously. Fix: require at least one IR node in the BB to count
it as "examined" before eliminating.

**Gates:**
- All three suspects investigated (sequential — stop if one yields
  a full fix).
- LASE + DBE enabled under `CYRIUS_IR=3` produces a cc5 that:
  (a) is byte-identical on repeated `CYRIUS_IR=3` compile (determinism),
  (b) correctly compiles `fn main() { return 42; }` and runs → 42,
  (c) successfully cross-builds cc5_aarch64 + cc5_win byte-identical
  to the non-IR paths.
- Measured byte savings recorded in `benchmarks.md` — if < 500 B
  after all 3 suspects investigated, STOP and ask (not worth
  shipping an enabled pass that barely fires).

~100–300 LOC depending on which suspect root-causes first.

### v5.6.15 — Phase O3b: IR constant folding + propagation, liveness + DCE

**Split out of the original single-slot O3 plan.** Ships the two
smaller new passes together because they're naturally chained
(fold reduces node count; liveness runs cleaner on the reduced
graph) and neither is as big as copy-prop. ~260 LOC.

- **Constant folding + propagation on IR**: promote the existing
  parse-time folding into a CFG-aware pass. Integer arithmetic,
  boolean, comparisons on constant operands. ~200 LOC.
- **Bitmap-based liveness + DCE**: one u64 = liveness for 64
  virtual registers; backward sweep; mark defs with no live uses
  as dead. Pattern lifted from
  `vidya/content/optimization_passes/cyrius.cyr`. ~60 LOC.
- **Gate**: byte-identical narrow-scope self-host under both
  `IR_ENABLED == 0` and `IR_ENABLED == 3`. Measure and record
  incremental savings over the v5.6.12 floor. **Bails cleanly if
  measured savings are 0 B** — we STOP and ask rather than ship
  dead code.

### v5.6.16 — Phase O3c: copy propagation + dead-store elim + fixed-point driver

**Split out of the original single-slot O3 plan.** Last of the
three O3 patches. ~330 LOC.

- **Copy propagation + dead-store elimination**: forward sweep
  with per-vreg "current copy-of" map; backward sweep marking
  live stores. ~300 LOC.
- **Fixed-point driver**: run fold → propagate → reduce → DCE
  in a loop until no-change. ~30 LOC.
- **Gate**: byte-identical narrow-scope self-host under both
  `IR_ENABLED == 0` and `IR_ENABLED == 3`. Measure incremental
  savings. Bails cleanly if 0 B.

### v5.6.17 — Phase O4: linear-scan register allocation

The big investment. Replaces today's peephole `#regalloc`.
~600–900 LOC.

- Sort live intervals by start point; greedy assignment with
  spill heuristic = furthest next use (Poletto & Sarkar).
  Covers: live-range build, active-set management, spill slot
  assignment, parallel-move resolution at block boundaries.
- **Determinism guard**: keep hint-based preferences but skip
  iterated coalescing — byte-identical self-host must hold.
- **Depends on v5.6.8's completed IR coverage** (live ranges
  need every def and use to be in IR).
- Expected output-code speedup: 2–3× over current stack-machine
  baseline on hot inner loops; 10–20 % quality gap vs.
  graph-coloring at a fraction of the code.

### v5.6.18 — aarch64 fused ops (`madd` / `msub` / `ubfx` / `sbfx`)

**Re-pinned from v5.6.11** after bytescan found 0× matches there.
Post-emit codebuf peephole scanning for 2-instruction sequences
the aarch64 ISA can fold into one:

- `mul Xd, Xn, Xm` immediately followed by `add Xd, Xd, Xk` →
  `madd Xd, Xn, Xm, Xk`.
- `mul` followed by `sub` → `msub`.
- `lsr Xd, Xn, #s` followed by `and Xd, Xd, #((1<<w)-1)` where the
  mask is contiguous low-bits → `ubfx Xd, Xn, #s, #w` (unsigned
  bit-field extract); signed variant `asr + and` → `sbfx`.

~150 LOC. **Precondition: v5.6.17 linear-scan regalloc.** Today
the combine codegen always shuttles intermediate values through
the stack (LHS pushed, evaluated, popped), so `mul` and its
consumer-`add` are never adjacent in the codebuf. After v5.6.17
regalloc can keep intermediate values in registers, and the
`mul x2, x0, x1; add x0, x2, x3` shape starts to appear. The
peephole then fires.

Gate: if v5.6.17 ships and a bytescan on the new aarch64 cc5
still shows 0× matches, STOP and report — do not re-slip
unilaterally (same rule that caught v5.6.10 and v5.6.11).

### v5.6.19 — Phase O5: maximal-munch instruction selection

~300–500 LOC.

- Formalize existing ad-hoc tile patterns (mem-operand `add`/`sub`
  on x86_64, aarch64 addressing modes) into a tile pattern
  database per backend. Walker traverses IR tree bottom-up,
  matching largest subtree to a single machine instruction.
- Opens the door for target-specific tiles (RISC-V v5.7.0) without
  touching the walker — v5.6.19 therefore SHIPS BEFORE v5.7.0 so
  the rv64 backend can land its tile table on day one instead of
  retrofitting.

### v5.6.20 — Phase O6: slab allocator for IR pools (measurement-gated)

~150 LOC. **Conditional on O4 numbers** — ships iff v5.6.9's
profile shows bump-allocation hot during live-range construction.
After O4 lands, the benchmark numbers go to the user with a
recommendation; user decides whether O6 ships or the slot remains
empty. Never skip unilaterally — report measurements and ask.

- `vidya/content/allocators` documents 20–30× speedup over bump
  for fixed-size churn. Applied to IR node pools during live-
  range build.
- If user decides to skip, record the decision in CHANGELOG with
  the specific O4 bench numbers that drove it.

---

## v5.6.x — Consumer-surfaced tooling fix (v5.6.21; sha1 pulled to v5.6.13)

Two items raised by the `owl` bootstrap (first Cyrius consumer
project — `cat`/`bat`-style file viewer for AGNOS). Both are
low-severity ergonomic / layout work with no compiler code paths
touched. Details in `docs/development/issues/owl-*.md`.

### v5.6.21 — `cyrius init` scaffold gaps (5 fixes in `cyrius-init.sh`)

Fresh `cyrius init --language=none .` scaffold fails `cyrius test`
out of the box and ships with string drift in generated docs.
Reference: `docs/development/issues/owl-init-scaffold-gaps-2026-04-22.md`.

**Scope:**
- **Issue 1** — write `src/test.cyr` (stub that compiles and exits
  0 so `cyrius test` passes); the file is announced by the success
  summary, referenced in generated `cyrius.cyml [build].test` and
  `.github/workflows/ci.yml`, but never created.
- **Issue 2** — global-replace `cyrius.toml` → `cyrius.cyml` in the
  heredocs at `cyrius-init.sh:272/288/305/462/531/565`. Stale
  boilerplate from before the `.cyml` migration; every new project
  ships with a wrong-filename comment at the top of `src/main.cyr`
  and in the generated `CLAUDE.md`.
- **Issue 3** — regenerate the `--dry-run` listing from the same
  writer-table the real path uses (or at least gate each dry-run
  line on `$LANGUAGE`); current listing advertises
  `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, and a
  populated `docs/development/` that the real path never creates.
- **Issue 4** — `cyrius.cyml [package].description` always empty.
  Add `--description=<str>` flag; when absent, default to
  `"<name> — TODO"` rather than empty string so `cyrius publish` /
  `cyrius distlib` / ecosystem listings get a placeholder.
- **Issue 5** — the "directory already exists" hint suggests the
  same command that just failed. Change the hint to `cd "$NAME" &&
  cyrius init --language=none .` when `$NAME != "."`.
- **Adjacent** — the `cbt` front-end caps arg forwarding at 2
  (`cbt/cyrius.cyr:299` → `cmd_init_args(argv(2), argv(3))`), so
  `cyrius init --language=none --agent=claude <name>` silently
  drops later args. Raise to at least 4-arg forwarding so combined
  flags work via the front-end instead of requiring direct script
  invocation.

**Gate:** `tests/regression-cyrius-init.sh` — after `cyrius init
--language=none .` in an empty dir, both (a) `cyrius test` exits 0
and (b) no generated file contains the literal string
`cyrius.toml`. Two-flag + three-flag invocation via the `cyrius`
front-end both reach the script with all args.

## v5.6.x — Active-bug investigations (v5.6.22–v5.6.23)

Both surviving Active Bugs investigate on a clean post-optimization
baseline. If an investigation doesn't yield after real attempts,
STOP and report findings — never slip, defer, or re-slot
unilaterally. The user decides next step.

### v5.6.22 — Libro layout-dependent memory corruption

Carry-over from v5.3.x. Each `println` insertion shifts the
crash site — classic memory-corruption signature. Localized with
`CYRIUS_SYMS`; isolated test binary works around it. CFG +
diagnostics from v5.0.0 IR are available for the hunt.

**Investigation plan:**
- Reduce the libro PatraStore failing test to the minimum
  `.cyr` that reproduces (start from `CYRIUS_SYMS` snapshot,
  delete by halves).
- Walk the heap map for any region that grew across v5.5.x
  without an audit (the v5.5.40 closeout's relaxed regex
  surfaced 26 previously-unseen regions — re-verify each).
- Compare CFG output between a small-program run (works) and a
  cc5-shaped run (crashes) — look for an arena-pointer reuse or
  a fixup-table indirection that goes stale.
- If stuck after real attempts, STOP and ask.

### v5.6.23 — `cc5_win.exe` HIGH_ENTROPY_VA stdin failure

v5.5.35 audited all 2043 MOVABS sites; the 264 uncovered turned
out to be data constants, not pointers. Simple programs run
fine, but `cc5_win.exe`'s stdin-read path fails 5/5 under 64-bit
ASLR. Currently shipping with 32-bit ASLR (DYNAMIC_BASE) only.

**Why re-try at v5.6.23 (vs leave as known-shipping limit):** the
PE backend has changed materially since v5.5.35:
- v5.5.36 added struct-return + varargs syntax + `__chkstk` (any
  of which may shift the failure surface).
- v5.5.37 raised `fixup_tbl` cap and reshuffled heap (new offsets
  could change the relocation pattern that failed).
- v5.5.38 split parse.cyr / lex.cyr (new emit-call ordering may
  reveal the corrupted site).

**Investigation plan:**
- Re-run the v5.5.35 MOVABS audit against current cc5_win.exe;
  diff the site list.
- Bisect the 32-bit-vs-64-bit ASLR failure on the stdin-read
  path specifically (rather than the full CLI); v5.5.36's varargs
  + `__chkstk` interact with stack-frame layout.
- If stuck after real attempts, STOP and ask.

---

### v5.6.24 — Native aarch64 self-host repair (Pi)

Fix `error:292: undefined variable '_TARGET_MACHO'` when the native
aarch64 cc5 (built by cross-compiler, running on Pi) parses its
own `src/main_aarch64.cyr`. `_TARGET_MACHO` is declared at
`src/backend/aarch64/emit.cyr:37` and included at line 67 of
main_aarch64.cyr — BEFORE the line-290 reference — so parse-time
resolution should work. Likely difference between the cross-
compiler's include-handling context and the native binary's.

Caught during v5.6.11's aarch64-runtime verification. Affects at
least v5.6.10 and v5.6.11 identically (same error, same line),
so the regression is pre-v5.6.10. The CLAUDE.md "native aarch64
self-hosts byte-identical on Pi" claim does NOT currently hold.

**Mandatory gate (regression test — part of this slot's scope):**
- Add `tests/regression-aarch64-native-selfhost.sh`:
  1. Skip cleanly if `pi` is unreachable OR `cc5_aarch64` not built.
  2. `scp` the cross-built native aarch64 cc5 to the Pi.
  3. `tar`-over-ssh `src/` + `lib/` to Pi.
  4. Run `cat src/main_aarch64.cyr | /tmp/cc5_native > /tmp/out`
     on the Pi; assert exit=0 and `cmp` with the cross-built
     native binary (byte-identical self-host).
- Wire into `scripts/check.sh` alongside the existing "aarch64
  syscalls + threads" gate.
- A stub is shipped pre-fix that SKIPs with a clear "pin v5.6.24"
  message so CI doesn't go red; the skip flips to PASS as part
  of this slot.

### v5.6.25 — macOS arm64 runtime regression repair (ecb)

Cross-built Mach-O `syscall(60, 42)` binary exits **1** on Apple
Silicon (ssh ecb) instead of 42. v5.5.13 memory entry explicitly
verified exit=42 after first `__got[0]` reroute; regressed
somewhere in v5.5.14–v5.6.10. v5.6.11 output is byte-identical
to v5.6.10 for minimal syscall-only code, so NOT a v5.6.11
regression.

**Suspects (in order):**
- `__got[0]` reroute's adrp/ldr/br emission changed between
  v5.5.14 (first reroute) and v5.5.17 (argv prologue added);
  argv prologue's `stp x0,x1,[sp,#-16]!` might have shifted LC_MAIN
  entry alignment.
- `LC_DYLD_INFO_ONLY` bind opcode list grew 1 → 7 across v5.5.14–
  v5.6.6 (each reroute added a symbol). A malformed or mis-sized
  bind entry could fail silently on recent macOS dyld.
- macOS 26.4.1 (sequoia+) dyld may enforce a stricter Mach-O
  shape than v5.5.13 was tested against.

**Investigation plan:**
1. Bisect Mach-O output bytes: build the same `syscall(60,42)`
   source with each v5.5.14 → v5.6.10 cross-compiler, diff the
   outputs, find the first version that produces the broken binary.
2. If bisection finds a clear offender, repair and re-verify.
3. If no single offender (gradual rot), revisit the Mach-O
   emitter structure as a whole (`src/backend/macho/emit.cyr` +
   aarch64 backend's `EMITMACHO_ARM64`).

**Mandatory gate (regression test — part of this slot's scope):**
- Add `tests/regression-macho-exit.sh`:
  1. Skip cleanly if `ecb` unreachable OR `cc5_aarch64` not built.
  2. `CYRIUS_MACHO_ARM=1 cc5_aarch64 < macos_bare.cyr > macos_bare`.
  3. `scp` to ecb, `codesign -s -`, run.
  4. Assert exit code == 42. Also verify a multi-fn arithmetic
     test (exercises v5.6.11 peephole on Mach-O output).
- Wire into `scripts/check.sh`.
- Stub ships SKIPping with "pin v5.6.25" message until the fix lands.

### v5.6.26 — Windows 11 runtime regression repair (cass)

Cross-built PE `syscall(60, 42)` binary exits **0x40010080**
(NTSTATUS informational / DBG_-class, decimal 1073745920) on
Windows 11 24H2 (build 10.0.26200) instead of 42. PowerShell
reports `ApplicationFailedException` when invoking cc5_win.exe
directly. v5.6.11 output is byte-identical to v5.6.10 so NOT a
v5.6.11 regression.

**Suspects (in order):**
- Windows 11 24H2 (released mid-2024) tightened loader checks.
  The v5.5.10 exit42 verification was on an older Win11 build
  (nejad@hp, build unclear); current cass is 26200. 24H2 added
  stricter DEP/CFG/CET enforcement and may reject the bare PE
  shape cyrius emits.
- ASLR bucket: v5.5.35 DYNAMIC_BASE-only (32-bit ASLR). Whatever
  preferred-base cyrius picks may now be in a reserved range.
- 0x40010080 is an NTSTATUS informational code (high nibble 0x4 =
  STATUS_SEVERITY_INFORMATIONAL). Specific code is NOT a widely-
  documented one; may be a CET (Control Flow Enforcement)
  shadow-stack violation signalled via informational status.

**Investigation plan:**
1. Test on an older Windows 11 build (pre-24H2) to confirm the
   regression is version-specific.
2. Capture the failing PE's execution with ProcMon / WinDbg on
   cass to identify the exact failure mode (CET violation, DEP
   block, loader reject).
3. If CET: disable shadow-stack in the PE header (`IMAGE_DLLCHARACTERISTICS_EX_CET_COMPAT` stays off; may need explicit opt-out).
4. If loader reject: compare the failing PE's headers against a
   known-working Rust-compiled hello-world on the same Win11 build,
   diff field by field.

**Mandatory gate (regression test — part of this slot's scope):**
- Add `tests/regression-pe-exit.sh`:
  1. Skip cleanly if `cass` unreachable OR `cc5_win` not built.
  2. `cc5_win < win_bare.cyr > win_bare.exe`.
  3. `scp` to cass, run via `cmd /c runtest.bat`.
  4. Assert `%ERRORLEVEL%` == 42. Also verify arithmetic test
     exercising v5.6.10 x86 combine-shuttle peephole.
- Wire into `scripts/check.sh`.
- Stub ships SKIPping with "pin v5.6.26" message until the fix lands.

### v5.6.27 — Shared-object emission completion

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
partial state is a known audit rough edge. Lands before v5.6.28
closeout so the audit item is cleared before the downstream
arch-neutral sweep begins. An alternate fit is v5.8.1 post-bare-
metal, but bare-metal doesn't exercise `.so` emission (kernel is
static all the way down), so slotting earlier is fine.

**Downstream:** no current consumer requires `.so` output. Sigil /
mabda / yukti / kybernet all ship as static libraries or source
bundles. Unblocks any future "cyrius stdlib available as system
libc peer" work, which isn't on the roadmap yet.

---

### v5.6.28 — v5.6.x closeout (LAST patch of v5.6.x)

Last patch before v5.7.0 RISC-V opens. CLAUDE.md "Closeout Pass"
11-step checklist: self-host verify, bootstrap closure, full
check.sh, heap-map audit, dead-code audit, refactor pass,
code-review pass, cleanup sweep, security re-scan, downstream
dep-pointer check, CHANGELOG/roadmap/vidya sync.

**Downstream gate.** This closeout is the opening signal for
genesis repo Phase 13B (arch-neutral boot pipeline —
`scripts/boot.cyr`, ISO Stages 1–4, `bootstrap-toolchain.sh`,
`build-order.txt`) and the ecosystem arch-neutral sweep: must-touch
(agnos, kybernet, argonaut, agnosys, sigil), should-touch (ark,
nous, zugot, agnova, takumi), may-touch (phylax, shakti,
ai-hwaccel, seema). All of them wait on v5.6.19 and must complete
before v5.7.0 RISC-V opens. Practical consequence: the closeout
carries extra rigor beyond the standard pass —

- **Heap-map cleanup** — not just verify; actively collapse any
  orphan allocations surfaced during the optimization arc. Leave
  no "temporary" arenas downstream would have to work around.
- **Refactor pass** — one targeted sweep for naming/API drift
  introduced across v5.6.0–v5.6.27. If a public function got
  reshaped mid-arc, this is the last chance to stabilize the name
  before downstream repos pin to it.
- **Audit pass** — dead code, stale comments, orphan tests,
  unused `#include` lines. Downstream sees this as the baseline
  they mirror in their own sweeps.
- **Downstream dep-pointer check** — walk every downstream repo's
  `cyrius.toml` / `cyrius.cyml` and verify they resolve cleanly
  against the v5.6.28 artifacts. Broken pins get fixed before
  v5.7.0 opens, not after.
- **Compiler surface freeze signal** — after v5.6.28 ships, public
  compiler API is frozen for the duration of the downstream sweep
  (approximately one minor cycle). v5.7.0 RISC-V can add, but not
  reshape, existing surface.

Rationale: downstream projects are batching their own arch-neutral
work against this closeout. If v5.6.28 ships with loose ends, each
downstream repo absorbs the cost and the sweep fragments. One
tight closeout here is cheaper than N downstream workarounds.

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
- **v5.6.5 + v5.6.7–v5.6.20** — Compiler optimization arc. New port
  should inherit an optimized compiler, not one still queueing
  baseline optimization. v5.6.19 (maximal-munch) in particular
  matters — rv64 backend lands its tile table against the new
  walker on day one instead of retrofitting.
- **v5.6.27** — shared-object emission landed (audit rough edge
  closed before new port opens).
- **v5.6.28** — downstream ecosystem sweep gate complete.
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
from `scripts/boot.cyr` landed in genesis Phase 13B (v5.6.27 gate).

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
  exactly what `#must_use` in v5.6.3 was designed to catch).
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
| **v5.1.0** | macOS x86_64 | Mach-O | **Done** (narrow-scope) |
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Narrow-scope byte-identity green**; broad-scope self-host on M-series was verified v5.3.13 era — **currently broken on Sequoia 15+** (platform drift, bytes unchanged, pinned **v5.6.25**) |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 (older build) |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Narrow-scope byte-identity green** (v5.5.10 md5-match on exit42 + multi-fn add); broad-scope runtime **currently broken on Win11 24H2** (build 26200+) (platform drift, bytes unchanged, pinned **v5.6.26**) |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | v5.5.13–v5.5.17 broad-scope verified on ecb at the time; **currently broken on Sequoia 15+** (see v5.3.0–v5.3.18 row; same platform drift, pinned **v5.6.25**) |
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
| `parse.cyr` arch-guard cleanup | **v5.6.0** ✅ | Small |
| `#else` / `#elif` / `#ifndef` preprocessor | **v5.6.1** ✅ | Small |
| Explicit overflow operators (`+%` / `+\|` / `+?`) | **v5.6.2** ✅ | Small |
| `#must_use` + `@unsafe` attributes | **v5.6.3** ✅ | Small |
| `#deprecated("reason")` attribute | **v5.6.4** ✅ | Small |
| `lib/sha1.cyr` extraction (owl) | **v5.6.13** | Small |
| `ir_lase` / `ir_apply_lase` correctness fix | **v5.6.14** | Investigation |
| `cyrius init` scaffold gaps (owl) | **v5.6.21** | Small |
| Libro layout-corruption investigation | **v5.6.22** | Investigation |
| `cc5_win.exe` HIGH_ENTROPY_VA re-investigation | **v5.6.23** | Investigation |
| Native aarch64 self-host repair (Pi) | **v5.6.24** | Investigation |
| macOS arm64 Mach-O platform drift | **v5.6.25** | Investigation |
| Windows 11 24H2 PE platform drift | **v5.6.26** | Investigation |
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
| parse_*.cyr x86-emit guard sweep | — | **Closed v5.6.0** |
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
| Linux x86_64 | ELF | **✅ Narrow + Broad** — primary host. cc5 487 KB (v5.6.11); 3-step fixpoint byte-identical; self-host ~347 ms. |
| Linux aarch64 | ELF | **✅ Narrow** (cross-build byte-identity holds); **⚠️ Broad** — cross-built binary runs fine on Pi (`regression-aarch64-syscalls.sh` 5/5 PASS; `regression.tcyr` 102/102 at v5.3.18) but **native self-host on Pi fails** at parse time (`_TARGET_MACHO` undef; pinned **v5.6.24**). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **✅ Narrow** (v5.1.0); Broad-scope not retested since. |
| macOS aarch64 | Mach-O | **✅ Narrow** (cross-build byte-identity holds; bytes unchanged since v5.5.13–v5.5.17); **❌ Broad** — cross-built `syscall(60, 42)` exits 1 instead of 42 on current Sequoia (macOS 15+). **Platform drift, not cyrius regression** — emitted Mach-O bytes are identical to what was verified exit=42 in v5.5.13. Pinned **v5.6.25**. |
| Windows x86_64 | PE/COFF | **✅ Narrow** — byte-identical fixpoint verified v5.5.10 (md5 match on exit42 + multi-fn add; cc5_win emits PE byte-identical to Linux cross-build). **❌ Broad** — on Windows 11 24H2 (build 26200+), PE `syscall(60, 42)` exits `0x40010080` and cc5_win.exe itself hits `ApplicationFailedException`. **Platform drift, not cyrius regression** — PE bytes unchanged since v5.5.10; Win11 24H2 tightened CET/CFG/ASLR loader enforcement. Pinned **v5.6.26**. Win64 ABI complete (v5.5.36); .reloc + 32-bit ASLR (v5.5.35); HIGH_ENTROPY_VA (64-bit ASLR) deferred — see Active Bugs. |
| Compiler optimization (O1–O6) | — | v5.6.5 ✅ + v5.6.7–v5.6.12 ✅ + **v5.6.14–v5.6.20** (NEXT: O3a-fix + O3b + O3c + O4–O6; v5.6.13 is sha1 quick-win) |
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
  `_macho_wstr_pad`, `SYSV_HASH` (if v5.6.27 doesn't re-wire it).
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
