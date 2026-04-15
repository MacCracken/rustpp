# Agent handoff — 4.8.5 GA

## State at handoff

- **Released**: 4.8.5 (math stdlib pack + HTTP CRLF hardening +
  TLS interface scaffold). Merge commit on `main`.
- **Previous release**: 4.8.4 (register allocation), retagged
  post-GA to fold in a `PP_IFDEF_PASS` preprocessor fix bote 2.5.0
  surfaced.
- **Working tree**: clean on `main` at 4.8.5 after the merge.
- **Downstream consumers**: pins range 4.0.0 → 4.8.3 across the
  ecosystem. See `docs/development/roadmap.md` for the list.

## Repo health snapshot

- cc3 self-host: byte-identical (verified at GA).
- `check.sh`: 8/8 PASS.
- Test surface: 51 .tcyr files, 396 assertions. 5 fuzz harnesses.
  11 .bcyr benchmarks.
- Compiler capacity at self-compile: `fn=324/4096 ident=8146/131072
  var=100/8192 fixup=1621/16384 code=345368/1048576`. Plenty of
  headroom on every axis.
- Dead fn count: 7 (stable since 4.8.3).
- Heap map last authoritative audit: v3.6.10 (per
  `src/main.cyr` header). Incremental updates tracked per-alpha
  in the CHANGELOG; re-run `tests/heapmap.sh` when adding a new
  table.

## Immediate next work

Per `docs/development/roadmap.md`:

1. **4.8.6 — defmt**. Compile-time format-string interning +
   runtime decode ring. High effort (new bytecode for formats,
   runtime expander in stdlib). Slid from 4.8.5 to make room for
   the math pack.
2. **4.8.7 — `f64_parse(cstr)`**. Standalone minor per the abaco
   triage. Scientific notation + `Inf`/`NaN` + round-to-nearest.
3. **4.8.8 — Live TLS bridge**. Prereq: `lib/dynlib.cyr`
   hardening pass (it currently segfaults on `libssl.so.3`
   parse). Once dynlib is stable, wire
   `lib/tls.cyr` through to libssl. Interface was intentionally
   shipped as fail-clean stubs in 4.8.5-alpha3 so there's no API
   churn at bridge-landing time.

Order can slide — 4.8.8 is blocked on a dynlib fix that could
jump the queue if any consumer hits a dynlib segfault.

## Open threads

- **bote 2.5.0 CI binary skew** (`../bote/docs/bugs/cyrius-4.8.4-ci-binary-skew.md`):
  *Fixed* in the 4.8.4 retag. Bote should un-pin the lean
  workaround in `tests/bote.tcyr` once they've rolled forward
  to 4.8.4-retagged or 4.8.5.
- **Downstream pin floor** (`CLAUDE.md` says "v3.4.0 recommended
  minimum"): still accurate. Raise when the install tarball
  format or dep resolution protocol changes incompatibly.
- **dynlib.cyr segfault on libssl.so.3**: reproduced on the dev
  box during 4.8.5-alpha3. Blocking the live TLS bridge. Owned
  separately from the TLS interface work.

## Conventions the outgoing agent leaned on

- **Per-alpha CHANGELOG entry, always.** Every alpha / beta / GA
  gets its own `## [X.Y.Z-...]` block with Added / Changed /
  Fixed / Validation / Roadmap sections. The `## [4.8.5]` GA
  entry is the canonical template.
- **Validation section is mandatory and specific.** "cc3
  self-host byte-identical (two-step bootstrap)" and
  "X/X check.sh PASS" are the minimum; benchmarks get captured
  numbers, security fixes get CVE-class identifiers.
- **Feature work runs on a branch, security + critical fixes
  land on main.** The 4.8.5 cycle ran on a `4.8.5` branch;
  the 4.8.4 retag (bote regression) landed on main directly.
  Cherry-picking from branches into main is OK; the other
  direction needs a merge.
- **Scope-discipline over rapid iteration.** When 4.8.5-alpha3
  tried to ship the live libssl bridge but hit dynlib segfaults,
  the fix was to walk scope back to interface-only, not to
  debug dynlib under time pressure. Alpha discipline (small,
  self-contained, tested) matters more than minor velocity.
- **Consumer-driven stdlib additions only.** Every 4.8.5 helper
  traced back to an abaco or bote stopgap. No speculative
  additions. The triage doc
  (`docs/issues/stdlib-math-recommendations-from-abaco.md`)
  is the template — use it when the next consumer submits a
  recommendation list.

## Files worth skimming early

- `CLAUDE.md` — non-negotiables.
- `CHANGELOG.md` head → `## [4.8.5]` GA entry (current state) and
  `## [4.8.4]` (register allocation + bote triad).
- `docs/language-development-notes.md` — outgoing agent's opinion
  piece. Not doctrine.
- `docs/development/roadmap.md` — shipped vs. planned.
- `src/main.cyr` heap map header (lines 10–115). The state layout
  is load-bearing; every new table goes through that map.
- `lib/u128.cyr::u128_divmod` (fast path + asm block) — the
  cleanest current example of the Cyrius asm-block idiom.

## Things not to change without asking

- Self-hosting gate. If you're about to commit something that
  breaks `cc3 == cc4` byte-identical, stop and investigate. There
  is no "it's a harmless cosmetic change" here.
- The heap map offsets in `src/main.cyr`. Every offset is
  load-bearing across the compiler and asm blocks. New tables
  claim new offsets, they don't shift existing ones.
- The two-step bootstrap chain (seed → cyrc → asm → cyrc). If a
  change needs the bootstrap to re-run, call that out in the
  alpha before shipping.
- CHANGELOG ordering. Newest at top, `[Unreleased]` entries only
  for *true* pending releases (the 4.8.4 retag re-used the
  existing 4.8.4 entry rather than adding a dangling section).

Good luck. The language is small and the tests are honest — lean
on both.
