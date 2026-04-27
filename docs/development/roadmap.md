# Cyrius Development Roadmap

> **v5.7.12.** cc5 compiler (709,544 B x86_64; +4,568 B from v5.7.6's
> 704,976 — fixup-table cap 262K → 1M, brk +12 MB, lint UFCS Pascal-
> prefix exemption, `cyrius build` atomic-output via tmp+rename). Native aarch64 cc5
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
> - **v5.7.5**: ✅ shipped 2026-04-26 — real JSX AST (13 structured JSX token kinds + 9 JSX AST kinds + `TS_PARSE_JSX_ELEMENT` from PRIMARY). Inner-expr tokenization deferred to v5.7.6 — empty `JSX_EXPR_CONTAINER` in this iteration. `.tsx` 428 → 429/435 (98.6%); `.ts` held at 2033/2053. Mode-stack-driven prototype reverted at end-of-cycle for clean cut. See CHANGELOG.
> - **v5.7.6**: ✅ shipped 2026-04-26 — JSX inner-expr tokenization (P4.3d). Mode-stack-driven lex (modes 4/5/8). `.tsx` 429 → 430/435 (98.85%). 5 sticky failures remain (non-JSX TS feature gaps). See CHANGELOG.
> - **v5.7.6-old**: **JSX inner-expr tokenization (P4.3d resume)** — pick up the mode-stack-driven design from v5.7.5: lex pushes mode 4 (JSX_TAG) / mode 5 (JSX_TEXT) / mode 8 (JSX_EXPR) onto the existing template stack; main TS_LEX loop dispatches to per-mode helpers; matching `}` of mode 8 emits `JSX_EXPR_CLOSE` and pops back to outer JSX mode. Helpers `TS_LEX_JSX_TAG` + `TS_LEX_JSX_TEXT` were drafted clean during v5.7.5 P4.3d-1; the regression bug surfaced when wiring d-2 dispatch (specific JSX shape leaves mode stack inconsistent; couldn't isolate via single-line bisect). v5.7.6 picks this up with full investigation budget. After landing: parser real-expr consumption inside containers + spread attrs. Pinned 2026-04-26.
> - **v5.7.7**: ✅ shipped 2026-04-26 — fixup-cap 1MB+ bundle (lint UFCS exemption + atomic-output `cyrius build` + fixup-table 262K → 1M). Wedged in after cyrius-ts polish surfaced 3 tooling issues. cc5 704,976 → 709,544 B (+4,568 B). 2-step bootstrap fixpoint clean. See CHANGELOG.
> - **v5.7.8**: ✅ shipped 2026-04-26 — `cyrius check` repair (cc5 exit-code propagation + drop dep auto-prepend for `check` + output formatting) + `cyrius deps` ergonomics (P1-P5 from cyrius-bb `tooling-pain-points.md`) + syscall-arity warning fix (`lib/syscalls_x86_64_linux.cyr:358` — `_SC_ARITY(112)` 1→0; `lex.cyr:227+240` cross-arch sentinel false-positive). cc5 709,544 → 709,688 B. 3-step fixpoint clean; check.sh 29/29.
> - **v5.7.9**: silent fn-name collision investigation (lifted from v5.7.10 on 2026-04-26 — smaller, contained slot lands first; the v5.7.10 input_buf reshuffle is a ~1586-edit heap shuffle that deserves its own slot).
> - **v5.7.10**: `input_buf` 512KB → 1MB heap-map reshuffle (pattern matches v5.6.40's preprocess_out 1MB → 2MB). **Load-bearing for the ecosystem, not speculative**: hisab `dist/hisab.cyr` is 505,237 B = 96% of the 524288 B cap and actively censoring upstream to stay under; every consumer of hisab inherits the full 505 KB via cyrius's `[deps]` auto-prepend, leaving only 19,051 B of budget for the consumer's own source. Sandhi/sit/yantra-class folds compound the pressure — hisab is the canary, not the only blocker. Slot lifted to v5.7.10 (was v5.7.9) on 2026-04-26 because the reshuffle scope (~214 distinct heap-region addresses, ~1586 occurrences, all in the 0x80000..0xFFFFF range) is bigger than v5.7.9's collision-investigation work and deserves its own slot rather than rushing under the v5.7.9 banner.
> - **v5.7.11**: `main_cx.cyr` (cyrius-x bytecode entry) drift fix — parse-time + build-time + no-SIGSEGV-at-startup; plus `tests/regression-cx-build.sh` CI gate (the durable part — drift accumulated across v5.6.x + v5.7.x reshuffle because no gate built it). 4 missing pieces added (ir.cyr include, _AARCH64_BACKEND/_TARGET_MACHO/_TARGET_PE/_flags_reflect_rax + 4 peephole-tracker globals), 2 dead PF64BIN/PF64CMP cx-stubs deleted (surfaced by v5.7.9's duplicate-fn warning), brk bumped 5.5 MB → 39 MB. Bytecode semantic correctness cascaded to v5.7.12 (correctness over new features per user 2026-04-27).
> - **v5.7.12**: cyrius-x bytecode semantic correctness — parser-to-emit interface re-architecture so cc5_cx output round-trips cleanly through cxvm. parse_*.cyr currently emits raw x86 bytes via `E3(S, 0xC18948)`-style calls in shared codepaths; cx interpreter sees x86 noise interleaved with valid CYX opcodes. Fix: replace direct emits with abstract operations routed through the active backend, or guard with `_TARGET_CX == 0` per site. Real engineering, multi-session. Cascaded from v5.7.12 RISC-V slot 2026-04-27 — correctness work claims the slot, new features queue.
> - **v5.7.13**: RISC-V rv64 port (inherits optimized compiler + post-fold stdlib shape + bumped fixup table + complete cyrius-ts frontend + collision-resolution rule + 1MB input_buf + cx-build-clean + cx-correct). Slid across 2026-04-24/27 as sandhi fold/cyrius-ts/fixup-cap/JSX/JSX-AST/JSX-inner-expr/cyrius-check-and-deps/collision-investigation/input-buf/cx-drift/cx-correctness took priority slots in turn.
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

### Parser-to-emit named-op refactor (path A from v5.7.12 inventory)

**Status**: pinned long-term 2026-04-27 after v5.7.12 took
path B (`_TARGET_CX == 0` guards on ~10 sites). The path A
refactor is the right long-term architecture; v5.7.12 ships
the tactical fix without committing to it.

**The problem path A solves**: `parse_*.cyr` directly emits
x86 instruction bytes via `EB(S, 0xNN)` / `E2(S, 0xNNNN)` /
`E3(S, 0xNNNNNN)` calls in shared codepaths. Each backend
(x86, aarch64, cx, future-RISC-V) has to either map those
literal bytes to its own emit (cx already does, but x86 hex
literals aren't CYX opcodes) or guard the site
arch-conditionally. Path B chose the latter; path A would
replace every direct emit with a named abstract op that each
backend implements natively.

**Scope estimate** (per the v5.7.12 inventory at
[`docs/audit/2026-04-27-cx-direct-emit-inventory.md`](../audit/2026-04-27-cx-direct-emit-inventory.md)):
- ~10 distinct logical sites at v5.7.11. Each is a 3-12 byte
  x86 sequence that needs a single named op in each backend.
- Roughly: 10 new abstract ops × 3 backends (= 4 with RISC-V)
  = 30-40 fn definitions, plus rewriting the 10 parse_*.cyr
  call sites to use the named ops.
- Multi-session real engineering. Not a wedge.

**Trigger conditions** (any one):

1. **RISC-V (v5.7.13) lands and adds 4th backend**, making
   path B's `_TARGET_CX == 0 && _TARGET_RISCV == 0` chains
   unwieldy at every site.
2. **2+ new direct-emit sites slip past the static-analysis
   gate** (TBD if a regex-scanner check.sh gate gets added in
   the v5.7.x cycle). If parse_*.cyr drift recurs, path A
   becomes the durable fix.
3. **A bytecode VM consumer surfaces** that needs the cx
   backend to handle ops path B currently no-ops (f64,
   struct return, regalloc). Adding those one at a time to
   cx would expose the same architectural mismatch path A
   solves once.

**Per-backend impact** when path A lands:
- x86 emit: every existing direct-byte sequence in
  `parse_*.cyr` becomes a 1-line wrapper in `backend/x86/emit.cyr`
  (mostly already wrapped — EMOVCA, EADDR, ESUBR, etc.).
  Direct-emit sites in parse_*.cyr replaced with named ops.
  Byte-identity must hold (the new named op emits the same
  bytes the old direct call did).
- aarch64 emit: implements the same named ops with aarch64
  encodings. Many already exist; the new ones map to
  patterns currently handled by `if (_AARCH64_BACKEND == 1)`
  branches (which path B leaves in place).
- cx emit: implements the named ops as CYX bytecode opcodes —
  THIS is where the real semantic work happens. Half the
  v5.7.12 path-B sites are currently no-ops on cx;
  path A forces a real CYX opcode for each (which means
  cxvm interpreter changes too, in lockstep).
- RISC-V emit: starts with the named-op interface from day
  one. Cleanest backend addition path.

**Why deferred**: v5.7.12 needs to STOP THE BLEEDING (cx
output is x86 noise + valid CYX interleaved) on a tractable
budget. Path B does that in ~50 LOC. Committing to path A's
30-40 fn definitions + cxvm coordination + byte-identity
across 3 backends is a different scope category. Defer until
a trigger fires.

**Reference**: full inventory + per-site classification at
`docs/audit/2026-04-27-cx-direct-emit-inventory.md`. When a
trigger fires, the audit doc is the starting point — every
class B/C/D site listed there becomes a named-op design
decision in path A.

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


## v5.7.5 — Real JSX AST ✅ shipped 2026-04-26

Replaced v5.7.3's `TOK_INT` placeholder with 13 structured JSX token
kinds (block 300-312) + 9 JSX AST kinds (block 700-708) built by
`TS_PARSE_JSX_ELEMENT` invoked from `PRIMARY`. `TS_LEX_JSX_SKIP` and
`TS_LEX_JSX_SKIP_INNER` deleted (256 LOC). New `TS_LEX_JSX_BYTE_SKIP`
catches generic types like `Foo<HTMLParagraphElement>` mis-firing as
JSX (bails on stray `}`). `TS_LEX_JSX_SKIP_WS` extended to skip `//`
+ `/* */` comments inside JSX tags (eslint-disable pragmas). cc5
687,088 → 697,840 B (+10,752 B). 3-step fixpoint clean.

**Acceptance results:**
- `.tsx`: 428 → **429/435 = 98.6%**; threshold raised 425 → 429
- `.ts`: held at 2033/2053 = 99.03%
- New `tests/tcyr/ts_lex_p43.tcyr` (49 assertions, 12 groups)
- New `tests/tcyr/ts_parse_p43.tcyr` (11 groups)
- check.sh 29/29

**Inner-expr tokenization deferred to v5.7.6.** v5.7.5 ships with
empty `JSX_EXPR_CONTAINER` nodes — lex byte-balances `{...}`
expression bodies without emitting inner tokens. The mode-stack-
driven design was prototyped during v5.7.5 P4.3d work
(`TS_LEX_JSX_TAG` / `TS_LEX_JSX_TEXT` helpers + modes 4/5/8 on the
existing template stack + main-loop dispatch + parser real-expr
consumption) and reverted at end of cycle for clean cut.

**Following slot:** v5.7.6 — JSX inner-expr tokenization (P4.3d resume).

## v5.7.6 — JSX inner-expr tokenization (P4.3d resume)

**Pinned 2026-04-26.** v5.7.5 shipped the real JSX AST but with empty
`JSX_EXPR_CONTAINER` nodes. v5.7.6 wires the mode-stack-driven design
prototyped + reverted during v5.7.5.

**Scope:**

- **Lex-mode stack extension.** Reuse the existing template stack
  (slot values 0-3 are template-related). Add:
  - 4 = JSX_TAG_MODE (inside `<TAG ...>` or `</TAG>`, expecting attrs)
  - 5 = JSX_TEXT_MODE (between tags, expecting children)
  - 8 = JSX_EXPR_MODE (inside `{...}` of JSX expr — main TS_LEX
    loop tokenizes normally; matching `}` pops 8 + emits
    `JSX_EXPR_CLOSE`)

- **TS_LEX main-loop dispatch.** Extend the existing template-body
  dispatch (top == 0/1) to also dispatch on top == 4 → `TS_LEX_JSX_TAG`
  and top == 5 → `TS_LEX_JSX_TEXT`. The `{`/`}` handlers extended
  for top == 8.

- **TS_LEX_JSX entry rewrite.** Push mode 4 (or 5 for fragment) and
  return — no more self-contained walk. Subsequent JSX structure
  driven by main loop.

- **Parser real-expr consumption.** `TS_PARSE_JSX_CHILD`'s
  `JSX_EXPR_CONTAINER` consumer parses the actual expression
  (was: empty assert close). `JSX_ATTRIBUTE` value-kind=2 (expr)
  consumer same. `JSX_SPREAD_ATTR` consumes `ELLIPSIS` + expr.

- **IS_PRIMARY_CONTEXT whitelist.** Add `JSX_CLOSE_END`,
  `JSX_SELF_CLOSE`, `JSX_FRAGMENT_CLOSE` (post-JSX is value-context).

- **Cleanup.** Delete `_TS_LEX_JSX_WALK` (the v5.7.5 self-contained
  walker) + `TS_LEX_JSX_BYTE_SKIP` + `TS_LEX_JSX_BALANCE_BRACES`
  (no longer needed once main loop drives JSX).

**Methodology / known investigation pointers from v5.7.5 P4.3d
attempt:**
- d-1 helpers (`TS_LEX_JSX_TAG`, `TS_LEX_JSX_TEXT`) compiled clean
  in parallel without breaking regressions — these go straight back
  in.
- d-2 dispatch wiring caused `.tsx` regression from 429 → 372 (57
  lost) with `code=3 tok=301` (JSX_TAG_NAME at unexpected parse
  position). Single-line bisect on failing files (McpManager,
  ConnectionManager, WebScraperConfigPage) couldn't isolate the
  trigger — likely a cumulative mode-stack-popping bug on a
  specific JSX shape interaction. Targeted minimal repros all
  passed. Full investigation budget required.
- d-2 also restored `.ts` at 2033/2053 once a pre-flight
  `BYTE_SKIP` check landed (without it, `<Foo>x` cast-style
  caused JSX false-positive on `.ts` files).
- Pre-flight balance check before mode push is load-bearing —
  mode-driven dispatch can't easily roll back leaked tokens
  across multiple mode pushes.

**Acceptance:**
- `tests/regression-ts-parse-tsx.sh` threshold ≥430 (≥99%)
- `tests/regression-ts-parse.sh` stays at 2030
- `tests/tcyr/ts_parse_p43.tcyr` extended: assert
  `JSX_EXPR_CONTAINER`'s payload[0] points at a real expression
  node (not 0).
- All P1 lex + P2-P5 parse + check.sh stay green
- cc5 self-host fixpoint clean

**Following slot:** v5.7.8 — `cyrius check` repair + `cyrius deps`
ergonomics + syscall-arity warning fix (was RISC-V; slipped
2026-04-26 when cyrius-bb wiring surfaced multiple silent
failures + UX gaps in tooling on the same day).

## v5.7.8 — `cyrius check` repair + `cyrius deps` ergonomics + syscall-arity warning fix

**Pinned 2026-04-26.** cyrius-bb (`docs/development/tooling-pain-
points.md`) surfaced five `cyrius deps` ergonomic issues during
its first end-to-end wiring; same-day investigation of `cyrius
check` revealed three independent silent-failure layers; the
build's recurring `warning:lib/syscalls_x86_64_linux.cyr:358:
syscall arity mismatch` was traced to a one-character bug in
the `_SC_ARITY` table. None of these individually warrant a
slot; together they're a single coherent "silent failures and
bad UX surfaced this week" patch.

### Bundle scope

#### 1. cc5 exit-code propagation

Repro: `echo 'undefined()' | build/cc5 > /dev/null 2>&1; echo
$?` → `0`. cc5 prints `error:` to stderr but exits 0. Every
downstream caller relying on the exit code (`cyrius check`,
`cyrius build` after rename, every gate in `scripts/check.sh`
that pipes through cc5 expecting non-zero on failure) silently
treats failed compiles as successes.

Fix: route the `error:` emit path through a `_HAD_ERROR` flag,
exit 1 on flag-set at end-of-compile. ~10 LOC in `src/main.cyr`
+ `src/frontend/parse.cyr`. Foundational — every subsequent
gate fix in this slot depends on it.

#### 2. `cyrius check` plumbing

Three independent bugs in `cmd_check` (`cbt/commands.cyr:223`):

- **Auto-prepend trap.** `cyrius check programs/hello.cyr`
  falls back to `actual = src/main.cyr` (since hello.cyr has no
  includes), but then `compile()` injects manifest deps
  (patra, sigil, …) AT THE TOP, before main.cyr's own
  `include "lib/syscalls_x86_64_linux.cyr"`. patra references
  `SYS_LSEEK` at parse time → fails with
  `error:lib/patra.cyr:101: undefined variable 'SYS_LSEEK'`.
  Fix: `cyrius check` passes a `skip_deps=1` flag to
  `compile()`. Syntax-checking a file shouldn't drag the dep
  graph into the parse.
- **"is a module" message fires when source IS the entry.**
  `cyrius check src/main.cyr` prints `check via src/main.cyr
  (src/main.cyr is a module)` — confusing tautology. Fix:
  only emit the redirect line when `actual != source`.
- **Output formatting.** Missing newline before `error:
  src/main.cyr` line on the failure path (cc5's stderr output
  doesn't end with `\n` for some error shapes; the wrapper
  doesn't compensate). Fix: emit `\n` before the wrapper's own
  `error: <source>` line if cc5 stderr didn't.

#### 3. `cyrius deps` ergonomics (P1–P5)

From `cyrius-bb/docs/development/tooling-pain-points.md`:

- **P1 — silent dangling symlink.** `cbt/deps.cyr:467-469`
  builds `src` from `dep_path/mod_path`, has a fallback at
  ~470, but if neither path exists, blindly creates a
  symlink to the bad path and increments `copied`. ~8 LOC
  fix: after the fallback block, `if (file_exists(src) == 0)
  { _err_ctx + errors+1 + skip }`. A successful "N deps
  resolved" line should never coexist with a dangling
  `lib/<dep>.cyr` symlink.
- **P2 — `cyrius deps --help` runs the resolver.**
  `cbt/cyrius.cyr:304-308` only handles `--verify`/`--lock`;
  every other arg falls through to `cmd_deps()`. Add a
  `--help` branch that prints subcommand-specific usage:
  flags (`--verify`, `--lock`, `--update`/`cyrius update`),
  cache location (`~/.cyrius/deps/`), how to force re-clone,
  how to clear stale entries. Same shape as `cargo build
  --help`.
- **P3 — `deps` not listed in `cyrius help`.**
  `cmd_help` in `cbt/commands.cyr` lacks a Deps section. Add
  one (or fold under Project alongside `init`).
  Discoverability matters more than where it lives.
- **P4 — first-resolve count off-by-one.** Cold run reports
  `5 deps resolved` for 4 declared `[deps]` blocks; warm run
  reports `4`. `copied` increments per-symlink in
  `cmd_deps`; off-by-one likely from Phase 1 stdlib batch
  counting as one extra unit on cold but skipped on warm.
  Audit + fix: count distinct deps, not operations.
- **P5 — lockfile flag opt-in + undocumented.** `--lock`
  exists (`cbt/cyrius.cyr:306` → `cmd_deps_lock`) but is
  off-by-default; `cyrius.lock` not generated by bare
  `cyrius deps`. `--lock` not documented in `cyrius help`,
  not in `cyrius deps --help` (since that runs the resolver
  per P2), not in any usage error. **PROPOSED**: flip
  default-on (write `cyrius.lock` after every successful
  resolve), add `--no-lock` opt-out for the rare suppress
  case, document the `--lock`/`--no-lock`/`--update`/`cyrius
  update` family in `cyrius help` and the new `cyrius deps
  --help`. Confirm at slot start before flipping the
  default — existing projects without a checked-in lockfile
  will get one written on next `cyrius deps`.

#### 4. Syscall-arity warning sweep (partial)

Three classes of `warning: ... syscall arity mismatch` in
v5.7.7's cc5 self-build, plus the `lib/syscalls_x86_64_linux.cyr:358`
warning that fires on every `cyrius build` of any downstream
that includes patra/syscalls. All trace to the `_SC_ARITY`
table at `src/frontend/parse_expr.cyr:10`.

- **`lib/syscalls_x86_64_linux.cyr:358` — true bug.** Line 358
  is `return syscall(SYS_SETSID);` — SYS_SETSID = 112. Table
  has `if (n == 112) { return 1; }` with the comment "actually
  0 args but Cyrius wraps" — comment admits it's wrong. Linux
  `setsid()` takes 0 args; the wrapper passes 0 user args;
  expected should be `0`. **One-character fix:** `1` → `0`.
- **`src/frontend/lex.cyr:227 + 240` — false positives.** The
  `else` branch `syscall(SYS_OPEN, 0 - 100, path, 0, 0)` is a
  cross-arch sentinel pattern (sentinel `-100` signals
  aarch64 openat translation downstream); on x86_64 builds
  `SYS_OPEN` constant-folds to 2, the expected arity is 3,
  the call has 4 user args, mismatch fires. The dead
  branch is correct cross-arch code. Fix: in the arity check
  at `parse_expr.cyr:578`, skip the warning when arg-1 is a
  recognized cross-arch sentinel (`-100` for openat). Or
  guard the arity check inside `if (CONST == VAL) {} else
  {}` blocks where `CONST` is a known stdlib enum. Conservative
  approach: special-case the `-100` sentinel value.
- **`<source>:7` — auto-prepend site.** Investigate which
  prepended module's line 7 emits an arity-mismatched
  syscall. Likely `version_str.cyr` or similar generated
  prelude. If genuine, fix; if false-positive, suppress per
  same rule as lex.cyr.

The remaining warning-sweep items (36 unreachable-fn floor
audit, `scripts/check.sh:305-306` bash syntax warning, `cbt/`
+ `programs/` + `bootstrap/` shell-warn pass) stay in the
existing `### v5.7.x — warning sweep` slot — v5.7.8 only
covers the syscall-arity items.

### Acceptance gates

1. `echo 'undefined()' | build/cc5 > /dev/null 2>&1; echo $?`
   → 1.
2. `cyrius check programs/hello.cyr` parses standalone
   (no dep auto-prepend), exits non-zero on parse error,
   exits 0 on clean parse.
3. `cyrius check src/main.cyr` does NOT print "is a module"
   (since source IS the entry).
4. `cyrius deps --help` prints subcommand help, does NOT
   resolve deps. `cyrius help` lists `deps`. P1 fixture
   (declare a `[deps.X]` with a `modules` path that doesn't
   exist at the pinned tag) produces a clear error and
   leaves no symlink. Cold/warm `cyrius deps` print
   identical N. `cyrius.lock` written by default.
5. cc5 self-build emits zero `warning: ... syscall arity
   mismatch` lines. `cyrius build` of any patra-using
   downstream emits zero arity warnings.
6. New regression `tests/regression-cyrius-check.sh`
   covering: error → exit non-zero; clean → exit 0; no
   dep auto-prepend; standalone-file shape.
7. New regression `tests/regression-cyrius-deps-p1.sh`
   covering: dangling-modules-path produces error + zero
   `lib/` symlinks for the bad dep.
8. cc5 self-host fixpoint clean (cc5's own behavior unchanged
   except for the exit-code propagation; bytes change due
   to the `_HAD_ERROR` flag wiring + arity-table edit).
9. check.sh stays at 29/29 PASS post-bundle.

### Bonus pin (drop in if scope allows)

`cyrius build --no-deps` flag (carried over from v5.7.7's
"slotted into v5.7.7 IF time allows; otherwise v5.7.8" pin
at line 1014). Fix to `cyrius check` partially closes the
gap (skips deps for check) but `cyrius build src/main.cyr
build/cc5_v578` still over-prepends and trips the 262K
token cap; the `--no-deps` flag closes it. Trivial — wire
one bool flag from CLI parse → `compile()`. Land in v5.7.8
if there's headroom; otherwise carry forward.

### Slot relationship

Standalone slot. v5.7.9 (silent fn-name collision), v5.7.10
(`input_buf` 512KB → 1MB), v5.7.11 (cx-drift fix), v5.7.12
(cx-correctness), and v5.7.13 (RISC-V) follow.

## v5.7.9 — silent fn-name collision investigation

**Pinned 2026-04-26.** Real cyrius-language correctness issue
surfaced during the v5.7.7 closeout: when two stdlib modules
define a function with the same name but different arities, the
compiler silently accepts the second definition and the first
is overwritten. There is **no** arity-mismatch warning, no
duplicate-definition warning, and no error. Last definition
wins by include order — which means the bug is order-dependent
and triggers based on whichever consumer happens to include
which library last.

**Reproduction (verified 2026-04-26 against cc5 5.7.6):**

- `lib/json.cyr:125` defines `fn json_build(pairs)` (arity 1).
- `lib/patra.cyr:2931` defines `fn json_build(buf, max, keys,
  vals, types, n)` (arity 6).
- A consumer that includes both (`include "lib/json.cyr";
  include "lib/patra.cyr"`) gets ONLY the patra/6-arg variant
  visible. A 1-arg call to `json_build(pairs)` either fails
  with a parse error (if the parser checks arg count against
  the resolved definition) or silently miscompiles with the
  6-arg signature reading 5 stack slots of garbage.
- Reverse the include order and the json/1-arg variant wins;
  patra's 6-arg callers silently miscompile in the same way.
- Compiler emits no diagnostic. `cyrius build` reports `OK` on
  the build that has the collision.

**Why this matters:** stdlib modules are included transitively
via `cyrius.cyml [deps]`. As the stdlib grows (40+ modules
post-fold), the chance of a name overlap grows quadratically.
Today's `json.cyr` + `patra.cyr` collision is the visible one;
audit will likely surface more.

**Investigation scope (v5.7.9):**

1. **Audit current stdlib** for duplicate fn-name definitions
   across modules. Smallest hammer: `grep -h '^fn ' lib/*.cyr |
   sort | uniq -c | sort -rn | awk '$1 > 1'`.
2. **Decide the resolution rule** — three options, in increasing
   ergonomic cost:
   a. **Hard error** on duplicate fn-name across translation
      units. Forces the user to rename one. Most strict, breaks
      any existing code that happens to collide.
   b. **Warn + last-wins** (today's silent behavior, made
      visible). Lower friction; preserves existing behavior;
      surfaces the issue.
   c. **Arity-aware overload resolution** — multiple defs OK
      if arities differ; resolve by call-site arg count.
      Highest ergonomic, but a real semantic addition.
3. **`json_build` collision** specifically: rename one. Likely
   `lib/patra.cyr::json_build/6` → `patra_json_build/6`
   (namespace-prefix, mirroring `patra_*` convention used
   elsewhere in patra), since `lib/json.cyr::json_build/1` is
   the more general utility. Or reverse — user judgment.
4. **Fix-or-warn** in cc5 itself: at minimum add the warning
   that's missing today. The full overload-resolution path is
   a separate language addition.

**Acceptance gates:**

1. Stdlib audit committed under `docs/audit/2026-04-26-stdlib-fn-collisions.md`.
2. cc5 emits a warning (or error, per the chosen resolution
   rule) when two `fn` definitions share a name within a
   compilation unit.
3. The `json_build` collision specifically resolved via rename
   (or overload resolution if that path is chosen).
4. New regression test under `tests/tcyr/fn_name_collision.tcyr`
   covering: same-arity duplicate, different-arity duplicate,
   transitive collision via includes.

**Slot relationship:** standalone slot. Cascaded out of the
v5.7.8-bundled position 2026-04-26 when the cyrius check /
deps / arity bundle took v5.7.8; lifted from v5.7.10 → v5.7.9
on 2026-04-26 when the v5.7.10 input_buf reshuffle audit
showed it deserved its own slot. v5.7.10 (input_buf 1MB) and
v5.7.11 (cx-drift fix), v5.7.12 (cx correctness), and v5.7.13 (RISC-V) follow.

## v5.7.10 — input_buf 512KB → 1MB heap-map reshuffle

**Pinned 2026-04-26; lifted from v5.7.9 → v5.7.10 on
2026-04-26** when the v5.7.9 audit (see [task #17] / agent
report) showed the reshuffle scope is bigger than the original
roadmap entry suggested — ~214 distinct heap-region addresses
in the 0x80000..0xFFFFF range, ~1586 occurrences across the
src/ tree. Same shape as v5.6.40's preprocess_out 1MB → 2MB
reshuffle; not a 3-line cap bump.

### Why this matters (load-bearing for the ecosystem)

Hisab's `dist/hisab.cyr` is **505,237 bytes = 96 % of the
524,288 byte cap** as of 2026-04-26 and actively censoring
upstream to stay under. cyrius auto-prepends every
`[deps.NAME]` module above the consumer's source, so any
project pulling hisab gets only **19,051 bytes** of budget for
its own source before the read-cap fires. Sandhi/sit/yantra-
class folds compound the pressure — hisab is the canary, not
the only blocker. Forward-looking deps (mabda's bundled dist,
agnostik's derive-codegen expansion, sit's full-tree state
files) hit the same ceiling.

### Scope (audit completed during v5.7.9 wedge)

`input_buf` lives at heap offset `0x00000` in `src/main.cyr`'s
heap map. **The cap value itself appears at 18 sites across
6 main_*.cyr files** (3 per file: heap-map comment, read-loop
length, over-cap guard):

- `src/main.cyr` × 3
- `src/main_aarch64.cyr` × 3
- `src/main_aarch64_native.cyr` × 3
- `src/main_aarch64_macho.cyr` × 3
- `src/main_win.cyr` × 3
- `src/main_cx.cyr` × 2 (no heap-map comment)
- `src/frontend/lex_pp.cyr` × 1 (PP IFDEF-pass copy-back cap;
  must move with input_buf size)

All become `1048576` (0x100000).

### Heap reshuffle (the actual work)

Today: `input_buf` 0..0x80000 (524288 B); compiler state
starts at 0x8C100 (struct tables, fn state, locals, macros,
IFDEF stack, gvar tables, file_map, include_fnames at 0xC0000,
codebuf compaction tables at 0xA0000). With `input_buf` widened
to 0x100000, every state region in 0x80000..0xFFFFF collides
and must shift +0x80000:

- `0x8C100 → 0x10C100` (compiler scalars)
- `0x8DA00 → 0x10DA00` (fn state)
- `0x8E630 → 0x10E630` (struct tables)
- `0x90500 → 0x110500` (include_fname / locals / macros)
- `0x97F10 → 0x117F10` (IFDEF state stack — v5.6.1)
- `0x98000 → 0x118000` (gvar tables)
- `0x9A000 → 0x11A000` (file_map)
- `0x9D000 → 0x11D000` (file_map_str)
- `0xA0000 → 0x120000` (codebuf compaction — v5.6.27)
- `0xC0000 → 0x140000` (include_fnames)
- (every other distinct address in the range)

Brk grows ~+0x80000 (~512 KB) to absorb the shifted regions.
Regions at 0x100000+ (fn tables, fixup_tbl, IR area, codebuf,
output_buf, etc.) DO NOT shift — already past the new
input_buf boundary.

Disambiguation discipline (per v5.6.40's reshuffle):
- Every shifted region must not collide with any region above
  the shift boundary (at 0x100000+).
- Adjacent regions must not overlap after shift (the same
  +0x80000 delta preserves relative offsets, so internal
  layout is unchanged).
- 3-step fixpoint catches deterministic mis-shifts; non-x86
  paths (aarch64-native, mach-o, PE, cx) need explicit testing.

### tok_names overlay-rebuild contract

`tok_names` at `0x60000..0x80000` is nested INSIDE
`input_buf` today (rebuilt-by-LEX after preprocessing — the
input bytes are no longer needed at the point tok_names
writes start). With `input_buf` widened to 0x100000,
tok_names at 0x60000 is still inside that range — overlap
pattern unchanged, contract still holds. The rebuild contract
is verified by 3-step fixpoint (cc5_a == cc5_b byte-identical
after self-compile).

### Acceptance gates

1. `tests/tcyr/large_input.tcyr` (or new `tests/tcyr/
   input_1mb.tcyr`) covers an 800KB+ source — passes post-
   bump, fails pre-bump (the 524288 cap rejected it).
2. cc5 self-host fixpoint clean (cc5's own source is well
   under 1MB; bump is invisible to cc5 itself).
3. Downstream consumers that hit the 524288 cap (agnostik
   derive expansion, mabda dist, sit state) build green
   without manual splitting.
4. CHANGELOG enumerates the cap change, the disambiguation
   audit findings, and any consumer unblock impact.

### Slot relationship

Standalone slot. v5.7.11 (cx-drift fix) and v5.7.12 (cx
correctness) follow; v5.7.13 (RISC-V) after that.

## v5.7.11 — main_cx.cyr drift fix + CI gate

**Pinned 2026-04-27** as a wedge before RISC-V. Surfaced during
v5.7.10's cross-arch verify: `main_cx.cyr` (the cyrius-x
bytecode entry) failed to build with
`error: undefined variable 'IR_RAW_EMIT'`. Investigation showed
the failure was the visible tip of accumulated drift across
multiple minors — no CI gate ever built `main_cx.cyr`, so each
addition to the shared frontend that x86/aarch64 picked up
silently broke cx.

### Smaller-slot scope (per user 2026-04-27)

Three bars, all met:

1. **Parse-time clean** — `cc5 < src/main_cx.cyr` succeeds.
2. **Build-time clean** — output is a valid 365,696 B ELF
   (`cc5_cx`).
3. **No-SIGSEGV-at-startup** — `echo '' | cc5_cx` and
   `echo 'syscall(60, 0);' | cc5_cx` both exit 0.

Bytecode SEMANTIC correctness is **explicitly out of scope** —
cascaded to v5.7.12 (parse_*.cyr emits raw x86 bytes via
`E3(S, 0xC18948)`-style calls in shared codepaths; cx
interpreter sees those interleaved with valid CYX opcodes).

### Drift surfaced + fixed

- **Missing include**: `src/main_cx.cyr` lacked
  `include "src/common/ir.cyr"` (added to main.cyr at v5.6.12
  for O3a IR instrumentation; never propagated). Same shape as
  v5.6.32's `main_aarch64_native.cyr` fix.
- **Missing globals in `src/backend/cx/emit.cyr`**:
  - `_AARCH64_BACKEND = 0` (parse.cyr / parse_decl.cyr /
    parse_fn.cyr / parse_expr.cyr all reference)
  - `_TARGET_MACHO = 0` (parse_expr.cyr line 412)
  - `_TARGET_PE = 0` (same)
  - `_flags_reflect_rax = 0` (v5.6.8 flag-reuse tracker;
    parse_ctrl.cyr / parse_expr.cyr reference)
  - `_last_push_cp` / `_last_emovca_cp` /
    `_last_movca_popr_cp` (v5.6.9 + v5.6.10 peephole
    trackers; parse_ctrl.cyr references)
  - `_INLINE_OK` / `_LOOPVAR_OK` (x86 inline-fn / loop-var-reg
    toggles)
- **Dead colliding stubs deleted**: `PF64BIN` and `PF64CMP` in
  `src/backend/cx/emit.cyr` lines 449-450 were stubs `return 0`
  that collided with parse_expr.cyr's authoritative versions.
  Last-include-wins meant the parse_expr versions always won
  silently. v5.7.9's duplicate-fn warning surfaced this.
- **brk extension undersized**: `syscall(SYS_BRK, S +
  0x54A000)` (5.5 MB) never reached the tok_types region at
  `S + 0x74A000` (7.5 MB). cc5_cx SIGSEGV'd at LEX the moment a
  non-empty input landed any token. Bumped to `S + 0x270B000`
  (39 MB, matching `main_aarch64.cyr` — cx skips the TS
  frontend, so doesn't need main.cyr's +13.5 MB).

### CI gate (the durable fix)

`tests/regression-cx-build.sh` runs three checks:
1. `cc5 < src/main_cx.cyr` exits 0; output > 100 KB.
2. `echo '' | cc5_cx` exits < 128 (no signal).
3. `echo 'syscall(60, 0);' | cc5_cx` exits < 128.

Wired into `scripts/check.sh` as gate **4u**. check.sh **32/32
PASS**.

The reason cx accumulated 4+ silent drift breakages over 6+
minor releases is that no gate ever built it. This gate closes
that hole — any future addition to the shared frontend that
breaks cx fails check.sh immediately.

### Acceptance gates verified

- 3-step fixpoint on x86 main.cyr: cc5_a == cc5_b byte-identical
  at 709,776 B (no regression on x86 path). ✅
- check.sh **32/32 PASS** (gate 4u added). ✅
- cc5_cx builds at 365,696 B. ✅
- cc5_cx exits 0 on empty input. ✅
- cc5_cx exits 0 on `syscall(60, 0);` input. ✅
- Bytecode output starts with `CYX\0` magic header. ✅

### What's next: v5.7.12 (cx correctness)

cc5_cx output today: valid CYX magic + some valid opcodes
interleaved with raw x86 instruction bytes
(`mov [rbp-8], rbx` etc. from parse_fn.cyr's prologue emit).
cxvm rejects most of it. Fixing requires parser-to-emit
interface re-architecture — see v5.7.12 section.

## v5.7.12 — cyrius-x bytecode semantic correctness

**Pinned 2026-04-27.** v5.7.11 fixed the build/startup drift
but explicitly stopped short of bytecode semantic correctness.
This slot fixes it. Cascaded from v5.7.12 RISC-V slot per user
"correctness over new features always".

### Problem

`parse_*.cyr` (the shared frontend) emits raw x86 instruction
bytes directly via `E3(S, 0xC18948)`-style calls in many code
paths that are NOT guarded by `if (_AARCH64_BACKEND == 1)` or
similar. On x86 builds: those calls produce x86 machine code →
correct. On aarch64 builds: aarch64 backend overrides `E3` to
do something arch-appropriate. On cx builds: the calls land in
cx's `EB` / `E2` / `E3` (which write the literal bytes into the
CYX bytecode stream) — producing x86 instruction bytes inside
what should be `[opcode:8][a:8][b:8][c:8]` 4-byte CYX
instructions. The interpreter sees noise.

### Approach (to be confirmed at slot start)

Two paths, both viable:

**Path A — replace direct x86 emits with abstract operations.**
Inventory every `E3(S, 0xNNNNNN)` etc. in `parse_*.cyr` shared
code; replace each with a named op (e.g.,
`E3(S, 0xC18948)` → `EMOVCA(S)`). Each backend defines the
abstract op natively. Cleaner long-term; matches the design
intent of having a backend abstraction. Probably hundreds of
sites.

**Path B — gate every direct-x86 emit with `_TARGET_CX == 0`.**
Less invasive structurally; preserves x86 emits in shared
code. Fragile: every future direct-x86 addition needs the
guard.

Path A is the right architectural answer; path B is a tactical
shortcut. Decision at slot start.

### Acceptance gates

1. `tests/regression-cx-build.sh` (v5.7.11 gate) still
   passes — no regression on the smaller-slot bar.
2. New `tests/regression-cx-roundtrip.sh`:
   - Compile `echo 'syscall(60, 42);' | cc5_cx > x.cyx`.
   - Run `cat x.cyx | cxvm` — exit code 42.
   - Repeat for half a dozen small programs (arithmetic,
     fn call + return, conditional, while loop).
3. cxvm accepts cc5_cx output without "not a .cyx file"
   errors.
4. x86 fixpoint clean — re-architecture must not regress
   x86 emits.

### Slot relationship

v5.7.13 (RISC-V) follows.

## v5.7.13 — RISC-V rv64

First-class RISC-V 64-bit target. Elevated from the v5.5.x
pillar list to its own minor on 2026-04-20, then slid:
v5.6.0 → v5.7.0 (2026-04-20, optimization arc lands first);
v5.7.0 → v5.7.1 (2026-04-24, sandhi fold takes v5.7.0);
v5.7.1 → v5.7.2 (2026-04-24, cyrius-ts takes v5.7.1);
v5.7.2 → v5.7.3 (2026-04-25, cyrius-ts completion takes v5.7.2);
v5.7.3 → v5.7.4 (2026-04-25, JSX slot for v5.7.3 cascaded final cleanup);
v5.7.4 → v5.7.5 (2026-04-25, real JSX AST cascaded out of v5.7.4 once heuristic-skip limits became clear);
v5.7.3 → v5.7.4 (2026-04-25, fixup-cap bump took v5.7.1 sit-blocking
slot, cyrius-ts cascaded down by one);
v5.7.7 → v5.7.8 (2026-04-26, fixup-cap 1MB+ + lint UFCS + atomic-output
bundle took v5.7.7 — cyrius-ts polish surfaced 3 tooling issues
in one pass that all needed to ship together);
v5.7.8 → v5.7.13 (2026-04-26/27, five slots inserted before
RISC-V: v5.7.8 = `cyrius check` repair + `cyrius deps` P1-P5
+ syscall-arity warning fix; v5.7.9 = silent fn-name collision
investigation (was bundled at v5.7.8 alongside RISC-V; lifted
from v5.7.10 → v5.7.9 on 2026-04-26 once v5.7.10's audit
showed the input_buf reshuffle deserves its own
slot); v5.7.10 = `input_buf` 512KB → 1MB heap-map reshuffle
(load-bearing for the ecosystem — hisab `dist/hisab.cyr` at
505,237 B = 96% of cap, every consumer inherits the prepended
bytes via `cyrius deps` auto-prepend);
v5.7.11 = `main_cx.cyr` drift fix + CI gate (smaller-slot:
parse-time + build-time + no-SIGSEGV-at-startup; the durable
part is the gate — drift accumulated because no CI ever built
cx); v5.7.12 = cyrius-x bytecode semantic correctness
(parser-to-emit re-architecture; cascaded from v5.7.12 RISC-V
slot 2026-04-27 per user "correctness over new features
always"). Rationale: a new architecture is
structurally different from v5.5.x items (correctness /
completion / runtime work on existing platforms), different
from v5.7.0's lib/-reshape work, different from v5.7.1's
ecosystem unblock, and different from
v5.7.2/v5.7.3/v5.7.4/v5.7.5's frontend work — separate
minor-patches for separate kinds of change. RISC-V needs:

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

**Prerequisites that must ship before v5.7.13 starts:**
- **v5.6.5 + v5.6.7–v5.6.21** — Compiler optimization arc.
- **v5.6.28** — shared-object emission landed.
- **v5.6.29** — downstream ecosystem sweep gate.
- **v5.7.0** — ✅ sandhi fold (post-fold stdlib shape).
- **v5.7.1** — ✅ fixup-table cap bump (32K → 262K). RISC-V port
  inherits the bumped cap and relocated brk so rv64 backend
  development happens against the new fixup-table size from
  day one.
- **v5.7.2** — ✅ cyrius-ts foundational. RISC-V inherits a
  compiler that emits from both `.cyr` and `.ts` source for the
  sync subset.
- **v5.7.3** — ✅ cyrius-ts completion + JSX (lex skip).
- **v5.7.4** — ✅ final cyrius-ts cleanup (`.ts` ≥99%, async
  tracking).
- **v5.7.5** — ✅ real JSX AST (consumes the last `.tsx` edges).
  RISC-V inherits a frontend-complete compiler so the rv64
  backend doesn't have to re-test frontend-specific code paths
  separately.
- **v5.7.6** — ✅ JSX inner-expr tokenization.
- **v5.7.7** — ✅ fixup-cap 1MB + atomic-output `cyrius build`
  + lint UFCS exemption.
- **v5.7.8** — `cyrius check` repair + `cyrius deps` P1-P5 +
  syscall-arity warning fix. RISC-V port inherits a clean
  toolchain UX (no silent-failure traps) before backend work
  begins, so rv64-specific failures surface loudly.
- **v5.7.9** — silent fn-name collision rule. RISC-V's
  syscalls peer (`lib/syscalls_riscv64_linux.cyr`) lands
  against a stdlib whose collision policy is fixed.
- **v5.7.10** — `input_buf` 512KB → 1MB. RISC-V's larger
  cross-arch sources fit without manual splitting; ecosystem
  hisab-class deps no longer eat the consumer's source budget.
- **v5.4.19 `#ifplat`** directive is live → RISC-V dispatch
  uses the new syntax from day one.

Deliberately NOT bundling other items into v5.7.13 — a new
architecture port is plenty of work on its own.

---

## v5.7.x — patch slate (interleaved with RISC-V)

Pinned items for the v5.7.x cycle, slot numbers assigned **during
the port** as RISC-V porting work surfaces additional items that
also need to land. Single-issue patches in the v5.4.x / v5.5.x
style — one focused fix per release, no grab-bags. The pinned
items below are guaranteed to ship before v5.7.x closeout; the
specific patch number depends on what else surfaces.

Items that already have firm slot numbers (v5.7.8 = check + deps
+ arity bundle, v5.7.9 = fn-name collision investigation,
v5.7.10 = input_buf 1MB, v5.7.11 = cx-drift fix, v5.7.12 = cx
semantic correctness, v5.7.13 = RISC-V) live in the dedicated
sections above; this section holds the rest of the v5.7.x work
that hasn't been pulled into a specific patch slot yet.

### v5.7.7 — fixup-cap 1MB+ + tool-issue bundle

**Pinned 2026-04-26** (re-pinned from earlier "v5.7.4 OR v5.7.5"
slot, now that v5.7.6 has shipped). v5.7.7 wedges in the
fixup-cap bump alongside three tooling fixes that surfaced
during v5.7.6 closeout work; RISC-V rv64 (was v5.7.7) slips to
v5.7.8.

**Bundle scope:**

1. **Fixup-table cap bump 262K → 1M (4×)** — the planned v5.7.4-
   OR-v5.7.5 entry, now landing here. The v5.7.1 bump (32K →
   262K) wasn't enough; sandhi consumers + agnostik-class
   derive-codegen burn fixups faster than 262K allows.
   - Cap bumped 262,144 → 1,048,576. Table size 4 MiB → 16 MiB.
   - 5 cap-check sites updated (parse_expr.cyr × 2,
     backend/cx/emit.cyr × 3) — the v5.7.1 entry's "16 sites
     across 5 files" framing was overcounted; today's actual
     sites are these 5. parse_expr's stale `>= 4096` check
     (lying error message said 262144) corrected to 1048576.
   - Brk extends +12 MB. Heap-relative offsets in
     `src/frontend/ts/lex.cyr` shift `S + 0x1B0B000` →
     `S + 0x270B000`. Total brk in `main.cyr` (with TS frontend):
     `S + 0x288C000` → `S + 0x348C000` (~52.5 MB).
2. **`cyrius lint` UFCS Pascal-prefix exemption** — agnostik-
   filed 2026-04-26 ([`docs/development/issues/cyrius-lint-ufcs-pascal-prefix-snake-case-2026-04-26.md`](../../../agnostik/docs/development/issues/cyrius-lint-ufcs-pascal-prefix-snake-case-2026-04-26.md);
   stays local per agnostik's instruction). 28/28 false-positive
   rate against the `<PascalStruct>_<snake_verb>` convention
   (`ResourceLimits_to_json`, etc.). Fix: extend the existing
   `Type_method` carve-out in `programs/cyrlint.cyr`'s snake_case
   check to accept `<PascalIdent>_<lowercase_snake>` patterns.
   The camel detector below the carve-out still catches
   `Foo_BadCase`, so genuine errors don't slip through. Closes
   all 28 agnostik warnings; genuine `badCamelCase` still flags.
3. **`cyrius build` atomic-output** — v5.7.6 cyrius build opened
   the output file with `O_TRUNC` BEFORE the compile ran, so
   any non-zero exit (e.g., the auto-prepend TS_TOK_CAP overflow
   on cyrius self-build) left an empty file on disk —
   destroying the previously-working binary. Fix: write to
   `<output>.tmp.<pid>`; on success rename → `output`
   (POSIX-atomic, same FS); on failure unlink the partial tmp
   and leave `output` untouched. Verified end-to-end: failed
   compile of bad source against an existing binary now
   preserves the binary byte-identical.
4. **`cyrius build --no-deps` for compiler self-build** —
   pinned, NOT yet implemented in this slot. Today
   `cyrius build src/main.cyr build/cc5` auto-prepends the 6
   stdlib deps from cyrius.cyml, which exceeds the 262K JS
   token cap (`error: token limit exceeded (262144)`) and (pre
   atomic-output fix) destroyed build/cc5. Workaround:
   `/tmp/cyrius_rebuild.sh` does the cat-pipe form directly.
   Fix scope: add `--no-deps` flag to `cmd_build` that skips
   the dep-include prepend. Trivial — wire one bool flag from
   CLI parse → `compile()`. Slotted into v5.7.7 IF time
   allowed (it didn't); carried forward as a v5.7.8 bonus
   pin (drop in if scope allows alongside the cyrius check /
   deps / arity bundle), since v5.7.8 already touches the
   `compile()` dep-prepend path for `cyrius check`.

**Acceptance gates:**

1. Cap message reads `(1048576)`.
2. cc5 self-host fixpoint clean (cc5 itself nowhere near 1M
   fixups; bump is invisible to cc5's own behavior). ✓
3. SY corpus parse acceptance still 100% on both .ts (2053/
   2053) and .tsx (435/435) post-bump. ✓
4. agnostik 1.0.0 lint warnings 28 → 0 across the 6 named
   files. ✓
5. `cyrius build` failure preserves any pre-existing output
   binary (atomic-output regression test). ✓
6. CHANGELOG enumerates the cap change, the relocation delta,
   the lint carve-out, the atomic-output fix, and any consumer
   unblock impact.

**Long-term consideration**: this is the THIRD time we've bumped
the fixup cap (16K → 32K pre-v5.6.x, 32K → 262K at v5.7.1, 262K
→ 1M here). At some point the static-cap pattern stops scaling.
The proposal section in [sit's original writeup](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md#alternative-considered-dynamic-fixup-table)
considered (and deferred) a dynamic vec-shaped table. If we hit
a 4th bump, the dynamic-table conversion becomes the right move.
Pin that as a v5.8.x or v5.9.x consideration if needed.

### v5.7.x — advanced TS features beyond SY corpus (anti-slip slot)

**Pinned 2026-04-26.** SY corpus parse acceptance hit 100% on
both `.ts` (2053/2053) and `.tsx` (435/435) at v5.7.6 via 10
narrow polish slots (definite-assignment, instantiation
expressions, modifier-vs-name disambig, generic fn types in
type position, template literal types, array destructure
defaults, labeled tuples, labeled statements, computed-key
destructure, arrow-w-object-return-type). The corpus is closed,
but TypeScript as a language has more depth that no SY file
exercises. Without an explicit slot, this work slips into the
void as "later" forever — the agent who shipped 100% on SY
won't see what to do next, and downstream consumers porting
non-SY-shaped TS bring back paper-cuts one by one.

This entry is the explicit pin so the work doesn't disappear.
Each line item is its own narrow patch slot when it surfaces:

- **Mapped types — full grammar**:
  `{ [+-]?readonly? [K in keyof T] (as T)? [+-]??: U }`. The
  `as`-clause for key remapping (TS 4.1+), `+/-readonly` and
  `+/-?` modifiers (the bare `readonly`/`?` already work; add
  the `+/-` prefixes), and `in <UnionType>` form for arbitrary
  iterators (not just `keyof`). Spec:
  <https://www.typescriptlang.org/docs/handbook/2/mapped-types.html>.
- **`asserts` predicate signatures**:
  `function assert(x: T): asserts x;` and
  `function assertIsString(x: unknown): asserts x is string;`.
  Return-type position only, after the `:` of a function /
  method signature. Not allowed on arrow function expression
  types. Spec: TS 3.7 release notes.
- **Decorators**: `@foo class X {}`, `@foo prop: T`,
  `@foo method() {}`, `@foo() class X {}` (decorator factory
  call form). TS 5.0 stage-3 standard decorators preferred over
  the `experimentalDecorators` form. Affects parse — emit a
  decorator AST node attached to the following declaration.
- **`as const`** assertion expressions. Postfix `expr as const`
  is parsed today as a regular `as` cast against an undeclared
  `const` ident — works by accident. Make it explicit: a
  `KW_CONST` token after `as` is a literal-narrowing assertion,
  not a type ref.
- **Variadic tuple types**: `[...A, ...B]`, `[T, ...U]`,
  `[...U, T]`. The single `...rest: T[]` already works in
  labeled tuples; the multi-spread / leading-spread / mixed
  forms don't.
- **Const type parameters (TS 5.0)**:
  `function f<const T>(x: T)`. `const` modifier in front of a
  type parameter — narrows inferred literal types. New
  contextual keyword position.
- **`satisfies`** operator. v5.7.4 added KW_SATISFIES as a
  contextual keyword usable as an ident name; verify the
  postfix `expr satisfies Type` operator form parses too.
  Already a TS-corpus feature flag.
- **`never` and `unknown` as primitives** in type position.
  Audit whether these are accepted alongside `void`/`null`/
  `undefined` in `TS_PARSE_TYPE_PRIMARY`.
- **Conditional types — exhaustive corpus**:
  `T extends U ? X : Y` already parses; verify nested
  conditional + `infer T` + distributive patterns
  (`T extends any ? f<T> : never`) all hold up.

**How items get triggered:** when a downstream consumer files a
parse failure on a non-SY TS shape, the matching item from this
list moves out and gets its own narrow slot (matching the
v5.7.6 cyrius-ts polish pattern: smallest repro → grammar
ref → fix → corpus regression → bump threshold).

**No fixed deadline.** This is a "don't lose track" pin, not a
schedule pin. The 8-item list above is illustrative — TS is an
active language and more features will land. Update this slot
when they do.

### v5.7.x — warning sweep (compiler emits + scripts/check.sh + tooling)

**Pinned 2026-04-26** (surfaced during v5.7.7 closeout). cc5
self-build emits three classes of warnings that have accumulated
without dedicated cleanup; `scripts/check.sh` itself emits a
shell-syntax warning at line 305-306 mid-run that's been tolerated
because the gate it guards still PASSes. None individually warrant
a slot; together they're a single targeted sweep.

**Findings on cc5 self-build (5.7.7):**

1. `warning:src/frontend/lex.cyr:227: syscall arity mismatch`
2. `warning:src/frontend/lex.cyr:240: syscall arity mismatch`
3. `warning:<source>:7: syscall arity mismatch` (the auto-prepend
   `version_str.cyr`-or-similar inclusion site, surfacing whenever
   cc5 builds itself).
4. `note: 36 unreachable fns (22571 bytes — set CYRIUS_DCE=1 to
   eliminate)` — the dead-code floor includes the
   `dead: ir_dce` / `dead: ir_dead_store` / `dead: ir_dead_block_elim`
   trio (the optimizer scaffolding shipped at v5.6.16-O3b but never
   wired live at default), plus
   `dead: TS_LEX_JSX_BALANCE_BRACES` / `dead: _TS_LEX_JSX_WALK`
   from v5.7.5's pre-mode-stack JSX prototype, plus three
   `_macho_w*` helpers + `EMITMACHO_ARM64`. The floor needs an
   audit pass: keep the IR-pass scaffolding (paid-for foundation),
   delete the genuinely-dead JSX/macho remainders.

**Findings in `scripts/check.sh`:**

5. Line 305-306 emits `command substitution: line 306: syntax
   error: unexpected end of file from \`if' command on line 305`
   immediately before the "Bare-truthy after fn-call" gate runs.
   The gate still PASSes — the warning is from a malformed
   `$( ... )` block in the test's setup that bash silently recovers
   from. Belongs in the same sweep so the audit reads clean.

**Findings across tooling:**

6. Pass over `cbt/`, `programs/`, `bootstrap/` for shell-script
   warnings (any `sh -n`-clean check first; then a `shellcheck`-
   style read where available without bringing in a foreign tool).
7. Pass over `cyrius lint` / `cyrius vet` / `cyrius fmt` warnings
   on the stdlib + `programs/`. The current 7 dep-files-skipped
   note from check.sh is informational; check that the skips are
   still wanted and not swallowing real findings.

**Fix scope:**

- Investigate and resolve each `syscall arity mismatch` —
  3 sites in lex.cyr + 1 source-time site. Either fix the
  arity (most likely root cause: a syscall fn declared with
  N args being called with N+1 / N-1 in those specific lines)
  or document the deliberate variadic-style call pattern with
  a `# noqa`-style suppression if one exists.
- Audit the 36-dead-fn floor; remove genuine corpses, leave
  paid-for scaffolding with a one-line comment pointing at the
  slot that earned it.
- Repair `scripts/check.sh` line 305-306 syntax.
- Sweep one tier outward (`cbt/`, `programs/`, `bootstrap/`).

**Acceptance gates:**

1. `cc5 < src/main.cyr > /tmp/cc5_b 2>/tmp/err; wc -l /tmp/err`
   — emits ZERO `warning:` lines.
2. `note: N unreachable fns` floor reduced to a documented
   minimum (target ≤ 20 from current 36).
3. `sh scripts/check.sh 2>&1 | grep -c "syntax error"` returns 0.
4. Full check.sh still 29/29 PASS post-sweep.

**Slot relationship:** standalone slot. Don't bundle with
feature work — warning sweeps tend to spread without a dedicated
boundary.

### v5.7.x — cx codegen literal-arg propagation

**Pinned 2026-04-27** (surfaced during v5.7.12 path-B testing).
cc5_cx's codegen for `syscall(N, V)` and similar literal-arg
patterns doesn't propagate the literal value through `EMOVI`.
Bytecode for `syscall(60, 42)` shows `movi r0, 0` (val=0)
instead of `movi r0, 60` and `movi r0, 42`. The 60 *does*
appear later as `movi r1, 60` (the syscall-number register
load), but the second arg (42) doesn't appear at all.

**Repro** (against cc5_cx v5.7.12):
```sh
echo 'syscall(60, 42);' | cc5_cx | xxd | head -4
# 00000000: 4359 5800 0000 0000 5001 0000 0100 0000  CYX.....P.......
# 00000010: 8000 0000 0100 0000 8000 0000 8102 0000  ................
# 00000020: 8101 0000 7000 0000 0202 0000 0101 3c00  ....p.........<.
# 00000030: 7000 0000                                p...
# Note: literal 42 is NOWHERE in the bytecode.
```

**Pre-existing**: same bytecode shape with v5.7.11 cc5_cx —
this is NOT a v5.7.12 regression. Path B made the bytecode
clean of x86 noise; this slot fixes the literal-propagation
gap independently.

**Root-cause investigation needed**:
- Is `parse_expr.cyr`'s syscall arg parse path calling
  `EMOVI(S, val)` correctly?
- Is `CX_MOVI(S, 0, val)` getting val=0 instead of the actual
  literal?
- Or is some prior call clobbering `_cfv` between PCMPE and
  EMOVI?

The same parse path produces correct bytecode on x86 (cc5
self-compile works); cx-specific behavior in EMOVI or a state
global it depends on is the suspect.

**Acceptance gate**:
- `echo 'syscall(60, 42);' | cc5_cx | cxvm` → exit 42.
- New `tests/regression-cx-syscall-exit.sh` (or extension of
  `regression-cx-roundtrip.sh`).

**Slot scope**: small focused investigation (likely 1-2 hour
debug pass). Slot when v5.7.13 RISC-V wraps or earlier if a
cx consumer surfaces.

### v5.7.x — basic regex primitives in the stdlib

**Pinned 2026-04-27** (user request, alongside the cyim
`--grep` → `--find` design from cyrius-bb's tooling pain
points). Cyrius stdlib lacks regex support; consumers fall
back to literal-substring matching (`memeq`, `strstr`-style
loops) or bring their own ad-hoc state machines. cyim's
`--grep` was designed assuming regex semantics it didn't
have — exactly the kind of gap a stdlib primitive would
prevent.

**Scope (basic)**: a small focused module —
`lib/regex.cyr` — that ships a usable subset, not full PCRE.
Target the 80% case for downstream tools (cyim, cyrius lint,
agent-side log scanning, etc.).

**Proposed primitive set** (confirm at slot start):
- **Anchors**: `^` (start), `$` (end).
- **Single chars**: literal chars, `.` (any non-newline), `\d`
  (digit), `\D` (non-digit), `\s` (whitespace), `\S`
  (non-whitespace), `\w` (word char), `\W` (non-word).
- **Char classes**: `[abc]`, `[^abc]`, `[a-z]`, `[a-zA-Z0-9_]`.
  No POSIX `[[:digit:]]` named classes in basic — `\d` covers it.
- **Quantifiers**: `*` (0+), `+` (1+), `?` (0 or 1). NO `{n}` /
  `{n,m}` in basic — pin those for an extended-regex follow-up
  if needed.
- **Alternation**: `a|b`. Lowest precedence within a group.
- **Grouping**: `(...)` for grouping. NO capture groups in
  basic — extended pin if a consumer needs match extraction.
- **Escape**: `\` for literal metacharacters.

**Out of scope for basic** (extended-regex follow-up):
- Backreferences (`\1`, `\2`).
- Lookahead / lookbehind (`(?=...)`, `(?<=...)`).
- Named captures (`(?<name>...)`).
- POSIX character classes (`[[:digit:]]`, etc.).
- `{n,m}` exact-count quantifiers.
- Unicode property classes (`\p{L}` etc.).
- Multi-line flag, case-insensitive flag — pin for a `\flags`
  / fn-arg-flags follow-up.

**API shape** (proposed, confirm at slot start):
```cyr
# Compile a regex pattern at runtime. Returns a regex handle
# (heap-allocated state machine) or 0 on parse error.
fn regex_compile(pattern: Str) : i64;

# Free a regex handle.
fn regex_free(re: i64) : i64;

# Test if pattern matches anywhere in subject.
fn regex_test(re: i64, subject: Str) : i64;

# Find first match; returns byte offset or -1.
fn regex_find(re: i64, subject: Str) : i64;

# Extract first match into a buffer; returns match length or
# -1. Buffer should be at least subject_len bytes.
fn regex_match(re: i64, subject: Str, out_buf: Ptr) : i64;
```

**Implementation approach**: Thompson NFA construction +
backtracking interpreter. Small, well-understood, no
dependency on Cyrius features that aren't shipping.
Reference: Russ Cox's "Regular Expression Matching Can Be
Simple And Fast" (https://swtch.com/~rsc/regexp/regexp1.html).
~300-500 LOC implementation.

**Acceptance gates**:
- `tests/tcyr/regex_basic.tcyr` covers each primitive: anchors,
  char classes, quantifiers (`*` `+` `?`), alternation, escape,
  grouping (non-capturing).
- `tests/tcyr/regex_edge.tcyr` covers edge cases: empty pattern,
  empty subject, pattern with only metacharacters, alternation
  with empty branch, quantifiers on grouped subexpressions.
- `lib/regex.cyr` lints clean; documented in
  `docs/cyrius-guide.md` stdlib section.
- Compiler self-host fixpoint clean (regex.cyr is opt-in via
  `include`; cc5 itself doesn't use it).

**Consumer unblock**: cyim ships `--find <pattern>` (regex)
+ `--regex=<flavor>` (selector) per the cyrius-bb tooling
pain-point doc design — once `lib/regex.cyr` lands, cyim's
`--find` becomes a thin wrapper around the stdlib API instead
of importing a foreign regex engine.

**Slot scope**: medium (300-500 LOC + tests + doc). Lands as
its own focused patch in the v5.7.x cycle. Pre-RISC-V is fine
if it surfaces a need; otherwise post-RISC-V.

### v5.7.x — `cyrius fuzz` stdlib auto-prepend parity

**Pinned 2026-04-25** (cyim-agent surfaced). `cyrius fuzz` builds
each `fuzz/*.fcyr` harness via raw `compile(path, tmpbin)` —
nothing prepends the stdlib deps the way `cyrius bench` /
`cyrius test` do for `*.bcyr` / `*.tcyr` harnesses (which inherit
the project's stdlib via the `cyrius.cyml` deps phase). Result:
authors of fuzz harnesses must hand-add `include "lib/io.cyr"`,
`include "lib/alloc.cyr"`, etc. for any stdlib symbol the included
`src/*` files reference, even though the project manifest already
declares those deps.

**Fix scope:** `cbt/commands.cyr::cmd_fuzz` should walk the same
manifest-deps codepath that `cmd_test` / `cmd_bench` walk before
calling `compile()`. One refactor: extract the prepend logic into
a shared helper (`_run_with_stdlib(path)` or similar) and call it
from all three command bodies.

**Acceptance:** delete the redundant `include "lib/*.cyr"` lines
from each `fuzz/*.fcyr` harness; `cyrius fuzz` still passes all
5 current harnesses (freelist, hashmap, str_coerce, string, vec).

**Bundle candidate:** ship alongside the `.scyr` / `.smcyr`
slot below — both are "test-runner shape" cleanups in the same
file.

### v5.7.x — string-literal escape sequences (`\x##`, `\u####`, full set)

**Pinned 2026-04-26** (cyim-surfaced; cyim v1.1.x uses
`"\x1b[?1049h"` and family for ANSI/VT escape sequences in
`lib/tty.cyr`-equivalent code, with hardcoded byte-length
arguments to `syscall(write)` that assume the lex decodes
`\x1b` → byte `0x1b`). Cyrius's lex today appears to **strip
the leading `\` but emit the next character verbatim**, so
`"\x1b[?1049h"` becomes the 10-byte string `x1b[?1049h`; the
syscall's hardcoded length (`8`) then truncates to `x1b[?104`,
which the terminal renders as literal text instead of executing
the alt-screen-enter command. cyim is currently **unusable
interactively** because of this — agent-drive (`--write` /
`--replace[-all]` / `--grep`) works (no escape sequences in
that path), but the TTY editor surface is a stream of literal
`\x1b[…` characters on screen.

This is a **language-side bug** per the "compiler grows to fit
the language, never the other way around" rule
(`feedback_grow_compiler_to_fit_language.md`). The right fix
is to grow the lex's escape-sequence set; the wrong fix is to
rewrite cyim's `tty.cyr` to build escape sequences via
`store8(&buf, 0x1b)` byte-at-a-time (which is what
`tty.cyr:196` already does as a workaround pattern, but
shouldn't have to).

**Audit first** — the v1.1.0 cyim surface assumes `\x##` works
silently; we don't actually know what cyrius lex *does* support
today vs what the user-facing reference doc claims. Likely
already supported: `\n`, `\t`, `\r`, `\\`, `\"`, `\0`. Likely
missing: `\x##`, `\u####`, `\u{…}`, possibly `\a` `\b` `\f`
`\v`. The audit determines exact scope.

**Fix scope** (size depends on audit; conservative estimate):

- `src/frontend/lex.cyr` (and the TS variant
  `src/frontend/ts/lex.cyr` if independently authored) string-
  literal scanner: extend the `\` branch to recognize:
  - `\x` followed by exactly two hex digits (case-insensitive
    `[0-9a-fA-F]{2}`) → emit one byte (the parsed value).
    Reject `\xZ` / `\x1` / `\x1Q` etc. with a lex error
    pointing at the bad nibble.
  - `\u` followed by exactly four hex digits → emit the UTF-8
    encoding of the codepoint (1-4 bytes). Codepoints in the
    surrogate range `D800-DFFF` are a lex error.
  - `\u{…}` form for codepoints > U+FFFF (1-6 hex digits inside
    the braces; `\u{0}` valid; max `\u{10FFFF}`).
  - Audit-time addition: `\a` (0x07), `\b` (0x08), `\f` (0x0C),
    `\v` (0x0B) if missing.
- Update the cyrius user-facing docs (`docs/cyrius-guide.md`
  string-literals section) with the full table.
- Update `vidya/content/cyrius/language.toml` per CLAUDE.md
  closeout-pass step 11 (vidya falls out of sync silently).

**Acceptance gates:**

1. New `tests/tcyr/string_escapes.tcyr` covers each new escape
   form, including reject-cases (`\x` followed by non-hex,
   `\u` followed by < 4 hex digits, surrogate codepoints).
2. cc5 self-host fixpoint clean (cc5's own source has zero
   `\x##` today; the bump is invisible to cc5 itself).
3. cyim v1.1.1 (or whichever version is current when the bump
   ships) toolchain-pin bumped in `cyrius.cyml`; cyim rebuilt;
   the alt-screen / cursor / clear sequences in `src/tty.cyr`
   reach the terminal as actual ESC `[…` byte sequences;
   interactive `cyim <file>` round-trips without literal-text
   garbage.
4. CHANGELOG enumerates the new escape forms + the cyim
   unblock; `feedback_grow_compiler_to_fit_language.md` cited
   in the slot's project-memory entry as the framing
   precedent.

**Out of scope for this slot:** raw-string literals
(`r"…"` / `r#"…"#`); template/format strings beyond what
the lex already does; locale-dependent `\N{…}` Unicode names.
Each of those is its own slot if they're ever wanted.

**Pre-fix cyim workaround** (so cyim can ship interactively
*before* this lands, if needed): rewrite the six functions in
`cyim/src/tty.cyr:163-168` to build their escape sequences
into a heap buffer via repeated `store8` (mirroring the
existing pattern at `tty.cyr:196`), then `syscall(write)` the
buffer. ~30 LOC; ugly, but unblocks the editor surface. cyim
slot if the cyrius bump slips: `tty_alt_enter` /
`tty_alt_leave` / `tty_clear` / `tty_cursor_hide` /
`tty_cursor_show` / `tty_cursor_home` rewritten as
byte-builders.

### v5.7.x — `.scyr` (soak) + `.smcyr` (smoke) file types

**Pinned 2026-04-25.** Today, soak and smoke testing are scattered:
`cyrius soak` is a built-in fixed routine (N self-host iterations,
hardcoded in `cbt/commands.cyr::cmd_soak`); smoke is implicit in
`scripts/check.sh` via shell scripts that orchestrate cyrius
binaries — and at least one (`tests/regression-capacity.sh`) drops
to **Python 3** to synthesize a 3,500-fn stress source. The Python
dependency leaks into the test surface despite cyrius's
"sovereign toolchain, no external runtime" stance.

**Fix scope:** mirror the `*.tcyr` / `*.bcyr` / `*.fcyr` discovery
shape:

- **`*.scyr`** (soak harnesses): user-authored long-running
  loops + invariants. `cyrius soak` discovers `tests/scyr/*.scyr`
  and `soak/*.scyr` in addition to the built-in self-host loop;
  per-harness iteration count via `--iterations=N` flag (already
  parsed for the built-in case).
- **`*.smcyr`** (smoke harnesses): user-authored quick-validation
  programs (a smoke test is "did this start at all"). New
  `cyrius smoke` subcommand discovers `tests/smcyr/*.smcyr` and
  `smoke/*.smcyr`; runs each, exits non-zero on first failure.

Both inherit the same stdlib auto-prepend that `cyrius test` /
`cyrius bench` use (and `cyrius fuzz` will, post the slot above).

**Migration:** rewrite `tests/regression-capacity.sh`'s
synthetic-source generation as a `.scyr` (cyrius emits
`var f1 = 0; var f2 = 0; ...` via a loop, then includes the
result). One Python invocation gone; the larger goal is no
Python in the `check.sh` chain at all (`cyrius-port.sh`
references python only as a future port-source language, which
is fine to leave).

**Acceptance:**
- `cyrius soak` discovers + runs `tests/scyr/*.scyr` (creates
  the dir if absent; skips silently when empty)
- `cyrius smoke` is a new subcommand with the same shape
- `tests/regression-capacity.sh` rewritten to invoke
  `cyrius soak --filter=capacity` (or similar) instead of
  shelling to `python3`
- `grep -rn 'python3' scripts/ tests/` returns zero hits

**Bundle decision:** likely lands as a single patch with the
`cyrius fuzz` parity slot above — both touch the same
`cmd_test` / `cmd_bench` / `cmd_fuzz` family in
`cbt/commands.cyr`.

### v5.7.x — `cyrius deps` transitive resolution

**Pinned 2026-04-23.** Distinct from v5.7.8's `cyrius deps`
P1-P5 ergonomic fixes — that slot covers silent-failure /
discoverability / count / lockfile-default issues; this slot
covers transitive resolution (the resolver itself walking the
dep graph). Both ship in v5.7.x; transitive resolution stays
its own slot because the design surface is wider (recursive
walker, cycle detection, conflict policy).

`cyrius deps` currently resolves only **direct** dependencies
from `cyrius.cyml`'s `[deps]` table — if the user's manifest
pins `mabda`, mabda's own `cyrius.cyml` depends on `sigil` and
`sakshi`, those transitive deps don't get fetched. Today the workaround is to add every transitive dep to
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
| **v5.7.13** | RISC-V rv64 | ELF | Queued — slid v5.6.0 → v5.7.0 → v5.7.1 → v5.7.2 → v5.7.3 → v5.7.4 → v5.7.5 → v5.7.6 → v5.7.7 → v5.7.8 → v5.7.9 → v5.7.10 → v5.7.11 → v5.7.12 → v5.7.13: optimization arc → sandhi fold → fixup-cap bump → cyrius-ts foundational → cyrius-ts completion → cyrius-ts polish → real JSX AST → JSX inner-expr → fixup-cap 1M + tooling → cyrius check + deps + arity → fn-name collision → input_buf 1MB → cx-drift fix → cx semantic correctness → RISC-V |
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
| RISC-V (rv64) | ELF | Queued — **v5.7.13** |
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
