# Cyrius Development Roadmap

> **v5.6.24.** cc5 compiler (522,624 B x86_64), x86_64 + aarch64
> cross + Windows PE cross + macOS aarch64 cross. IR + CFG.
> **Narrow-scope byte-identity** (the 3-step fixpoint
> `cc5_a → cc5_b → cc5_c; b == c`) holds on every target —
> this is the load-bearing invariant and check.sh verifies it on
> every commit. **Broad-scope self-host** (target binary runs +
> reproduces itself on native hardware) currently holds on Linux
> x86_64 + Linux aarch64 cross-built-runs-on-Pi; it is broken on
> Linux aarch64 native-self-host-on-Pi (pinned **v5.6.32**),
> macOS arm64 Mach-O (pinned **v5.6.33** — platform drift, bytes
> unchanged since v5.5.13), and Windows 11 24H2 PE
> (pinned **v5.6.34** — platform drift, bytes unchanged since
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
> O3 spans v5.6.12 + v5.6.14–v5.6.17 (v5.6.13 is the sha1 quick
> win; v5.6.15 is the IR-emit-order audit retargeted from O3b).
> O3 split: O3a (precondition, ✅ shipped) / O3a-fix (LASE
> correctness, ✅ shipped) / O3a-audit (IR-emit-order fix) / O3b
> (fold+liveness+DCE) / O3c (copy-prop+fixpoint). O4–O6 at
> v5.6.18, v5.6.20, v5.6.21. The originally-slotted aarch64 fused
> ops (`madd`/`msub`/`ubfx`/`sbfx`) are re-pinned to v5.6.19,
> behind v5.6.18 linear-scan regalloc — the precondition that
> lets the patterns actually appear in the codebuf (intermediate
> values in regs, not stack).
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
> - **v5.6.15**: Phase O3a-audit — IR-emit-order correctness fix
>   in `ESETCC` (records `IR_SETCC` BEFORE `ECMPR` records
>   `IR_CMP`, inverting IR order vs byte order; would corrupt
>   const-fold/copy-prop/liveness/DCE). ~5 LOC. Foundation for
>   all O3+ passes. Const-fold scope from old v5.6.15 moves to
>   v5.6.16 — it's not foundational, this is.
> - **v5.6.16**: Phase O3b — IR constant folding (~200 LOC) +
>   `ir_dce` skeleton (~100 LOC, bailed and re-pinned). 130 folds
>   / 774 B NOP-fill at IR=3 on cc5 self-compile; both fixpoints
>   clean. DCE attempt corrupted output even with expanded RAX
>   user-set; deferred to v5.6.17 per "STOP and ask" rule.
> - **v5.6.17**: Phase O3b-fix — bitmap liveness + DCE (re-attempt
>   the v5.6.16-deferred half). ~80 LOC + bisection methodology.
>   Bug fixed: `IR_RAX_CLOBBER` (EMULH/EIDIV/ELODC) reads RCX, not
>   writes it; v5.6.16 had it as `_ir_def_rcx_any`. 678 DCE kills
>   / 2,010 B NOP-fill at IR=3.
> - **v5.6.18**: Phase O3c — dead-store elimination + fixed-point
>   driver. ~100 LOC. 15 DSE on cc5 self-compile (matches recon).
>   Fixed-point catches cascade: const-fold rises 132 → 135 once
>   DCE+DSE remove wrapping ops. **Copy-prop deferred** to long-term
>   (no version pin) after v5.6.18 + v5.6.19 recons both bailed —
>   see "Long-term considerations" section.
> - **v5.6.19**: Phase O4a — per-fn live-interval infrastructure.
>   Foundation for linear-scan; ships data tracking + dump knob,
>   no codegen change. Originally pinned as full Poletto-Sarkar in
>   one slot; split into 3 phases after structural reality made
>   one slot infeasible.
> - **v5.6.20**: Phase O4b — Poletto-Sarkar picker. Replaces greedy
>   use-count picker with proper interval-based linear scan over
>   v5.6.19 intervals. Time-sliced patch pass shipped here too.
> - **v5.6.21**: **Codegen bug fix — bare-truthy `if (r)` after
>   fn-call (patra-blocking).** v5.6.x regression: `var r = fn();
>   if (r) {...}` takes FALSE when r==1. Strong suspect = v5.6.8
>   `_flags_reflect_rax` not reset after CALL/SYSCALL. Workaround
>   `if (r != 0)` rewritten across `src/*.cyr` keeps cc5 self-host
>   clean but downstreams hit. Patra 1.6.0 needs this fix to fold
>   in cleanly. Repro: `/tmp/cyrius_5.6_codegen_bug.cyr`.
> - **v5.6.22**: ✅ shipped — Phase O4c (partial). Picker
>   correctness fix (loop-back time-share extend) + auto-enable
>   infrastructure DISABLED by default. Default-on attempt
>   surfaced what looked like a v5.5.21 array-alignment regression
>   (mis-framed; v5.6.23 traced the actual root cause).
> - **v5.6.23**: ✅ shipped — Misdiagnosis correction. The v5.6.22
>   "alignment regression" was actually inline-asm + regalloc
>   stack-frame layout collision: asm hardcodes `[rbp-N]` disps;
>   regalloc's callee-save block (rbx + r12-r15) shifts every
>   local-var slot by `_cur_fn_regalloc * 8`, so `mov rdi,
>   [rbp-0x08]` reads the saved RBX value instead of param 1.
>   `parse_fn.cyr` body-scan lookahead for token 48 (`asm`); auto-
>   enable silently skips, opt-in `#regalloc` warns and skips.
>   `regression-inline-asm-discard.sh` PASS under `AUTO_CAP=99999`.
>   Default-on flip surfaced a SECOND picker bug — pinned v5.6.24.
>   cc5 521,216 → 522,624 B (+1,408 B for body-scan).
> - **v5.6.24**: Picker correctness — cross-fn corruption
>   investigation. v5.6.23 default-on flip bisects to AUTO_CAP=118
>   = `test_str_short`: regalloc-enabling that fn (5 vars, 2 calls)
>   breaks the next-fn `test_defaults`'s 5-arg
>   `flags_add_int(fs, 0, "count", 7, "")` call (default_val 7
>   comes back as 0). Independent of asm-skip and NOP-fill.
>   Different shape from v5.6.22 loop-back time-share. Bisection
>   methodology + per-action context dump per the v5.6.17 saved
>   playbook. Fix is the precondition for default-on flip.
> - **v5.6.25**: Live-across-calls regalloc investigation.
>   Consumer report (patra-side workaround surfaced 2026-04-24):
>   "every loop counter and pointer that crosses a patra call
>   needs explicit boxing. The real fix is in cyrius codegen:
>   probably stop register-allocating locals that are live across
>   calls, or save/restore them correctly around the spill." May
>   be the same root as v5.6.24 or distinct — sequenced after
>   for clean attribution. If consolidates with v5.6.24 in
>   investigation, the slot frees for next-priority work.
> - **v5.6.26**: aarch64 fused ops (`madd` / `msub` / `ubfx` /
>   `sbfx`) — post-emit codebuf peephole. Re-pinned from v5.6.11
>   after bytescan found 0× matches there; v5.6.22 regalloc is
>   the precondition that lets intermediate values stay in
>   registers so `mul+add` / `lsr+and-mask` pairs become adjacent.
> - **v5.6.27**: Phase O5 — maximal-munch instruction selection.
> - **v5.6.28**: Phase O6 — codebuf compaction (NOP harvest).
>   Sweeps accumulated NOPs from LASE/const-fold/DCE/DSE
>   in one pass with jump+fixup repair. Real binary shrinkage. (Old
>   slab-allocator scope reclaimable as a future v5.7.x slot if
>   v5.6.22 regalloc benchmarks show bump-allocation hot.)
> - **v5.6.29**: `cyrius init` scaffold gaps (owl-surfaced — 5 fixes
>   in `cyrius-init.sh`).
> - **v5.6.30**: libro layout-dependent memory corruption
>   investigation.
> - **v5.6.31**: HIGH_ENTROPY_VA `cc5_win.exe` stdin-read failure
>   re-investigation.
> - **v5.6.32**: native aarch64 runtime capability gap (Pi) — the
>   native aarch64 cc5 fails to parse its own source with
>   `error:292: undefined variable '_TARGET_MACHO'`. Narrow-scope
>   byte-identity (`cc5_a → cc5_b` on x86) is unaffected;
>   broad-scope "aarch64 binary self-hosts on Pi" is broken.
>   Likely a feature gap in the aarch64 runtime path (envvar
>   reading / include resolution) that the x86 cross-compiler
>   doesn't hit. Caught during v5.6.11 verification.
> - **v5.6.33**: macOS arm64 Mach-O platform drift (ecb) —
>   cross-built `syscall(60, 42)` exits 1 instead of 42. **Our
>   Mach-O bytes are unchanged since v5.5.13** (byte-identical
>   v5.6.10 ↔ v5.6.11 for this shape); what regressed is macOS
>   dyld's tolerance for the LC_DYLD_INFO bind opcodes / `__got`
>   alignment we emit. Sequoia 15+ enforces stricter than Sonoma
>   14.x that v5.5.13 was tested on.
> - **v5.6.34**: Windows 11 24H2 PE platform drift (cass) — PE
>   `syscall(60, 42)` exits 0x40010080 (NTSTATUS informational /
>   DBG_-class) on Windows 11 24H2 (build 26200) instead of 42.
>   **Our PE bytes are unchanged since v5.5.10** (byte-identical
>   v5.6.10 ↔ v5.6.11); 24H2 tightened CET shadow-stack / CFG /
>   loader heuristic checks that our bare PE shape doesn't meet.
>   cc5_win.exe itself fails with PS `ApplicationFailedException`.
> - **v5.6.35**: shared-object (.so / .dll / .dylib) emission
>   completion.
> - **v5.6.36**: v5.6.x closeout + downstream ecosystem sweep gate
>   (agnos, kybernet, argonaut, agnosys, sigil, ark, nous, zugot,
>   agnova, takumi). **Last patch of v5.6.x.**
>
> **Long-term considerations** (no version pin yet — revisit when
> the right preconditions land):
> - **Copy propagation** — v5.6.18 recon: 110 raw local-copy
>   patterns / 18 actual rewrites after invalidation / 1
>   cascade-target dead store. Direct savings on cyrius's stack-
>   machine IR are zero (LOAD-for-LOAD rewrite is byte-equal). May
>   revisit when v5.6.19 regalloc lands cross-BB liveness data —
>   copy chains can then potentially span BBs and the cascade math
>   changes.
> - **Extended dead-store elimination** — v5.6.19 recon: 0
>   candidates within the safe per-BB scope (RET/EPILOGUE-
>   terminated only). The cross-BB version that would catch "STORE
>   never read till function exit" needs proper data-flow liveness —
>   same v5.6.19 regalloc precondition as copy-prop.
>
> Both items intentionally NOT pinned to a v5.6.x or v5.7.x slot.
> Add to a future minor only when the regalloc data structures exist
> to make a meaningful version land cleanly.
>
> - **v5.7.0**: **sandhi fold + lib/ cleanup** (clean-break consolidation release — `lib/http_server.cyr` deletes, `lib/sandhi.cyr` adds, downstream consumers migrate includes). Per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md) — pinned 2026-04-24 after shifting from an "alias-window before v5.6.x closeout" model to a one-event clean-break cutover at the v5.7.0 release gate.
> - **v5.7.1**: RISC-V rv64 port (inherits optimized compiler + post-fold stdlib shape). Slid from v5.7.0 on 2026-04-24 so the sandhi fold can ride v5.7.0 as its own consolidation moment.
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
> at v5.3.15 and is currently broken (pinned v5.6.32). Apple
> Silicon Mach-O broad-scope self-host was last verified at
> v5.3.13–v5.5.17 (per-minor exit=42 checks in v5.5.13–v5.5.17)
> and regressed on macOS Sequoia 15+ (pinned v5.6.33) — the
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
| `cyrius init` scaffold gaps (owl) | `cyrius init` consumer UX | **v5.6.22** — ergonomic fixes (5 issues) surfaced during owl bootstrap. See `docs/development/issues/owl-init-scaffold-gaps-2026-04-22.md`. |
| Picker correctness — cross-fn regalloc corruption | default-on `#regalloc` unsafe | **v5.6.24** — v5.6.23 default-on flip bisects to AUTO_CAP=118 = `test_str_short`: regalloc-enabling that fn corrupts the next-fn `test_defaults`'s 5-arg `flags_add_int(fs, 0, "count", 7, "")` call (default_val 7 → 0). Independent of asm-skip (shipped v5.6.23) and NOP-fill (attempted + reverted at v5.6.23). Different shape from v5.6.22 loop-back time-share. Bisection methodology from v5.6.17 playbook. Fix is the precondition for flipping `CYRIUS_REGALLOC_AUTO_CAP` default. |
| Live-across-calls regalloc (patra-surfaced) | consumer codegen workarounds | **v5.6.25** — consumer report 2026-04-24: "every loop counter and pointer that crosses a patra call needs explicit boxing. The real fix is in cyrius codegen: probably stop register-allocating locals that are live across calls, or save/restore them correctly around the spill." Possibly the same root as v5.6.24 (regalloc + call interaction); sequenced after for clean attribution. If consolidates, slot frees. |
| `cyrius init` scaffold gaps (owl) | `cyrius init` consumer UX | **v5.6.29** — ergonomic fixes (5 issues) surfaced during owl bootstrap. See `docs/development/issues/owl-init-scaffold-gaps-2026-04-22.md`. |
| Layout-dependent memory corruption | Libro PatraStore tests | **v5.6.30** — investigation patch. Localized with `CYRIUS_SYMS`. Classic memory-corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG available for diagnosis (5.0.0 IR). Note: ark cyml_parse crash (SA-002) was NOT this bug (wrong fn signature, fixed). If stuck after attempts, STOP and ask — never slip unilaterally. |
| HIGH_ENTROPY_VA deterministic `cc5_win.exe` stdin failure | Windows 11 64-bit ASLR | **v5.6.31** — re-investigation patch. v5.5.35 audited all 2043 MOVABS sites; 264 uncovered turned out to be data constants, not pointers. Simple programs work but `cc5_win.exe` stdin-read fails 5/5 under 64-bit ASLR. Currently shipping with 32-bit ASLR (DYNAMIC_BASE) only. v5.6.31 re-tries because the PE backend changed since (struct-return + varargs + `__chkstk` from v5.5.36 + cap raises from v5.5.37 + parser refactor from v5.5.38) — any of those may have shifted the failure surface. |
| Native aarch64 self-host on Pi fails at parse time | `cc5_aarch64_native` can't self-host on real Pi 4 | **v5.6.32** — fix the `error:292: undefined variable '_TARGET_MACHO'` when the native aarch64 cc5 (built by cross-compiler, running on Pi) parses its own `src/main_aarch64.cyr`. `_TARGET_MACHO` IS declared in `src/backend/aarch64/emit.cyr:37` and included before main_aarch64.cyr's reference, so this is likely a scope / forward-ref difference between the cross-compiler's include handling and the native binary's. Pre-existing (v5.6.10 native cc5 hits the exact same error; surfaced during v5.6.11 aarch64-runtime verification). The CLAUDE.md "native aarch64 self-hosts byte-identical on Pi" claim does NOT currently hold — add `tests/regression-aarch64-native-selfhost.sh` gate to catch it. |
| macOS arm64 runtime regression (syscall(60) reroute) | Apple Silicon deploys | **v5.6.33** — cross-built `syscall(60, 42)` Mach-O binary exits 1 on ssh ecb instead of 42. v5.5.13 memory entry explicitly verified exit=42; regressed somewhere in v5.5.14–v5.6.10. v5.6.11 output is byte-identical to v5.6.10 for this shape, so NOT a v5.6.11 regression — investigation starts by bisecting v5.5.14 → v5.6.10 Mach-O output changes. `__got[0]` (`_exit`) reroute is the suspect. Add `tests/regression-macho-exit.sh` gate. |
| Windows 11 runtime regression (PE exit code) | Windows 11 24H2+ deploys | **v5.6.34** — cross-built `syscall(60, 42)` PE binary exits 0x40010080 on ssh cass (Windows 11 24H2, build 10.0.26200) instead of 42. PowerShell reports `ApplicationFailedException` on cc5_win.exe itself. v5.6.11 output byte-identical to v5.6.10 so NOT a v5.6.11 regression. Likely 24H2 loader behavior change since v5.5.10 verification. Test on multiple Windows 11 builds to identify the loader threshold. Add `tests/regression-pe-exit.sh` gate. |

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

