# Cyrius Development Roadmap

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).


## v5.3.x / v5.4.x / v5.5.x / v5.6.x / v5.7.x — shipped

All v5.3.x–v5.7.x per-patch detail lives in
[completed-phases.md](completed-phases.md);
[CHANGELOG.md](../../CHANGELOG.md) is the source of truth.

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

1. **RISC-V (v5.7.26-v5.7.30) lands and adds 4th backend**, making
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

### Stdlib data-domain distlib carve-out (sibling-repo consolidation)

**Status**: long-term thought captured 2026-05-01 during the
v5.8.x slot-pinning conversation. Not pinned to any minor; revisit
post-v5.8.x when the language vocabulary stabilizes and hisab-
class consumers have ported.

**The idea**: extend the v5.7.0 sandhi-fold precedent (HTTP/RPC
moved out of stdlib into a sibling distlib) across the rest of
the data-domain stdlib modules. Cyrius core retains primitives
(syscalls, alloc, str/string, vec, hashmap, fmt, io, fs); the
"data offshoots" (json, toml, cyml, csv, base64, regex, math,
matrix, linalg, bigint, u128) carve out into a new sibling-
distlib repo. Consumers pull what they need via `[deps.<name>]`:

```
[deps.core]   = "cyrius-core"   (always — language primitives)
[deps.json]   = "cyrius-data"   (modules = ["dist/json.cyr"])
[deps.math]   = "cyrius-data"   (modules = ["dist/math.cyr", "dist/matrix.cyr"])
[deps.regex]  = "cyrius-data"   (modules = ["dist/regex.cyr"])
```

**Why the precedent fits**: sandhi proved the model works (clean-
break fold at minor cut, byte-identical distfile, consumer
adopts `[deps.<name>]` line, stdlib surface trims). Each carve-
out shrinks cyrius's stdlib footprint without changing what
consumers can build with the toolchain. Downstream usage gets
cleaner — projects pull only what they touch instead of
inheriting the kitchen-sink.

**Why deferred (not v5.8.x scope)**: the v5.8.x cycle is already
folding 5 language features forward; adding a 13-module-carve-out
would blow scope. More importantly, the v5.8.x language-
vocabulary work (slices / Result / allocators) WILL touch these
modules' APIs (`json.cyr` parses via `Result<Value, JsonError>`,
`vec_push` takes an allocator). Carving them out before the API
shape stabilizes means re-folding right after — wasted motion.

**Trigger to pin**: post-v5.8.41 closeout, once the language-
vocabulary migration has rippled through stdlib. At that point
each carve-out is a clean lift-and-shift (no API churn imminent).
Likely v5.9.x consideration if the carve-out aligns with bare-
metal needs (kernel target may want NO data-distlib, just
core), or v6.0.0 cleanup if held longer.

**Out of scope for this entry**: the specific repo split (one
big "cyrius-data" sibling vs. multiple narrow ones — `cyrius-
json` / `cyrius-math` / `cyrius-regex`). Pin that decision when
the trigger fires. Sandhi is one repo with `dist/sandhi.cyr` —
multiple-modules-per-distlib pattern works.

**Why `dep.core` matters as a primitive**: separating "language
primitives the compiler needs to see" from "stdlib modules
consumers may opt into" makes bare-metal targets cleaner —
the AGNOS kernel target (v5.9.0) only needs the primitives.
Today there's no clean line; this carve-out draws it.

---

## Sigil 3.0 enablers — remaining

Downstream `sigil` items the Cyrius toolchain still owes. Shipped
enablers (`ct_select` v5.3.2, `mulh64` v5.3.3, `secret var` v5.3.5,
`lib/keccak.cyr` v5.4.15, SSE m128 alignment fix v5.5.21 unblocking
AES-NI, fixup cap raise v5.5.37 unblocking sigil 3.0 parallel batch)
are in CHANGELOG. **Sigil 3.0 shipped 2026-05-01** — toolchain side
unblocked end-to-end; X25519 (if/when needed) is a sigil-internal
addition with no remaining cyrius-side prereqs. Pure-Cyrius TLS work
absorbed into sandhi at v5.7.0 fold; section retained for shipped-
enabler audit trail.




## v5.8.x — Optimization + language-vocabulary stabilization (42 pinned slots; soft backstop ~.49; 7-slot headroom)

**Theme** (re-scoped 2026-05-01 at v5.8.0 ship): bug-fix /
optimization minor that ALSO folds forward the language-feature
suites originally pinned for v5.10.x / v5.11.x / v5.12.x —
slices, effect annotations, tagged unions + exhaustive match,
`Result<T,E>` + `?` propagation, and allocators-as-parameter.

**Strategic re-theming** to compress the original 4-5 separate
language-feature minors into one cycle: shipping these in v5.8.x
lets hisab + downstream consumers do ONE port pass instead of
re-porting across v5.9.x → v5.12.x. Coherent with the
optimization theme — `Result<T,E>` IS an optimization across
every -1/0/errno hot path; allocator-parameter convention IS
the perf-correctness alignment that enables per-request arenas;
slices replace ptr+len pairs in every crypto / network / I/O
hot path.

**42 pinned slots** (v5.8.1 → v5.8.42) across 3 phases (cascaded
+1 at v5.8.5 for SSH-gate carve-out, +4 at v5.8.9 for slices
re-scope to 5-patch sub-arc, **+6 at v5.8.14 to absorb the
slices true-completion sub-arc** — v5.8.13's "honest scope-
shrink" deferrals were a bandaid; user-directed re-scope to
ACTUALLY ship first-class slices instead of typedef + helpers;
**+1 at v5.8.18 for api-surface refresh + auto-build wiring +
null-byte-in-shell-substitution fix** — gate has been silently
skipping since v5.7.50 due to unbuilt binary):
- Phase 1 (v5.8.1–v5.8.8): quick-win unblockers — fmt cap raise,
  packaging fix, ts/parse fmt sweep, f64_log2 parser dispatch
  (v5.8.4) + f64_log2 SSH-gate hardware verification (v5.8.5),
  syscall surface symmetry, _SC_ARITY audit, NI-class
  investigation. **Phase 1 complete at v5.8.8 ship.**
- Phase 2 (v5.8.9–v5.8.36): language vocabulary —
  slices foundation (5, v5.8.9-13) + slices true-completion
  (6, v5.8.14-19), effects (1), tagged unions (5),
  Result<T,E>+? (5), allocators (6).
- Phase 3 (v5.8.37–v5.8.42): polish + closeout — including
  api-surface refresh as v5.8.42 (pre-closeout backstop
  sized for fix + snapshot regen + downstream consumer
  rebuild verification).

Soft backstop pushed from ~.44 to ~.49 (mirroring v5.7.49's
end-of-cycle backstop pattern). 7-slot headroom (v5.8.43-v5.8.49)
covers surface-during-cycle items + a final closeout backstop if
Phase 3 finds late-cycle issues. Below v5.7.x's 51-patch record.

**Bare-metal arc + RISC-V rv64 stays at v5.9.x** — arch-port
work better paired after the language vocabulary stabilizes.
**v5.13.x** then opens for tail-end v5.x work (security
hardening, polymorphic codegen, `cc5`→`cyc` prep) before v6.0.0.

### v5.8.0 ✅ P(-1) hardening + vani fold-in + cyriusly starship.toml — SHIPPED 2026-05-01

Triple-anchor opener for the minor:

