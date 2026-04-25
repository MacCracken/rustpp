# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.7.1** (shipped — **fixup-table cap bump 32,768 → 262,144**.
sit-blocking ecosystem unblock per sit's proposal. All 8 named
sandhi consumers (vidya/yantra/hoosh/ifran/daimon/mela/ark/sit)
now able to actually pin sandhi in `[deps].stdlib` without
overflowing the fixup table. Wedged into v5.7.1 via git rewind +
fixup-cap commit + cherry-pick of cyrius-ts P1.1+P1.2 work back
on top (preserved on `wip/cyrius-ts-p1` branch during the dance).
16 cap-check sites updated across 5 backend files; brk extended
+3.5 MB across 4 main entry files; capacity-meter output and
heap-layout comments updated. cc5 self-host fixpoint clean at
531,880 B (8 B smaller than v5.7.0; cc5 itself never approaches
32K fixups so cap bump doesn't change its behavior). check.sh
26/26 PASS.)

**5.7.0** (shipped — **THE SANDHI FOLD**. Clean-break consolidation
per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md).
`lib/sandhi.cyr` adds (vendored byte-identical from `sandhi/dist/sandhi.cyr`
at the v1.0.0 tag, 376,037 B / 9,649 lines, 469 fns); `lib/http_server.cyr`
deletes (no alias, no passthrough); `tests/tcyr/http_server.tcyr` deletes
with it. All 17 deprecated `http_*` public fns have 1:1 `sandhi_server_*`
replacements (audit-confirmed pre-fold, full table in CHANGELOG).
`scripts/lib/audit-walk.sh` extended to skip `cyrius distlib`-generated
files in fmt+lint walks (marker-based, complements existing symlink-based
skip for `cyrius deps`-managed deps; dep files skipped 6 → 7).
Acceptance gates 1, 2, 5, 6 ✅ on cyrius side; gates 3 + 4 (downstream
sweep across yantra/hoosh/ifran/daimon/mela/vidya/sit-remote/ark-remote)
are separate work, organized by user. Sandhi repo enters maintenance
mode — subsequent surface patches land via Cyrius release cycle.
Zero compiler change → cc5 byte-identical at 531,888 B; check.sh
26/26 PASS.)

**5.6.45** (shipped — VS Code TextMate grammar refresh.
Extended `editors/vscode/syntaxes/cyrius.tmLanguage.json` to
cover the v5.6.x syntax wave: 4 new keywords (`secret`, `match`,
`in`, `shared`) + 10 new directives (`#deprecated`, `#pe_import`,
`#must_use`, `#regalloc`, `#endplat`, `#include`, `#ifplat`,
`#elif`, `#else`, `#ifndef`). All grep-confirmed as live cyrius
syntax before adding. Directives ordered longest-prefix-first
to avoid Oniguruma alternation false-matches. JSON valid. Pairs
with v5.6.44: now the `#deprecated("use lib/sandhi.cyr instead")`
attributes on `lib/http_server.cyr` render as preprocessor
directives in VS Code, making the deprecation banner unmissable.
Zero compiler change → cc5 byte-identical at 531,888 B; check.sh
26/26 PASS.)

**5.6.44** (shipped — v5.7.0 prep patch. `lib/http_server.cyr`
deprecation-notice cycle: all 17 public fns marked
`#deprecated("use lib/sandhi.cyr instead -- removed at v5.7.0")`
via the v5.6.4 fn-attribute mechanism + file-header deprecation
block. Per-call-site warning fires at every consumer call site
(stronger notice than one-shot include-time print). Satisfies
roadmap line 718 prerequisite. Zero compiler change → cc5
byte-identical at 531,888 B; check.sh 26/26 PASS;
http_server.tcyr 31/31 with 31 deprecation warnings fired.
v5.7.0 fold blocks on sandhi M5 → v1.0.0 tag + downstream
consumer-side dual-build branches + `cyrius distlib`
verification.)