The v5.6.x minor bundles six arcs before v5.7.0 (sandhi fold + lib/ cleanup) and v5.7.1 (RISC-V) open:

1. **v5.6.0 — `parse.cyr` arch-guard cleanup (✅ shipped).** Closes
   the v5.5.40-discovered Active Bug.
2. **v5.6.1–v5.6.4 — Small language polish (✅ shipped).** Four
   single-patch additions that remove long-standing friction.
3. **v5.6.5 — Phase O1 (✅ shipped).** FNV-1a FINDFN + CYRIUS_PROF
   Linux + benchmarks baseline.
4. **v5.6.6 — CYRIUS_PROF cross-platform (✅ shipped).** Windows
   PE GetTickCount64 + macOS Mach-O _clock_gettime_nsec_np.
5. **v5.6.7–v5.6.21 — Compiler optimization arc continues (O2 split
   across 5 slots; O3 split across 5 slots after recon +
   LASE-bug + IR-emit-order-bug discoveries, interleaved with
   v5.6.13 sha1 quick-win; O4–O6 each their own slot; aarch64
   fused-ops peephole slotted at v5.6.19 behind regalloc).**
   Peephole, IR-driven passes, linear-scan regalloc, maximal-munch,
   slab allocator. Lands BEFORE RISC-V so the new port inherits an
   optimized compiler. v5.6.11 was retargeted to port v5.6.10's
   combine-shuttle elim to aarch64 (4419 shuttle sites; 12 B → 8 B
   per site) after bytescan found the originally-planned `madd` /
   `msub` / `ubfx` / `sbfx` patterns 0× in cc5_aarch64 (the
   combine shuttle separates the pair); fused-ops work re-pinned
   to v5.6.19, post-regalloc. O3 recon (v5.6.12 kickoff) also
   surfaced a 590 LOC bundle that would have been too big for one
   slot — split into v5.6.12 (precondition + instrumentation; ✅
   shipped), v5.6.14 (LASE correctness fix — surfaced by the
   v5.6.12 enable attempt; ✅ shipped), v5.6.15 (IR-emit-order
   correctness fix — surfaced by v5.6.15 recon, foundation for
   all later IR-walking passes), v5.6.16 (fold + liveness+DCE),
   v5.6.17 (copy-prop + fixpoint driver). Each sub-slot bails
   cleanly if measured byte savings are 0. v5.6.13 slots the
   `lib/sha1.cyr` extraction between v5.6.12 and v5.6.14 as a
   quick-win release (stdlib addition, zero compiler change) —
   momentum between the LASE-bug discovery and the harder
   correctness audit.
6. **v5.6.22–v5.6.23 — Regalloc auto-enable safety.** v5.6.22
   shipped picker correctness fix (loop-back time-share extend) +
   auto-enable infrastructure DISABLED by default. v5.6.23 fixed
   a misdiagnosed v5.6.22 bug (inline-asm + regalloc stack-frame
   layout collision, not the alignment bug it was first framed as).
   Default-on flip still pending v5.6.24 picker-correctness fix.
7. **v5.6.24–v5.6.25 — Picker correctness + live-across-calls.**
   v5.6.23 default-on flip surfaced two picker bugs needing
   separate investigation: (a) cross-fn state corruption
   (`test_str_short` regalloc breaks `test_defaults`); (b)
   consumer-surfaced live-across-call boxing workaround in patra.
   Fix is the precondition for flipping `#regalloc` default-on.
8. **v5.6.26–v5.6.28 — Remaining optimization arc.** aarch64
   fused ops (re-pinned post-regalloc), maximal-munch instruction
   selection, codebuf compaction (NOP harvest). Real binary
   shrinkage lands at v5.6.28.
9. **v5.6.29–v5.6.31 — Consumer-surfaced tooling fixes.**
   `cyrius init` scaffold gaps (owl), libro layout corruption,
   `cc5_win.exe` HIGH_ENTROPY_VA stdin failure.
