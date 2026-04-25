# Cyrius Development Roadmap

> **v5.7.1.** cc5 compiler (531,392 B x86_64, −11,536 B from v5.6.26
> via codebuf compaction; net +10,176 B vs v5.6.22 baseline = default-on
> regalloc save/restore minus compaction savings). Native aarch64 cc5
> output (Pi 4) is 503,328 B at v5.6.27 (was 497,008 at v5.6.25; the
> x86-only compaction code is dead-emitted on aarch64 builds — strip
> via `#ifdef CYRIUS_ARCH_X86` pinned as future cleanup). x86_64 +
> aarch64 cross + Windows PE cross + macOS aarch64 cross. IR + CFG.
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
>   local-var slot by `_cur_fn_regalloc * 8`. `parse_fn.cyr`
>   body-scan lookahead for token 48 (`asm`). cc5 521,216 →
>   522,624 B (+1,408 B). Default-on flip attempted, surfaced
>   second picker bug — fixed at v5.6.24.
> - **v5.6.24**: ✅ shipped — **Default-on regalloc**, two-bug fix.
>   (1) SysV `ECALLPOPS` for n>6 args used r12-r14 as scratch in
>   the stack-arg shuttle. Under v5.6.20+ regalloc the picker pinned
>   caller's locals to those callee-saved regs so 8+ arg calls
>   silently corrupted the locals. Surfaced as the sandhi-reported
>   "live-across-calls" boxing workaround AND the
>   `flags-test test_str_short → test_defaults` bisection
>   (AUTO_CAP=118 = `test_str_short` regalloc'd; its `_argv(...)`
>   9-arg call clobbered r12 holding fs in test_defaults). Rewrote
>   the SysV shuttle to use only r10 (caller-saved) via direct
>   `[rsp+offset]` addressing; no pops, end with `add rsp, 48`.
>   (2) Flipped `_ra_auto_cap` default from -1 (disabled) to
>   "uncapped". Every eligible fn (x86 + no asm) now gets auto-
>   regalloc'd. cc5 522,624 → 542,928 B (+20,304 B for save/restore).
>   check.sh 23/23 + all 84 .tcyr PASS. v5.6.25 (sandhi-issue
>   live-across-calls) consolidated here — same root.
> - **v5.6.25**: ✅ shipped — **aarch64 push/pop-cancel completion**
>   (scope retargeted from "aarch64 fused ops"). Bytescan under
>   default-on regalloc found 0 `mul+add` / 0 `lsr+and-mask`
>   adjacent pairs — cyrius's stack-machine IR keeps a push
>   between sub-expression results and their consumers, so the
>   originally-hoped-for regalloc-enabled fusion windows never
>   open without deeper IR work. But bytescan ALSO found **2,569**
>   adjacent `push x0; pop x0` pairs in native aarch64 cc5 — a
>   latent gap in v5.6.9's cancel mechanism. `EPOPARG(S, 0)`
>   (which emits the same `ldr x0, [sp], #16` as EPOPR) bypassed
>   the adjacency check, so every 1-arg call site paid 8 bytes.
>   Fix: 13 LOC in `src/backend/aarch64/emit.cyr::EPOPARG` — mirror
>   EPOPR's `GCP == _last_push_cp` rewind when `n == 0`. Native
>   aarch64 cc5 **517,376 → 497,008 B (−20,368 B / −3.94%)** —
>   bigger than v5.6.11's aarch64 combine-shuttle win. x86 cc5
>   unchanged. Fused-ops pattern pinned to a future v5.6.x slot if
>   a separate IR-level push-elision pass materializes.
> - **v5.6.26**: ✅ shipped — peephole refinement + v5.6.25
>   doc/CHANGELOG completion. The EPOPARG `n == 0` adjacency-cancel
>   block landed cleanly. Phase O5 maximal-munch dropped from the
>   optimization arc — recon found 0 fused-op candidates (cyrius's
>   stack-machine IR keeps a push between sub-expression results
>   and consumers); push-imm rewrite has rax-side-effect +
>   forward-jump-target issues. Pinned long-term, no slot — needs
>   an IR-level push-elision pass first.
> - **v5.6.27**: Phase O6 — codebuf compaction (NOP harvest).
>   Sweeps accumulated NOPs from LASE/const-fold/DCE/DSE
>   in one pass with jump+fixup repair. Real binary shrinkage.
>   Needs explicit NOP-position tracking at every NOP-emit site
>   and per-fn jump-source table — byte-scan for NOP signatures
>   false-positives on data bytes (immediates, disp32 fields). (Old
>   slab-allocator scope reclaimable as a future v5.7.x slot if
>   v5.6.20 regalloc benchmarks show bump-allocation hot.)
> - **v5.6.28**: `cyrius init` scaffold gaps (owl-surfaced — 5 fixes
>   in `cyrius-init.sh`).
> - **v5.6.29**: ✅ shipped — sandhi-surfaced `lib/tls.cyr` HTTPS
>   infinite-loop fix (symptom #3 of the sandhi M2 design report).
>   `_tls_init` now runs `dynlib_bootstrap_cpu_features` +
>   `_tls` + `_stack_end` before `dynlib_open("libcrypto.so.3")` /
>   `libssl.so.3`. Without it, IFUNC cipher selection in libcrypto
>   + `%fs:N` accesses in libssl handshake init faulted; init
>   returned 0 (looked-success) but `SSL_connect` entered a tight
>   retry loop. tls.tcyr 22/22, check.sh 23/23, no compiler change.
> - **v5.6.29-1**: ✅ shipped — undef-fn call sites now SIGILL at
>   the call site (ud2 on x86, UDF #0 on aarch64) instead of
>   leaving a `call rel32` placeholder that could resolve to
>   arbitrary executable bytes. Sandhi M2's "fdlopen blocked"
>   report was misdiagnosed on their side (missing
>   `include "lib/dynlib.cyr"` in probes, not an ld-linux
>   re-open collision); `fdlopen_init_full` itself has been
>   complete since v5.5.34 and tests/tcyr/fdlopen.tcyr 40/40
>   still passes. Stale v5.5.29 status block in fdlopen.cyr
>   replaced with current v5.5.34-complete text. Fix is purely
>   additive (byte-identical for every program that doesn't call
>   an undef fn); failure is now loud and localisable.
> - **v5.6.30**: ✅ shipped — preprocessor `#derive` reads past
>   the IFDEF-pass copy-back cap. `PP_DERIVE_*` handlers read
>   from `S + ip` which was capped at 524288 bytes; any
>   `#derive(accessors)` / `#derive(Serialize)` past that offset
>   got zeros instead of the real struct definition, wrote
>   garbage, and left a 0xff sentinel leaking through for LEX
>   to trip on. Fixed by threading `src_base` through
>   `PP_PARSE_STRUCT_DEF` + derive helpers so reads route from
>   the full `tmp` buffer in IFDEF_PASS context. libro 2.0.5
>   unblocked. Stale "libro layout-dependent memory corruption"
>   bug-tracker entry retired in the same slot — that symptom
>   was libro's own 2026-04-19 UAF fix (libro v1.1.0).
> - **v5.6.31**: ✅ shipped — HIGH_ENTROPY_VA `cc5_win.exe`
>   stdin-read failure root-caused. Was NOT a MOVABS-relocation
>   issue (the v5.5.35 audit chased a red herring). Real cause:
>   `EREAD_PE` and `EWRITE_PE` used `mov rax, [rsp+0x28]` to
>   load the post-call bytes-read/written count, but ReadFile /
>   WriteFile only write a DWORD (4 bytes) at that pointer.
>   Under DYNAMIC_BASE the upper 4 bytes happened to be zero;
>   under HIGH_ENTROPY_VA the Win11 loader hands over a stack
>   with garbage in those bytes and `n` came back as a 12-digit
>   bogus value. Fix: 64-bit load → 32-bit `mov eax` (auto
>   zero-extends rax). Default-on HIGH_ENTROPY_VA shipped.
> - **v5.6.32**: ✅ shipped — native aarch64 self-host on Pi
>   repaired. Root cause: `main_aarch64_native.cyr` was missing
>   `include "src/common/ir.cyr"` that the x86-hosted cross-
>   compiler (`main_aarch64.cyr`) received when v5.6.12 O3a IR
>   instrumentation shipped. 1-line include add closed the gap.
>   Native self-host fixpoint on Pi: `cc5_b == cc5_c` byte-
>   identical at 463,768 B. `tests/regression-aarch64-native-
>   selfhost.sh` flipped from skip-stub to active gate; wired
>   into `check.sh` as step 4o; PASS.
> - **v5.6.33**: macOS arm64 Mach-O platform drift (ecb) —
>   cross-built `syscall(60, 42)` exits 1 instead of 42. **Our
>   Mach-O bytes are unchanged since v5.5.13** (byte-identical
>   v5.6.10 ↔ v5.6.11 for this shape); what regressed is macOS
>   dyld's tolerance for the LC_DYLD_INFO bind opcodes / `__got`
>   alignment we emit. Sequoia 15+ enforces stricter than Sonoma
>   14.x that v5.5.13 was tested on.
> - **v5.6.34 ✅ shipped** (sit symptom 1 of 2): stdlib `alloc`
>   grow-undersize SIGSEGV. `lib/alloc.cyr` (Linux brk) +
>   `lib/alloc_macos.cyr` (mmap) grew by a fixed `0x100000`
>   step regardless of requested size; any `alloc(>1 MB)` near
>   the boundary returned a pointer past the brk/mmap →
>   SIGSEGV on first tail-write. Fix: Linux rounds to next
>   1 MB grain; macOS loops 1 MB mmaps preserving the per-step
>   contiguity guard. Windows separable (no grow path). New
>   gate `tests/tcyr/alloc_grow.tcyr` (10 assertions). cc5
>   unchanged (uses raw `brk`).
> - **v5.6.35 ✅ shipped** (sit symptom 2 of 2): `sit fsck`
>   memory anomaly at scale closed via sankoch dep bump
>   2.0.1 → 2.0.3. Triage 2026-04-24 eliminated patra, cyrius
>   alloc, and sit-side aliasing; pinned the bug to sankoch's
>   deflate encoder on sit-tree-shaped inputs. sankoch shipped
>   2.0.2 (51/53 fixed) then 2.0.3 (0/53 remaining). Cyrius
>   side: `cyrius.cyml` `[deps.sankoch]` pin bump + new active
>   `tests/regression-sit-status.sh` gate. Zero compiler
>   change; cc5 byte-identical at 531,680 B.
> - **v5.6.36 ✅ shipped**: `regression-pe-exit` gate fixture
>   repair — same exact misdiagnosis pattern as v5.6.33 on
>   the PE side. The `fn main() { syscall(60, 42); }` fixture
>   never entered `main()` (cyrius has no auto-call); entry
>   prologue branched over the dead body to `EEXIT_PE` →
>   `kernel32!ExitProcess(arg)` with whatever was in the
>   arg-slot register (= `0x40010080` on Win11 24H2).
>   PE shape is fine on Win11 24H2 (verified by patching
>   DllCharacteristics 0x0000 → 0x0160 and seeing
>   byte-identical exit behavior). Gate rewritten with
>   correct top-level syntax (3 tests: ExitProcess, WriteFile,
>   peephole). Zero compiler change.
> - **v5.6.37 ✅ shipped**: `SSL_connect` libssl pthread deadlock
>   closed. `dynlib_bootstrap_tls`'s zeroed TCB left libssl's
>   mutex `__kind` = 0 (non-recursive); OPENSSL_init_ssl's
>   same-thread re-entry deadlocked on a futex at TCB+0x118.
>   Fix: `lib/tls.cyr::_tls_init` routes libssl through
>   `fdlopen_init_full` which invokes ld.so to run a shim
>   through real `__libc_start_main` + `__libc_pthread_init`;
>   subsequent `dlopen("libssl.so.3")` loads against a
>   fully-initialised glibc. End-to-end verified: TLS
>   handshake + HTTP round-trip to `https://1.1.1.1/`
>   returns `HTTP/1.1 301 Moved Permanently`. Zero compiler
>   change. **BREAKING:** consumers now need
>   `include "lib/fdlopen.cyr"` before `include "lib/tls.cyr"`
>   (1-line migration).
> - **v5.6.38 ✅ shipped**: shared-object emission slot —
>   verify-premise check (per v5.6.33/v5.6.36 lessons) showed
>   `.so` emission already complete since v5.5.x. Slot
>   deliverable: dead `SYSV_HASH` removed (the chain-lookup
>   uses pure strcmp per SysV spec + glibc dl-lookup.c, not
>   hash comparison; `nbucket=1` makes the hash genuinely
>   unused). cc5 −320 B. `regression-shared.sh` (already
>   shipping) continues PASS.
> - **v5.6.39 ✅ shipped**: `cc5 --version` drift repair +
>   hardcoded-literal removal. Caught via Starship prompt
>   observation — cyrius repo bumped to v5.6.38 but
>   `cc5 --version` still said `5.6.29-1` (drifted across
>   9 releases). Root cause: `version-bump.sh`'s sed regex
>   `[0-9]+\.[0-9]+\.[0-9]+\\n` didn't match the `-N` hotfix
>   suffix; once 5.6.29-1 baked the literal in `src/main.cyr`,
>   every subsequent bump silently failed. Fixed by removing
>   the hardcoded-literal class entirely: new auto-generated
>   `src/version_str.cyr` is the single source of truth;
>   `main.cyr` + `main_win.cyr` include it and reference the
>   vars. cc5 rebuilt; `cc5 --version` reports current.
> - **v5.6.40 ✅ shipped**: `lib/tls.cyr` ALPN/mTLS/custom-
>   verify hook surface. Sandhi-pinned per
>   `sandhi/docs/issues/2026-04-24-stdlib-tls-alpn-hook.md`,
>   Option A. Adds `tls_dlsym(name)` (resolves any libssl/
>   libcrypto symbol via the fdlopen-managed handle) +
>   `tls_connect_with_ctx_hook(sock, host, hook_fp, hook_ctx)`
>   (hook runs after SSL_CTX_new + stdlib's verify defaults,
>   before SSL_new / handshake). `tls_connect` becomes a 1-line
>   wrapper. End-to-end verified: ALPN `h2,http/1.1` on
>   1.1.1.1:443 → server picks h2.
> - **v5.6.41** (was v5.6.40 → v5.6.41): v5.6.x closeout +
>   downstream ecosystem sweep gate (agnos, kybernet, argonaut,
>   agnosys, sigil, ark, nous, zugot, agnova, takumi). **Last
>   patch of v5.6.x.** Fold in `PP_DEFINE` / `PP_DEFINED`
>   `src_base` hardening (same shape as v5.6.30's derive-helper
>   fix — latent same-class bug, no observed in-the-wild
>   trigger yet).
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
> - **v5.7.0**: ✅ SHIPPED 2026-04-25 (cyrius side). **sandhi fold + lib/ cleanup** — `lib/http_server.cyr` deletes, `lib/sandhi.cyr` adds, per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md). Gates 1, 2, 3, 5, 6 ✅; gate 4 (downstream sweep) is separate user-organized work.
> - **v5.7.1**: ✅ SHIPPED 2026-04-25. **fixup-table cap bump 32K → 262K** (8×). sit-blocking ecosystem unblock per [sit's proposal](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md); unblocks all 8 named sandhi consumers from `[deps].stdlib "sandhi"` overflow. Wedged ahead of cyrius-ts foundational work via git-rewind + fixup-cap commit + cherry-pick of preserved cyrius-ts P1 work.
> - **v5.7.2**: **cyrius-ts foundational** — TypeScript frontend (sync, non-TSX subset) for SY-port-clean. Resumes the cyrius-ts P1 work cherry-picked back from `wip/cyrius-ts-p1` after the v5.7.1 fixup-cap wedge. Scope is data-driven from a 2026-04-25 SY TS inventory (2,053 sync TS files / 94,324 LOC); async + JSX explicitly defer to v5.7.3.
> - **v5.7.3**: **cyrius-ts completion** — async runtime (`async`/`await`/`Promise` for the 73% of SY TS files using them) + JSX scope decision (likely "explicitly NOT supported"; SY's 435 TSX files stay in SY's web-frontend track). Pinned 2026-04-25.
> - **v5.7.4**: RISC-V rv64 port (inherits optimized compiler + post-fold stdlib shape + bumped fixup table + cyrius-ts foundational + completion). Slid across 2026-04-24/25 as sandhi fold/cyrius-ts/fixup-cap took priority slots in turn.
> - **v5.8.0**: bare-metal / AGNOS kernel target.
> - **v5.9.0–v5.9.x**: medium language additions — first-class
>   slices (`slice<T>` / `[T]` generalizing `Str`) and per-fn effect
>   annotations (`#pure`, `#io`, `#alloc`).
>
>   **Removed from this roadmap (2026-04-24)**: pure-Cyrius TLS 1.3
>   arc (X25519 + ChaCha20-Poly1305 + record layer + handshake,
>   `libssl.so.3` dynlib bridge retirement). Per the sandhi
>   scope-absorption decision — TLS work belongs outside Cyrius's
>   compiler/stdlib roadmap; `lib/tls.cyr` continues to use the
>   `libssl.so.3` bridge indefinitely from stdlib's perspective.
>   Canonical home for the pure-Cyrius TLS implementation work to
>   be confirmed in the next Cyrius-agent cleanup pass and pointed
>   at from here.
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
> - **v5.13.x**: **polymorphic codegen** — security hardening
>   (code diversification / anti-ROP defense; post-v1.0 work per
>   `docs/development/threat-model.md`). Slotted 2026-04-25 after
>   surfacing as a deferment-gap during the v5.7.x cleanup pass —
>   documented in memory and threat-model.md but had no roadmap
>   slot until now. **Pre-v6.0** per the original plan: last v5.x
>   feature minor before the `cc5 → cyc` rename, so the rename
>   doesn't have to also re-baseline a hardening minor. Originally
>   estimated 14 weeks; corrected to ~4–6 weeks at observed Cyrius
>   velocity. Detailed scope/acceptance gates live in
>   `docs/development/threat-model.md`; this slot pin is the
>   work-driving artifact entry.
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

No active bugs at present. The 13-row table that lived here
(all pinned to v5.6.13–v5.6.37 slots) is **all shipped** as of
v5.6.39 — see
[completed-phases.md § v5.6.0–v5.6.39](completed-phases.md#v560v5639--polish--optimization-arc--bug-fixes-closeout-v5640-active)
for one-liner archive entries and
[CHANGELOG.md](../../CHANGELOG.md) for full per-release detail.

When a new bug surfaces: add a row pinned to a concrete v5.6.x
slot here. No "investigate" / "future work" phrasing without a
patch number. If an investigation doesn't yield, STOP and ask —
never slip, defer, or re-slot unilaterally.

<!-- archived rows (v5.6.13 sha1, v5.6.14 ir_lase, v5.6.28 cyrius
init, v5.6.29 tls.cyr HTTPS, v5.6.29-1 fdlopen-undef-fn, v5.6.30
preprocessor #derive cap, v5.6.31 HIGH_ENTROPY_VA stdin,
v5.6.32 native aarch64 self-host, v5.6.33 macho-exit fixture,
v5.6.34 alloc grow-undersize, v5.6.35 sit fsck / sankoch,
v5.6.36 pe-exit fixture, v5.6.37 SSL_connect futex) all SHIPPED;
narratives in completed-phases.md. -->

| Bug | Impact | Pinned slot |
|-----|--------|-------------|
| _(empty — no active bugs as of v5.6.39)_ | | |

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

## v5.6.x — Active (closeout v5.6.41 only)

All v5.6.x slots through v5.6.40 are shipped. Per-slot detail
narratives have been moved to
[completed-phases.md § v5.6.0–v5.6.40](completed-phases.md#v560v5640--polish--optimization-arc--bug-fixes-closeout-v5641-active).
[CHANGELOG.md](../../CHANGELOG.md) is the source of truth for
the full per-release detail. Only the active closeout slot
remains in this file.

### v5.6.40 — `lib/tls.cyr` ALPN/mTLS hook surface ✅ SHIPPED

Sandhi-blocking surface gap. `lib/tls.cyr` exposed
`tls_connect(sock, host)` only — callers had no way to set
ALPN protocols, install a custom verify callback, or pin a
client cert before handshake. Sandhi was waiting on this
since 2026-04-24
(`sandhi/docs/issues/2026-04-24-stdlib-tls-alpn-hook.md`,
Option A: fn-pointer hook).

**What shipped**:
- `_tls_libssl_handle` — global, set inside `_tls_init` to the
  fdlopen-managed `libssl.so.3` handle. Read by `tls_dlsym`.
- `tls_dlsym(name)` — resolves any libssl/libcrypto symbol via
  the same handle `_tls_init` already holds. Returns 0 if TLS
  isn't initialized or the symbol isn't found. No new fdlopen
  bootstrap on the call path.
- `tls_connect_with_ctx_hook(sock, host, hook_fp, hook_ctx)` —
  identical to `tls_connect` but invokes
  `hook_fp(hook_ctx, ssl_ctx)` after `SSL_CTX_new` + the
  stdlib's verify defaults but BEFORE `SSL_new`. Hook returns
  non-zero to abort. Caller-driven configuration without any
  stdlib-side knowledge of ALPN/mTLS specifics.
- `tls_connect(sock, host)` — refactored to a 1-line wrapper:
  `return tls_connect_with_ctx_hook(sock, host, 0, 0);`. No
  behavior change for existing callers.

**Verification**: end-to-end ALPN probe to Cloudflare
1.1.1.1:443 advertising `h2,http/1.1` via
`SSL_CTX_set_alpn_protos` in the hook, then reading the
selected protocol via `SSL_get0_alpn_selected` after
handshake → server picked `h2`. `tests/tcyr/tls.tcyr` gained
4 assertions covering `tls_dlsym` (resolves
`SSL_CTX_set_alpn_protos`, resolves `SSL_get0_alpn_selected`,
returns 0 on unknown symbol, returns 0 when fdlopen helper
absent). check.sh 25/25.

**Sandhi side** (parallel): sandhi can now wire ALPN + mTLS
without forking `lib/tls.cyr`. Fold lands in v5.7.0 (sandhi
fold release) — the hook surface stays even after the fold,
so direct cyrius callers (non-sandhi HTTP libs, future ARK
supplicant code) can use it without going through sandhi.

### v5.6.41 — v5.6.x closeout (LAST patch of v5.6.x)

Last patch before v5.7.0 (sandhi fold + lib/ cleanup) and v5.7.2 (RISC-V) open. CLAUDE.md "Closeout Pass"
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
ai-hwaccel, seema). All of them wait on v5.6.41 and must complete
before v5.7.0 (sandhi fold) opens. Practical consequence: the closeout
carries extra rigor beyond the standard pass —

- **Heap-map cleanup** — not just verify; actively collapse any
  orphan allocations surfaced during the optimization arc. Leave
  no "temporary" arenas downstream would have to work around.
- **Refactor pass** — one targeted sweep for naming/API drift
  introduced across v5.6.0–v5.6.40. If a public function got
  reshaped mid-arc, this is the last chance to stabilize the name
  before downstream repos pin to it.
- **Audit pass** — dead code, stale comments, orphan tests,
  unused `#include` lines. Downstream sees this as the baseline
  they mirror in their own sweeps.
- **Downstream dep-pointer check** — walk every downstream repo's
  `cyrius.toml` / `cyrius.cyml` and verify they resolve cleanly
  against the v5.6.41 artifacts. Broken pins get fixed before
  v5.7.0 (sandhi fold) opens, not after.
- **Compiler surface freeze signal** — after v5.6.41 ships, public
  compiler API is frozen for the duration of the downstream sweep
  (approximately one minor cycle). v5.7.0 fold + v5.7.2 RISC-V can
  add, but not reshape, existing surface.
- **PP_DEFINE / PP_DEFINED `src_base` hardening** — fold in the
  same-class fix as v5.6.30's `PP_DERIVE_*` helper repair. The
  preprocessor's `#ifdef`-pass copies content back to `S+0`
  capped at 524288 B; helpers that read directly from `S+ip`
  past the cap leak heap garbage into the lex stream. v5.6.30
  fixed `PP_DERIVE_*`; `PP_DEFINE` / `PP_DEFINED` share the
  same shape and are a latent (not-yet-triggered) instance of
  the same bug. Tracked since v5.6.30.

Rationale: downstream projects are batching their own arch-neutral
work against this closeout. If v5.6.41 ships with loose ends, each
downstream repo absorbs the cost and the sweep fragments. One
tight closeout here is cheaper than N downstream workarounds.

---

## Long-term considerations (no version pin yet)

Items deferred without a v5.6.x or v5.7.x slot. Add to a future
minor only when the right preconditions land — typically when
v5.6.19 regalloc + cross-BB liveness machinery exists to make a
meaningful version land cleanly.

### `.gnu.hash` for shared-object emission

**Status**: deferred 2026-04-24 at v5.6.38 (during the slot's
verify-premise check). `.so` emission works correctly today
with the SysV `.hash` table (nbucket=1; chain walk does pure
strcmp per glibc `dl-lookup.c`). `.gnu.hash` is an optimization
that uses a Bloom filter pre-check to skip strcmp on misses;
modern linkers prefer it.

**Why deferred**: cyrius has zero current `.so` consumers
(sigil / mabda / yukti / kybernet all ship as static libraries
or source bundles). The optimization is purely speculative for
hypothetical future use. `.hash` works fine for the
small-symbol-count libraries cyrius emits today.

**Revisit when**: any cyrius consumer pins on `.so` output
and reports a measurable lookup-time cost from the linear
chain walk. At that point, `.gnu.hash` migration is a slot
that drops the SysV `.hash` table entirely (modern loaders
require only `.gnu.hash` if it's present).

**Reference for the future implementer**: glibc
`elf/dl-lookup.c::do_lookup_x` is the consumer side; the
Bloom filter format is documented in
`https://flapenguin.me/elf-dt-gnu-hash` (tutorial) +
`elf/dl-hash.h` in glibc (the hash function itself —
single-precedent definition for the format).

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

## v5.7.0 — sandhi fold + lib/ cleanup ✅ SHIPPED 2026-04-25 (cyrius side)

**Cyrius-side gates 1, 2, 5, 6 ✅. Gates 3 + 4 (downstream sweep) are separate user-organized work — see "Downstream worklist" in [CHANGELOG.md § 5.7.0](../../CHANGELOG.md#570--2026-04-25).**

**The clean-break fold.** Per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md) (2026-04-24):

- Stdlib **adds** `lib/sandhi.cyr` vendored from sandhi's `dist/sandhi.cyr`
- Stdlib **deletes** `lib/http_server.cyr` — no alias, no passthrough, no empty stub
- Both changes land in the same release — one event, one tag

v5.7.0 is the consolidation release for the v5.7.x minor. The cyrius-ts foundational frontend ended up at v5.7.2 after the v5.7.1 fixup-table cap bump (sit-blocking) wedged in 2026-04-25. **cyrius-ts completion** (async + JSX) takes v5.7.3; **RISC-V rv64** (originally scheduled as v5.7.0) slides further to v5.7.4. Each minor-patch covers a single focus — sandhi fold, ecosystem unblock, foundational frontend, frontend completion, new architecture — separate kinds of change kept apart for clean bisection + clean release notes.

**Scope:**

- **Vendor `dist/sandhi.cyr`** from sandhi's M5-complete release (sandhi v1.0.0) into `lib/sandhi.cyr`.
- **Delete `lib/http_server.cyr`** — its content has been canonical in `sandhi::server` since sandhi v0.2.0 (M1, 2026-04-24); stdlib's copy has been redundant-but-unchanged through the 5.6.x window, with a 5.6.YY deprecation warning (see prerequisite below) giving downstream consumers advance notice.
- **Propagate consumer-side migration** — original list named yantra, hoosh, ifran, daimon, mela, vidya, sit-remote, ark-remote; **post-fold audit (2026-04-25) found `sit-remote` and `ark-remote` don't exist** (real names are `sit` and `ark`), and the actual `include "lib/http_server.cyr"` consumer is **only `vidya`** (in `src/main.cyr`). yantra and sit have orphan pre-fold file copies (no callers; cleanup-only). Other repos have no v5.7.0 work.
- **Document the lib/ reshape** — CHANGELOG entry enumerates every deleted symbol from `lib/http_server.cyr` (now accessible via `sandhi::server::*`), every added symbol exposed via `lib/sandhi.cyr`, and any additional redundant lib/ objects surfaced during the 5.6.x consumer sweep that are being retired in the same release.
- **Retire the sandhi repo to maintenance mode** — subsequent patches land via the Cyrius release cycle, not sandhi releases. The sandhi repo keeps its git history as historical reference; no new tags cut post-fold.

**Prerequisites that must ship before v5.7.0:**

- **sandhi M2–M5 complete** — the public surface freezes at fold, so all planned verbs must ship as part of a sandhi release and be exercised by at least one consumer before the fold lands. No speculative surface goes into stdlib.
- **v5.6.YY deprecation-warning patch** — ✅ SHIPPED at v5.6.44 (2026-04-25). All 17 public fns in `lib/http_server.cyr` marked `#deprecated("use lib/sandhi.cyr instead -- removed at v5.7.0")` via the v5.6.4 fn-attribute mechanism + file-header deprecation block. Per-call-site warning is *stronger* notice than the originally-specified include-time print — consumers see the warning at every API use, not just at the top of the build. Notice cycle runs through every release between v5.6.44 and v5.7.0.
- **Consumer-side dual-build readiness** — original prereq named 8 repos; ✅ **substantially overstated**: post-fold audit found only `vidya` actually `include`s `lib/http_server.cyr`, and zero of the 8 had `[deps.sandhi]` pinned. Real prereq surface was 1 consumer migration + 2 orphan-file cleanups, not 8 dual-build branches.
- **`cyrius distlib` produces self-contained `dist/sandhi.cyr`** — verified clean-build from the sandhi repo at its M5-final tag, with no transitive-dep surprises.

**Acceptance gates:**

1. ✅ `lib/sandhi.cyr` exists in stdlib, byte-identical to `dist/sandhi.cyr` at the fold commit (`cmp` clean, 376,037 B / 9,649 lines, vendored at sandhi commit `6e32096`).
2. ✅ `lib/http_server.cyr` is absent from stdlib — `git rm`'d at v5.7.0.
3. ✅ No AGNOS repo has `[deps.sandhi]` pinned in `cyrius.cyml` on a 5.7.0-compatible tag — **gate already satisfied at fold time** (audit across all 8 listed consumers found zero `[deps.sandhi]` pins; no per-repo work needed).
4. ⏳ No AGNOS repo has `include "lib/http_server.cyr"` on a 5.7.0-compatible tag — **only `vidya` actually consumes the lib** (in `src/main.cyr`); user-organized migration. yantra and sit have orphan pre-fold file copies (no consumers; cleanup-only). Original 8-repo roadmap list contained two stale names: `sit-remote` and `ark-remote` don't exist (real names: `sit`, `ark`).
5. ✅ sandhi repo tagged v1.0.0 (M5-complete) at commit `6e32096`; HEAD on tag; entering maintenance mode (no new tags post-fold).
6. ✅ CHANGELOG entry enumerates 17-symbol removal table + sandhi 469-fn surface summary + actual downstream worklist at [CHANGELOG.md § 5.7.0](../../CHANGELOG.md#570--2026-04-25).

**Why bundle lib/ cleanup with sandhi fold rather than run two separate releases**: consumer-side migration work is the same shape whether stdlib is reshaping 1 file or N. One release, one migration, one CHANGELOG entry naming the whole reshape — consumers audit once, not repeatedly.

---

## v5.7.1 — fixup-table cap bump ✅ SHIPPED 2026-04-25

**Sit-blocking ecosystem unblock.** Per [sit's proposal](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md): cyrius's hardcoded 32,768-entry fixup table fills up when consumers add `"sandhi"` to `[deps].stdlib`, before DCE can strip unreached symbols. Compiler emitted `error: fixup table full (32768)` and exited rc 1.

Affected consumers (all 8 named in v5.7.0 CHANGELOG): vidya, yantra, hoosh, ifran, daimon, mela, ark, sit. Sandhi alone burns ~2,350 fixups (469 fns × ~5/fn).

**Wedge workflow** (per user direction 2026-04-25): cyrius-ts P1 work was rewound to v5.7.0 + preserved on `wip/cyrius-ts-p1` branch; fixup-cap shipped as v5.7.1; cyrius-ts cherry-picks back as the first commits of v5.7.2. Pattern: high-priority single-issue patches can preempt single-focus minors via this rewind+cherry-pick dance when ecosystem unblocking is at stake.

**Shipped**: cap 32,768 → 262,144 (8×); 16 cap-check sites updated across 5 backend files; brk +3.5 MB in 4 main entry files; capacity-meter output + heap-layout comments updated; pre-existing off-by-2x percentage math bug (line 1073 stale `/ 16384` divisor) fixed in passing. Full enumeration in [CHANGELOG.md § 5.7.1](../../CHANGELOG.md#571--2026-04-25).

**Verification**: cc5 self-host fixpoint clean at 531,880 B (8 B smaller than v5.7.0 from constant-change byte-shift; cc5 itself unchanged semantically). check.sh 26/26 PASS. Sit's v0.7.2 build verification pending — cyrius side of the unblock is in place.

---

## v5.7.2 — cyrius-ts foundational

**Pinned 2026-04-25** (cascaded from original v5.7.1 slot when fixup-cap wedged). TypeScript frontend for the Cyrius compiler. Parses `.ts` files and emits through the existing native backend chain (x86_64, aarch64, Apple Silicon, Windows PE32+).

Resumes the cyrius-ts P1 work cherry-picked from `wip/cyrius-ts-p1` after the v5.7.1 fixup-cap wedge. Cherry-picked content needs a one-line heap-base update (`S + 0x178B000` → `S + 0x1B0B000`) to land on the post-v5.7.1 brk.

**NOT Bun-shaped.** A TS runtime in Cyrius would let TS *run* on AGNOS but wouldn't *port* — TS source stays TS, interpreted by the runtime, never becoming a sovereign Cyrius-native artifact. cyrius-ts as a frontend means TS source becomes valid Cyrius-compiler input and emits native binaries.

**Rationale (load-bearing).** SecureYeoman (SY) ports by recompilation rather than rewriting. With cyrius-ts as a frontend, SY's **TS portion** becomes valid input to the Cyrius compiler. *Port via the compiler.*

**SY scope clarification (2026-04-25):** SY is mixed-language. Its **TS portion** is what cyrius-ts gobbles up — that's the v5.7.2 acceptance gate. Its **Rust portion** still requires separate porting work (manual transliteration or a future cyrius-rs frontend), tracked outside this slot.

**Scope (data-driven from SY TS inventory, 2026-04-25):**

Surveyed 2,053 sync TS files / 94,324 LOC across SecureYeoman. Async + JSX explicitly defer to v5.7.3.

**IN SCOPE — v5.7.2 must achieve parity for:**

| Category | Features (>20% file usage) |
|---|---|
| Type system | `interface`, `type` aliases, generics `<T extends>`, utility types (Partial/Pick/Omit/Record/ReturnType/Parameters), `as`, `as const`, `typeof` (type pos), `keyof`, `readonly`, optional `?:` |
| Class / OOP | `class`, `extends`, `implements`, access modifiers, constructor parameter properties, `static`, `get`/`set` |
| Functions | arrow fns, default/rest/optional params, destructuring, optional chaining `?.`, nullish coalescing `??` |
| Modules | ES modules (`import`/`export`/`default`/`*`), dynamic `import()` (sync resolution at compile time only) |
| Iteration | `for...of` (structural iterator protocol) |
| Modern syntax | template literals (100% of files), numeric separators, logical assignment (desugar) |
| Builtins | `Map<>`, `Set<>`, Array methods, `Object.{keys/values/entries}`, `JSON.{parse/stringify}`, `RegExp` (49% of files), `Date` |
| Node API shim (`lib/ts/`) | `fs.{readFileSync/writeFileSync/existsSync}`, `path.{join/resolve/basename}`, `process.{argv/env/exit}` |

**OUT OF SCOPE for v5.7.2 — explicit defer to v5.7.3:**

- `async` / `await` (1472–1514 files / ~73%) — needs microtask queue + Promise machinery + event loop. Substantial design surface, owns its release.
- `Promise.{all/race/allSettled/any}` constructors (217 files / ~11%) — pairs with async runtime.
- JSX / TSX (435 .tsx files) — DOM/component model. v5.7.3 makes the scope decision.
- Browser APIs (49 files / 2%) — never (web-frontend territory).

**NOT SUPPORTED — never (zero usage in SY):** conditional types, mapped types, `infer`, `satisfies`, `enum`, `namespace`, decorators, generators, BigInt literals, `WeakMap`/`WeakSet`/`Symbol`, tagged templates, `abstract`, CommonJS `require()`.

**Architecture decisions:**

- **Frontend module placement**: `src/frontend/ts/{lex,parse,typecheck,lower}.cyr` — peer to `src/frontend/{lex,parse,parse_*}.cyr`. Shares the rest of the compiler unchanged.
- **Heap layout**: separate from .cyr lexer (TS-heap-relative offsets via `ts_base` parameter). P1.6 wire-in: `ts_base = S + 0x1B0B000` (post-v5.7.1 brk).
- **Internal cc5 dispatch**: `cbt/build.cyr::compile()` detects `.ts` extension, passes flag; cc5 routes to `TS_LEX` vs existing `LEX`. Mirrors platform-dispatch pattern.
- **Type system**: structural, monomorphizing. Each generic instantiation produces a distinct compiled function (no type erasure).

**Implementation phases (commit-per-phase pins):**

| Phase | Deliverable | Status |
|---|---|---|
| **P1.1** | TS lexer scaffold + token enum + heap region map | ✅ done at v5.7.0; cherry-picked into v5.7.2 from `wip/cyrius-ts-p1` |
| **P1.2** | Simple tokens (idents/keywords/ints/strings/single-char ops); 131-assertion test | ✅ done at v5.7.0; cherry-picked into v5.7.2 |
| **P1.3** | Multi-char operators (`===`, `!==`, `<=`, `>>>`, `=>`, `??`, `?.`, `**=`, etc.) | ⏳ pending |
| **P1.4** | Template literals — backtick strings with `${...}` interpolation | ⏳ pending |
| **P1.5** | Comments (`//` line + `/* */` block) | ⏳ pending |
| **P1.6** | Regex literal disambiguation (context-sensitive) + wire-in to cc5 main | ⏳ pending |
| **P1.7** | Acceptance: lex SY's largest TS file without panic | ⏳ pending |
| **P2** | TS parser (statements + expressions + type expressions + class/interface/generic decls) | ⏳ pending |
| **P3** | Type checker (structural, generic monomorphization queue, utility-type compile-time resolution) | ⏳ pending |
| **P4** | TS → IR lowering | ⏳ pending |
| **P5** | Stdlib bridge + Node-API shim (`lib/ts/{builtins,fs,path,process}.cyr`) | ⏳ pending |
| **P6** | SY-side compile gate | ⏳ pending |
| **P7** | Release | ⏳ pending |

**Acceptance gates:**

1. `cyrius build foo.ts foo` emits a valid native binary on at least one supported target.
2. SY's sync, non-TSX TS portion compiles via cyrius-ts; SY's TS-side test suite passes against cyrius-built binaries (with SY's async + TSX files explicitly excluded — those are v5.7.3 territory).
3. Every IN-SCOPE feature above has a `.tcyr` test exercising it.
4. The TS frontend reuses the existing native backend chain — no new per-target backend code in v5.7.2.
5. CHANGELOG enumerates IN-SCOPE / OUT-OF-SCOPE / NOT-SUPPORTED + SY compile numbers.

**Prerequisites that must ship before v5.7.2 starts:**

- **v5.7.0** — sandhi fold lands first. cyrius-ts inherits post-fold stdlib shape.
- **v5.7.1** — fixup-cap bump lands first. cyrius-ts P1 work cherry-picks onto post-v5.7.1 brk; new ts/lex.cyr `TS_HEAP_BASE` references update from `0x178B000` → `0x1B0B000`.
- **TS subset scope decision** — ✅ DONE 2026-04-25. Data-driven from SY inventory; full IN-SCOPE / OUT / NEVER breakdown above.

**Conditional split-out** — start in-tree. Watch for the depth/complexity inflection where stdlib items accumulate enough that it warrants its own repo (the sandhi precedent). If/when it gets there, clean-break with an ADR like sandhi 0002.

---

## v5.7.3 — cyrius-ts completion (async runtime + JSX scope decision)

**Pinned 2026-04-25** when v5.7.2 explicitly deferred async + JSX. v5.7.2 ships cyrius-ts with TS parity for the sync, non-TSX subset (~27% of SY's TS files). v5.7.3 closes the gap so SY's full TS portion compiles.

**Scope:**

- **Async runtime** — minimal cyrius-side machinery for `async`/`await` + `Promise` (1472–1514 SY files, ~73%). Choices to make during scoping: futex/event-loop-based vs CPS-transform-at-compile-time. Inventory data favors a runtime over CPS.
- **`Promise.{all/race/allSettled/any}`** + `new Promise((resolve, reject) => ...)` constructors (217 SY files / ~11%). Pairs with async runtime.
- **JSX / TSX scope decision** — 435 .tsx files in SY. Most likely outcome: explicit "NOT supported," documented as such. SY's TSX stays in SY's web-frontend track. Decision made before P1 of v5.7.3 starts.
- **Async-aware Node API shim** — `fs.promises.*`, callback-style `fs.readFile`, etc. Bridges the v5.7.2 sync shim with the new async runtime.

**Acceptance gates:**

1. SY's full TS portion (sync + async, non-TSX) compiles via cyrius-ts.
2. SY's TS-side test suite (full, including async tests) passes against cyrius-built binaries.
3. CHANGELOG documents the JSX scope decision — whether NOT supported or scoped in.
4. Async-runtime overhead measured on a representative SY benchmark.

**Prerequisites that must ship before v5.7.3 starts:**

- **v5.7.2** — cyrius-ts foundational lands first; v5.7.3 inherits the frontend/lex/parse/typecheck infrastructure.
- **Async runtime architecture decision** — futex-event-loop vs CPS-transform; pick before any code lands.
- **JSX scope decision** — supported (with subset) or not supported (with rationale). Default: not supported.

---

## v5.7.4 — RISC-V rv64

First-class RISC-V 64-bit target. Elevated from the v5.5.x
pillar list to its own minor on 2026-04-20, then slid:
v5.6.0 → v5.7.0 (2026-04-20, optimization arc lands first);
v5.7.0 → v5.7.1 (2026-04-24, sandhi fold takes v5.7.0);
v5.7.1 → v5.7.2 (2026-04-24, cyrius-ts takes v5.7.1);
v5.7.2 → v5.7.3 (2026-04-25, cyrius-ts completion takes v5.7.2);
v5.7.3 → v5.7.4 (2026-04-25, fixup-cap bump took v5.7.1 sit-blocking
slot, cyrius-ts cascaded down by one). Rationale: a new
architecture is structurally different from v5.5.x items
(correctness / completion / runtime work on existing platforms),
different from v5.7.0's lib/-reshape work, different from
v5.7.1's ecosystem unblock, and different from v5.7.2/v5.7.3's
frontend work — separate minor-patches for separate kinds of
change. RISC-V needs:

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

**Prerequisites that must ship before v5.7.4 starts:**
- **v5.6.5 + v5.6.7–v5.6.21** — Compiler optimization arc.
- **v5.6.28** — shared-object emission landed.
- **v5.6.29** — downstream ecosystem sweep gate.
- **v5.7.0** — ✅ sandhi fold (post-fold stdlib shape).
- **v5.7.1** — ✅ fixup-table cap bump. RISC-V port inherits the bumped
  262K cap and relocated brk so rv64 backend development happens
  against the new fixup-table size from day one.
- **v5.7.2** — cyrius-ts foundational. RISC-V inherits compiler that
  emits from both `.cyr` and `.ts` source for sync subset.
- **v5.7.3** — cyrius-ts completion (async + JSX scope decision).
  RISC-V inherits a frontend-complete compiler so rv64 backend
  doesn't have to re-test frontend-specific code paths separately.
- **v5.4.19 `#ifplat`** direction is live → RISC-V dispatch uses
  the new syntax from day one.

Deliberately NOT bundling other items into v5.7.4 — a new
architecture port is plenty of work on its own.

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

**Why this is the last *language-feature* v5.x minor:** after v5.12.x
closes, the language has sum types, exhaustive match, Result+?,
allocator-parameter convention, slices, effect annotations, overflow
operators, `#must_use` / `#deprecated`. The language surface is stable.
v5.13.x then lands polymorphic codegen as the *security-hardening*
v5.x minor before v6.0.0 opens with the `cc5` → `cyc` rename + the
cleanup sweep that's been accruing debt across the v5.x line. v5.13.x
is the last v5.x feature minor; no further v5.x feature work after it.

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
| **v5.7.4** | RISC-V rv64 | ELF | Queued — slid v5.6.0 → v5.7.0 → v5.7.1 → v5.7.2 → v5.7.3 → v5.7.4: optimization arc → sandhi fold → fixup-cap bump (sit-blocking, 2026-04-25) → cyrius-ts foundational → cyrius-ts completion → RISC-V |
| **v5.8.0** | Bare-metal | ELF (no-libc) | Queued — AGNOS kernel target |
| ~~**v5.9.0–5.9.5**~~ | ~~Pure-cyrius TLS 1.3~~ | — | **Removed from roadmap 2026-04-24** — pure-Cyrius TLS work outside Cyrius's compiler/stdlib scope per sandhi scope-absorption decision; `lib/tls.cyr` continues using `libssl.so.3` bridge from stdlib's perspective; canonical home for pure-Cyrius TLS implementation TBD. See v5.9.x slot bullet in *What's next* for details. |

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