**1. P(-1) hardening** per CLAUDE.md §"P(-1): Project Hardening" —
cleanliness (`cyrius fmt --check`, `cyrius lint`, `cyrius vet`), test
sweep (.tcyr / heap audit / self-host), benchmark baseline (`cyrius
bench` pre-changes), audit (stale code / dead paths / opt
opportunities), refactor pass on findings, post-audit benchmarks vs
baseline, doc sync (CHANGELOG / roadmap / vidya).

**2. Vani audio distlib fold-in.** Pinned 2026-04-30. `vani` (Sanskrit
वाणी, Saraswati's name — "voice / speech") is the audio-domain
sibling distlib mirroring the mabda / sankoch / sigil / yukti pattern.
Fold-in doc: [`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md).
Vani-side migration done already (lib/audio.cyr → vani/src/alsa.cyr,
two-byte stack-array bug fix carried in the lift, "audio" dropped
from `[deps].stdlib` in vani's manifest).

Cyrius-side work:

1. Add `[deps.vani]` block to `cyrius/cyrius.cyml` (alphabetical slot
   between `[deps.sigil]` and `[deps.yukti]`), pinned to whatever
   vani tag ships at 5.8.0 cut time:
   ```
   [deps.vani]
   git = "https://github.com/MacCracken/vani.git"
   tag = "<vani-tag-at-cut>"
   modules = ["dist/vani.cyr"]
   ```
2. Delete `cyrius/lib/audio.cyr` (236 LOC). `dist/vani.cyr` provides
   the same `audio_*` symbol set bundled inline plus the higher-level
   `vani_*` API (typed errors, ring buffer, XRUN recovery, mixer,
   yukti adapter).
3. CHANGELOG entry: "audio.cyr retired — ALSA PCM now lives in vani;
   consumers replace `include \"lib/audio.cyr\"` with `include
   \"lib/vani.cyr\"`."
4. Pre-flight `grep -rn 'lib/audio.cyr' /home/macro/Repos` to confirm
   no in-tree consumer still imports the old path (per vani's fold-in
   doc, no AGNOS in-tree consumer does as of vani v0.1.0 cut).
5. Refresh stdlib-reference and ecosystem.cyml entries — vani joins
   the canonical sibling-distlib roster alongside mabda / sankoch /
   sigil / yukti / sandhi.

API stability: `audio_*` surface is byte-for-byte stable — existing
call sites keep working under the new include path. New `vani_*`
surface (typed errors, ring buffer, XRUN recovery, mixer) becomes
available without further work.

**3. `cyriusly` starship.toml prompt rework.** Cyrius identity glyph
at the shell level. Current state (`scripts/cyriusly:190-206`) ships
a single `[custom.cyrius]` segment with `symbol = "𝕮"` (Mathematical
Bold Fraktur C, U+1D56E) showing the toolchain version. Reworking
into a two-segment flow:

Target format: `<pkg-icon> NAME VERSION (repo) | <cyrius-icon> VERSION`

- **Cyrius icon**: 🌀 cyclone (U+1F300) primary, with `𝕮` retained
  as the ASCII-ish fallback (the existing symbol stays valid in
  terminals that don't render the emoji cleanly; cyclone signals
  self-hosting recursion + the "cyr-" name shape). Implementation:
  set `symbol = "🌀"`, document the fallback in the script comment;
  consumers on emoji-hostile terminals can keep their existing
  installs (which still have `𝕮`).
- **Package icon**: ॐ Om (U+0950). Aligns with the ecosystem's
  Sanskrit naming convention (sigil / mabda / sakshi / sankoch /
  samvada / vani / yukti / patra all Sanskrit) — instantly identifies
  a cyrius package without competing with rust's 📦 / go's gopher /
  python's snake.

Sketch:

```toml
# Package segment — fires when cyrius.cyml [package] block exists
[custom.cyrius_pkg]
command = """awk '/^\\[package\\]/{p=1; next} p && /^\\[/{p=0} p && /^name/{gsub(/[ "=]/,""); n=substr($0,5)} p && /^version/{gsub(/[ "=]/,""); v=substr($0,8); if(v ~ /\\$\\{file:VERSION\\}/) {while((getline x < "VERSION") > 0) v=x}} END{print n " " v " (" basename "")}' basename="${PWD##*/}" cyrius.cyml"""
when = "test -f cyrius.cyml"
symbol = "ॐ"
style = "bg:teal"
format = '[[ $symbol $output ](fg:base bg:teal)]($style)'

# Toolchain segment — fires alongside, separated by the | divider
[custom.cyrius]
command = """if [ -f bootstrap/asm ]; then cat VERSION 2>/dev/null; else cc5 --version 2>/dev/null | awk '{print $2}' || cat ~/.cyrius/current 2>/dev/null || echo '?'; fi"""
when = "test -f cyrius.cyml || test -f cyrius.toml"
symbol = "🌀"
style = "bg:teal"
format = '[| $symbol $output]($style)'
```

Concrete format-string + parser robustness (cyrius.cyml `[package]`
shape variations, version interpolation `${file:VERSION}`) pinned
during the slot. Mirror the same icon swap into the p10k segment
(`scripts/cyriusly:198-206`).

### v5.8.x — pinned slot map (30 slots; pinned 2026-05-01)

Surfaced from sakshi `2026-04-30-cyrius-lang-blockers.md`, mabda
`2026-04-30-toolchain-issues.md`, phylax `2026-04-30-cyrius-
stdlib-issues.md`, and the 2026-05-01 vidya audit. Plus the
language-vocabulary suites pulled forward from the original
v5.10.x / v5.11.x / v5.12.x scope per the 2026-05-01 re-theming
(strategic compression: one ecosystem port pass instead of 4-5).

**Pinning policy**: 30 slots pinned firm; soft backstop ~.44
with 14 slots of headroom for surface-during-cycle items.
Single-issue patches per the v5.4.x / v5.5.x discipline — no
grab-bags. Phase boundaries are advisory; if Phase 1 surfaces
follow-ons or Phase 2 sub-patches need extra slots, the cycle
absorbs them within the headroom budget.

#### Phase 1 — Quick-win unblockers (slots 1-7)

- **v5.8.1** — `cyrius lint` / `cyrius fmt` 128 KiB buffer cap
  raise (mabda Class A1). Same fix shape as v5.7.36 distlib
  (64K → 256K → 524K). Silent truncation past 131,072 B —
  `cyrius fmt $f > $f` destroys data; mabda `backend_native.cyr`
  (137 KiB), cyrius's own `src/frontend/ts/parse.cyr` (195 KiB,
  deferred from v5.8.0 fmt sweep) both hit this. Bump to
  ≥524288 B (4× distlib precedent for fmt output growth).
  **Bundles**: `cyrius-prompt-info` redundancy fix (drop
  `name` from `pkg` mode output — `ॐ vidya 2.3.0 (vidya)` →
  `ॐ 2.3.0 (vidya)`; one-line edit to `scripts/cyrius-prompt-
  info`).

- **v5.8.2** — `cc5_aarch64` packaging fix (sakshi / yukti) +
  `build/cyrc_check` orphan delete (audit §4). Move
  `cc5_aarch64` back under `bin/` in `install.sh` / release
  tarball; drop downstream workaround pattern from sakshi /
  yukti / patra / mabda CI files. Paired with the trivial
  `build/cyrc_check` orphan delete (zero references in `scripts/`
  / `.github/` / `tests/`; audit §4). Canonical upstream report:
  [`yukti/docs/development/issues/2026-04-30-cyrius-cc5-aarch64-packaging.md`](https://github.com/MacCracken/yukti/blob/main/docs/development/issues/2026-04-30-cyrius-cc5-aarch64-packaging.md).

- **v5.8.3** — `src/frontend/ts/parse.cyr` fmt sweep follow-up.
  Closes the v5.8.0 deferral (file at 195,483 B couldn't fmt
  without truncation); v5.8.1's cap raise unblocks it. Mechanical
  patch — single `cyrius fmt` invocation; should produce the
  ~1500-line idiomatic re-flow.

- **v5.8.4** ✅ `f64_log2` aarch64 polyfill — parser dispatch
  (phylax #1). Shipped 2026-05-01 at `79eeae4`. Replaced the
  parse_expr.cyr hard-reject with stdlib polyfill dispatch
  mirroring the v5.7.30/31 f64_exp/f64_ln shape. New
  `_f64_log2_polyfill` in `lib/math.cyr` via change-of-base
  `log2(x) = ln(x) * F64_LOG2E`; new `F64_LOG2E` global hoisted
  from `_f64_exp_polyfill`'s local. cc5 720,928 → 721,352 B
  (+424 B for new dispatch). x86 path unchanged (native fyl2x).

- **v5.8.5** ✅ `f64_log2` aarch64 polyfill — SSH-gate hardware
  verification. Shipped 2026-05-01. Carved out from v5.8.4
  per user direction after pi-live status surfaced post-commit.
  Extended `tests/regression-aarch64-f64-polyfill.sh` with 4 new
  log2 cases (log2(1)=0, log2(8)=3, log2(1024)=10, log2(0.5)=-1)
  + ulp-budget comments + check.sh gate description update.
  cc5_aarch64 cross-compiler rebuilt (420,648 → 421,072 B,
  matching cc5's dispatch growth). Verified bit-accurate on real
  aarch64 hardware via SSH pi. **Phylax #1 now FULLY closed**
  (parser dispatch + hardware-verified polyfill). Bug-fixed
  during gate authoring: initial test bit-pattern for log2(1024)
  was wrong (0x408F4... = 1000.0, not 1024.0); corrected to
  0x4090000000000000.

- **v5.8.6** ✅ `sys_stat` / `sys_fstat` x86_64 wrapper backfill
  (phylax #2). Shipped 2026-05-01. 4 LOC fn additions to
  `lib/syscalls_x86_64_linux.cyr` (sys_stat → SYS_STAT direct
  syscall; sys_fstat → SYS_FSTAT direct) closing the cross-arch
  surface asymmetry against `lib/syscalls_aarch64_linux.cyr:346-
  353`. Block comment documents the divergence (x86 has direct
  stat/fstat; aarch64 routes through newfstatat with AT_FDCWD).
  cc5 unchanged at 721,352 B (stdlib-only). Phylax + agnosys
  drop their local backfills on next pin bump.

- **v5.8.7** ✅ `_SC_ARITY` cross-arch false-positive gate
  (phylax #3 + sakshi). Shipped 2026-05-02. Single-line gate in
  `parse_expr.cyr:589` (`if (_AARCH64_BACKEND == 0) { ... arity
  check ... }`). The arity table is x86_64-specific by design;
  on aarch64 the same numerical syscall values denote different
  operations (e.g. aarch64 SYS_NEWFSTATAT=79 = x86 getcwd; aarch64
  SYS_FSTAT=80 = x86 chdir). Pre-fix: 11 spurious warnings on
  4-line stdlib probe. Post-fix: 0. Tradeoff: hand-written aarch64
  syscalls with wrong arity now surface at runtime instead of
  compile-time. Future polish slot could add `_SC_ARITY_AARCH64`
  to restore aarch64-side arity warnings — held until a consumer
  surfaces an aarch64 arity bug.

- **v5.8.8** ✅ phylax #4 NI-class investigation — STALE PIN,
  closed by sigil 3.0.0 upstream churn. Shipped 2026-05-02.
  Premise-check at slot entry surfaced the dupes don't reproduce
  at v5.8.7 + sigil 3.0.0; sigil's own `[lib].modules` section-
  header fix in 2.9.5 → 3.0.0 closed both x86 and aarch64 dupe
  classes; cyrius's pin to 3.0.0 at v5.7.49 deps refresh
  transitively closed phylax-reported residue. Verified clean
  across 3 reproduction paths (sigil src/lib.cyr aarch64 cross,
  programs/smoke.cyr aarch64 cross, sigil tcyr 96/96). Doc-only
  patch matching v5.7.46 audit-pass shape.

#### Phase 2 — Language vocabulary stabilization (slots 9-30)

The 5-feature compression: ship slices + effect annotations
+ tagged unions + `Result<T,E>` + `?` + allocators in one
cycle so hisab + downstream consumers do ONE port pass. Each
sub-feature's sub-patch breakdown matches the original
v5.10.x/v5.11.x/v5.12.x scopes.

##### v5.8.9–v5.8.13 — First-class slices (`slice<T>` / `[T]` generalizing `Str`)

A type carrying `(ptr, len)` with bounds-aware APIs. Every
`read(buf, len)` / `memcpy(dst, src, n)` / `aead_encrypt(pt,
pt_len, ct, ct_len, tag)` today is a ptr+len pair the compiler
doesn't check — slices make bounds-aware APIs the default.

**Scope re-pinned 2026-05-02 at v5.8.9 ship**: originally
single-slot; honest scope-check at slot entry surfaced this
needs the same 5-patch sub-arc shape as Tagged unions / Result /
Allocators. Sub-arc:

- **v5.8.9** ✅ §1 — Type-position parse-acceptance for
  `slice<T>` + `[T]`. Shipped 2026-05-02. Pure parser change in
  `parse_decl.cyr`'s PARSE_VAR type-annotation block: added
  LBRACKET branch consuming `[T]` element-type forms;
  `slice<T>` form already parse-accepted via the existing ident
  + SKIP_GENERICS path. No codegen, no AST tree (cyrius main
  parser has no TYPE AST kinds; that's TS-frontend-only). §1
  description's "TYPE_SLICE AST kind" was overscope — corrected
  during slot to "parse-acceptance only" matching v5.7.45 const-
  type-params shape. cc5 +464 B for new branch. Test:
  `tests/tcyr/slices_parse.tcyr` 9/9 PASS across all element-
  type variations.
- **v5.8.10** ✅ §2 — Codegen layer (16-byte alloc + helper API).
  Shipped 2026-05-02. PARSE_VAR's `[T]` branch sets
  `scalar_type = 16` (reusing u128's 16-byte stack-slot path);
  `slice<T>` ident form matched via 5-byte "slice" name-match
  (0x6563696C73 little-endian). Both forms now allocate 16-byte
  `{ptr, len}` slots. New `lib/slice.cyr` ships 9 helpers
  taking slice POINTER (`&s`): slice_set / slice_of / slice_ptr
  / slice_len / slice_zero / slice_copy / slice_eq /
  slice_is_empty / slice_is_null. Honest scope-shrink during
  slot: dot-syntax field access (`s.ptr` / `s.len`) deferred —
  would require unifying struct-field path with `scalar_type=16`
  scalar path. Bounds-aware indexing also deferred — needs
  element-type tracking parser doesn't have. Both pin candidates
  for follow-up slots if consumers surface concrete pain.
  cc5 +88 B. Tests: `tests/tcyr/slices_codegen.tcyr` 26/26 PASS.
- **v5.8.11** ✅ §3 — Str ↔ slice<u8> structural equivalence +
  stack-slice builders. Shipped 2026-05-02. Honest scope-shrink
  during slot: investigation surfaced that Str is ALREADY a
  slice<u8> structurally (`str_new` does `alloc(16); store64(s,
  data); store64(s + 8, len)` — byte-identical to a 16-byte
  stack slice). No API migration needed — Str-typed values pass
  directly to any slice helper. Documented the equivalence in
  both `lib/str.cyr` and `lib/slice.cyr` headers. Added 2 stack-
  slice builders to `lib/slice.cyr`: `slice_from_cstr` (analog
  of `str_from`) and `slice_from_buf` (analog of `str_new`) —
  for cases where heap allocation is undesirable. cc5 unchanged
  at 721,936 B (stdlib-only). Tests:
  `tests/tcyr/slices_str_interop.tcyr` 15/15 PASS.
- **v5.8.12** ✅ §4 — vec ↔ slice<T> structural-prefix
  equivalence + scope-shrink doc. Shipped 2026-05-02. Honest
  scope-shrink: vec fits naturally (first 16 bytes byte-identical
  to slice prefix); hashmap doesn't (32-byte header is not a
  contiguous-element shape, no slice abstraction); 454-site
  migration of sys_read/memcpy/memeq deferred (multi-slot scope,
  opt-in once helpers exist). Documented vec's structural
  equivalence in `lib/vec.cyr` + `lib/slice.cyr` headers; vec
  values pass directly to slice_ptr/len/is_empty/is_null/eq.
  Added `vec_as_slice(dst, v)` to lib/slice.cyr — snapshot
  semantics (dst's ptr may invalidate if vec_push reallocs).
  cc5 unchanged at 721,936 B (stdlib-only). Tests:
  `tests/tcyr/slices_vec_interop.tcyr` 12/12 PASS.
- **v5.8.13** ✅ §5 — Sub-arc closeout (slices FOUNDATION
  shipped, true completion deferred). Shipped 2026-05-02.
  Doc-only patch. Sub-arc retrospective documented (4 tcyrs,
  62 assertions, 11 helpers, 3 docs, ~190 LOC, +552 B cc5
  across 5 slots). **Honest reckoning post-ship**: §1-§5
  shipped a typedef + 11 helpers, NOT first-class slices —
  every hard piece (TYPE_SLICE typing, bounds-aware indexing,
  dot-syntax access, Str API migration, 454-site migration)
  got "honest scope-shrink" deferral. User-directed re-scope
  v5.8.14-v5.8.19 absorbs the deferred work as proper slots
  (see "##### v5.8.14–v5.8.19 — slices true-completion sub-arc"
  immediately below). v5.8.13 stays shipped as foundation
  release; .14+ delivers what "first-class" actually means.

##### v5.8.14–v5.8.19 — slices TRUE-COMPLETION sub-arc ✅ COMPLETE 2026-05-02

Re-pinned 2026-05-02 at v5.8.13 ship. The v5.8.9-v5.8.13 sub-
arc shipped a foundation but deferred every load-bearing piece.
This sub-arc absorbs that deferred work as proper slots.

**Sub-arc complete at v5.8.19 ship.** All 6 slots green:
§6 (typing), §7 (subscript), §8 (dot-syntax), §9 (pointer-to-
struct dot-syntax), §10 (slice-typed wrappers), §11 (closeout
retrospective). 159 slice assertions across 9 tcyrs. cc5 size
delta +6,024 B (721,936 → 727,960 B). See v5.8.19 CHANGELOG
entry for the full retrospective + lessons learned.

- **v5.8.14** §6 — TYPE_SLICE element-type tracking. Parser
  stores element width per slice var (currently `scalar_type=16`
  loses element type after annotation parses). New per-local
  field tracking (1=u8, 2=u16, 4=u32, 8=i64/ptr, 16=u128) so
  downstream lowering knows the right load*/store* width.
  Foundation for sized indexing in §7.
- ✅ **v5.8.15** §7 — Bounds-aware indexing `s[i]` (shipped
  2026-05-02). Lowering uses element width from §6: `s[i]` →
  `_slice_idx_get_W(&s, i)` via the width-specific helper from
  `lib/slice.cyr`. Bounds violation: stderr `slice bounds
  violation\n` + exit 134. **§7 SCOPE NOTE**: subscript syntax
  works on fn-local slices (where ~99% of real subscripting
  happens); top-level vars still need the helper-fn API
  directly — var-side subscript-syntax support reserved as
  follow-up if a downstream consumer asks. Slot also fixed a
  **pre-existing slot-collision bug**: adjacent fn-local
  16-byte vars (slices, u128) shared a stack slot because
  PARSE_VAR only bumped local count by +1; now bumps by +2 for
  scalar_type=16 with high-slot name/depth/type/slice-w
  cleared. Bug had been silent since v5.5 because no tcyr
  exercised adjacent fn-local 16-byte vars. Editor integration
  folded in: new `.lsp.json` + `docs/editor-integration.md` +
  README section.
- ✅ **v5.8.16** §8 — Dot-syntax field access `s.ptr` /
  `s.len` (shipped 2026-05-02). PARSE_FIELD_LOAD/STORE local-
  ident branch grew a slice short-circuit lowering dot access
  to address-based memory I/O via the canonical-slot address.
  Slot also fixed a **pre-existing 16-byte fn-local layout
  bug**: pre-fix the canonical slot was at the higher address
  and `&slice + 8` overflowed past the local frame into saved-
  rbp territory; `slice_set` clobbered saved rbp, `slice_len`
  read it back. Layout-flip puts the high half at the higher
  address, canonical at the lower address — `&slice + 8` now
  correctly hits the high half. Slot also added a **tail-call
  escape skip**: PARSE_RETURN's TCO detector skips when any
  arg passes `&local`, since the tail-call epilogue
  deallocates the frame before the callee reads through the
  pointer. **§8 SCOPE NOTE**: same as §7 — fn-local slices
  only; top-level vars still need helper-fn API. Var-side
  support reserved as the same follow-up slot.
- ✅ **v5.8.17** §9 — Pointer-to-struct dot-syntax capability
  + Str fn-param SLTYPE tagging (shipped 2026-05-02).
  PARSE_FIELD_LOAD/STORE auto-detects pointer-vs-inline by
  checking if slot lli-1 has the v5.5.36 sentinel name -1; if
  yes, inline-mode (`EFLADDR_X1`); else pointer-mode
  (`EFLLOAD + EMOVCA`). PARSE_FN_DEF tags `: <StructName>`
  param slots with `SLTYPE = -sid` so `param.field` resolves
  via the struct-typed-local branch. **Honest scope shift**:
  pinned scope was ~30-site stdlib migration; empirical scope
  was 81 sites + a `: Str` annotation per site (most stdlib
  fns take untyped params). Capability ships now; mass
  migration moves to v5.8.18 §10 which folds in the
  str_data/str_len sweep alongside the original 454-site
  sys_read/memcpy/memeq work. **§9 SCOPE NOTE**: dot-syntax
  fires only when the local or param has the `: Str` (or other
  struct) annotation; untyped locals storing Str pointers fall
  through to the existing error path.
- ✅ **v5.8.18** §10 — Slice-typed wrapper helpers
  (`sys_read_slice` / `slice_copy_bytes` / `slice_eq_bytes`)
  shipped 2026-05-02. **Honest scope-shrink**: pinned scope
  was the 454-site mass migration + the §9-deferred ~80-site
  str sweep; empirical counts came in smaller (~295 sites
  total) and a pilot migration of `lib/fs.cyr` was reverted
  twice in-flight, signalling that mass call-site churn isn't
  wanted this slot. Capability ships now (additive — canonical
  (ptr, len) primitives stay as the building blocks); mass
  sweep deferred to a future slot once a downstream consumer
  earns the change. The "454-site re-port pain" the cycle-
  compression argument was meant to prevent doesn't materialize
  from the helper-fn API existing — downstream code calling
  `memcpy(dst, src, n)` keeps working unchanged.
- ✅ **v5.8.19** §11 — TRUE sub-arc closeout (shipped
  2026-05-02). Doc-only / verification slot — no compiler or
  stdlib code change. Sub-arc retrospective + sub-arc
  COMPLETE marker. The "downstream consumers rebuild against
  migrated stdlib" line in the original pin assumed §9/§10
  would mass-migrate; both honest-scope-shrunk to capability
  + tcyr (twice-reverted lib/fs.cyr pilot signalled mass
  churn wasn't wanted), so §11's downstream-rebuild story
  collapses to a no-op assertion: additive helpers don't
  break any pre-existing call site. Sub-arc total: §6-§11,
  6 slots, 159 slice assertions across 9 tcyrs, +6,024 B
  compiler size delta (721,936 → 727,960 B), 11+10+3 = 24
  helpers in lib/slice.cyr, 4 stale pin items closed.

**Acceptance gates** (per slot, true-completion sub-arc):
1. Byte-identical self-host at every patch.
2. v5.8.14 gate: type-tracking visible — `var s: [u8] = 0`
   stores element width 1; `var t: [i64] = 0` stores 8;
   verifiable via compiler-internal probe or runtime sentinel.
3. v5.8.15 gate: `tests/tcyr/slices_indexing.tcyr` — bounds
   guard fires on out-of-range index; in-range elements load
   with correct width per §6 element type.
4. v5.8.16 gate: `tests/tcyr/slices_field_access.tcyr` —
   `s.ptr` and `s.len` work without helper fns; assignable
   via `s.ptr = newptr` / `s.len = newlen`.
5. v5.8.17 gate: stdlib `str_data` / `str_len` call sites
   migrated; backward-compat aliases functional; tcyr coverage
   exercises both old and new shapes.
6. v5.8.18 gate: stdlib internal callers of sys_read/memcpy/
   memeq migrated; tcyr coverage exercises slice-typed signatures.
7. v5.8.19 gate: every downstream consumer builds against the
   migrated stdlib (with explicit migration notes for any that
   need source changes — backward-compat aliases mean most
   downstream is unaffected).

Was originally pinned at v5.9.0 in the defunct TLS arc; rehomed
at v5.7.49; re-pinned to v5.8.9 at the 2026-05-01 re-theming;
expanded from single-slot to 5-patch sub-arc at v5.8.9 ship;
re-expanded to 11-patch sub-arc (foundation 5 + true-completion
6) at v5.8.13 ship per user direction "complete the task as
assigned, it was there for a reason".

##### v5.8.20 — Per-fn effect/purity annotations (`#pure` / `#io` / `#alloc`)

Compiler-checked decorators that catch helpers that silently
allocate or touch I/O in "pure" crypto paths. Simpler than
OCaml5 / Koka effects (no polymorphism, no row types) — just
three decorators the compiler enforces. Annotate `lib/keccak.cyr`,
X25519 (when sigil-side), AEAD as `#pure` so the compiler
catches accidental allocation regression. Single-slot;
annotation ramp happens gradually after the slot ships.

##### v5.8.21–v5.8.25 — Tagged unions + exhaustive pattern match

Algebraic data types — biggest language-ergonomics addition of
the v5.x line. Every ad-hoc `int tag; union { ... }` struct
pattern across IR walkers, NSS-strategy dispatch, fdlopen
result codes, parser state machines, hashmap key-typing folds
into first-class sum types. **Required by Phase 2's later
slots** (`Result<T,E>` IS a tagged union; `?` operator pattern-
matches it).

- **v5.8.21** — Sum-type syntax + constructor parsing.
  `enum Result<T,E> { Ok(T), Err(E) }` shape. Lex / parse
  reuses existing `enum`/`struct` infrastructure.
- **v5.8.22** — Exhaustive pattern match in `switch`. Compiler
  verifies every variant is covered; missing variants → error;
  `_ =>` explicitly opts out.
- **v5.8.23** — Stdlib adoption pass 1: collapse ad-hoc tag+
  union patterns (hashmap `key_type`, dynlib error codes,
  json/toml parse state) into sum types. Internal representation
  swap; no API breakage yet.
- **v5.8.24** — Stdlib adoption pass 2: public API migration
  for modules where the sum-typed form is visibly better
  (parse results, cross-boundary error returns).
- **v5.8.25** — Tagged unions sub-suite closeout. Downstream
  dep-pointer audit (sigil, mabda, yukti, kybernet, etc.).

**Acceptance gates**: byte-identical self-host at every patch;
`tests/tcyr/exhaustive_match.tcyr` (missing variant → error;
`_ =>` accepted; new variant triggers diagnostic at every
uncovered site); `cyrius audit` passes with internal-migration-
only changes visible at v5.8.23.

**Out of scope**: GADTs, higher-kinded types, type-level
computation. Keep feature surface boringly orthogonal.

##### v5.8.26–v5.8.30 — `Result<T,E>` + `?` propagation operator

Replaces -1/0/errno convention pervasive in stdlib with
compiler-enforced error handling. Depends on tagged unions
(v5.8.21-25). The `?` operator: `var x = foo()?;` short-
circuits on `Err`, unwraps `Ok` — half the LOC of error-
checking code in practice.

- **v5.8.26** — `Result<T,E>` type in `lib/result.cyr`.
  Convenience constructors `Ok(v)` / `Err(e)`; pattern-match
  consumers. Uses v5.8.21-25 sum types directly.
- **v5.8.27** — `?` propagation operator. Postfix on `Result`-
  typed expressions; desugars to pattern-match `Err` early-
  return. Requires enclosing fn to also return `Result`.
- **v5.8.28** — Stdlib migration pass 1: `lib/io.cyr` (file_
  open / read / write), `lib/syscalls.cyr` wrappers, `lib/
  json.cyr` + `lib/toml.cyr` + `lib/cyml.cyr` parsers. Ad-hoc
  -1 returns → `Result<T, IoError>` or per-module error types.
- **v5.8.29** — Stdlib migration pass 2: `lib/net.cyr`,
  `lib/http.cyr`, `lib/dynlib.cyr`, NSS identity modules
  (`pwd.cyr`/`grp.cyr`/`shadow.cyr`/`pam.cyr`). Cleanest wins.
- **v5.8.30** — Result sub-suite closeout. Cross-repo downstream
  smoke test (sigil, mabda, yukti, ark compile against
  migrated stdlib).

**Acceptance gates**: byte-identical self-host every patch;
`tests/tcyr/result_propagation.tcyr` (`?` on `Err` short-
circuits, on `Ok` unwraps, outside Result-returning fn is type
error); cross-repo smoke at v5.8.29.

**Migration policy**: modules migrate one at a time. `-1`-
return fns stay callable from non-migrated call sites through
v5.8.x. v6.0.0 closeout fully removes the old convention.

##### v5.8.31–v5.8.36 — Allocators-as-parameter convention

Largest ecosystem-churn item; biggest modern-systems-language
insight (Zig's contribution). Every allocating fn takes an
`Allocator`; global `alloc_init()` singleton retires; per-
request arenas fall out naturally; failing-allocator test
harness becomes a one-liner. Slotted last in Phase 2 because
it ripples through every stdlib module that allocates — having
sum types + Result already in means the migration uses
`Result<T, AllocError>` for failure returns (cleaner than
doing it before Result lands).

- **v5.8.31** — `Allocator` interface in `lib/alloc.cyr`.
  vtable shape: `alloc`, `realloc`, `free`, `reset`. Default
  implementations: `bump_allocator` (current behavior),
  `arena_allocator` (scoped), `test_allocator` (tracks every
  allocation, fails on demand).
- **v5.8.32** — Failing-allocator test harness. `lib/assert.cyr`
  extension: `fail_after_n_allocs(n)` helper. Enables
  `tests/tcyr/oom_handling.tcyr` coverage.
- **v5.8.33** — Stdlib migration pass 1 core modules:
  `lib/vec.cyr`, `lib/str.cyr`, `lib/hashmap.cyr`. Pass
  `Allocator` as first arg; default-allocator wrapper
  preserves existing call-sites.
- **v5.8.34** — Stdlib migration pass 2 peripheral modules:
  `lib/json.cyr`, `lib/toml.cyr`, `lib/cyml.cyr`, `lib/http.cyr`,
  `lib/sandhi.cyr`. Per-request arenas benefit most.
- **v5.8.35** — Retire `alloc_init()` global singleton.
  Backward compat through `lib/alloc.default()` shim for
  consumers not ready to migrate.
- **v5.8.36** — Allocator sub-suite closeout. Downstream
  ecosystem sweep (every repo's allocator usage audited).

**Acceptance gates**: byte-identical self-host every patch;
`tests/tcyr/oom_vec_push.tcyr` (`vec_push` returns
`Err(OutOfMemory)` under `fail_after_n_allocs(1)`) at
v5.8.32; every internal compiler path uses explicit allocator
at v5.8.35.

**Migration policy**: allocator parameter is opt-in during
v5.8.x. Default-allocator wrapper preserves existing
`vec_push(v, x)` shape as `vec_push(default_alloc(), v, x)`
syntactic sugar. v6.0.0 closeout removes the shim — every
fn requires explicit allocator.

#### Phase 3 — Polish + cycle closeout (slots 31-35)

- **v5.8.37** — Preprocessor include-pattern in string literals
  (filed 2026-05-01 from vidya audit;
  `docs/development/issues/2026-05-01-preprocessor-include-pattern-in-string-literals.md`).
  `PREPROCESS` in `src/frontend/lex.cyr` scans raw bytes for
  `include "` without string-literal awareness — string literals
  containing the pattern get processed as file inclusions,
  corrupting source. Affects `cyrc vet`/`deny`-class scanners.
  Mirror the v5.7.36 cyrlint string-literal fix shape: state-
  machine flag tracking `"` boundaries.

- **v5.8.38** — `cyrlint` multi-line assert false-positive
  (mabda C5). Has full issue file at [`mabda/docs/development/issues/2026-04-28-cyrlint-multi-line-assert.md`](https://github.com/MacCracken/mabda/blob/main/docs/development/issues/2026-04-28-cyrlint-multi-line-assert.md).
  cyrlint expression-walker confused by multi-line bracket matching.

- **v5.8.39** — Vidya cyrius-language audit (annotation pass).
  Sweep `vidya/content/cyrius/` (~15K lines across 13 cyml
  files). For each open-issue-shaped entry: confirm if still
  active, file locally in `cyrius/docs/development/issues/`
  if so, annotate vidya entry with cross-ref + status. Policy:
  preserve consumer-facing workaround text; add the tracking
  pointer alongside. First example (preprocessor include-
  pattern) shipped at v5.7.50 as the pattern template.

- **v5.8.40** — Paired UX/diagnostic polish: `cyrius fmt
  --check` exit-code semantics (mabda A2; match Rust/Go —
  exit non-zero on drift, silent on no-drift) + `var X;`
  bare-decl error-message polish (mabda C1; current "expected
  expression after `=`" → "uninitialized variable not allowed;
  use `var X = 0;` or initial value").

- **v5.8.41** — Phase 3 polish (last pre-closeout polish slot;
  see Phase 3 description above for the floating slot's
  surface-during-cycle absorption role).

- **v5.8.42** — api-surface refresh + auto-build wiring +
  null-byte-in-shell-substitution fix. Pinned 2026-05-02 at
  v5.8.18 ship. Three-part deliverable:

  1. **`cyrius_api_surface` binary auto-build wiring.** The
     binary is in `cyrius.cyml`'s `bins = [...]` list but the
     CI/release pipeline doesn't build it on `sh scripts/check.sh`
     paths, so `tests/regression-api-surface.sh` has been silently
     skipping with `skip: build/cyrius_api_surface not built`
     since v5.7.50. Fix: include the build in the same path that
     builds cc5/cyrlint/cyrfmt/cyrdoc, OR teach the gate to
     compile-on-demand from `programs/api_surface.cyr`.

  2. **Snapshot regeneration.** `docs/api-surface.snapshot` was
     last refreshed 2026-04-29 at 2563 entries. Current code has:
     additions (slice helpers from §6-§10 — `_slice_idx_get_W`,
     `slice_unchecked_get_W`, `sys_read_slice`, `slice_copy_bytes`,
     `slice_eq_bytes`, etc.); some agnosys removals (e.g.
     `bootloader_config_*` family). Regen via `cyrius
     api-surface --update`.

  3. **Null-byte-in-shell-substitution fix.** The gate's three
     test cases produce `command substitution: ignored null
     byte in input` warnings on the synthetic-snapshot tests
     (lines 54 + 71 of `tests/regression-api-surface.sh`). Root
     cause is the tool emitting null bytes in some failure
     paths that survive the shell capture; either the tool's
     emit path needs trimming or the shell capture needs
     `tr -d '\\0'` filtering. Pre-existing — noted in the
     v5.7.50 P(-1) audit as deferred.

  Acceptance gate: `tests/regression-api-surface.sh` returns 0
  with all three test cases green and zero null-byte warnings;
  `sh scripts/check.sh` shows api-surface gate as PASS not skip.

- **v5.8.43-v5.8.49** — Cycle headroom. Reserved for
  surface-during-cycle items + a final closeout backstop if
  Phase 3 finds late-cycle issues. Mirrors v5.7.49's
  end-of-cycle backstop role. The cycle's TRUE closeout
  protocol (CLAUDE.md 11-step + downstream consumer sweep +
  vidya per-minor refresh + completed-phases.md migration of
  all v5.8.* sections) lands in whichever slot in this range
  ends up the actual end-of-cycle (v5.8.42 if no headroom is
  consumed, otherwise the last consumed-or-pinned slot).

### v5.8.x — held items (surfacing-ask only; not pinned, no slot consumed)

- **`cyim` regex pattern parse error** (mabda C6) — pin when a
  cyim consumer hits it concretely. (Note: a regex-lib
  scaffold may already exist user-side; defer until cyim
  surfaces specific use case.)
- **`ESTORESTACKPARM` cx >6 args** (audit §4) — pin when a cx
  consumer surfaces a 7+-arg fn. cx backend stub returns 0
  with `# TODO: >6 args` comment at `src/backend/cx/emit.cyr:385`.
- **`float.cyr:41` peephole pattern** (audit §4) — pin when
  measured to matter. 5-instruction sequence `push rax;
  movabs rax, 0x7FFF...; mov rcx, rax; pop rax; and rax, rcx`
  may reduce to 3 bytes; preflight with bench delta.

### v5.8.x — deferred to v5.9.x or later

- **Class B FFI/wgpu fncall6 ABI** (mabda B1/B2). Mabda-only
  blast radius today; complex root-cause (ABI bug in Cyrius's
  fncall6 vs SysV AMD64 calling convention). Pairs naturally
  with v5.9.x's bare-metal / RISC-V cycle when ABI invariants
  get touched anyway.

---

## v5.9.x — Bare-metal arc (AGNOS kernel) + RISC-V rv64

Two arch-port-style efforts grouped into one minor since both land at
the "no libc, direct hardware/different ABI" layer. Moved from v5.8.x
at 2026-05-01 v5.7.49 ship — v5.8.x became the slices true-completion
+ language-feature arc instead (slot-map cascade +6 at v5.8.14 absorbed
the deferred §6-§11 work; sub-arc through v5.8.18 = halfway mark);
arch-port work needs its own dedicated cycle.

### v5.9.0 — Bare-metal / AGNOS kernel target

**Bare-metal target.** Bare-metal output (no libc, no syscalls,
direct hardware). AGNOS kernel is the concrete consumer. Slid through
multiple minors (was v5.7.0 pre-v5.6.x pin → v5.8.0 → v5.9.0). Details
pinned closer to landing — rough scope: ELF no-libc output format,
interrupt-handler emit conventions, kernel-mode syscall stubs
stripped, boot pipeline from `scripts/boot.cyr` landed in genesis
Phase 13B (v5.6.29 gate).

### v5.9.x — RISC-V rv64 (3-5 sub-patches)

First-class RISC-V 64-bit target. Moved from v5.8.x at 2026-05-01
along with bare-metal — pairs naturally with the bare-metal scope
since both deal with new ABI / non-libc runtime considerations and
both are arch-port-shaped efforts.

Inherits a frontend-complete compiler against a clean toolchain UX
with the full v5.7.x → v5.8.x prerequisite chain shipped, including
the v5.7.30 + v5.7.31 aarch64 f64 pair that gives RISC-V a working
f64-on-non-x87 reference (likely reuse the polyfill shape — RISC-V
has hardware f64 in the F/D extensions but the polynomial reuses
cleanly).

**RISC-V needs:**

- **New backend module** — `src/backend/riscv64/` with its own
  `emit.cyr`, `jump.cyr`, `fixup.cyr` mirroring x86/aarch64.
- **New stdlib syscall peer** — `lib/syscalls_riscv64_linux.cyr` with
  the Linux rv64 generic-table numbers (different from aarch64's even
  though both use the generic table — numbers match aarch64 for most
  syscalls but rv64 drops `renameat`, `link`, `unlink` which means
  the at-family wrappers need review). Selector in
  `lib/syscalls.cyr` gains an `#ifplat riscv64` arm (the v5.4.19
  directive extends naturally here).
- **New cross-entry** — `src/main_riscv64.cyr` mirroring
  `main_aarch64.cyr`'s arch-include swap.
- **New test runner** — QEMU or real hardware (HiFive Unmatched or
  equivalent) for self-host verification.
- **New CI matrix** — `linux/riscv64` runners via qemu-user-static,
  analogous to the aarch64 cross-test flow.
- **ABI** — RISC-V Linux ELF psABI (different register names: `a0–a7`
  for args, `sp` for stack, no frame pointer by default but we'll
  use `s0` for parity with aarch64's `x29`).

**Acceptance gates:**

1. Cross-compiler (`build/cc5_riscv64`) emits valid rv64 ELF that
   `file(1)` identifies correctly.
2. A single-syscall "exit 42" probe runs under `qemu-riscv64-static`
   and exits 42.
3. Hello-world probe via `sys_write` + `sys_exit` runs under QEMU.
4. `regression.tcyr` 102/102 via QEMU cross-test.
5. Native self-host byte-identical on real rv64 hardware (not QEMU
   — hardware-gated like the aarch64 ssh-pi check).
6. Tarball includes `cc5_riscv64` alongside `cc5_aarch64`.
7. `[release]` table in `cyrius.cyml` gets a `cross_bins` entry for
   `cc5_riscv64`.

Deliberately NOT bundling other items into the v5.9.x RISC-V arc —
a new architecture port is plenty of work on its own. Bare-metal
(v5.9.0) lands first; RISC-V picks up the rest of the v5.9.x range.

---

## v5.x — Platform Targets

Each platform is one minor release. cc5 backend-table dispatch
enables adding new targets without touching the frontend.

| Release | Platform | Format | Status |
|---------|----------|--------|--------|
| **v5.1.0** | macOS x86_64 | Mach-O | **Done** (narrow-scope) |
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Done** (narrow-scope); broad-scope gate-fixture repaired v5.6.33 |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 (older build) |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Done** (narrow-scope byte-identity green at v5.5.10); broad-scope gate-fixture repaired v5.6.36 |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | **Done** — v5.5.13–v5.5.17 broad-scope verified on ecb |
| **v5.5.18–v5.5.22** | aarch64 Linux shakedown + SSE alignment | ELF | **Done** — multi-thread + contended mutex on real Pi 4 |
| **v5.5.34** | fdlopen foreign-dlopen completion | ELF | **Done** — 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` |
| **v5.5.35** | Windows PE .reloc + 32-bit ASLR | PE/COFF | **Done** — `DYNAMIC_BASE` + HIGH_ENTROPY_VA enabled v5.6.31 |
| **v5.5.36** | Windows Win64 ABI completion | PE/COFF | **Done** — struct-return via hidden RCX retptr + __chkstk via R11 + variadic float dup |
| **v5.9.x** | RISC-V rv64 | ELF | **Moved from v5.8.x at v5.7.49 ship** — paired with v5.9.0 bare-metal AGNOS scope (both "no libc / new ABI" arch-port work); v5.8.x reframed as bug-fix/optimization minor. |
| **v5.9.0** | Bare-metal | ELF (no-libc) | Queued — AGNOS kernel target |
| ~~**v5.9.0–5.9.5**~~ | ~~Pure-cyrius TLS 1.3~~ | — | **Removed from roadmap 2026-04-24** — pure-Cyrius TLS work outside Cyrius's compiler/stdlib scope per sandhi scope-absorption decision; `lib/tls.cyr` continues using `libssl.so.3` bridge from stdlib's perspective; canonical home for pure-Cyrius TLS implementation TBD. See v5.9.x slot bullet in *What's next* for details. |

---

## v5.x — Toolchain Quality

| Feature | Effort | Status / Description |
|---------|--------|----------------------|
| `cyrius api-surface` | Medium | **✅ Shipped v5.7.33.** Snapshot-based public API diff. Scans `fn` declarations, tracks `mod::name/arity`, diffs against committed snapshot. Catches breaking removals/renames, allows additions. Pure-cyrius impl in `programs/api_surface.cyr`; pattern from agnosys `scripts/check-api-surface.sh`. |
| `cyrius api-surface --update` | Low | **✅ Shipped v5.7.33.** Regenerate snapshot after intentional API bump. |
| CI template with api-surface gate | Low | **✅ Shipped v5.7.33** (gate 4ao in cyrius's own check.sh; downstream consumers add their own copy). |
| LSP cross-file resolution + go-to-def | Medium | **✅ Shipped v5.7.39.** Symbol indexer (parallel-array table cap 4096), recursive include walker, `textDocument/definition`, `textDocument/documentSymbol`. cyrius-lsp promoted to release binary. Cross-file resolution verified by `tests/regression-lsp-definition.sh` (5 sub-tests including includer→included resolution). |
| LSP `textDocument/semanticTokens/full` | Medium | **Pinned long-term 2026-04-30 at v5.7.39 ship.** Deferred from v5.7.39's "polish" framing — go-to-def landed as the headline; semanticTokens earns its own slot when a real consumer surfaces a token-coloring request the editor's textmate grammar can't satisfy. Adds a mini-lexer + delta-encoded token array per the LSP 3.16 spec. ~150 LOC. |
| LSP `textDocument/references` | Low-Medium | **Pinned long-term 2026-04-30 at v5.7.39 ship.** Easy add on top of v5.7.39's symbol-table infrastructure — needs an inverted index (name → use-sites). ~80 LOC. Claims a slot when a downstream consumer asks. |
| cyrlint forward-ref scanner — string-literal awareness | Low-Medium | **✅ Shipped v5.7.36.** Pulled forward from the v5.7.37 trio. Pass-2 scan loop in `lint_globals_init_order` skips IDENTs inside `"..."` and `'...'` literals (with `\\` / `\"` / `\'` escapes); regression test 4 in `tests/regression-lint-global-init-order.sh` covers the shape. |
| TS test harness program (option E from v5.7.37) | Medium | **Pinned long-term 2026-04-30 at v5.7.37 ship.** A single `programs/ts_test_runner.cyr` consuming both internal-symbol fn dispatch (replacing the current `tests/tcyr/ts_{lex_combined,parse_core,parse_decls,parse_advanced}.tcyr` runners) and TS fixture files (replacing the SY-corpus regression gates `regression-ts-{lex,parse,parse-tsx,asserts,decorators,mapped}.sh`). One tool, two modes. v5.7.37 group-level consolidation is sufficient until a downstream consumer surfaces a test pattern that doesn't fit either current shape; at that point claims a v5.7.x slot (likely v5.7.45 floating slot in the queue). Out of scope: replacing `cc5 --parse-ts`-style flags themselves — the harness CALLS them, doesn't replace them. |

---

## v5.x — Language Refinements

**Pinned arc** (re-eval'd 2026-04-28 at v5.7.33 ship — arc holds; ordering reflects "smaller language adds first, big own-minor features as their slot opens"):

| Feature | Pinned | Effort | Notes |
|---------|--------|--------|-------|
| First-class slices (`slice<T>` / `[T]` generalizing `Str`) | **v5.8.x** | Medium | **Moved from v5.9.0 (defunct TLS arc) at v5.7.49 ship.** Bounds-aware (ptr, len) pair as a first-class type — sandhi / sigil / stdlib net.cyr / fs.cyr all want this; `slice<u8>` collapses the ptr+len pattern repeated across stdlib. Pinned as a v5.8.x slot candidate alongside the dep-surfaced bug fixes. |
| Per-fn effect annotations (`#pure` / `#io` / `#alloc`) | **v5.8.x** | Medium | **Moved from v5.9.1 (defunct TLS arc) at v5.7.49 ship.** Compiler-checked decorators (`#pure`, `#io`, `#alloc`) catch helpers that silently allocate or touch I/O in "pure" crypto paths; simpler than OCaml5/Koka effects (no polymorphism, no row types). sigil + sankoch want this. Pinned as a v5.8.x slot candidate. |
| Tagged unions + exhaustive pattern match | **v5.8.x** (slots 10-14) | Large | **Moved from v5.10.x at 2026-05-01 v5.8.x re-theming** — folded into the language-vocabulary stabilization phase. Biggest ergonomics win; replaces tagged.cyr + manual dispatch. See v5.8.x §Phase 2 for sub-patch breakdown. |
| `Result<T,E>` + `?` propagation | **v5.8.x** (slots 15-19) | Large | **Moved from v5.11.x at 2026-05-01 re-theming.** Depends on tagged unions (slots 10-14). Replaces -1/0/errno convention across stdlib + ecosystem. |
| Allocators-as-parameter | **v5.8.x** (slots 20-25) | Large | **Moved from v5.12.x at 2026-05-01 re-theming.** Per-call-site allocator selection. Last language addition of the compressed v5.8.x cycle. |

**Still unpinned / lower priority** (re-eval'd 2026-04-28):

| Feature | Effort | Surfacing / votes | Disposition |
|---------|--------|-------------------|-------------|
| Phase 2b-aarch64 struct copy (LDRB/STRB loop) | Medium | x86 shipped v5.5.36; aarch64 path pending | **Pin candidate** — likely v5.7.x patch slate or v5.8.x aarch64-polish slot. Surfaces whenever a consumer cross-builds struct-by-value calls for aarch64. Phylax / mabda may hit. |
| Closures capturing variables | High | gotcha #8 — consumers feel the absence | **Watching.** Promote to pinned slot when a consumer concretely blocks on it (vs. lambda-pattern workaround). v5.10.x ADTs make captured-state encoding cleaner. |
| Generics / traits | High | 1 vote (kavach) | **Watching.** Wait for kavach to actively reach for it; speculative implementation pre-need is risk. |
| Hardware 128-bit div-mod | Medium | — | **Stays unpinned.** abaco / sigil currently work around via u128 shifts; not blocking. |
| Phase 3-full varargs (va_arg for structs-by-value + nested) | Medium | Phase 3-min shipped v5.5.36 | **Stays unpinned.** Niche — most consumers use array-of-args pattern instead. |
| cc5 per-block scoping | Medium | — | **Stays unpinned.** Function-scope works for current consumer base; promote when a real refactor surfaces the pain. |
| Incremental compilation | High | — | **Stays unpinned.** Whole-program self-host is fast (<400 ms); incremental adds complexity for cyrius-style projects without proportional payoff. Reconsider when cc5 self-host time crosses ~2 sec. |

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
| Audio | (vani distlib at v5.8.0; lib/audio.cyr retired into vani's higher-level vani_* API) |
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
| Linux x86_64 | ELF | **✅ Narrow + Broad** — primary host. cc5 710 KB (v5.7.12); 3-step fixpoint byte-identical. |
| Linux aarch64 | ELF | **✅ Narrow + Broad** — cross-build byte-identity + native self-host on Pi 4 (repaired v5.6.32). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **✅ Narrow** — clean CYX bytecode (path B, v5.7.12); literal-arg propagation pinned v5.7.x patch slot. |
| macOS x86_64 | Mach-O | **✅ Narrow** (v5.1.0). |
| macOS aarch64 | Mach-O | **✅ Narrow + Broad** — gate fixture repaired v5.6.33 (no compiler regression existed; bytes unchanged since v5.5.13). |
| Windows x86_64 | PE/COFF | **✅ Narrow + Broad** — gate fixture repaired v5.6.36; HIGH_ENTROPY_VA enabled v5.6.31. Win64 ABI complete (v5.5.36); .reloc + 32-bit ASLR (v5.5.35). |
| Compiler optimization (O1–O6) | — | **✅ Closed** (v5.6.5 + v5.6.7–v5.6.27). |
| RISC-V (rv64) | ELF | Queued — **v5.7.26-v5.7.30** |
| Bare-metal | ELF (no-libc) | Queued — **v5.9.0** |

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