10. **v5.6.32–v5.6.34 — Broad-scope platform-runtime repairs.**
    Three broad-scope failures surfaced during v5.6.11 verification.
    Important framing: **the narrow-scope byte-identity invariant
    (`cc5_a → cc5_b; cc5_a == cc5_b`) holds on every target** — v5.6.11
    output is byte-identical to v5.6.10 for each of these failure
    shapes. What's broken is the *broad-scope* claim that a cyrius-
    emitted binary can (a) run its own source through itself on
    native hardware, or (b) survive current-gen OS loader
    enforcement. Two distinct root-cause categories:
    - **Native-runtime capability gap (v5.6.32).** The native
      aarch64 cc5 binary fails to parse its own source on a Pi
      because something the x86 cross-compiler does at startup
      (envvar read / include resolution) doesn't work on the
      aarch64 runtime path. A *feature gap in our aarch64 binary*,
      not a codegen bug.
    - **External platform drift (v5.6.33 + v5.6.34).** The Mach-O
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
11. **v5.6.35 — Shared-object (.so / .dll / .dylib) emission.**
12. **v5.6.36 — v5.6.x closeout + downstream ecosystem sweep gate.**
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

## v5.6.x — Compiler optimization arc (v5.6.5 ✅ + v5.6.7 ✅ + v5.6.8–v5.6.21, v5.6.13 interleaved sha1 quick-win)

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
v5.6.19, post-regalloc, when intermediate values stay in registers.

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

**Pulled forward** from v5.6.22 at user request as a quick
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

### v5.6.15 — Phase O3a-audit: IR-emit-order correctness fix

**Scope retargeted from the originally-slotted O3b (const-fold +
liveness+DCE)** after v5.6.15 recon surfaced an IR-vs-byte
ordering bug that would corrupt any IR-walking pass downstream
(const-fold, copy-prop, liveness, DCE, regalloc). Fixing the
foundation before building on it. Original v5.6.15 O3b content
moves to v5.6.16.

**The bug.** `ESETCC` in `src/backend/x86/emit.cyr` recorded
`IR_SETCC` BEFORE calling `ECMPR`, which itself records `IR_CMP`
and emits the `cmp rax, rcx` bytes. Then ESETCC emits `setcc al`
+ `movzx rax, al`. So the IR stream ordering was `SETCC → CMP`
while the actual byte-emission order was `cmp → setcc → movzx`.
Any IR-walking pass that inferred execution order from IR-record
order got the wrong answer — specifically, a naive linear scan
reported **3,588 "dead CMP" candidates on cc5 self-compile**
because it thought SETCC appeared before CMP and CMP's flags
were then "overwritten" by subsequent TEST. In reality CMP's
flags are consumed by SETCC; those CMPs are live.

**Audit.** Seven emit fns record IR then call another emit helper
before their own raw-byte emit. Six are safe (the called helper
doesn't record its own IR — e.g. `EVSTORE(IR_STORE_GLOBAL) →
_EVRCX → ESTOC`, where neither sub-call records). Only ESETCC
records IR twice across the boundary, producing the inverted
order.

**Fix.** ~5 lines in ESETCC: move `_IR_REC1(S, IR_SETCC, op)`
AFTER the call to `ECMPR(S)`. IR stream now reads `CMP → SETCC`
matching the byte-emit order. Dead-CMP bytescan drops from
3,588 → 242 (the residual 242 are other patterns, not
ESETCC-induced false-positives).

**Gate:**
- Byte-identical self-host at `IR_ENABLED == 0` (the default) —
  3-step fixpoint verified: 488,776 B unchanged.
- LASE count unchanged at 564 — no regressions to the v5.6.14
  correctness fix.
- `SETCC → CMP` IR adjacency count: 3,665 → 0 (the fix fires on
  every comparison-bool-valued site).
- `CMP → SETCC` IR adjacency count: 0 → 3,665 (the correct order
  is now recorded everywhere).
- 22/22 check.sh.

**Why this matters for later passes.** Every IR-walking O3/O4
pass (const-fold, copy-prop, liveness, DCE, regalloc) relies on
IR record order reflecting execution order. Without the ESETCC
fix those passes would silently compute wrong answers — the same
class of pre-existing-unseen bug v5.6.14 fixed for LASE's BB-split
assumption. Fix the foundation before building on it.

### v5.6.16 — Phase O3b (part 1/2): IR constant folding ✅ shipped 2026-04-23

**Shifted from v5.6.15** after the ordering-audit release. Now
lands on clean IR. Originally planned as ~260 LOC bundling
const-fold + bitmap liveness + DCE; **shipped const-fold alone**
after DCE's correctness audit hit the "STOP and ask" rule. DCE
re-pinned to v5.6.17.

**Const-fold (shipped, ~200 LOC)**:

- Forward state-machine sweep over IR detecting
  `LOAD_IMM(a), PUSH, LOAD_IMM(b), [POP_RCX | MOV_CA + POP_RAX], OP`
  patterns the parse-time `_cfo` fold missed. Two shapes covered:
  the v5.6.10-shuttle-elim commutative path (`POP_RCX, OP`) and
  the non-commutative path (`MOV_CA, POP_RAX, OP`).
- Foldable ops: ADD/SUB/MUL/AND/OR/XOR/SHL/SHR. DIV/MOD skipped
  (divide-by-zero would need a panic mid-fold).
- For each match: compute `fold_val = a OP b`, in-place rewrite
  codebuf — write `EMOVI(fold_val)` bytes at `cp(LHS_LOAD_IMM)`,
  NOP-fill the remainder of the span up to `cp(OP+1)`. Mark all
  consumed IR nodes as `IR_NOP` to keep the IR consistent with the
  rewritten bytes.
- v5.6.15 recon predicted **128 candidates** (109 SUB + 18 SHL + 1
  AND); v5.6.16 measurement: **130 folds, 774 B NOP-fill** on cc5
  self-compile at `CYRIUS_IR=3`. Both fixpoints (IR=0 b==c, IR=3
  b==c) verified at 497,696 B. check.sh 22/22.
- Note: NOP-fill preserves byte positions (so jumps and fixups stay
  valid) but does NOT shrink cc5 itself — the bytes remain in the
  binary as `0x90`. Real binary shrinkage comes via v5.6.21
  (codebuf compaction) which sweeps all per-pass NOP overhead in
  one pass. cc5 grew +4,568 B (488,776 → 493,344 B) for the const-
  fold helpers; final shipped at 497,696 B (also includes v5.6.16
  ir_dce + ir_apply_lase mods even though dce wiring is commented
  out in main.cyr).

**Bitmap liveness + DCE (deferred to v5.6.17, ~60 LOC of skeleton
shipped in `src/common/ir.cyr` as `ir_dce` but commented out in
`src/main.cyr`)**:

- Per-BB backward sweep with u64 liveness bitmap (bit 0 = RAX,
  bit 1 = RCX). Standard liveness algorithm: `live_in =
  (live_out − all_defs) | all_uses`; pure RAX/RCX defs whose
  target reg isn't in `live_out` are dead.
- Two correctness attempts in v5.6.16 both corrupted cc5 even
  after expanding `_ir_uses_rax` to include SYSCALL / CALL /
  CALL_KNOWN / TAIL_JMP / RET / EPILOGUE / RAW_EMIT /
  RAX_CLOBBER. There is at least one missing-use case the audit
  didn't catch — bisecting by elimination-count cap and
  inspecting IR around the first wrongly-killed node is the
  v5.6.17 starting point. Killed-count without correctness:
  738 (with the second-pass use-set) → 1,674 (with the original
  bare set).
- Per "quality before ops" rule: ship what works correctly,
  bail on broken passes. v5.6.16 const-fold shipped clean;
  DCE waits.

### v5.6.17 — Phase O3b-fix: bitmap liveness + DCE ✅ shipped 2026-04-23

**Ships the v5.6.16-deferred bitmap liveness + DCE half alone.**
Originally bundled with copy-prop + dead-store elim + fixed-point
driver (~390 LOC); split because the bug fix justifies its own
patch and the bisection methodology is the load-bearing learning.
Copy-prop + dead-store + fixed-point cascades to v5.6.18.

**Bug fix (~80 LOC + bisection methodology)**:

- Per-BB backward sweep with u64 liveness bitmap (bit 0 = RAX,
  bit 1 = RCX). Standard liveness algorithm: `live_in =
  (live_out − all_defs) | all_uses`; pure RAX/RCX defs whose
  target reg isn't in `live_out` are dead. Implementation in
  `src/common/ir.cyr` as `ir_dce` / `ir_dce_capped`.
- **v5.6.16's hidden bug, found via bisection**: kill cap +
  context dump narrowed to **kill #3 = `MOV_CA` before a
  CLBRA-protected sequence**. Root cause: `IR_RAX_CLOBBER`
  (recorded by EMULH/EIDIV/ELODC) reads RCX as operand /
  divisor / address, but v5.6.16 had it as a `_ir_def_rcx_any`
  (treating it as a writer). Going backward through CLBRA
  cleared RCX-liveness, making the upstream MOV_CA's RCX-def
  look dead. Fix: remove `IR_RAX_CLOBBER` from
  `_ir_def_rcx_any`; add to `_ir_uses_rcx`. Same correction
  for `IR_ADD_IMM_X1` (rcx += imm reads rcx) and `IR_RAW_EMIT`
  (opaque conservative reader).
- **Result**: 678 DCE kills, **2,010 B NOP-fill** at
  `CYRIUS_IR=3` on cc5 self-compile. Combined with v5.6.16's
  const-fold: 132 folds + 678 DCE = 810 candidates / 2,794 B
  total NOP-fill. Both fixpoints clean (IR=0 b==c, IR=3 b==c
  at 498,720 B). check.sh 22/22.
- **`CYRIUS_DCE_CAP=N`** kept as a debug knob for future
  audits — caps DCE kills at N for bisection.
- Real binary shrinkage still waits for v5.6.22 codebuf
  compaction (NOP-fill preserves byte positions for safety).

### v5.6.18 — Phase O3c: dead-store elimination + fixed-point driver ✅ shipped 2026-04-23

**Originally bundled with copy-prop (~330 LOC); shipped as
DSE + fixed-point driver alone (~100 LOC) after recon found
copy-prop yields zero direct savings on cyrius's stack-machine
IR.** Copy-prop re-pinned to its own slot at v5.6.19; everything
else cascades +1 through closeout (v5.6.31, was v5.6.30). 32
slots through v5.6.31 closeout.

**Recon (the bytescan-before-peephole rule)**: pre-implementation
walk of cc5 IR found:
- **15 dead-store candidates**: `STORE_LOCAL(x)` followed in same
  BB by another `STORE_LOCAL(x)` with no intervening LOAD or
  opaque op (CALL/SYSCALL/RAW_EMIT/&local).
- **110 local-copy candidates**: `LOAD_LOCAL(x), STORE_LOCAL(y)`.
  Direct savings: **0 B** — both LOAD_LOCALs are 7-byte
  instructions; rewriting `LOAD_LOCAL(y)` → `LOAD_LOCAL(x)` is
  byte-equal. Copy-prop's value here would be purely cascading
  into dead-store (if y is never read post-rewrite, its
  STORE_LOCAL becomes dead). User-decided: skip copy-prop in
  v5.6.18, evaluate in v5.6.19 with measurement after DSE +
  fixpoint ship.

**Dead-store (shipped, ~80 LOC)**:

- `ir_dead_store_capped(S, cap)` in `src/common/ir.cyr`. Per-BB
  forward sweep: for each `STORE_LOCAL(x)`, scan forward; if we
  find another `STORE_LOCAL(x)` before any `LOAD_LOCAL(x)` or
  opaque op, the first store is dead. Mark `IR_ELIMINATED`.
- Conservative bail set: `IR_LOAD_ADDR_L(same lidx)`,
  `IR_CALL/CALL_KNOWN/SYSCALL/RAW_EMIT/TAIL_JMP` — any of these
  may surface a pointer or read a local opaquely.
- `CYRIUS_DSE_CAP=N` env knob from day 1 (per the v5.6.17
  bisection methodology).

**Fixed-point driver (shipped, ~30 LOC)**:

- Loop in `src/main.cyr` under `CYRIUS_IR=3`: const-fold → DCE →
  dead-store; repeat until no candidates fire. Hard cap of 8
  iterations as a safety belt.
- Cascading observed on cc5 self-compile: const-fold count grew
  from 132 (v5.6.17) → **135 in 3 fixpoint iterations** as DCE +
  DSE removed wrapping ops, exposing new fold patterns.

**Result**:
- 135 folds + 678 DCE + **15 DSE** in 3 fixpoint iterations.
- Total NOP-fill at IR=3: **6,099 B** on cc5 self-compile (up
  from v5.6.17's 2,794 B — adds 567 LASE applies + DSE fill).
- Both fixpoints clean: IR=0 b==c==501,616 B; IR=3 b==c==
  501,616 B. check.sh 22/22 PASS.
- cc5 grew 498,720 → 501,616 B (+2,896 B) for `ir_dead_store` +
  `CYRIUS_DSE_CAP` knob + fixpoint loop.

### v5.6.19 — Phase O4a: per-fn live-interval infrastructure ✅ shipped 2026-04-23

**First of three Phase O4 sub-slots.** Originally pinned as
"Phase O4: full Poletto-Sarkar linear-scan register allocation
(~600-900 LOC)" — split after the structural reality emerged:
cyrius IR is position-encoded (RAX/RCX hardcoded into every emit
fn), no vreg layer, no cross-BB liveness. Real linear-scan needs
all of that. Splitting into three legitimate sub-phases:

- **v5.6.19** = O4a: live-interval data infrastructure (this slot)
- **v5.6.20** = O4b: Poletto-Sarkar picker
- **v5.6.21** = O4c: time-sliced rewrite + auto-enable + bisection

**Shipped (~80 LOC + dump)**:

- `src/frontend/parse_fn.cyr` — extended the existing v4.8.4
  `#regalloc` peephole's codebuf scan to also build per-local
  `ra_first[256]` + `ra_last[256]` interval tables alongside the
  existing `ra_counts[256]` use-count table.
- Three arrays sized **2048 bytes (256 i64 slots)** — uncovered
  a pre-existing latent sizing bug in `ra_counts[256]` (declared
  256 BYTES but written 256 i64s — wrote past end into adjacent
  global memory, tolerated because use-count picker defaults to 0
  for high-idx reads, so wrong values rarely affected outcomes).
  Interval tracking can't tolerate stale/random values per slot,
  so all three arrays are properly sized now.
- `CYRIUS_REGALLOC_DUMP=1` env knob in `src/main.cyr` — prints
  per-fn header (`fi`, `fn_start`, `fn_end`, `flc`, `pc`) plus
  one line per local with refs (`lidx`, `count`, `first_cp`,
  `last_cp`, `span`). Foundation for v5.6.20 picker — verifies
  intervals match expectations before wiring the algorithm.
- `_ra_dump_enabled` global in `src/frontend/parse.cyr` — read
  once at compile start, consulted per-fn (no per-fn env-syscall).

**Verification**:

- Test program (`#regalloc fn` with sum + i loop counter):
  ```
  ra: fi=0 fn_start=36 fn_end=193 flc=3 pc=1
  ra:   lidx=1 count=4 first=50 last=159 span=109
  ra:   lidx=2 count=5 first=59 last=147 span=88
  ```
  Both intervals within `[fn_start, fn_end)`. Spans reasonable
  (sum 109 B over fn body, i 88 B over loop body).
- Both fixpoints clean (IR=0 b==c, IR=3 b==c at 508,880 B).
- check.sh 22/22 PASS.
- cc5 grew 501,616 → 508,880 B (+7,264 B) for the two new
  arrays + the dump path + properly-sized ra_counts.

**No codegen change yet** — the picker still runs the existing
greedy use-count algorithm. v5.6.20 swaps it for Poletto-Sarkar.

### v5.6.20 — Phase O4b: Poletto-Sarkar linear-scan picker ✅ shipped 2026-04-23

**Second of three Phase O4 sub-slots.** Replaces the greedy
"pick top-N by use-count" picker in the existing `#regalloc`
peephole with proper Poletto-Sarkar linear scan over the
v5.6.19-built intervals.

~200 LOC.

- Sort intervals by `first_cp` (deterministic tie-break by lidx).
- Walk forward; maintain active set (intervals currently holding
  a register).
- For each interval: expire active intervals whose `last_cp <
  current.first_cp`; assign a free register if any; else apply
  spill heuristic = furthest next use (Poletto & Sarkar).
- **Determinism guard**: tie-break active-set ordering by lidx;
  keep hint-based preferences but skip iterated coalescing.
- `CYRIUS_REGALLOC_PICKER_CAP=N` knob — caps assignments for
  bisection per the v5.6.17 saved methodology.
- **Gate**: byte-identical narrow-scope self-host. Measure delta
  against v5.6.19's greedy picker. Bails cleanly if 0 or
  negative delta.
- **Still opt-in via `#regalloc`** — auto-enable lands in v5.6.22
  (bumped from v5.6.21 after the codegen-bug fix slot inserted).

### v5.6.21 — Codegen bug fix: bare-truthy after fn-call (patra-blocking) ✅ shipped 2026-04-23

**Pinned + shipped 2026-04-23.** Root cause: 4 missing
`_flags_reflect_rax = 0` resets in EFLLOAD/ECALLFIX/ECALLTO/
ESYSCALL. Fix is 4 lines in `src/backend/x86/emit.cyr`. New
regression gate `tests/regression-truthy-after-fncall.sh` (4r in
check.sh, 22 → 23). Patra 1.6.0 unblocked. cc5 grew +48 B.

A v5.6.x codegen regression surfaced by
user testing: `var r = helper(); if (r) { ... }` takes the FALSE
branch even when `r == 1`. Confirmed broken on 5.6.10 / 5.6.18 /
5.6.19 / 5.6.20; works on 5.5.27 / 5.5.40 / 5.6.5. Bisection
window: v5.6.6 — v5.6.10. Workaround across `src/*.cyr` (rewrite
all `if (r)` → `if (r != 0)`) keeps cc5 self-host clean, but
downstream consumers using idiomatic `if (r)` get hit (`tbl_find`
silently returns -1, test 12 onward cratered).

**Patra-blocking**: patra 1.6.0 (just bumped at v5.6.20 for `sit`
blob support) needs to fold into this cyrius rev cleanly without
the workaround. v5.6.21 ships the compiler fix so patra 1.6.0
release can close.

**Strong suspect**: v5.6.8's `_flags_reflect_rax` tracker (Phase
O2 cat 2). The optimization tracks when ZF reflects RAX and
skips an explicit `test rax, rax`. If the tracker isn't reset
after CALL/SYSCALL, the bare-truthy branch reads STALE flags
from inside the callee — branch target is essentially random per
callee shape.