**5.6.43** (shipped — LAST polish patch of v5.6.x. Closeout finish
(CLAUDE.md "Closeout Pass" steps 9-11) + sigil 2.9.0 → 2.9.3 +
sankoch 2.0.3 → 2.1.0 dep bumps + output_buf 1MB → 2MB heap
reshuffle (16-region shift
+1MB; brk 22.5MB → 23.5MB) + heap-map fix-through across the 4
main_*.cyr files (stale fixup_tbl docs corrected; 0xA0000
documented as v5.6.27 codebuf-compaction tables not fixup_tbl)
+ vidya per-minor refresh (language/dependencies/ecosystem).
Sigil 2.9.3 brings AES-NI + SHA-NI compress (~80x SHA-NI
throughput win on hosts with hw support).)

## Compiler

- **cc5 (x86_64)**: **531,880 B** (8 B smaller than v5.7.0 —
  small byte-shift from v5.7.1's 32K → 262K constant change
  creating slightly different optimization opportunities; cc5
  itself never approaches 32K fixups so the cap bump doesn't
  change its semantic behavior). `cc5 --version` reports
  `cc5 5.7.1`.
- **cc5_win (cross)**: 526,856 B (unchanged from v5.6.42 — same reason)
- **cc5_aarch64 native (Pi)**: 463,768 B (was: did not build — v5.6.32 added
  the missing `include "src/common/ir.cyr"` to `main_aarch64_native.cyr` that
  had been orphaned since v5.6.12 O3a shipped the IR instrumentation
  references to `IR_RAW_EMIT`)
- **cc5_aarch64 (cross)**: 411,520 B (was 411,136 at v5.6.39; +384 B from heap-shift constants)
- **cc5_win (cross)**: 526,552 B (was 526,376 at v5.6.39)
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

- **check.sh**: 26/26 PASS (Linux x86_64 daily-driver + cross-platform skip-stubs)
- **`tests/tcyr/*.tcyr`**: 67 files (was 68; `http_server.tcyr` deleted with the v5.7.0 fold)
- **`fuzz/*.fcyr`**: 5 harnesses
- **`benches/*.bcyr`**: 14 benchmarks
- **Stdlib**: 60 modules (53 first-party + 7 vendored/deps: 6 via `cyrius deps`
  symlinks — sakshi, patra, sigil, yukti, mabda, sankoch — plus
  `lib/sandhi.cyr` vendored from `cyrius distlib` at sandhi v1.0.0)

## In-flight

**v5.7.2 (cyrius-ts foundational) — about to resume after fixup-cap
wedge.** v5.7.1 just shipped (fixup-table cap bump 32K → 262K, sit
unblock). cyrius-ts P1.1 + P1.2 work preserved on
`wip/cyrius-ts-p1` branch during the wedge; cherry-picks back as
the first commits of v5.7.2 with one-line heap-base update
(`S + 0x178B000` → `S + 0x1B0B000`) to land on the post-v5.7.1
brk. Then resume P1.3 (multi-char operators).

**v5.7.0 (sandhi fold) — cyrius side ✅ shipped.** Cyrius-side
acceptance gates 1, 2, 3, 5, 6 closed (CHANGELOG enumerates the
deleted/added symbol delta + downstream audit). Open work
(separate, user-organized):

- ⏳ Downstream consumer sweep — gate 4 of v5.7.0. Audit found
  the real footprint is much smaller than the original 8-repo
  roadmap list implied: `sit-remote` and `ark-remote` don't
  exist (real names are `sit` and `ark`); none of the 8 had
  `[deps.sandhi]` pinned (gate 3 already satisfied); only
  **vidya** actually `include`s `lib/http_server.cyr`
  (in `src/main.cyr`). yantra and sit also have orphan
  pre-fold copies of `lib/http_server.cyr` (regular files, not
  `cyrius deps` symlinks — likely manual copies from early
  sandhi M0 era) that need deletion for cleanliness.
  hoosh / ifran / daimon / mela / ark have no v5.7.0 work.
- ⏳ Vyakarana grammar refresh for sandhi syntax (469 fns now in
  stdlib; vyakarana likely doesn't index them yet — coordinate
  with owl colorizer work).
- ⏳ Vidya per-minor refresh (language.toml / dependencies.toml /
  ecosystem.toml updates for the v5.7.0 stdlib reshape; deferred
  until downstream sweep also lands so vidya reflects post-sweep
  ecosystem state).