**Repro file**: `/tmp/cyrius_5.6_codegen_bug.cyr`

```
fn helper(a, b, c) {
    var e = strlen(a);
    if (e != c) { return 0; }
    return memeq(a, b, c);
}

fn caller(x, y, z) {
    var r = helper(x, y, z);
    if (r) { return 99; }     # Expected when r == 1
    return 0 - 1;              # Taken incorrectly on 5.6.x
}

fn main() {
    alloc_init();
    var result = caller("hello", "hello", 5);
    print("result=", 7); fmt_int(result); print("\n", 1);
    return 0;
}
```

**Investigation hooks**:
- `_flags_reflect_rax` is set/reset in `src/backend/x86/emit.cyr`
- Audit every emit fn that writes RAX to ensure
  `_flags_reflect_rax = 0` reset
- ECALLPOPS / ECALLCLEAN / the CALL emit (`0xE8` opcode) MUST
  reset the flag
- ESYSCALL likewise — `0F 05` clobbers flags
- EFLLOAD (mov rax, [rbp-N]) DOES write rax but does NOT set ZF
  from the value — `_flags_reflect_rax` should be 0 after

**Equivalent shapes that ALSO break** (any of these warrant a
regression test):
- `if (fn_call())` directly (no intermediate var)
- `var r = fn_call(); if (r)`
- Workarounds that mask: `if (r != 0)`, intervening `print()`

**Gate**: `/tmp/cyrius_5.6_codegen_bug.cyr` runs and prints
`result=99`. Add `tests/regression-truthy-after-fncall.sh` to
check.sh as gate 4r so this can't regress silently again.

**Cascade**: v5.6.21 takes the slot that was Phase O4c. Phase
O4c → v5.6.22; +1 through closeout (v5.6.32 → v5.6.33).

### v5.6.22 — Phase O4c (partial): picker correctness fix + auto-enable infra ✅ shipped 2026-04-24

**Shipped two pieces, deferred default-on auto-enable to v5.6.23.**

**Picker correctness fix** (load-bearing for any opt-in
`#regalloc` fn with loops, AND for v5.6.23 default-on):

v5.6.20's time-sliced register reuse silently broke loops.
When picker reassigned an expired interval's register (e.g.,
rbx for `cnt` in [135876, 135900], then rbx for `p` in
[135963, 136057]), the loop's JMP_BACK to a position INSIDE
the earlier interval's CP range read stale register state. The
v5.6.20 design assumed straight-line forward execution; backward
edges weren't accounted for.

Fix: extend `interval.last_cp = ra_end` for every interval.
Picker can no longer time-share registers (intervals never
expire before fn end). Effectively reverts to single-register-
per-local-for-whole-fn = greedy-equivalent. Proper time-sharing
needs cross-BB liveness analysis (extend last_cp through
backward edges) — pinned future slot.

**Auto-enable infrastructure** (shipped, default DISABLED):

- `CYRIUS_REGALLOC_AUTO_CAP=N` env knob — caps how many fns get
  auto-regalloc enabled. -1 = disabled (default). N>0 = first N
  fns get auto-enabled.
- `_ra_auto_cap` / `_ra_auto_count` globals in `parse.cyr`.
- Auto-enable gating in `parse_fn.cyr` PARSE_FN_DEF.
- Gated on `_AARCH64_BACKEND == 0` (x86-only).

**Bisection methodology saved (v5.6.17 pattern, working again)**:
- `CYRIUS_REGALLOC_AUTO_CAP=303` clean, =304 broken → pinpointed
  `PP_ALREADY_INCLUDED` as the culprit fn.
- `CYRIUS_REGALLOC_PICKER_CAP=2` clean, =3 broken → pinpointed
  the time-share REUSE as the trigger (pick #3 was the first
  reassignment of an expired reg).

**Why default-on deferred to v5.6.23**: surfaced second bug —
v5.5.21 array-alignment regression. `tests/regression-inline-asm-discard.sh`
SIGSEGVs with default-on. Auto-enable's per-fn code growth
(~40 B prologue + ~40 B epilogue × ~1000 fns) shifts globals
in a way that v5.5.21's per-array padding misses. Investigation
needs proper alignment-debug budget — the per-array pad logic
in `src/backend/x86/fixup.cyr` SHOULD work for any dbase mod 16
but empirically doesn't under auto-enable. Deeper inspection
of fixup pass + global-VA computation needed.

**Verification**:
- 3-step fixpoint clean (IR=0 b==c at 521,216 B; IR=3 same)
- check.sh **23/23 PASS**
- cc5 grew 520,504 → 521,216 B (+712 B for cap knob + time-share fix)

### v5.6.23 — Phase O4c (re-attempt): default-on auto-enable + alignment investigation

**Cascaded from v5.6.22 after the alignment regression surfaced.**

The picker correctness fix landed at v5.6.22; auto-enable
infrastructure shipped DISABLED by default. v5.6.23 re-attempts
default-on after fixing the alignment interaction.

**Investigation tasks**:
- Reproduce: `CYRIUS_REGALLOC_AUTO_CAP=99999 sh tests/regression-inline-asm-discard.sh`
- Inspect `src/backend/x86/fixup.cyr` prefix-sum pass: does the
  per-array `(0 - va) & 15` pad actually fire for `var rk[240]`?
  Print pad value during fixup with auto-enable on vs off.
- Check global ordering: does auto-enable's code growth shift
  `var rk` to a different position in the global var list?
- Check `data_size` vs per-var prefix sums: any computation that
  uses `data_size` directly (not via prefix-sum lookup) may miss
  the per-array padding.
- Test `dbase`-level alignment fix: aligning `dbase = entry +
  acp` to 16 up-front (belt-and-suspenders). Was tried at v5.6.22
  and didn't fix it alone — bug is somewhere else in the pipeline.

**Once alignment fixed**:
- Flip `_ra_auto_cap` default from -1 to 0, change gating from
  `if (_ra_auto_cap > 0)` to `if (_ra_auto_cap < 0 || ...)` —
  i.e., auto-enable by default unless cap explicitly set.
- Save/restore optimization: when picker assigns 0 regs, skip
  the prologue/epilogue save+restore entirely. Required to make
  default-on net-positive for fns with no hot locals.

**Gate**: byte-identical narrow-scope self-host AND broad-scope
(cc5_b runs on simple input, cc5_b self-hosts to cc5_c, b==c)
AND `tests/regression-inline-asm-discard.sh` PASS with default-on.

### v5.6.24 — aarch64 fused ops (`madd` / `msub` / `ubfx` / `sbfx`)

**Re-pinned from v5.6.11** after bytescan found 0× matches there.
Post-emit codebuf peephole scanning for 2-instruction sequences
the aarch64 ISA can fold into one:

- `mul Xd, Xn, Xm` immediately followed by `add Xd, Xd, Xk` →
  `madd Xd, Xn, Xm, Xk`.
- `mul` followed by `sub` → `msub`.
- `lsr Xd, Xn, #s` followed by `and Xd, Xd, #((1<<w)-1)` where the
  mask is contiguous low-bits → `ubfx Xd, Xn, #s, #w` (unsigned
  bit-field extract); signed variant `asr + and` → `sbfx`.

~150 LOC. **Precondition: v5.6.18 linear-scan regalloc.** Today
the combine codegen always shuttles intermediate values through
the stack (LHS pushed, evaluated, popped), so `mul` and its
consumer-`add` are never adjacent in the codebuf. After v5.6.18
regalloc can keep intermediate values in registers, and the
`mul x2, x0, x1; add x0, x2, x3` shape starts to appear. The
peephole then fires.

Gate: if v5.6.18 ships and a bytescan on the new aarch64 cc5
still shows 0× matches, STOP and report — do not re-slip
unilaterally (same rule that caught v5.6.10 and v5.6.11).

### v5.6.25 — Phase O5: maximal-munch instruction selection

~300–500 LOC.

- Formalize existing ad-hoc tile patterns (mem-operand `add`/`sub`
  on x86_64, aarch64 addressing modes) into a tile pattern
  database per backend. Walker traverses IR tree bottom-up,
  matching largest subtree to a single machine instruction.
- Opens the door for target-specific tiles (RISC-V v5.7.1) without
  touching the walker — v5.6.20 therefore SHIPS BEFORE v5.7.1 so
  the rv64 backend can land its tile table on day one instead of
  retrofitting.

### v5.6.26 — Phase O6: codebuf compaction (NOP harvest)

**Re-pinned 2026-04-23.** Replaced the originally-conditional
slab-allocator slot. v5.6.16's const-fold + LASE + future DCE
passes all NOP-fill bytes in the codebuf rather than rewinding
CP — the byte positions are preserved so jumps and fixups stay
valid. The "saved" bytes are still in the binary as `0x90` NOPs.
Compaction harvests ALL accumulated NOPs in one pass.

~150 LOC.

- Walk codebuf for runs of ≥4 NOP bytes (`0x90`).
- For each run: rewind CP past the run, shift subsequent code
  down, fix up:
  - Forward-jump offsets (relative `jXX`/`callXX` with target
    past the deleted range).
  - Fixup table CPs (the post-codegen FIXUP pass uses node CPs
    that need adjustment).
  - IR_NODE_CP records (so any later pass sees consistent CPs).
  - Function start offsets in the fn table (if compaction crosses
    a fn boundary).
- **Gate**: byte-identical narrow-scope self-host under both
  `IR_ENABLED == 0` and `IR_ENABLED == 3`. With const-fold +
  LASE shipped at ~774 + ~3,977 B NOP-fill on cc5 self-compile,
  compaction should harvest the bulk; expected shrinkage is the
  difference between current cc5 size and (current cc5 size −
  total NOP-fill across all passes). DCE adds another ~2k B once
  v5.6.17 fixes it.
- **Safety**: do NOT compact across BB boundaries that have
  incoming JMP_BACK edges (loop tops) until edge fixups are
  proven; start with intra-BB compaction only and expand once
  the simpler form is verified across all platforms.

The originally-pinned slab allocator (~150 LOC for IR-pool churn)
is reclaimable if v5.6.18 regalloc benchmarks show bump-allocation
hot — pin it as a future v5.7.x slot if so. Codebuf compaction is
the higher-leverage win because it sweeps ALL the per-pass NOP
overhead in one shot rather than just one allocator hot path.

---

## v5.6.x — Consumer-surfaced tooling fix (v5.6.22; sha1 pulled to v5.6.13)

Two items raised by the `owl` bootstrap (first Cyrius consumer
project — `cat`/`bat`-style file viewer for AGNOS). Both are
low-severity ergonomic / layout work with no compiler code paths
touched. Details in `docs/development/issues/owl-*.md`.

### v5.6.27 — `cyrius init` scaffold gaps (5 fixes in `cyrius-init.sh`)

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

## v5.6.x — Active-bug investigations (v5.6.23–v5.6.24)

Both surviving Active Bugs investigate on a clean post-optimization
baseline. If an investigation doesn't yield after real attempts,
STOP and report findings — never slip, defer, or re-slot
unilaterally. The user decides next step.

### v5.6.28 — Libro layout-dependent memory corruption

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

### v5.6.29 — `cc5_win.exe` HIGH_ENTROPY_VA stdin failure

v5.5.35 audited all 2043 MOVABS sites; the 264 uncovered turned
out to be data constants, not pointers. Simple programs run
fine, but `cc5_win.exe`'s stdin-read path fails 5/5 under 64-bit
ASLR. Currently shipping with 32-bit ASLR (DYNAMIC_BASE) only.

**Why re-try at v5.6.24 (vs leave as known-shipping limit):** the
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

### v5.6.30 — Native aarch64 self-host repair (Pi)

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
- A stub is shipped pre-fix that SKIPs with a clear "pin v5.6.25"
  message so CI doesn't go red; the skip flips to PASS as part
  of this slot.

### v5.6.31 — macOS arm64 runtime regression repair (ecb)

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
- Stub ships SKIPping with "pin v5.6.26" message until the fix lands.

### v5.6.32 — Windows 11 runtime regression repair (cass)

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
- Stub ships SKIPping with "pin v5.6.27" message until the fix lands.

### v5.6.33 — Shared-object emission completion

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
partial state is a known audit rough edge. Lands before v5.6.29
closeout so the audit item is cleared before the downstream
arch-neutral sweep begins. An alternate fit is v5.8.1 post-bare-
metal, but bare-metal doesn't exercise `.so` emission (kernel is
static all the way down), so slotting earlier is fine.

**Downstream:** no current consumer requires `.so` output. Sigil /
mabda / yukti / kybernet all ship as static libraries or source
bundles. Unblocks any future "cyrius stdlib available as system
libc peer" work, which isn't on the roadmap yet.

---

### v5.6.34 — v5.6.x closeout (LAST patch of v5.6.x)

Last patch before v5.7.0 (sandhi fold + lib/ cleanup) and v5.7.1 (RISC-V) open. CLAUDE.md "Closeout Pass"
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
ai-hwaccel, seema). All of them wait on v5.6.20 and must complete
before v5.7.0 (sandhi fold) opens. Practical consequence: the closeout
carries extra rigor beyond the standard pass —