Sandhi repo enters maintenance mode per ADR 0002 — subsequent
surface patches land via Cyrius release cycle, not sandhi releases.
Sandhi git history retained as historical reference; no new tags
cut post-fold.

**Long-term considerations (no version pin)**: copy propagation +
cross-BB extended dead-store elimination — both recon-evaluated at
v5.6.18/v5.6.19-attempt, both bail (zero direct savings on stack-machine
IR; cross-BB versions need v5.6.21 regalloc liveness data first). See
`roadmap.md §Long-term considerations` for full recon data + revisit
criteria.

## Recent shipped (one-liner per release)

- **v5.7.1** — **FIXUP-TABLE CAP BUMP** 32,768 → 262,144 (8×).
  sit-blocking ecosystem unblock per [sit's proposal](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md);
  unblocks all 8 named sandhi consumers (vidya/yantra/hoosh/ifran/
  daimon/mela/ark/sit) from `[deps].stdlib "sandhi"` overflow.
  Wedged into v5.7.1 via git rewind to v5.7.0 + fixup-cap commit +
  cherry-pick of cyrius-ts P1.1+P1.2 work (preserved on
  `wip/cyrius-ts-p1`). 16 cap-check sites updated across 5 backend
  files (proposal originally listed 5 sites; x86 backend was missing
  + aarch64 had a variant string format we caught). Brk extended
  +3.5 MB across 4 main entry files. main.cyr capacity-meter
  output + heap-layout comments updated; pre-existing off-by-2x
  percentage math bug at line 1073 (stale `/ 16384` divisor)
  fixed in passing. cx backend's cap bumped uniformly but its
  smaller heap layout left untouched (cx never approaches 32K
  fixups). cc5 self-host fixpoint clean at 531,880 B (8 B
  smaller than v5.7.0 from the constant-change byte-shift; cc5
  itself unchanged semantically). check.sh 26/26 PASS. Resumes
  cyrius-ts work as v5.7.2.
- **v5.7.0** — **THE SANDHI FOLD**. Clean-break consolidation per
  sandhi ADR 0002: `lib/sandhi.cyr` adds (vendored byte-identical
  from `sandhi/dist/sandhi.cyr` at v1.0.0 tag — 376,037 B / 9,649
  lines / 469 fns covering M0–M5: HTTP client + server + HTTP/2 +
  streaming + JSON-RPC + service discovery + TLS policy);
  `lib/http_server.cyr` deletes (no alias, no passthrough); 17
  deprecated `http_*` fns confirmed 1:1-mapped to `sandhi_server_*`
  pre-fold. `tests/tcyr/http_server.tcyr` deletes with the lib
  (suite 68 → 67 files). `scripts/lib/audit-walk.sh` extended to
  skip `cyrius distlib`-generated files (marker-based, complements
  symlink-based skip for `cyrius deps` deps; dep skip count 6 → 7).
  Acceptance gates 1, 2, 5, 6 ✅; gates 3 + 4 (downstream sweep
  across yantra/hoosh/ifran/daimon/mela/vidya/sit-remote/ark-remote)
  are separate user-organized work. Sandhi repo enters maintenance
  mode. Zero compiler change → cc5 byte-identical at 531,888 B
  (cc5 doesn't include either lib); cc5 --version → 5.7.0;
  check.sh 26/26 PASS.
- **v5.6.45** — VS Code TextMate grammar refresh
  (`editors/vscode/syntaxes/cyrius.tmLanguage.json`). Extended
  to cover the v5.6.x syntax wave: 4 new keywords (`secret`,
  `match`, `in`, `shared`) + 10 new directives (`#deprecated`,
  `#pe_import`, `#must_use`, `#regalloc`, `#endplat`, `#include`,
  `#ifplat`, `#elif`, `#else`, `#ifndef`). All grep-confirmed
  as live cyrius syntax. Directive pattern ordered
  longest-prefix-first to avoid Oniguruma alternation
  false-matches; trailing `\b`. Pairs with v5.6.44: the
  `#deprecated("use lib/sandhi.cyr instead")` attributes on
  `lib/http_server.cyr` now render as preprocessor directives in
  VS Code (and through Claude Code's IDE integration via
  `mcp__ide__getDiagnostics`), making the v5.7.0 cutover
  signal unmissable. Out-of-scope (deliberately not bundled):
  CLI fence-tag convention (no Claude Code plugin/config surface
  for custom-language grammar registration — researched via
  claude-code-guide; working through OWL routing instead via
  `~/.claude/settings.json` permission rule); vyakarana grammar
  resync (separate repo, separate audit); CYIM (cyrius-aware
  editor binary, pinned for after owl + sit stable). cc5
  byte-identical at 531,888 B (grammar-only edit). check.sh
  26/26 PASS.
- **v5.6.44** — `lib/http_server.cyr` deprecation-notice cycle
  for v5.7.0 prep. All 17 public fns marked
  `#deprecated("use lib/sandhi.cyr instead -- removed at v5.7.0")`
  via the v5.6.4 fn-attribute mechanism + file-header deprecation
  block. Per-call-site warning fires at every consumer call site
  (parse_fn.cyr:352) — stronger notice than one-shot include-time
  print. Satisfies roadmap line 718 prereq for the v5.7.0 sandhi
  fold (which deletes the file). Design choice: reuse existing
  `#deprecated` infra rather than build a new `#warning`
  directive — zero compiler change → zero self-host risk; matches
  "compiler grows to fit language, never the other way around."
  cc5 byte-identical at 531,888 B (cc5 doesn't include the lib).
  http_server.tcyr 31/31 (31 deprecation warnings fire at compile;
  test exits 0). check.sh 26/26 PASS. Notice cycle now runs in
  parallel with sandhi's M5 → v1.0.0 work; v5.7.0 fold lands
  when sandhi tags v1.0.0 + downstream branches ready.
- **v5.6.43** — closeout finish + sigil 2.9.0 → 2.9.3 + sankoch
  2.0.3 → 2.1.0 + output_buf 1MB → 2MB heap reshuffle. CLAUDE.md "Closeout Pass" steps 9-11
  ran clean: security re-scan (no new sys_system / unchecked
  READFILE / new execve paths; full audit due v5.7.x — last v5.0.1),
  downstream pin matrix snapshotted across 16 ecosystem repos
  (older-minor pins enumerated as v5.7.0 sandhi-fold worklist),
  vidya refreshed (language.toml / dependencies.toml /
  ecosystem.toml — version refs, patra 1.6.0 → 1.8.3 details,
  sigil 2.9.0 → 2.9.3 details, ALPN hook surface mention).
  Sigil 2.9.3 = AES-NI dispatch + SHA-NI compress (drop-in
  software-SHA-256 replacement, ~80x throughput win on x86_64
  SHA-NI hosts; surfaced by sit v0.6.4 perf review). Bump
  required adding `lib/fdlopen.cyr` / `lib/ct.cyr` /
  `lib/sha1.cyr` / `lib/keccak.cyr` includes to the 3
  "include-everything" test fixtures (transitive deps from
  sigil's new symbols). Resulting compiled-fixture size crossed
  the 1MB output_buf cap → reshuffle: output_buf 1MB → 2MB,
  16 regions shifted +1MB (tok_types/values/lines, struct
  ftypes/fnames, fn_names band, ir_nodes/blocks/state/edges/cp,
  fixup_tbl), brk 22.5MB → 23.5MB. Cap-check sites at 4
  EMITELF/macho overflow points updated 1048576 → 2097152.
  Heap-map fix-through caught stale `0xA0000 fixup_tbl` docs in
  4 main_*.cyr files (region was repurposed at v5.6.27 to
  jump_src_tbl for codebuf compaction; docs were 16 patches
  stale). cc5 byte-identical at 531,888 B (heap shifts are
  immediates, no byte-count change). check.sh **26/26 PASS**
  with the previously-failing 3 fixtures (large_input,
  large_source, preprocessor_past_cap) now compiling to
  ~1.08MB ELF and running cleanly. **v5.6.x closes here**;
  v5.7.0 (sandhi fold + lib/ cleanup) is next. Pinned for
  v5.7.x: `cyrius deps` transitive resolution, full security
  audit, downstream pin sweep before fold opens.
- **v5.6.42** — compiler-side closeout (CLAUDE.md "Closeout Pass"
  steps 1-8) + bundled PP_DEFINE/PP_DEFINED/PP_GETVAL/PP_EVAL_IF/
  PP_HASH `src_base` hardening (latent v5.6.30 same-class bug
  closed for the rest of the helper family). Mechanical: cc5
  3-step fixpoint clean at 531,888 B (+112 B); bootstrap closure
  clean; check.sh **26/26 PASS** (new gates: `preprocessor_past_cap.tcyr`
  + `regression-macho-cross-build.sh`). Judgment: heap-map clean,
  24-fn dead floor preserved (each is a real scaffold per its own
  inline docstring — multi-target Mach-O, ESHRIMM/ELVR* unfinished
  optimizations, IR scaffolds for deferred O3 work), refactor pass
  found cross-backend duplication intentional (alternates per build),
  code-review surfaced the PP_DEFINE bug fixed in this slot, cleanup
  sweep updated stale brk heap-map comments to 0x168B000 / 22.5 MB
  across main_aarch64*.cyr + main_win.cyr. v5.6.43 = closeout finish
  (compliance + downstream dep-pointer check + sigil 2.9.3 fold-in
  + final doc sync). LAST patch of v5.6.x.
- **v5.6.41** — SysV 16-byte stack alignment fix for odd-stack-arg
  callers (sandhi-blocking, M2 HTTPS-live unblock). Sandhi-filed
  2026-04-25: any cyrius fn with 7/9/11 formal params calling
  `tls_connect` (or any libssl/libc fn with SSE in its prologue)
  SIGSEGV'd at the resolved external symbol's first instruction.
  Root cause: `ECALLPOPS`'s SysV path emitted `add rsp, 48`
  unconditionally; for odd `nextra = N - 6` this left rsp 8-aligned
  at the CALL site, violating SysV's `rsp+8 16-aligned at entry`
  rule. Win64 path already aligned (line 1067). Fix: shift step-2
  writes down 8 bytes (write to `[rsp+(5+i)*8]` not `[rsp+(6+i)*8]`)
  and `add rsp, 40` not `add rsp, 48` for odd nextra; even nextra
  unchanged. `ECALLCLEAN` adds 8 extra back to release the alignment
  padding. New regression gate `tests/tcyr/sysv_odd_stack_args.tcyr`
  (5 assertions, callers 7/8/9/10/11 → SSE-using leaf). cc5
  531,584 → 531,776 B (+192 B). check.sh **25/25 PASS**. 3-step
  fixpoint clean. Sandhi's `_min_repro_7arg_tls.cyr` now returns
  valid TLS contexts for both 6-arg and 7-arg paths. Closeout
  cascaded: v5.6.42 = compiler-side closeout, v5.6.43 = finish.
- **v5.6.40** — `lib/tls.cyr` ALPN/mTLS/custom-verify hook
  surface (sandhi-pinned) **+ bundled patra 1.6.0 → 1.8.3
  dep bump + 1 MB → 2 MB preprocessor expanded-source cap
  raise (12-region heap reshuffle, brk 21.5 MB → 22.5 MB)**.
  ALPN: sandhi 0.8.1 had wire-format encoding ready since
  2026-04-24 but couldn't fire `SSL_CTX_set_alpn_protos`
  because stdlib `tls_connect` built its `SSL_CTX` privately
  with no customisation point. New `tls_dlsym(name)` +
  `tls_connect_with_ctx_hook(sock, host, hook_fp, hook_ctx)`;
  `tls_connect` collapses to a 1-line wrapper. End-to-end
  verified at Cloudflare 1.1.1.1:443 → server picks h2.
  Patra: 1.7.0 INSERT OR IGNORE + 1.7.1 STR-keyed B+ tree
  indexes + 1.8.2 page-slab allocator + word-at-a-time
  `_memeq256` + prepared statements (`patra_prepare` /
  `patra_exec_prepared` / `patra_query_prepared` /
  `patra_finalize`) + 1.8.3 fmt/lint/doc cleanup. Cap raise:
  `large_input.tcyr` + `large_source.tcyr` crossed the 1 MB
  cap by ~280 B once patra 1.8.3 (~14 KB larger than 1.6.0)
  joined the include set; both tests' actual goal is
  >256 KB, so they were already 768 KB above their stated
  bar. Right answer: grow the cap, not trim the language.
  Reshuffle hit `preprocess_out → 2 MB` and shifted every
  region forward 1 MB across `src/main*.cyr`, every
  `parse_*.cyr`, `lex.cyr`, `lex_pp.cyr`, `ir.cyr`, every
  `backend/*/{emit,fixup,jump}.cyr`. Subtle bugs surfaced:
  (1) 9 `var O = S + 0x64A000` EMITELF sites were OLD
  output_buf base, not new codebuf — moved to 0x74A000;
  (2) `var pfx = S + 0x64A000 + 131072` scratch in
  `backend/x86/fixup.cyr` was OLD output_buf tail — moved
  to 0x74A000; (3) `0x150B000` ambiguous between OLD
  fixup_tbl (16-byte stride) and NEW ir_cp (4-byte stride)
  — disambiguated via stride; (4) `0x13CA000` ambiguous
  between OLD ir_state and NEW ir_blocks — ir_state shifted
  to 0x14CA000 with offset family `+8/+10/+18/+20`;
  (5) `0xECA000` ambiguous between OLD ir_nodes and NEW
  struct_fnames — ir.cyr shifted to 0xFCA000.
  3-step fixpoint clean (`b == c == d` byte-identical at
  531,584 B). check.sh **25/25 PASS** (was 24/25 with
  large_input/large_source failing the 1 MB cap; now well
  under 2 MB). Closeout cascaded v5.6.40 → v5.6.41.
- **v5.6.39** — `cc5 --version` drift repair + hardcoded-
  literal removal. Caught via Starship prompt observation:
  cyrius repo bumped to v5.6.38, but `cc5 --version` still
  said `5.6.29-1`. Root cause: `version-bump.sh`'s regex
  `[0-9]+\.[0-9]+\.[0-9]+\\n` didn't accept the `-N` hotfix
  suffix; once `5.6.29-1\n` baked in, the sed gate's grep
  failed silently for 9 consecutive releases (5.6.30→5.6.38).
  Fixed by **removing the hardcoded-literal class entirely**:
  new auto-generated `src/version_str.cyr` holds the version
  vars; `main.cyr` and `main_win.cyr` `include` it and
  reference the vars in the syscall. version-bump.sh writes
  the file via heredoc — no regex hunting, no per-file
  sweeping, no `-N` suffix vulnerability. Same-version
  invocation also regenerates (documented "regenerate without
  bumping" path now works). cc5 rebuilt: 531,360 → 531,584 B
  (+224 B for include + var refs); 3-step self-host
  byte-identical; `cc5 --version` correctly reports v5.6.39.
  Closeout cascaded v5.6.39 → v5.6.40.
- **v5.6.38** — shared-object emission slot ran the
  verify-premise check first (per v5.6.33/v5.6.36 lessons).
  Result: `.so` emission has been complete and shipping since
  v5.5.x. `tests/regression-shared.sh` (in check.sh as gate
  4a) covers all four PIC surfaces (fn calls + string literal
  refs + mutable globals + DT_INIT) and continues to PASS.
  The roadmap's "SYSV_HASH is unreachable, hash chain not
  wired" framing was misleading — the SysV ELF spec + glibc
  `dl-lookup.c` show chain walks do pure strcmp, never hash
  comparison, so `nbucket=1` makes the hash function
  genuinely irrelevant. Slot deliverable: removed dead
  `SYSV_HASH` (14 LOC) + the misleading comment + added a
  pointer to `.gnu.hash` as a long-term consideration (no
  consumer needs it). cc5 −320 B (531,680 → 531,360);
  unreachable-fn count 25 → 24. 3-step self-host
  byte-identical. check.sh 25/25.
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