- **Heap-map cleanup** — not just verify; actively collapse any
  orphan allocations surfaced during the optimization arc. Leave
  no "temporary" arenas downstream would have to work around.
- **Refactor pass** — one targeted sweep for naming/API drift
  introduced across v5.6.0–v5.6.28. If a public function got
  reshaped mid-arc, this is the last chance to stabilize the name
  before downstream repos pin to it.
- **Audit pass** — dead code, stale comments, orphan tests,
  unused `#include` lines. Downstream sees this as the baseline
  they mirror in their own sweeps.
- **Downstream dep-pointer check** — walk every downstream repo's
  `cyrius.toml` / `cyrius.cyml` and verify they resolve cleanly
  against the v5.6.29 artifacts. Broken pins get fixed before
  v5.7.0 (sandhi fold) opens, not after.
- **Compiler surface freeze signal** — after v5.6.29 ships, public
  compiler API is frozen for the duration of the downstream sweep
  (approximately one minor cycle). v5.7.0 fold + v5.7.1 RISC-V can
  add, but not reshape, existing surface.

Rationale: downstream projects are batching their own arch-neutral
work against this closeout. If v5.6.29 ships with loose ends, each
downstream repo absorbs the cost and the sweep fragments. One
tight closeout here is cheaper than N downstream workarounds.

---

## Long-term considerations (no version pin yet)

Items deferred without a v5.6.x or v5.7.x slot. Add to a future
minor only when the right preconditions land — typically when
v5.6.19 regalloc + cross-BB liveness machinery exists to make a
meaningful version land cleanly.

### Copy propagation

**Status**: deferred 2026-04-23 after v5.6.18 + v5.6.19 recons.

**Why deferred**: cyrius's stack-machine IR has no abundant virtual
registers to fold copies through. Every binary op shuttles values
through fixed RAX/RCX positions — there are no `add y, z` → `add
x, z` rewrites to perform. The classical copy-prop wins simply
don't translate.

**Recon data**:
- v5.6.18: 110 raw `LOAD_LOCAL(x), STORE_LOCAL(y)` patterns on
  cc5 self-compile.
- v5.6.19: 18 actual rewrites that survive per-BB invalidation
  through STOREs/CALLs/&local. Direct savings: 0 B (LOAD-for-LOAD
  is byte-equal). Cascade-target dead stores newly orphaned by
  the rewrites: **1**.
- Pre-set gate (in v5.6.18 entry): "Bails if cascade adds < 5 new
  dead stores." 1 < 5 → bail.

**When to revisit**: after v5.6.19 linear-scan regalloc lands.
With cross-BB liveness data and actual virtual registers, copy
chains can span BBs and the cascade math changes — copy-prop
might earn its keep alongside register-renaming opportunities
the regalloc surfaces.

### Extended dead-store elimination (cross-BB)

**Status**: deferred 2026-04-23 after v5.6.19 recon.

**Why deferred**: v5.6.18 ships the per-BB "STORE_LOCAL(x), [no
read], STORE_LOCAL(x)" pattern (15 kills). The natural extension
— "STORE_LOCAL(x) never read till function exit" — needs cross-BB
liveness to be safe. Cyrius doesn't have cross-BB liveness yet.

**Recon data**:
- v5.6.19: a naive "scan to BB terminator" version finds 2,409
  candidates — but most are spurious because they ignore that
  JMP/JCC/JMP_BACK flow to a successor BB where the local IS
  read.
- Tightening to RET/EPILOGUE-terminated BBs only: **0**
  candidates. By the time you're at a function-return BB, all
  upstream stores have already been read into the return path.
- Per the gate (same as copy-prop): 0 < 5 → bail.

**When to revisit**: same as copy-prop — after v5.6.19 regalloc
lands cross-BB liveness. With a proper liveness-out set per BB,
extended-DSE can safely catch genuine "computed-but-never-used"
locals.

### Why we tried both at v5.6.19 and bailed

Both passes share a common dependency: cross-BB data-flow analysis.
v5.6.x optimization arc deliberately stayed within per-BB scope
(LASE, const-fold, DCE, DSE) because the cross-BB version of any
of them needs liveness machinery that v5.6.19 regalloc will build.
Trying copy-prop or extended-DSE before regalloc means duplicating
that machinery for one-off use — high LOC for low payoff. Better
to wait for the natural precondition.

The recon work isn't wasted: if/when revisited, the implementation
plan already exists (`ir_copyprop_recon` and `ir_extdse_recon`
prototypes lived in `src/common/ir.cyr` during v5.6.19 evaluation,
and the data structures + gate criteria are documented above).

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

## v5.7.0 — sandhi fold + lib/ cleanup (clean-break consolidation)

**The clean-break fold.** Per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md) (2026-04-24):

- Stdlib **adds** `lib/sandhi.cyr` vendored from sandhi's `dist/sandhi.cyr`
- Stdlib **deletes** `lib/http_server.cyr` — no alias, no passthrough, no empty stub
- Both changes land in the same release — one event, one tag

v5.7.0 is the consolidation release for the v5.7.x minor; RISC-V rv64 (originally scheduled as v5.7.0) slides to [v5.7.1](#v571--risc-v-rv64) on 2026-04-24. A new architecture port doesn't ride with a lib/ reshape — separate minor-patches for separate kinds of change, and the fold has its own acceptance gates that wouldn't compose cleanly with a cross-architecture port landing simultaneously.

**Scope:**

- **Vendor `dist/sandhi.cyr`** from sandhi's M5-complete release (sandhi v1.0.0) into `lib/sandhi.cyr`.
- **Delete `lib/http_server.cyr`** — its content has been canonical in `sandhi::server` since sandhi v0.2.0 (M1, 2026-04-24); stdlib's copy has been redundant-but-unchanged through the 5.6.x window, with a 5.6.YY deprecation warning (see prerequisite below) giving downstream consumers advance notice.
- **Propagate consumer-side migration** — downstream repos (yantra, hoosh, ifran, daimon, mela, vidya, sit-remote, ark-remote) land 5.7.0-compatible tags switching `include "lib/http_server.cyr"` → `include "lib/sandhi.cyr"` and dropping `[deps.sandhi]` git pins in favor of the stdlib include.
- **Document the lib/ reshape** — CHANGELOG entry enumerates every deleted symbol from `lib/http_server.cyr` (now accessible via `sandhi::server::*`), every added symbol exposed via `lib/sandhi.cyr`, and any additional redundant lib/ objects surfaced during the 5.6.x consumer sweep that are being retired in the same release.
- **Retire the sandhi repo to maintenance mode** — subsequent patches land via the Cyrius release cycle, not sandhi releases. The sandhi repo keeps its git history as historical reference; no new tags cut post-fold.

**Prerequisites that must ship before v5.7.0:**

- **sandhi M2–M5 complete** — the public surface freezes at fold, so all planned verbs must ship as part of a sandhi release and be exercised by at least one consumer before the fold lands. No speculative surface goes into stdlib.
- **v5.6.YY deprecation-warning patch** — stdlib's `lib/http_server.cyr` emits a deprecation warning at include-time through at least one 5.6.YY release, naming `lib/sandhi.cyr` as the replacement and v5.7.0 as the cutover. Consumers hitting that warning have a release cycle's worth of notice. Slot TBD by the cyrius agent during the late-v5.6.x window.
- **Consumer-side dual-build readiness** — every named downstream repo (yantra, hoosh, ifran, daimon, mela, vidya, sit-remote, ark-remote) has a branch ready to switch includes at the 5.7.0 release gate.
- **`cyrius distlib` produces self-contained `dist/sandhi.cyr`** — verified clean-build from the sandhi repo at its M5-final tag, with no transitive-dep surprises.

**Acceptance gates:**

1. `lib/sandhi.cyr` exists in stdlib, byte-identical to `dist/sandhi.cyr` at the fold commit.
2. `lib/http_server.cyr` is absent from stdlib — `ls lib/http_server.cyr` returns no such file.
3. No AGNOS repo has `[deps.sandhi]` pinned in `cyrius.cyml` on a 5.7.0-compatible tag.
4. No AGNOS repo has `include "lib/http_server.cyr"` on a 5.7.0-compatible tag.
5. sandhi repo is tagged v1.0.0 (M5-complete) and its next commit marks maintenance-mode entry.
6. CHANGELOG entry enumerates the deleted + added symbols per the "document the lib/ reshape" scope item.

**Why bundle lib/ cleanup with sandhi fold rather than run two separate releases**: consumer-side migration work is the same shape whether stdlib is reshaping 1 file or N. One release, one migration, one CHANGELOG entry naming the whole reshape — consumers audit once, not repeatedly.

---

## v5.7.1 — RISC-V rv64

First-class RISC-V 64-bit target. Elevated from the v5.5.x
pillar list to its own minor on 2026-04-20, then slid from v5.6.0
to v5.7.0 on 2026-04-20 (same day) so the compiler-optimization
arc (v5.6.x) lands first; **slid again from v5.7.0 to v5.7.1 on
2026-04-24** so v5.7.0 can ride the sandhi fold + lib/ cleanup
as its own consolidation moment. Rationale: a new architecture
is structurally different from v5.5.x items (correctness /
completion / runtime work on existing platforms) *and* different
from v5.7.0's lib/-reshape work — separate minor-patches for
separate kinds of change. RISC-V needs:

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

**Prerequisites that must ship before v5.7.1 starts:**
- **v5.6.5 + v5.6.7–v5.6.21** — Compiler optimization arc. New port
  should inherit an optimized compiler, not one still queueing
  baseline optimization. v5.6.20 (maximal-munch) in particular
  matters — rv64 backend lands its tile table against the new
  walker on day one instead of retrofitting.
- **v5.6.28** — shared-object emission landed (audit rough edge
  closed before new port opens).
- **v5.6.29** — downstream ecosystem sweep gate complete.
- **v5.7.0** — sandhi fold + lib/ cleanup lands first. RISC-V
  port inherits the post-fold stdlib shape so the rv64 backend
  never has to carry legacy `lib/http_server.cyr`-era symbol
  mappings.
- **v5.4.19 `#ifplat`** direction is live → RISC-V dispatch
  uses the new syntax from day one, no legacy `#ifdef
  CYRIUS_ARCH_RISCV64` sites to migrate.

Deliberately NOT bundling other items into v5.7.1 — a new
architecture port is plenty of work on its own, and mixing it
with runtime correctness fixes or library reshapes would obscure
which changes caused which regressions.

---

## v5.7.x — patch slate (post-RISC-V)

Pinned items for the v5.7.x cycle, slot numbers assigned **during
the port** as RISC-V porting work surfaces additional items that
also need to land. Single-issue patches in the v5.4.x / v5.5.x
style — one focused fix per release, no grab-bags. The pinned
items below are guaranteed to ship before v5.7.x closeout; the
specific patch number depends on what else surfaces.

### v5.7.x — `cyrius deps` transitive resolution

**Pinned 2026-04-23.** `cyrius deps` currently resolves only
**direct** dependencies from `cyrius.cyml`'s `[deps]` table — if
the user's manifest pins `mabda`, mabda's own `cyrius.cyml`
depends on `sigil` and `sakshi`, those transitive deps don't get
fetched. Today the workaround is to add every transitive dep to
the consumer's manifest by hand, which means downstream consumers
duplicate the dep tree of every dep they pull in. Brittle, and a
real onboarding pain for new ecosystem repos.

**Surfacing consumer**: `sit` (2026-04-23) hit this directly
during onboarding — same shape every new consumer has hit since
the `cyrius deps` resolver shipped. Confirms the fix is
load-bearing for ecosystem ergonomics, not a nice-to-have.
User-confirmed long-term fix; deliberately NOT pulled into v5.6.x
(optimization arc), v5.7.0 (sandhi fold single-focus), or v5.7.1 (RISC-V single-focus).

**Scope** (~200–400 LOC):

- **Recursive walker** in `cyrius deps`: after resolving a direct
  dep, parse that dep's own `cyrius.cyml` and queue its `[deps]`
  for resolution. BFS, not DFS, so the user's direct deps win
  version conflicts over transitive ones (lockfile-style).
- **Cycle detection**: maintain a visited-set keyed by repo URL
  (or `name@version`); skip re-resolving any dep already in the
  graph. Hard-error on a true cycle (A→B→A).
- **Version-conflict resolution**: when transitive deps disagree
  on a sub-dep version, the policy is **"closest wins"** (the
  version pinned closest to the root, like npm/cargo's default).
  If two deps at the same depth disagree, hard-error and ask the
  user to pin a resolution explicitly in their own manifest.
- **Lockfile** (`cyrius.lock` or `.cyrius/lock.cyml`): records
  the resolved graph (every dep, every version, every transitive
  edge). `cyrius deps` consults it on subsequent runs for
  reproducibility; `cyrius deps --update` recomputes.
- **Auto-include extension**: `cyrius build`'s auto-prepend
  pass already iterates direct deps' `lib/`; extend it to also
  iterate transitive deps in topological order so transitive
  symbols resolve correctly.
- **Diamond dep detection**: when A depends on B and C, and both
  B and C depend on D at the same version, dedupe to a single D
  install (don't double-include).

**Acceptance gates:**

1. New tcyr regression `tests/tcyr/deps_transitive.tcyr` —
   construct a 3-level dep chain (A→B→C), run `cyrius deps` in
   A, verify all three populate under `lib/`.
2. Cycle detection: A→B→A produces a clear error message naming
   the cycle, not silent infinite recursion.
3. Version-conflict policy: closest-wins documented + tested.
4. Lockfile reproducibility: `cyrius deps` after lockfile commit
   produces an identical `lib/` tree on a fresh checkout.
5. All existing downstream repos (mabda, sigil, sakshi, yukti,
   kybernet, hadara, libro, argonaut, agnostik, agnosys, sit)
   build green after switching to transitive resolution — no
   manifest in the ecosystem should still be hand-listing
   transitives.

**Slot assignment**: deferred to during the v5.7.x cycle. The
RISC-V port will surface other items (compiler bugs, stdlib
gaps, tooling friction) that also need slotting; the patch
order falls out naturally once we see the actual surfacing
sequence. Acceptable bound: ships before v5.7.x closeout.

### v5.7.x — `cyrius init` library-vs-binary awareness

**Pinned 2026-04-23.** `cyrius init <name>` currently emits the
binary shape unconditionally: `[build] entry = "src/main.cyr"`,
`output = "<name>"`, `src/main.cyr` with top-level `main()` + `var
exit_code = main(); syscall(60, exit_code);`. For library crates
(the larger share of AGNOS shared crates — mabda, sigil, sankoch,
patra, yukti, vyakarana, yantra, and many more), this is the wrong
shape. The library pattern that's emerged organically across
those 7+ repos is:

```toml
[build]
entry = "programs/smoke.cyr"
output = "build/<name>-smoke"

[lib]
modules = ["src/main.cyr", ...]   # driven by `cyrius distlib` → dist/<name>.cyr
```

Every new library scaffold currently requires hand-rewriting the
scaffold output to this shape. yantra (2026-04-23) was the latest
instance; the meta agent rewrote four places in `cyrius.cyml` +
created `programs/smoke.cyr` + stripped the top-level `main()`
from `src/main.cyr` to convert the binary scaffold into the
library shape.

**Surfacing consumers**: yantra (2026-04-23), sit (2026-04-23 —
stayed binary, correctly), and every future library scaffold.

**Scope** (~100–200 LOC in `scripts/cyrius-init.sh` or wherever
`cyrius init` lives):

- **Flag-based selection**: `cyrius init --lib <name>` emits the
  library shape; `cyrius init --bin <name>` emits the current
  binary shape; bare `cyrius init <name>` defaults to `--bin` for
  backward-compat (or prompts — designer's call).
- **Library template**: `cyrius.cyml` with `[build] entry =
  "programs/smoke.cyr"` + `[lib] modules = ["src/main.cyr"]`.
- **Library `src/main.cyr`**: no top-level `main()` / syscall —
  just a header comment explaining it's a library module.
- **`programs/smoke.cyr`**: the compile-link proof program
  matching the mabda / sigil / sankoch convention (one-line
  banner print + `syscall(60, 0)`).
- **`src/test.cyr`**: currently declared in scaffold output's
  `cyrius.cyml` but the file itself is never created. Either
  create a stub file or drop the `test = "src/test.cyr"` line
  from the scaffold. Minor ergonomic fix either way.

**Acceptance gates:**

1. `cyrius init --lib yantra_demo` in a clean directory emits a
   project that builds clean with `cyrius build
   programs/smoke.cyr build/yantra_demo-smoke` and produces a
   working `dist/yantra_demo.cyr` via `cyrius distlib`.
2. `cyrius init --bin foo` emits a project whose `cyrius build
   src/main.cyr build/foo` works and whose output binary runs and
   exits 0.
3. Bare `cyrius init foo` emits something (pick a default),
   documented in help text.
4. The `test = "src/test.cyr"` line either references an existing
   stub file or is omitted from the scaffold's `cyrius.cyml`.

**Slot assignment**: during the v5.7.x cycle, after RISC-V
baseline stabilizes. Low risk, self-contained.

### v5.7.x — `cyrius init` / `cyrius port` first-party-documentation.md alignment

**Pinned 2026-04-23.** The `first-party-documentation.md` standard
([agnosticos/docs/development/applications/first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md))
was formalized 2026-04-23 and specifies the baseline `docs/` tree
every AGNOS repo should carry from day one: `docs/adr/` (with
`README.md` + `template.md`), `docs/architecture/` (with
`README.md`), `docs/guides/`, `docs/examples/`,
`docs/development/roadmap.md`, `docs/development/state.md`. Plus a
`CLAUDE.md` at the repo root following the durable-vs-volatile
split that cyrius/CLAUDE.md established as the gold standard.

`cyrius init` today emits only a bare `README.md`, `CHANGELOG.md`,
`LICENSE`, `VERSION`, `cyrius.cyml`, `.gitignore`, `build/`,
`docs/` (empty), `lib/`, `scripts/`, `src/`, `tests/`. None of the
first-party-documentation.md subtrees or the CLAUDE.md template are
scaffolded. The meta agent rewrote all of these by hand on sit
(2026-04-23) and yantra (2026-04-23), plus pasted the ADR
conventions + `template.md` from sit's hand-written version both
times. `cyrius port` has the same gap — ported projects don't
land with the standard doc shape.

**Surfacing consumers**: sit, yantra (2026-04-23), and every
future repo scaffolded or ported until the tooling catches up.

**Scope** (~200–300 LOC in scaffold templates):

- `docs/adr/README.md` + `docs/adr/template.md` — standard index
  + the 5-section template (Status/Date, Context, Decision,
  Consequences, Alternatives considered). Templates in
  [sit/docs/adr](https://github.com/MacCracken/sit/tree/main/docs/adr)
  and [yantra/docs/adr](https://github.com/MacCracken/yantra/tree/main/docs/adr)
  can be lifted directly.
- `docs/architecture/README.md` — standard header explaining
  *"non-obvious constraints and quirks a reader cannot derive
  from the code alone; numbered chronologically, never renumber"*.
- `docs/guides/getting-started.md` — stub with project-name
  placeholders.
- `docs/development/roadmap.md` — stub with v1.0-criteria
  section.
- `docs/development/state.md` — stub following cyrius/docs/
  development/state.md's shape (Version / Toolchain / Source /
  Tests / Dependencies / Consumers / Next).
- **`CLAUDE.md` at repo root** — fill `{project}` placeholders
  from the example_claude.md template
  ([agnosticos/docs/development/applications/example_claude.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/example_claude.md)).
  Durable content only; "Current State" is a pointer block into
  `docs/development/state.md`, not inlined state.
- **`cyrius port` parity** — when a Rust project is ported in,
  scaffold the same doc tree alongside the moved `rust-old/`.

**Acceptance gates:**

1. `cyrius init --lib foo` emits a project whose `docs/adr/`,
   `docs/architecture/`, `docs/guides/`, `docs/examples/`,
   `docs/development/` all exist with correct README/template
   contents.
2. A CLAUDE.md is emitted, containing no inlined state — the
   "Current State" section points at `docs/development/state.md`.
3. `cyrius port /some/rust/project` scaffolds the same tree.
4. The existing scaffolded repos that pre-date the standard
   (sit, yantra) match what new scaffolds now emit — cross-check
   with a diff against their hand-written versions.

**Relationship to the `cyrius init` ergonomic fixes at v5.6.22/
v5.6.23** — those are 5 specific fixes surfaced by owl during its
bootstrap; this is a broader alignment sweep on top of them. The
v5.6.22/23 fixes land first; this item assumes they've landed.

**Slot assignment**: during the v5.7.x cycle, after the
library-vs-binary item ships (depends on the scaffold template
format landed by that item).

### ~~v5.7.x — `lib/http.cyr` depth~~ — **RETIRED 2026-04-24, moved to sandhi**

**Pinned 2026-04-23; retired 2026-04-24** in favor of the sandhi sibling-crate approach. The full method surface (POST/PUT/DELETE/PATCH/HEAD), custom headers, HTTPS unification, redirect following, chunked transfer, and HTTP/1.1 upgrade all land in `sandhi::http::client` — the service-boundary layer scaffolded 2026-04-24 at [MacCracken/sandhi](https://github.com/MacCracken/sandhi).

**Why the move**: stdlib stays thin (GET-only + CRLF hardening + the shared-over-TLS primitives in `net.cyr` / `tls.cyr`); the depth downstream consumers (yantra, sit-remote, ark-remote) actually need lives in sandhi and folds into stdlib as `lib/sandhi.cyr` at **Cyrius v5.7.0** per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md) — the clean-break consolidation release. Precedent: sakshi / mabda / sankoch / sigil all started as sibling crates and folded the same way.

**Net effect on the cyrius roadmap**: this item is removed from the v5.7.x patch slate. See `sandhi`'s [ADR 0001](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0001-sandhi-is-a-composer-not-a-reimplementer.md) for the composer-not-reimplementer thesis and the full scope moved.

### v5.7.x — `lib/json.cyr` depth (stdlib baseline — RPC-grade scope moved to sandhi 2026-04-24)

**Pinned 2026-04-23; narrowed 2026-04-24** — RPC-grade handling (WebDriver / Appium response parsing, streaming large payloads, dialect-aware error envelopes) moved to `sandhi::rpc` along with the `lib/http.cyr depth` item. This slot retains the stdlib-baseline enrichment: deeper parsing for config / data files, safer error reporting, array support. The surfacing consumers for *baseline* json.cyr depth are cyml / toml parity, config loading, and data-file pipelines — not network RPC.

`lib/json.cyr` today supports a basic key-value pair parse and build with `json_parse(src)`, `json_get(pairs, key)`, `json_get_int(...)`, `json_build(pairs)`, `json_pair_new(key, value)`. What's thin for config / data use cases: nested objects, arrays, JSON numbers beyond int, booleans, null, and escaped string values. Streaming large payloads is deferred to v5.8.x+ or owned by `sandhi::rpc` since that's the consumer shape for multi-MB response bodies.

**Surfacing consumers (baseline scope)**: any crate reading / writing structured JSON config or data (not RPC responses — those go through sandhi).

**Scope** (~400–600 LOC):

- **Nested objects**: `json_get_obj(pairs, key)` returns a
  nested pair list. Recursion depth limit (default 32) with
  hard-error on overrun — defense against stack-smashing
  malicious input.
- **Arrays**: `json_get_array(pairs, key)` returns an array
  struct; `json_array_len(arr)`, `json_array_get(arr, idx)` for
  element access.
- **Type coverage**: booleans (`json_get_bool`), null (separate
  sentinel value vs "missing key"), floats/doubles
  (`json_get_double`), negative numbers (currently `atoi`-only —
  add signed support).
- **String escape handling**: `\n`, `\t`, `\"`, `\\`, `\uXXXX`
  on both parse and build paths. Today's parser silently breaks
  on escaped quotes inside strings.
- **Build path**: `json_build` today builds flat key-value
  objects. Extend to nested: `json_build_obj(pairs)`,
  `json_build_array(values)`.
- **Streaming parse**: **moved to `sandhi::rpc` 2026-04-24** — multi-MB streaming responses are an RPC-consumer concern (CDP debugger payloads, WebDriver trace responses), not a stdlib-baseline concern. Remains v5.8.x-deferrable from the sandhi side.
- **Error reporting**: currently `json_parse` returns 0 on
  failure — no position info, no reason. Add
  `json_parse_err(src)` variant that returns a parse-error
  struct with line/column/reason.

**Acceptance gates** (baseline scope — config / data files):

1. `json_parse` correctly handles a deeply-nested object (e.g. a
   multi-level application config file with nested sections).
2. Array access works on a real data file (e.g. a list of device
   records from `yukti` or a log-event array).
3. Escape handling: `"\"hello\\nworld\""` parses as the
   4-char string `"hel\no"` with proper quote.
4. Build round-trip: `json_build(json_parse(src))` produces
   byte-identical output for a canonical corpus.
5. Recursion depth limit: 33-deep input returns a parse error,
   not a segfault.
6. All existing `json_parse` consumers still pass.

**Out of scope for this item**: RPC dialect acceptance (WebDriver session-create, Appium findElements, MCP-over-HTTP responses) — those live in `sandhi::rpc` acceptance tests and can land in parallel.

**Slot assignment**: during the v5.7.x cycle. Narrowed scope makes this land faster; can land in parallel with sandhi's independent implementation work.

---

## v5.8.0 — Bare-metal / AGNOS kernel target

Bare-metal output (no libc, no syscalls, direct hardware). AGNOS
kernel is the concrete consumer. Slid with the optimization minor
insert (was v5.7.0 pre-v5.6.x pin). Details pinned closer to
landing — rough scope: ELF no-libc output format, interrupt-handler
emit conventions, kernel-mode syscall stubs stripped, boot pipeline
from `scripts/boot.cyr` landed in genesis Phase 13B (v5.6.29 gate).

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
  `lib/sandhi.cyr` (which now owns `::server` — formerly `lib/
  http_server.cyr` pre-sandhi-fold). These benefit most from
  per-request arenas.
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
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Narrow-scope byte-identity green**; broad-scope self-host on M-series was verified v5.3.13 era — **currently broken on Sequoia 15+** (platform drift, bytes unchanged, pinned **v5.6.26**) |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 (older build) |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Narrow-scope byte-identity green** (v5.5.10 md5-match on exit42 + multi-fn add); broad-scope runtime **currently broken on Win11 24H2** (build 26200+) (platform drift, bytes unchanged, pinned **v5.6.27**) |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | v5.5.13–v5.5.17 broad-scope verified on ecb at the time; **currently broken on Sequoia 15+** (see v5.3.0–v5.3.18 row; same platform drift, pinned **v5.6.26**) |
| **v5.5.18–v5.5.22** | aarch64 Linux shakedown + SSE alignment | ELF | **Done** — multi-thread + contended mutex on real Pi 4 |
| **v5.5.34** | fdlopen foreign-dlopen completion | ELF | **Done** — 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` |
| **v5.5.35** | Windows PE .reloc + 32-bit ASLR | PE/COFF | **Done** — `DYNAMIC_BASE` DLL Characteristic; HIGH_ENTROPY_VA deferred (see Active Bugs) |
| **v5.5.36** | Windows Win64 ABI completion | PE/COFF | **Done** — struct-return via hidden RCX retptr + __chkstk via R11 + variadic float dup |
| **v5.7.1** | RISC-V rv64 | ELF | Queued (slid from v5.7.0 on 2026-04-24 so sandhi fold rides v5.7.0; slid from v5.6.0 originally so optimization minor lands first) |
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
| `cyrius init` scaffold gaps (owl) | **v5.6.22** | Small |
| Libro layout-corruption investigation | **v5.6.23** | Investigation |
| `cc5_win.exe` HIGH_ENTROPY_VA re-investigation | **v5.6.24** | Investigation |
| Native aarch64 self-host repair (Pi) | **v5.6.25** | Investigation |
| macOS arm64 Mach-O platform drift | **v5.6.26** | Investigation |
| Windows 11 24H2 PE platform drift | **v5.6.27** | Investigation |
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
| Network | net, http, ws, tls (+ sandhi at v5.7.0 clean-break fold, absorbing http_server — see [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md)) |
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
| Linux aarch64 | ELF | **✅ Narrow** (cross-build byte-identity holds); **⚠️ Broad** — cross-built binary runs fine on Pi (`regression-aarch64-syscalls.sh` 5/5 PASS; `regression.tcyr` 102/102 at v5.3.18) but **native self-host on Pi fails** at parse time (`_TARGET_MACHO` undef; pinned **v5.6.25**). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | **✅ Narrow** (v5.1.0); Broad-scope not retested since. |
| macOS aarch64 | Mach-O | **✅ Narrow** (cross-build byte-identity holds; bytes unchanged since v5.5.13–v5.5.17); **❌ Broad** — cross-built `syscall(60, 42)` exits 1 instead of 42 on current Sequoia (macOS 15+). **Platform drift, not cyrius regression** — emitted Mach-O bytes are identical to what was verified exit=42 in v5.5.13. Pinned **v5.6.26**. |
| Windows x86_64 | PE/COFF | **✅ Narrow** — byte-identical fixpoint verified v5.5.10 (md5 match on exit42 + multi-fn add; cc5_win emits PE byte-identical to Linux cross-build). **❌ Broad** — on Windows 11 24H2 (build 26200+), PE `syscall(60, 42)` exits `0x40010080` and cc5_win.exe itself hits `ApplicationFailedException`. **Platform drift, not cyrius regression** — PE bytes unchanged since v5.5.10; Win11 24H2 tightened CET/CFG/ASLR loader enforcement. Pinned **v5.6.27**. Win64 ABI complete (v5.5.36); .reloc + 32-bit ASLR (v5.5.35); HIGH_ENTROPY_VA (64-bit ASLR) deferred — see Active Bugs. |
| Compiler optimization (O1–O6) | — | v5.6.5 ✅ + v5.6.7–v5.6.12 ✅ + v5.6.14 ✅ + **v5.6.15–v5.6.21** (NEXT: O3a-audit + O3b + O3c + O4–O6; v5.6.13 sha1 + v5.6.15 IR-order audit interleaved) |
| RISC-V (rv64) | ELF | Queued — **v5.7.1** |
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
- **sandhi repo extraction** (सन्धि — *junction, connection, joining*;
  named 2026-04-24, formerly the "services" placeholder) —
  `lib/http_server.cyr` extraction into `sandhi::server` landed
  at sandhi v0.2.0 (M1, 2026-04-24). **sandhi** is the
  service-boundary layer that composes stdlib primitives
  (`http.cyr`, `ws.cyr`, `tls.cyr`, `json.cyr`, `net.cyr`) into
  full-featured client patterns + service discovery.
  **Fold target: v5.7.0 clean-break** per [sandhi ADR
  0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md)
  — v5.7.0 stdlib deletes `lib/http_server.cyr` and adds
  `lib/sandhi.cyr` in one event; 5.6.YY releases carry a
  deprecation warning naming the cutover. Revised 2026-04-24
  from the original "before v5.6.x closeout" target after
  reconsidering the alias-window migration model.


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
  `_macho_wstr_pad`, `SYSV_HASH` (if v5.6.28 doesn't re-wire it).
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
