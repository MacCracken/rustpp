# Cyrius Development Roadmap

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).


## v5.3.x / v5.4.x / v5.5.x / v5.6.x — shipped

All v5.3.x–v5.6.x per-patch detail lives in
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



## v5.7.42 ✅ `lib/json.cyr` JSON Pointer (RFC 6901) — SHIPPED

**Shipped 2026-04-30.** Third and final slot of the v5.7.20-pinned
JSON depth follow-up series. Closes the triple: pretty-print
(5.7.40) + streaming (5.7.41) + pointer-walk (this slot) on top
of the existing tagged tree.

Plus a v5.7.41-introduced-noise hygiene fix: `lib/json.cyr` now
explicitly `include`s `lib/fnptr.cyr` so consumers don't need to
also remember to include it themselves. The streaming code shipped
at v5.7.41 references `fncall1/2/3` from fnptr.cyr — without the
include, every consumer of lib/json.cyr (even ones using only the
tree/build/pointer surface) tripped three "undefined function"
warnings at compile. Self-contained dep declaration matches the
existing pattern in 17 other stdlib files.

Zero compiler change; lib-only. cc5 byte-identical at 720,640 B.

**What landed:**

1. **`json_v_pointer(v, ptr)`** — public Str-input entry. Empty
   pointer returns root; non-empty must start with `/`. Returns
   the referenced value or 0 (not found / invalid pointer /
   can't descend into scalar).
2. **`json_v_pointer_cstr(v, ptr, plen)`** — explicit cstr+len
   entry; used internally by `json_v_pointer`, exposed for
   buffer-and-length callers.
3. **`_jp_obj_lookup(v, buf, len)`** — internal helper. Length-
   explicit key match (handles interior-NUL keys correctly).
4. **`_jp_parse_idx(buf, len)`** — strict RFC 6901 §4 index
   parser. Rejects leading zeros (`01`), the `-` next-element
   token, non-digits, and empty input.
5. **`_jp_token_unescape(src, src_len)`** — single-pass left-to-
   right `~1`→`/`, `~0`→`~`, with any other `~X` rejected.
   Equivalent to the spec's two-pass "~1 then ~0" order because
   only `~0` and `~1` are valid escapes — there's no chained-
   rewrite case to worry about.

**Hygiene:**
- **`lib/json.cyr`** now `include`s `lib/fnptr.cyr` at top.
  Closes the v5.7.41 incomplete-dep regression.

**Verification:**
- cc5 self-host two-step byte-identical at 720,640 B.
- `tests/tcyr/json_pointer.tcyr` — 36 assertions in 7 groups
  (empty pointer = root, obj key lookup with miss = 0, array
  index with OOB / leading-zero / `-` / non-numeric all
  rejected, deep nested mixed obj/arr/obj, RFC 6901 §5 corpus
  incl. `/a~1b` `/m~0n` `/` `/k\"l` `/ `, error paths,
  trailing-slash empty-token descent) all PASS.
- `tests/regression-json-pointer.sh` (gate 4aw) — end-to-end
  fixture: programmatically constructed doc + 8 pointer
  evaluations including 2 successful int extracts, 1 OOB, 2
  escape resolutions, 1 missing key, 1 descend-into-scalar
  attempt, 1 string extract. Exact-byte cmp.
- All four JSON tcyrs run clean post-fnptr include (engine 71 +
  pretty 18 + stream 65 + pointer 36 = **190 assertions** across
  the JSON surface).
- `sh scripts/check.sh` — 60/60 PASS (was 59/59; +gate 4aw).

**Out of scope (future polish, behind consumer ask):**
- **JSON Pointer mutation** — `json_v_pointer_set(v, ptr, value)`
  walk-and-replace. Implicit ownership questions (clone vs
  consume vs mutate-in-place) need a real consumer to anchor.
- **Relative JSON Pointer** — draft-bhutton-relative-json-pointer
  with `0/foo`, `2/bar` for parent-relative traversal. Mostly
  schema-engine-relevant; pin behind schema-engine work.

**Slot cascade:** backstop unchanged at v5.7.47. JSON depth
triple complete; v5.7.20-era pin retired. Queue advances to
v5.7.43-45 (advanced TS feature suite) → v5.7.46 (floating slot)
→ v5.7.47 (true closeout backstop).



## v5.7.41 ✅ `lib/json.cyr` streaming parser — SHIPPED

**Shipped 2026-04-30.** Second slot of the v5.7.20-pinned JSON
depth follow-up series. Adds an event-driven push parser for
multi-MB JSON inputs that don't fit the tagged-tree memory
model (log streams, debug dumps, RPC payloads where allocating
the full tree is the wrong trade-off).

Zero compiler change; lib-only. cc5 byte-identical at 720,640 B.

**What landed:**

1. **11 event constants** — `JS_EV_OBJECT_START` (0) through
   `JS_EV_ERROR` (10) plus `JS_EV_COUNT` (11) for sentinel-
   checked range validation in `json_stream_on`.
2. **Handler struct** (96 bytes) — `ctx` slot followed by 11
   fn-pointer slots. Each defaults to 0 = no-op so consumers
   register only the events they care about.
3. **Public API** — `json_stream_handler_new(ctx)`,
   `json_stream_on(h, event_id, fp)` (-1 on bad event_id),
   `json_stream_parse(buf, len, h)` (0/-1),
   `json_stream_parse_str(src, h)`.
4. **Driver shares lex state** with the tree parser
   (`_jp_buf` / `_jp_len` / `_jp_pos` + `_json_err_msg` /
   `_json_err_pos`) and reuses `_jp_skip_ws`, `_jp_parse_string`,
   `_jp_atoi`, `_jp_atof`, `_jp_set_err` unchanged. This kept the
   streaming surface to ~210 LOC instead of the ~400 a fully
   duplicated lex would have cost.
5. **Callbacks fire** via `fncall1` / `fncall2` / `fncall3` from
   `lib/fnptr.cyr`. Arities: object/array start/end + null →
   `fncall1(ctx)`; key/string/int/float/bool → `fncall2(ctx, v)`;
   error → `fncall3(ctx, msg, pos)`.

**Verification:**
- cc5 self-host two-step byte-identical at 720,640 B.
- `tests/tcyr/json_stream.tcyr` — 65 assertions in 9 groups
  (handler alloc + slot wiring incl. invalid event_id rejection;
  6 scalar shapes; empty containers; flat object 4 mixed types;
  nested with exact-byte event-order trace `{k[ii]k{ks}}`; array
  of 3 objects; 4 error paths; selective-callback no-op;
  convenience entries) all PASS.
- `tests/regression-json-stream.sh` (gate 4av) — end-to-end
  fixture `{"name":"alice","id":42,"flags":[true,null],"meta":{"k":"v"}}`
  → exact-byte trace `{kskik[bn]k{ks}}` (16 events: 2× obj_start,
  2× obj_end, 1× arr_start, 1× arr_end, 4× key, 2× string, 1× int,
  1× bool, 1× null) + `OK` rc=0.
- `sh scripts/check.sh` — 59/59 PASS (was 58/58; +gate 4av).

**Out of scope (future polish, behind consumer ask):**
- **Abort-on-callback** — non-zero callback return currently
  ignored. Could honour as early-exit signal (filtering, quota
  enforcement). ~5 LOC.
- **Streaming-from-fd** — current entry takes buf+len. Reading
  from an fd in chunks needs partial-token buffering across reads.
  Probably belongs in sandhi RPC layer.
- **`on_value` super-event** — combined string/int/float/bool/null
  for consumers that don't care about value type. Trivial to
  layer when asked.

**Slot cascade:** backstop unchanged at v5.7.47. Queue advances
to v5.7.42 (JSON Pointer, RFC 6901) → v5.7.43-45 (advanced TS) →
v5.7.46 (floating) → v5.7.47 (true closeout backstop).



## v5.7.40 ✅ `lib/json.cyr` pretty-printer — SHIPPED

**Shipped 2026-04-30.** First slot of the v5.7.20-pinned JSON
depth follow-up series. Adds `json_v_build_pretty(v, indent)`
on top of the existing tagged-value tree. Triggered by the
"compiler grows to fit the language" stance + `JSON.stringify`-
shape API parity (config-file writers, debug-log dumps).

Zero compiler change; lib-only. cc5 byte-identical at 720,640 B.

**What landed:**

1. **`json_v_build_pretty(v, indent)`** — public entry. `indent`
   is the spaces-per-level integer; `indent <= 0` short-
   circuits to compact `json_v_build(v)`.
2. **`_jb_walk_pretty(sb, v, indent, level)`** — walker
   mirroring the existing `_jb_walk` shape. Differences:
   members on own lines at `indent * (level + 1)` spaces;
   `": "` (colon-space) key separator; empty `{}`/`[]` short-
   circuit to bracket-pair with no internal whitespace per
   `JSON.stringify(v, null, n)` convention.
3. **`_jb_emit_indent(sb, indent, level)`** — emits LF
   (byte 10) + N spaces (byte 32). Single helper used by both
   array and object member emission.

**Verification:**
- cc5 self-host two-step byte-identical at 720,640 B.
- `tests/tcyr/json_pretty.tcyr` — 18 assertions in 10 groups
  (indent fallback `0` / `-4`, scalars unchanged, empty
  containers compact, indent=2 array/object, nested mix,
  empty arr inside obj, indent=4 step, parse→pretty→parse
  round-trip on 51-char + 25-char fixtures, embedded `\n`
  re-escape preservation through pretty path) all PASS.
- `tests/regression-json-pretty.sh` (gate 4au) — end-to-end
  fixture against canonical 8-line shape; negative-case
  verified by deliberately reverting `": "` to `":"` and
  confirming gate FAILs with meaningful diff.
- `sh scripts/check.sh` — 58/58 PASS (was 57/57; +gate 4au).

**Out of scope (future polish, behind consumer ask):**
- Configurable separator string (arbitrary indent string,
  `", "` after array members) — `JSON.stringify` permits but
  spaces-per-level is the 95% case.
- Sort-keys flag for stable diffs of object output.

**Slot cascade:** backstop unchanged at v5.7.47. Queue advances
to v5.7.41 (streaming parser) → v5.7.42 (JSON Pointer) →
v5.7.43-45 (advanced TS) → v5.7.46 (floating) → v5.7.47
(true closeout backstop).



## v5.7.39 ✅ LSP cross-file go-to-definition + documentSymbol — SHIPPED

**Shipped 2026-04-30.** Extends `programs/cyrius-lsp.cyr` from
diagnostics-only to a navigation-capable language server.
Originally pinned as "LSP semantic-tokens polish"; honest
sizing at slot entry split the framing — go-to-def is the
headline consumer-visible feature, semanticTokens is internal
polish that earns its own slot when a real consumer asks.
This slot ships the headline; semanticTokens deferred.

Zero compiler change. cc5 byte-identical at 720,640 B.

**What landed:**

1. **Symbol indexer** in cyrius-lsp — parallel-array table
   (cap 4096 entries × name/path/line/col/kind), backed by
   256 KB names buf + 32 KB paths buf. Walks `fn`/`var`/
   `enum`/`struct` decls; recursively follows `include
   "..."` directives (project-relative first, file-
   relative fallback); idempotent via a 256-entry indexed-
   path set.

2. **`textDocument/definition`** — looks up the IDENT
   under the cursor (re-reads the file to walk the
   position), returns `Location` (or `null`). Cross-file
   verified by the regression test
   (`includer.cyr`→`included.cyr` resolution).

3. **`textDocument/documentSymbol`** — flat
   `SymbolInformation[]` form filtered by URI; cyrius
   kinds map to LSP `SymbolKind` (Function=12, Variable=13,
   Enum=10, Struct=23, EnumMember=22).

4. **`cyrius-lsp` promoted to release binary** — added to
   `cyrius.cyml [release].bins`. Pre-v5.7.39 was install-
   on-demand via `cyrius lsp` subcommand; now `cyriusly
   setup` / `install.sh` build it as part of every install.
   Net effect: VSCode extension's `~/.cyrius/bin/cyrius-lsp`
   candidate path resolves out of the box on a fresh
   install.

**Verification:**

- cc5 self-host two-step byte-identical at 720,640 B (no
  compiler change).
- cyrius-lsp: 22 KB → 65,456 B (+43 KB for ~430 LOC of
  indexer + 2 new method handlers + capability changes).
- check.sh **57/57 PASS** (was 56; +gate 4at
  `regression-lsp-definition.sh` covering 5 sub-tests
  including cross-file resolution).
- Install snapshot 14 → 15 bins/scripts (cyrius-lsp
  joined).

**Out of scope (deferred):**

- `textDocument/semanticTokens/full` — pinned long-term in
  §v5.x — Toolchain Quality.
- `textDocument/references` — needs inverted index;
  future slot.
- `textDocument/hover` — needs doc-comment parser; future.
- UTF-16 column accounting (cyrius is ASCII-only today;
  bytes ≡ UTF-16 code units).
- Project-root indexing (walk cyrius.cyml's [build].src /
  [lib].modules to catch sibling files not transitively
  included).

**Slot cascade:** backstop unchanged. The slot landed
inside the v5.7.46 floating allocation. Queue holds at
v5.7.40-v5.7.42 JSON depth, v5.7.43-v5.7.45 advanced TS,
v5.7.46 floating, v5.7.47 closeout backstop.

## v5.7.38 ✅ `.scyr` (soak) + `.smcyr` (smoke) file types — SHIPPED

**Shipped 2026-04-30.** Two new test-discovery shapes mirroring
`*.tcyr` / `*.bcyr` / `*.fcyr`. Closes the `cyrius soak` /
`cyrius smoke` gap and kills the only Python3 dependency in
the test surface.

Originally bundled with LSP polish as the v5.7.37 trio (later
v5.7.38 duo at v5.7.36 ship after string-lit awareness moved
forward). Honest sizing at v5.7.38 entry flagged LSP as
substantially larger; user authorized splitting (LSP polish
moved to v5.7.39 own slot).

Zero compiler change. cc5 byte-identical at 720,640 B.

**What landed:**

1. **`cyrius smoke`** — new subcommand discovering
   `tests/smcyr/*.smcyr` + `smoke/*.smcyr`. Fail-fast: bails
   on the first FAIL rather than continuing. Auto-deps gate
   wired so harnesses get manifest auto-prepend.

2. **`cyrius soak` extension** — built-in self-host loop
   unchanged. After it completes, walks `tests/scyr/*.scyr`
   + `soak/*.scyr` and runs each user-authored harness once.
   `_skip_deps` save/restore guards the built-in loop from
   blowing the 2MB expanded-source cap when manifest deps
   would be prepended to src/main.cyr (six dep bundles +
   7,400 LOC compiler = explode); .scyr harnesses do get
   auto-prepend.

3. **`tests/regression-capacity.sh`** — Python3 inline
   synthesis (`python3 -c "..."`) replaced with shell loop.
   Output byte-identical; `python3 not found → skip` branch
   removed. `grep -rn 'python3' scripts/ tests/` returns
   zero invocations.

4. **Example harnesses** —
   - `tests/smcyr/compile_minimal.smcyr` — minimal smoke
     (fn returning literal value); ensures `cyrius smoke`
     finds something on fresh checkout.
   - `tests/scyr/alloc_pressure.scyr` — 10,000 × `alloc(4KB)`
     + sentinel-byte readback (40 MB total). Surfaces
     bump-allocator wrap / cap-too-small regressions.

**Verification:**

- cc5 self-host two-step byte-identical at **720,640 B**
  (no compiler change).
- check.sh **56/56 PASS** (was 55; +gate 4as
  `regression-smoke-discovery.sh` covering discovery, empty-
  dir, and fail-fast bail).
- `cyrius soak 1` end-to-end: self-host iter PASS + `.scyr`
  walker discovers and runs `alloc_pressure.scyr` → 1
  passed, 0 failed.

**Pinned method (small):** `_skip_deps` save/restore is the
right pattern for any `cmd_*` that calls `compile()` against
sources with size constraints (e.g. the compiler itself).
Don't put commands in the auto-deps gate without checking
whether their `compile()` calls would inflate large sources
past caps.

**Slot cascade** (continuing the +1 cascade; user-authorized
at v5.7.37 ship — split the duo, push backstop to v5.7.46;
this ship pushes one further to v5.7.47 to absorb the LSP
split):

- v5.7.38 = this slot
- v5.7.39 = LSP semantic-tokens polish (split from former
  v5.7.38 duo)
- v5.7.40-v5.7.42 ← v5.7.39-v5.7.41 prev = JSON depth series
- v5.7.43-v5.7.45 ← v5.7.42-v5.7.44 prev = advanced TS suite
- v5.7.46 ← v5.7.45 prev = floating slot for option E test-
  harness when pulled
- v5.7.47 ← v5.7.46 prev = TRUE CLOSEOUT BACKSTOP

## v5.7.37 ✅ TS test-org rework — group-level consolidation — SHIPPED

**Shipped 2026-04-30.** Closes the load-bearing prerequisite
for the v5.7.42-v5.7.44 advanced-TS suite. 24 individual
`tests/tcyr/ts_*.tcyr` files collapsed into 4 topic-grouped
runners that include the TS frontend (~6,615 LOC of
lex.cyr + parse.cyr) ONCE per group instead of once per
file.

**The slot's premise check** (per CLAUDE.md "research before
implementation"): the original roadmap framing was
"pre-compiled frontend object linkage." Verified
out-of-scope — cyrius today is whole-program; no `.o`
emission + linker exists (the `.gnu.hash` long-term entry
above confirms `.so` work isn't even fully wired). Slot
re-scoped to "consolidate the test surface using existing
language facilities."

**The user pushback that mattered**: agent first proposed a
single megafile runner (~17× speedup). User pushed back —
"do you GENUINELY think that one test runner is the
optimum?" — which surfaced the real trade-off: a megafile
trades the speedup for blast-radius-of-the-whole-suite on
any single segfault, zero scaling headroom, and aesthetics
at odds with cyrius's "small focused programs" taste.
Group-level consolidation gets ~5× of the speedup with
isolation per topic. Pattern recorded as feedback memory:
when an agent's proposal makes them say "trust the
accumulator" or hand-wave past an obvious downside, that's
a tell — push back instead of approving.

**Group split:**

- `ts_lex_combined.tcyr` (was 6 files: p12, p13, p14, p15,
  p16, p43) — 570 assertions
- `ts_parse_core.tcyr` (was 4 files: p21, p22, p23, p24) —
  AST scaffolding + expr/stmt/type — 257 assertions
- `ts_parse_decls.tcyr` (was 5 files: p25, p26, p44, p45,
  p47) — declarations / modules / async / `!:` /
  modifiers — 157 assertions
- `ts_parse_advanced.tcyr` (was 9 files: p43, p46, p48,
  p49, p50, p51, p52, p53, p54) — JSX, instantiation
  expressions, generic fn types, template literal types,
  array destructure, SY polish, asserts, mapped types,
  decorators — 133 assertions

**Verification:**

- cc5 self-host two-step byte-identical at **720,640 B**
  (no compiler change).
- Assertion-count parity: 1117 = 1117 (verified by running
  each original pre-deletion and summing).
- TS suite compile time: **4774ms → 926ms = 5.15×
  speedup** (timed against 24 originals before deletion).
- check.sh **55/55 PASS** (no gate count change; underneath
  93 tcyr files instead of 113).

**Files:**

- Deleted: 24 in `tests/tcyr/ts_{lex,parse}_p*.tcyr`.
- Added: 4 in `tests/tcyr/ts_{lex_combined,parse_core,parse_decls,parse_advanced}.tcyr`.

**Slot cascade** (user-authorized at this ship, +1 from
v5.7.36's cascade — backstop bumped v5.7.45 → v5.7.46 to
absorb option E test-harness pin):

- v5.7.37 = this slot
- v5.7.38 ← v5.7.37 prev = bundled duo (LSP polish +
  `.scyr`/`.smcyr`)
- v5.7.39-v5.7.41 ← v5.7.38-v5.7.40 prev = JSON depth series
- v5.7.42-v5.7.44 ← v5.7.41-v5.7.43 prev = advanced TS suite
- v5.7.45 ← floating slot for option E test-harness when
  pulled (long-term pinned in §v5.x — Toolchain Quality)
- v5.7.46 ← v5.7.45 prev = TRUE CLOSEOUT BACKSTOP

**Long-term pin (option E):** TS test harness program. A
single `programs/ts_test_runner.cyr` that consumes both
internal-symbol fn dispatch (replacing the current tcyr
runners) and TS fixture files (replacing the SY-corpus
regression gates) — one tool, two modes. Pinned in §v5.x —
Toolchain Quality. Claims a slot (likely v5.7.45) when a
downstream consumer surfaces a test pattern that doesn't fit
either the current tcyr shape or `cc5 --parse-ts` corpus
mode. Until then, group-level consolidation is sufficient.

## v5.7.36 ✅ fresh-install hardening + distlib cap raise — SHIPPED

**Shipped 2026-04-30.** Bundled five tooling-quality items
surfaced by re-setting up the toolchain on a fresh Arch
install plus a mabda-surfaced distlib truncation. Authorized
mid-execution by the user with explicit cascade direction:
"want to fix tests before adding additional testing verbs."

Zero compiler change. cc5 byte-identical at 720,640 B.

**Items shipped:**

1. **`scripts/check.sh:329` syntax-error noise** — backticks
   around `if (r)` triggered command substitution on every
   audit run (`syntax error: unexpected end of file from
   \`if'`). Switched the inner formatting to single quotes.
   Closes warning-sweep finding #5 from the v5.7.x slate;
   line number drifted from 305-306 (when logged) to 329-330
   (when fixed) as gates accreted.

2. **`scripts/check.sh` PATH fallback for fmt/lint + loud-FAIL
   on missing binaries** — pre-v5.7.36 a fresh checkout (only
   `build/cc3` + `build/cc5` committed) reported "skip:
   cyrfmt/cyrlint not built" and the audit counted a green
   "52/52 PASS" without exercising fmt/lint. `CYRFMT` and
   `CYRLINT` now prefer `$ROOT/build/<tool>` and fall back to
   `command -v <tool>`; if neither resolves, the audit emits
   `check ... "1"` (FAIL) with a message pointing at
   `cyriusly setup`. No path produces an honest-looking
   green run with un-exercised gates.

3. **`cyrius distlib` per-module cap 64 KB → 256 KB
   (mabda-surfaced)** — `cmd_distlib` in `cbt/commands.cyr:
   894-895` allocated 65536 and read up to 65535; modules
   over 64 KB truncated silently mid-bundle. Bumped to
   262144 for breathing room. Static-cap pattern preserved;
   dynamic vec only earns its keep on a fourth bump (per
   the v5.7.7 fixup-table precedent).

4. **`cyrlint` string-literal awareness** (pulled forward
   from v5.7.37 trio) — Pass-2 scan loop in
   `lint_globals_init_order` now skips IDENTs inside
   `"..."` strings and `'...'` chars (with `\\` / `\"` /
   `\'` escapes). Counter-check: pre-v5.7.36 emits a false
   positive on `var MSG = "FLAG_LATER ..."; var FLAG_LATER
   = 1;`; post-v5.7.36 emits zero warnings on the same shape.

5. **`cyriusly setup` — install from current repo
   checkout** — closes the fresh-checkout UX gap. Pre-
   v5.7.36 `cyriusly install <ver>` was the only native verb
   and re-cloned via tarball or `git clone`, ignoring
   any local checkout. The new verb requires VERSION +
   cyrius.cyml + scripts/install.sh in cwd, bootstraps the
   seed if `build/cc5` is missing, builds the release tools
   listed in `[release].bins` / `[release].cross_bins`, and
   delegates to `install.sh --refresh-only`. End-to-end
   first-time setup is now `git clone && sh scripts/cyriusly
   setup`.

**Verification:**

- cc5 self-host two-step byte-identical at 720,640 B (no
  compiler change).
- Bootstrap closure (seed → cyrc → asm → cyrc): byte-
  identical (`src/` untouched).
- check.sh **55/55 PASS** (was 52/52 going in; +2 from fmt/
  lint gates now running via PATH fallback rather than
  silent-skipping; +1 from new gate 4ar `regression-distlib-
  large-module.sh`).
- `tests/regression-lint-global-init-order.sh` extended with
  Test 4 (string-literal fixture).

**Files touched:**

- `cbt/commands.cyr` — distlib cap raise
- `programs/cyrlint.cyr` — Pass-2 string/char literal skip
- `scripts/check.sh` — syntax fix + PATH fallback +
  loud-FAIL + gate 4ar wiring
- `scripts/cyriusly` — new `setup` action + help text
- `tests/regression-distlib-large-module.sh` — new
- `tests/regression-lint-global-init-order.sh` — Test 4

**Slot cascade** (user-authorized; relative order preserved):

- v5.7.36 = this slot
- v5.7.37 ← v5.7.36 was = TS test organization rework
- v5.7.38 ← v5.7.37 was = trio (LSP polish + `.scyr`/
  `.smcyr`; cyrlint string-lit moved forward)
- v5.7.39-v5.7.41 ← v5.7.38-v5.7.40 were = JSON depth
- v5.7.42-v5.7.44 ← v5.7.41-v5.7.43 were = advanced TS
- v5.7.45 ← v5.7.44 was = TRUE CLOSEOUT BACKSTOP

**Pinned method update:** fresh-install rehearsal once per
minor (last: never; first: v5.7.36) — the silent-skip and
truncation failure modes are invisible to a developer
running from an active repo. The same audit-reporting
honesty issue as v5.7.29's `set -e` / `tail` masking; same
fix shape (loud-FAIL when the test would otherwise skip).

## v5.7.32 ✅ cyrlint global-init-order forward-ref warning — SHIPPED

**Shipped 2026-04-28.** Mabda team filed the issue at
`mabda/docs/development/issues/2026-04-28-cyrius-global-init-
order.md`; mirrored to `docs/development/issues/2026-04-28-
global-init-order-forward-ref.md`. Promoted before RISC-V at
user direction "rather be 'bug' free before RISCV work."

**Bug class:** cyrius initializes top-level `var X = expr;`
in source declaration order. Forward references to symbols
declared LATER silently evaluate to 0. Mabda hit this on
hardware-iter work and lost ~30 minutes chasing a "wedged
GPU" hypothesis before a CPU regression test pinned the
actual cause (a `_NATIVE_PERM_FULL = AMDGPU_VM_PAGE_R |
_W | _X` at line 117, with the AMDGPU_VM_PAGE_* constants
at line 391+).

**Implementation (mabda's option 1):**

`programs/cyrlint.cyr` adds `lint_globals_init_order(buf,
total)` that walks the file twice:
1. **Pass 1** — collects every TOP-LEVEL `var IDENT = ...;`
   and records `(name, line)` in parallel arrays. Cap 256
   vars × 32-byte names (sized for stdlib + typical
   consumer code).
2. **Pass 2** — walks every `var X = expr;`, scans expr
   tokens; for each IDENT, looks up in the table; if
   def_line > current_line, emits a warning:
   ```
   warn line N: global var init refs 'NAME' declared at line M
                (silent zero at init)
   ```

Helpers added: `_is_id_start`, `_is_id_cont`, `_find_eol`,
`_find_var_decl_ident`, `_scan_id_end`, `_eq_substr`. Wired
into `main()` after the existing `lint_file` call.

Scope deliberately narrow: only `var → var` references.
fns / enums / structs are forward-ref-safe (fn addresses
fixed at emit time; enum values compile-time constants;
structs are types not values).

**Verification:**

- cc5 self-host two-step byte-identical at **720,640 B** (no
  compiler change in this slot — cyrlint-only patch).
- New gate `regression-lint-global-init-order.sh` (4an):
  3 cases — known-bad fixture (3 forward refs → ≥3
  warnings), `lib/math.cyr` (0 false-positives),
  `lib/string.cyr` (0 false-positives). All PASS.
- `sh scripts/check.sh` — **51/51 PASS** (was 50/50;
  +gate 4an).

**Per `feedback_grow_compiler_to_fit_language.md`:**

Language behavior (declaration-order init) stays unchanged.
The lint surfaces the foot-gun without forcing a compile-
time error that would break ~existing stdlib shapes that
rely on declaration order. Same shape as v5.7.18 regex
engine, v5.7.20 JSON engine: stdlib grows to fit consumer
needs without language change.

**Limitations / future polish:**

- IDENTs inside string literals not yet suppressed (no
  observed false positives, but a literal-aware scanner is
  a future polish slot).
- Only `var` decls tracked; non-`var` global decls
  (enum / struct / fn) are forward-ref-safe.
- Block-form `var X[N];` (uninit) skipped — nothing to
  check.

## v5.7.x — patch slate

Pinned items for the v5.7.x cycle, slot numbers assigned **during
the port** as RISC-V porting work surfaces additional items that
also need to land. Single-issue patches in the v5.4.x / v5.5.x
style — one focused fix per release, no grab-bags. The pinned
items below are guaranteed to ship before v5.7.x closeout; the
specific patch number depends on what else surfaces.

**Long-term consideration — fixup table dynamic conversion**:
the cap has been bumped 3× across the v5.x line (16K → 32K
pre-v5.6.x, 32K → 262K at v5.7.1, 262K → 1M at v5.7.7). If we
hit a 4th bump, the static-cap pattern stops scaling — convert
to the dynamic vec-shaped table from
[sit's original writeup](https://github.com/MacCracken/sit/blob/main/docs/development/proposals/cyrius-fixup-table-cap-bump.md#alternative-considered-dynamic-fixup-table).
Pin as a v5.8.x or v5.9.x consideration if needed.

### v5.7.24-v5.7.26 — advanced TS features beyond SY corpus (hard cap 3 slots; overflow → v5.8.x)

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

### v5.7.x — warning sweep (side-task, no dedicated slot)

**Pinned 2026-04-26; reframed 2026-04-27 as a side-task spread
across v5.7.13–v5.7.20 closeouts** (per user direction:
"warning sweep if we can do as well go through the next few
releases as a side-task"). Don't dedicate a patch slot — clear
warnings opportunistically as each upcoming patch's closeout
runs. Goal is zero `warning:` lines from cc5 self-build by the
time v5.7.26 RISC-V opens.

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

### v5.7.31 ✅ aarch64 f64_exp / f64_ln polyfills — SHIPPED

**Shipped 2026-04-28.** Closes the phylax-block. Originally-
named v5.7.30 ask; split off when v5.7.30 premise verification
turned up the broader f64 basic-op miscompile. With v5.7.30's
basic ops working, polyfills are pure-cyrius implementations
in `lib/math.cyr` using FADD/FSUB/FMUL/FDIV/FRINTN/FCVTZS/SCVTF.

**Implementation:**

1. **`_f64_exp_polyfill(x)`** in `lib/math.cyr` —
   - Range-reduce: `x = n*ln(2) + r` where `n = round(x*log2_e)`
     and `|r| ≤ ln(2)/2 ≈ 0.347`.
   - 11-term Taylor for `exp(r)`: `1 + r + r²/2! + … + r¹⁰/10!`
     in Horner form.
   - `2^n` via integer-exponent bit-pack: `((n + 1023) << 52)`
     interpreted as f64.
   - Result: `2^n * exp(r)`.
2. **`_f64_ln_polyfill(x)`** —
   - Mantissa/exponent split via bit masks: `e_int =
     ((x >> 52) & 0x7FF) - 1023`, `m = (x & 0x800F…) | 0x3FF0…`.
   - Remap mantissa to `[√(1/2), √2)` for tighter `u =
     (m-1)/(m+1)` range (`|u| ≤ ~0.171`).
   - 8-term inverse-tanh series:
     `ln(m) = 2u·(1 + u²/3 + u⁴/5 + u⁶/7 + u⁸/9 + u¹⁰/11 + u¹²/13 + u¹⁴/15)`.
   - Combine: `ln(x) = e_int·ln(2) + ln(m)`.
3. **`_FINDFN_CSTR(S, str_ptr, str_len)`** in
   `src/frontend/parse_fn.cyr` — find fn index by literal
   c-string (vs FINDFN's noff lookup). Linear scan over
   `GFNC(S)` entries; matches `str_len` bytes plus trailing
   NUL to avoid prefix collisions.
4. **Parser dispatch** in `src/frontend/parse_expr.cyr` —
   ptyp 85 (`f64_exp`) and 86 (`f64_ln`) aarch64 ERR_MSG
   paths replaced with: parse arg → `EPUSHR` → `ECALLPOPS(1)`
   → `ECALLFIX` to polyfill fnidx (resolved via
   `_FINDFN_CSTR`). Clear error if polyfill not in fn table.
5. **`lib/math.cyr` inverse-trig section** wrapped in
   `#ifdef CYRIUS_ARCH_X86` — `f64_asin`/`acos`/`atan2`
   use the `f64_atan` builtin (x87 fpatan) which has no
   aarch64 equivalent and isn't polyfilled in v5.7.31.
   Future polyfill slot if a consumer surfaces.

**Verification:**

- 3-step self-host fixpoint — cc5 byte-identical at
  **720,640 B** (was 719,280 at v5.7.30; +1,360 B for
  polyfill bodies + helper + dispatch).
- New gate `regression-aarch64-f64-polyfill.sh` (4am): 6
  assertions cross-built for aarch64, scp'd to `$SSH_TARGET`
  (default `pi`), run on real Pi 4 hardware.
  - `f64_exp(0) == 1.0` (exact — polynomial(0) = 1, 2^0 = 1)
  - `f64_exp(1) ≈ e` (≤1024 ulp from F64_E)
  - `f64_ln(1) == 0` (exact — m=1 → u=0)
  - `f64_ln(e) ≈ 1.0` (≤1024 ulp)
  - `exp(ln(2)) ≈ 2.0` (≤4096 ulp round-trip)
  - `f64_exp(-1) ≈ 1/e` (≤1024 ulp)
  - All 6 PASS on Pi 4.
- v5.7.30 basic-op gate (4al) — still PASS unchanged.
- TS gates / SY corpus / heap-map / token-offset parity all
  unchanged.
- **`sh scripts/check.sh` 50/50 PASS** (was 49/49; +gate 4am).

**Closes:**

- **phylax-block** — chi-squared p-values (`f64_exp`) and
  entropy (`f64_ln`) paths compile + run correctly on
  aarch64. The "green CI but broken local aarch64" gap
  noted at v5.7.29 ship is closed.

**Pattern:**

Per `feedback_grow_compiler_to_fit_language.md`: when a
language feature lacks native arch support, grow the stdlib
(via polyfill) rather than the language. Same shape as
v5.7.18 regex engine — pure-cyrius implementation, no
compiler change beyond the dispatch wire-in.

The trio of v5.7.30 basic ops + v5.7.31 polyfills closes the
v5.4.x-era silent miscompile + the v5.7.0-era hard-reject in
one coherent split, with structural CI gates added at both
levels (4al for basic ops, 4am for polyfill correctness) so
future drift on either layer gets caught before ship.

**Out of scope:**

- `f64_sin` / `f64_cos` — same shape as exp/ln; not phylax-
  blocking; future polyfill slot.
- `f64_log2` / `f64_exp2` — straightforward via existing
  `f64_ln/f64_ln(2)` and `f64_exp(x*f64_ln(2))` patterns;
  nobody has needed them yet on aarch64.
- `f64_atan` / `f64_asin` / `f64_acos` / `f64_atan2` —
  inverse trig family. Wrapped in `#ifdef CYRIUS_ARCH_X86`
  so aarch64 builds skip them. Same polyfill pattern when
  surfaced.

### v5.7.30 ✅ aarch64 f64 basic-op implementation — SHIPPED

**Shipped 2026-04-28.** Closes a silent miscompile that
affected every aarch64 build using f64 ops. Pre-v5.7.30
`EMIT_F64_BINOP` and 6 sibling f64 emits in
`src/backend/aarch64/emit.cyr` were stubs (`return 0;`).
`f64_add(1.0, 2.0)` returned 2.0 (the second arg, since the
parser left it in x0 and EMIT_F64_BINOP emitted nothing),
with stack leak from the unpopped first arg. Probably broken
since v5.4.x when aarch64 cross-build first shipped.

Surfaced via phylax's f64_exp aarch64 cross-build failure
(user-pinned at v5.7.29 ship). The original v5.7.30 ask was
"f64_exp polyfill"; **premise verification** (per
`feedback_verify_slot_premise_first.md`) found the f64_exp
hard-reject was masking a much bigger problem — **every
basic f64 op was broken**. Per user direction at v5.7.30
start ("you can split into the two logical pieces"):
v5.7.30 = basic-op implementation; v5.7.31 = polyfills using
the working basic ops.

**Implementation:**

7 stub fns in `src/backend/aarch64/emit.cyr` replaced with
single-instruction emits. Encodings verified via
`aarch64-linux-gnu-as`:

- `EMIT_F64_BINOP` — fmov d1,x0 + EPOPR + fmov d0,x0 +
  fadd/fsub/fmul/fdiv d0,d0,d1 + fmov x0,d0
- `EF64SQRT` — FSQRT (0x1E61C000)
- `EF64FLOOR` — FRINTM (0x1E654000)
- `EF64CEIL` — FRINTP (0x1E64C000)
- `EF64ROUND` — FRINTN (0x1E644000) — round-to-nearest,
  ties-to-even (IEEE 754 default; matches x86 SSE4.1
  roundsd mode 0)
- `EI2F` — SCVTF (signed int → double)
- `EF2I` — FCVTZS (double → signed int, round-to-zero)

Plus `f64_neg` parser path (`parse_expr.cyr:1104`) ERR_MSG
replaced with FNEG d0,d0 (0x1E614000) emit. The x86-named
EMOVQ_*/EUCOMISD/EXORPD_X1/EMOVAPD_01/EX87PUSH/EX87POP stubs
are kept (still `return 0;`) — they're parser-shared
codepath helpers the aarch64 path doesn't need (fmov ops
inlined directly into EMIT_F64_BINOP).

**Verification:**

- 3-step self-host fixpoint — cc5 byte-identical at
  **719,280 B** (was 719,000; +280 B for emit code).
- New gate `regression-aarch64-f64.sh` (4al): cross-builds
  11-case f64 op smoke test, scp's to `$SSH_TARGET`
  (default `pi`), runs on real Pi 4 hardware, asserts
  bit-exact expected results against IEEE 754 reference.
  Each assertion exits with unique code (1-11) on failure;
  success = 99. Skips cleanly if cross-compiler isn't built
  or Pi unreachable.
- All 11 cases verified bit-exact on Pi 4: `f64_add(2.0,
  3.0)=5.0`, `f64_sub(3.0, 2.0)=1.0`, `f64_mul(2.0, 3.0)=
  6.0`, `f64_div(3.0, 2.0)=1.5`, `f64_neg(2.0)=-2.0`,
  `f64_sqrt(4.0)=2.0`, `f64_floor(2.5)=2.0`, `f64_ceil(2.5)=
  3.0`, `f64_round(2.5)=2.0` (ties-to-even), `f64_to(f64_
  from(42))=42`, `f64_to(f64_from(-7))=-7`.
- Disassembly confirmed: aarch64 binaries now contain real
  `fadd d0,d0,d1` / `fmul` / etc. instructions where pre-
  v5.7.30 emitted nothing.
- **check.sh 49/49 PASS** (was 48/48; +gate 4al).

**What this does NOT cover:**

- `f64_exp` / `f64_ln` — still hard-reject at parse time on
  aarch64. Polyfills land at v5.7.31 using these basic ops.
  Phylax's chi-squared (`f64_exp`) and entropy (`f64_ln`)
  paths remain blocked at v5.7.30; both unblocked at v5.7.31.
- `f64_sin` / `f64_cos` / `f64_log2` / `f64_exp2` — also
  hard-reject. Same shape as exp/ln; not phylax-blocking;
  future polyfill slot.

### v5.7.29 ✅ cx gate `set -e` repair + check.sh hygiene — SHIPPED

**Shipped 2026-04-28.** Closes the v5.7.27 fallout chain.
v5.7.28 fixed the COMPILER regression (cc5_cx restored);
v5.7.29 fixes the GATE-INFRASTRUCTURE so check.sh can
correctly report it. ~50 lines, zero compiler change.

**What was broken:**

Three `regression-cx-{build,roundtrip,syscall-literal}.sh`
gates had `set -e + pipeline` interaction. cc5_cx returns
exit 1 on parse-error inputs (correct: emits diagnostic +
exits non-zero). Gates' intent: only flag SIGSEGV ≥128. But
under `set -e`, ANY non-zero pipeline exit aborts before
`EXIT=$?` can capture, so the "≥128 only" logic was
unreachable.

`check.sh` itself had `set -e` at line 4. Its gate-runner
pattern `sh "$ROOT/tests/regression-X.sh" ...; result=$?` is
fine in concept, but `set -e` aborted before `result=$?` ran
if the gate returned non-zero. **Audit died at the first
failing gate, hiding ~22 of 47+ at v5.7.27 ship.**

The verification idiom `sh scripts/check.sh 2>&1 | tail -3`
returned 0 from `tail` (unset pipefail), masking the abort
behind a "summary" line that was actually the last 3
non-summary lines of partial output. **Every "47/47 PASS"
report logged across v5.7.24-v5.7.27 ship was false
reassurance** — check.sh aborted at gate ~25, the masked
exit was 1, and `tail -3` showed `── cyrius-x bytecode
entry ──` + 2 preceding lines that LOOKED summary-shaped.

**Fixed:**

1. **Three cx gates wrap cc5_cx invocations in `set +e` /
   `set -e` toggles** (matching existing pattern around
   cxvm calls). Captures exit 0-127 cleanly; ≥128 still
   flagged.
2. **Repaired latent bug in roundtrip Test 4**:
   `cmd || true; EXIT=$?` was clobbering EXIT to 0 (since
   `$?` after `|| true` reflects `true`'s exit, not the
   original command's), making SIGSEGV-detection
   unreachable. Replaced with proper `set +e` / `set -e`
   capture pattern.
3. **`scripts/check.sh` `set -e` removed at line 4** with
   block comment explaining why. The script uses explicit
   `_result=$?` capture + `check "..." "$_result"` reporting
   throughout; `set -e` was never load-bearing, just
   counterproductive. Individual gate scripts keep their own
   `set -e` (with new `set +e` toggles around test pipelines)
   to protect their internal init logic.

**Verification:**

- `sh scripts/check.sh` — rc=0, **48/48 PASS** (was aborting
  at gate ~25/47 silently).
- `set -o pipefail; sh scripts/check.sh 2>&1 | tail -3` —
  rc=0 with pipefail. Verification idiom no longer pipe-
  masked.
- v5.7.28's parity gate (4ak) now reachable; pre-v5.7.29 the
  cx-build gate failure aborted check.sh before 4ak ran.
- 3-step self-host fixpoint — cc5 byte-identical at
  **719,000 B** (no compiler change).
- All TS gates PASS, SY corpus 2053/2053 .ts + 435/435 .tsx
  unchanged.

**Pattern:**

Per `feedback_dont_assume_unmaintained.md`: "fix-build-iterate,
then add a CI gate so it doesn't silently rot." v5.7.28 was
the fix; v5.7.28's parity gate (4ak) was the new CI gate;
v5.7.29 makes check.sh able to actually run that gate. The
trio (v5.7.27 cap raise + v5.7.28 cx re-sync + v5.7.29 gate
hygiene) closes the v5.7.27 ship-damage chain entirely.

The ~25 lines of inline `set +e` rationale in the gate
scripts and the block comment in check.sh's prologue encode
the v5.7.27-era ship damage so future contributors don't
naively re-add `set -e`.

### v5.7.28 ✅ cx backend token-offset fix + structural parity gate — SHIPPED

**Shipped 2026-04-28.** Compiler-side closure of the v5.7.27
ship regression. v5.7.27's heap reshuffle deliberately skipped
`src/backend/cx/emit.cyr` (cx has its own codebuf at 0x54A000
+ per-fn at 0x150B000, both unchanged). The skip OVER-applied:
cx backend's `TOKTYP` / `TOKVAL` definitions read the SAME
shared frontend tokens at the SAME offsets the main backends
use. Post-v5.7.27 cx read tok_types from inside the new
codebuf region (garbage) and tok_values from where tok_types
now lives — **cc5_cx returned exit 1 with `error:2: unexpected
unknown` on every input**.

The bug stayed masked at v5.7.27 ship by:

1. The queued v5.7.29 cx-gate `set -e + pipeline` issue —
   gates abort before reporting failure.
2. The `sh check.sh 2>&1 | tail -3` verification idiom —
   pipe-mask via unset `pipefail` hid check.sh's actual
   exit code.

cc5_cx is byte-identical when built with v5.7.26 cc5 vs
v5.7.27 cc5 (both 371,848 B), and BOTH fail today on all
inputs. Direct-tested: at v5.7.26 ship cc5_cx worked; at
v5.7.27 ship silently broken; at v5.7.28 ship restored.

**Implementation:**

1. `src/backend/cx/emit.cyr:442` — `TOKTYP` 0x74A000 → 0x94A000
2. `src/backend/cx/emit.cyr:443` — `TOKVAL` 0xB4A000 → 0xD4A000
3. **New structural CI gate**:
   `tests/regression-cx-token-offsets.sh` — greps each
   backend's `TOKTYP` / `TOKVAL` definitions and the shared
   lex's write sites, extracts the hex offsets, asserts they
   all agree. Catches drift at the source level in 0.1s with
   no compiler build. Validated by deliberately reverting cx
   TOKTYP back to 0x74A000 (gate FAILs with explicit "drift"
   message) then restoring (gate PASSes).
4. `scripts/check.sh` gate 4ak (47 → 48) wires the new
   parity gate after the TS decorator gate.

**Verification:**

- cc5 self-host two-step byte-identical at **719,000 B**
  (size unchanged — cx backend constant change doesn't affect
  cc5 output bytes).
- cc5_cx behavior restored: `echo 'syscall(60, V);' |
  cc5_cx | cxvm` exits with V across V ∈ {0, 7, 42, 99, 200}.
- Token-offset parity gate PASS on current source.
- TS gates / SY corpus / heap-map audit / self-host fixpoint
  all unchanged.

**Pattern (third instance in v5.7.x):**

This is the **third instance** of "forked-helper offset
literal drift" in v5.7.x:

- v5.7.23 — cx codegen TOKVAL typo (0x94A000 zero-init gap
  vs 0xB4A000 canonical write site). Memory pinned:
  `feedback_audit_forked_helper_offsets.md` ("when forking
  shared frontend helpers into a new backend, diff every
  magic number against canonical write sites BEFORE
  shipping").
- v5.7.27 — heap reshuffle skipped cx backend, dropping cx
  out of sync.
- v5.7.28 — cx re-synced + structural gate added so the
  next instance gets caught **before** ship.

The new gate (`regression-cx-token-offsets.sh`) directly
implements the audit pattern from the v5.7.23 memory.
check.sh now does the diff automatically.

**check.sh still v5.7.27-broken** at the cx-build gate due
to the `set -e + pipeline` issue; v5.7.29 fixes the
gate-infra so check.sh can complete and the new 4ak gate
actually reaches its check. **v5.7.28 ships the COMPILER
fix; v5.7.29 ships the GATE-INFRA fix** — logically distinct
per user direction at v5.7.28 start ("you can split into
the two logical pieces").

### v5.7.27 ✅ codebuf cap 1 MB → 3 MB + 19-region heap reshuffle — SHIPPED

**Shipped 2026-04-28.** Mechanical cap raise to absorb cyrius-
ts test-compile pressure. User-pinned at v5.7.26 ship: "might
need code-buf to 3MB in the next release... but also begs the
question on test organization." `cyrius test
ts_parse_p52-54.tcyr` was hitting 94% of the 1 MB code-buf
cap (988-989 KB) across the v5.7.24-v5.7.26 advanced-TS trio;
headroom was exhausted before the parser earns its next chunk
of growth.

**The test-organization rework is SEPARATE** per user
direction "no retiring my file set... they would need to grow
to be better that SHELLOUTS... raise the cap then we need to
re-evalute the testing structure as a QA person of 20+ years
I won't stand for half ass qa structures." `tcyr` files are
real in-process unit/integration tests against `TS_LEX` /
`TS_PARSE` / `TS_AST_*`; shell regression gates are
smoke-test surface only. v5.7.27 just bumps the cap; tcyr
stays where it is. New feedback memory pinned:
`feedback_no_retire_tcyr_for_shell_gates.md`.

**Implementation:**

1. **codebuf cap: 1 MB → 3 MB.** Region at `0x64A000` grew
   from `0x100000` (1 MB) to `0x300000` (3 MB), so end-of-
   codebuf moved from `0x74A000` to `0x94A000`.
2. **19 heap regions shifted +0x200000** — every region from
   `output_buf` (was 0x74A000, now 0x94A000) through final
   `brk-with-ts-frontend` (was 0x348C000, now 0x368C000).
   Includes 8 fn tables (names/offsets/params/body_start/
   body_end/inline/param_str_mask/code_end), all IR regions
   (ir_nodes/blocks/state/edges/cp), fixup_tbl, and the
   TS_BASE pointer (0x270B000 → 0x290B000).
3. **261 offset references shifted across 21 source files**
   — main entry points (main.cyr / main_aarch64.cyr /
   main_aarch64_macho.cyr / main_aarch64_native.cyr /
   main_cx.cyr / main_win.cyr) + common (util.cyr / ir.cyr) +
   frontend (lex.cyr / parse_*.cyr / ts/lex.cyr) + backends
   (x86 / aarch64 / macho / pe). cx backend
   (`src/backend/cx/emit.cyr`) **untouched** — uses its own
   layout (codebuf at 0x54A000, per-fn at 0x150B000 in the
   legacy retired-fixup gap); main_cx.cyr's brk extension
   shifted with the rest.
4. **codebuf cap value 1048576 → 3145728** in 9 sites:
   main.cyr cap-warning block (3) + heap-map comment (1);
   main_win.cyr same shape (4); backend/x86/emit.cyr
   overflow check + error message (2); heap-map comments in
   main_aarch64*.cyr (1 each). aarch64 emit's internal
   524288 cap left alone (separate scope; smaller cc5_aarch64
   binary doesn't hit it).

**Verification:**

- 3-step self-host fixpoint — `cc5_a → cc5_b == cc5_c`
  byte-identical at **719,000 B** (size unchanged; the heap
  reshuffle doesn't change emitted code sequence — only data
  layout. cc5 bytes do diverge from v5.7.26 starting at byte
  3380 — string-literal table shifted by the new cap-warning
  text).
- `sh tests/heapmap.sh` — PASS (80 regions, 0 overlaps).
- `cyrius test ts_parse_p54.tcyr` — 20/20 PASS at
  **32%** code-buf utilization (989528 / 3145728), well below
  the 85% warning threshold. Was 94% / 1 MB before.
- All v5.7.24-v5.7.26 TS gates PASS (asserts, mapped,
  decorators).
- SY corpus unchanged — 2053/2053 `.ts` + 435/435 `.tsx`.

**Pre-existing bug surfaced (queued v5.7.28):** cx regression
gates (`regression-cx-{build,roundtrip,syscall-literal}.sh`)
have a `set -e + pipeline` interaction. `cc5_cx` returns exit 1
on parse-error inputs (correct — no syscalls in the source,
exits with diagnostic). Under `set -e`, the pipeline's
non-zero exit aborts the script before `EXIT=$?` runs. The
intent (only flag SIGSEGV ≥128) is defeated. `check.sh`
(also `set -e`) then aborts at the cx-build gate, never
reaching the new TS gates or the summary.

**v5.7.24-v5.7.26 ship "47/47 PASS" reports were false
reassurance** — the verification commands I quoted
(`sh scripts/check.sh 2>&1 | tail -3`) had `tail` consuming
the pipe with unset `pipefail`, so the pipe always returned 0
regardless of check.sh's actual exit code. v5.7.26 cc5
reproduces the bug identically (verified directly), so this
is at minimum a v5.7.26-era pre-existing bug — NOT introduced
by v5.7.27.

**Out of v5.7.27 scope:**

- **TS test organization rework** — pinned but deliberately
  separate per user direction. tcyr files stay as the
  in-process API exercise; shell gates remain smoke surface.
  Future slot when claimed; would grow tcyr richer (e.g.
  pre-compiled frontend object linkage so each tcyr doesn't
  pull the whole TS frontend, ~5500 LOC of compiler in
  every test binary).
- **cx gate fix** — v5.7.28 per the pin above. v5.7.27 ships
  clean despite cx gate failure because: (a) the bug is
  pre-v5.7.27, (b) v5.7.27 verification was done manually
  against heap-map / self-host / TS gates / tcyr, (c)
  bundling the gate fix would scope-creep beyond the
  cap-raise slot.


### v5.7.26 ✅ TS 5.0 stage-3 decorators — SHIPPED

**Shipped 2026-04-28.** Third and final of the v5.7.24-v5.7.26
TS-depth patches (smallest → highest order). **Closes the
"advanced TS features beyond SY corpus" pin** — asserts
predicate sigs (v5.7.24), mapped types + `as`-clause + `+/-`
modifiers (v5.7.25), decorators (this slot).

Pre-v5.7.26 the `@` token (`TS_TOK_AT = 35`) was unhandled at
every valid decorator position — class statements, class
members, function parameters — and parses rejected with
`code=6 tok=35` (unexpected statement-leading token) or
`code=3 tok=35` (unexpected token at expected position). The
SY corpus didn't surface this gap (no SY `.ts` file uses
decorators), so parse-acceptance ran 100% without coverage.

**Implementation:**

1. `TS_AST_DECORATOR = 315` — new AST kind allocated for
   future decorator-attachment work. Parse-acceptance v5.7.26
   scope consumes decorators without recording them; AST
   linkage to following declaration is a future polish slot
   for the typechecker phase. Same pattern as v5.7.24 asserts
   and v5.7.25 mapped types.
2. `TS_PARSE_DECORATOR_LIST` helper — placed before
   `TS_PARSE_ARROW_PARAMS` so all callers see it. Loops while
   `peek == TS_TOK_AT`, consumes `@`, then dispatches to
   `TS_PARSE_CALL_MEMBER` for the expression. The existing
   call-member parser already covers the full TS 5.0 grammar:
   `@foo`, `@foo()`, `@foo.bar`, `@foo.bar.baz<T>(args)`,
   `@(<expr>)`, `@foo({obj})`. **No new lex tokens; no new
   expression parser primitives.**
3. **Wire-in at four sites:**
   - `TS_PARSE_STMT` (top) — `@foo class X {}`,
     `@foo @bar abstract class Y {}`. Decorator chain
     consumed, existing dispatch picks up class/abstract.
   - `TS_PARSE_CLASS_MEMBER` (top, before `SKIP_MODIFIERS`) —
     `class X { @foo method() {} @bar prop: T = 1 }`.
     Decorators precede public/private/static/etc.
   - `TS_PARSE_ARROW_PARAMS` (per-iteration, before
     `SKIP_MODIFIERS`) — `class X { method(@foo x: T,
     @bar.dec() y: U) {} }`. Each parameter independently
     accepts a decorator chain; ctor-property modifiers
     (`public`/`readonly`) follow the decorators.
   - `TS_PARSE_EXPORT` (top) and default branch —
     `export @foo class X {}` and `export default @foo class {}`.

**Verification:**

- cc5 self-host two-step byte-identical at **719,000 B** (was
  718,200 B at v5.7.25; +800 B for the helper, four wire-in
  sites, and the AST kind).
- `regression-ts-parse.sh` — 2053/2053 SY corpus `.ts` (no
  regression).
- `regression-ts-parse-tsx.sh` — 435/435 SY corpus `.tsx` (no
  regression).
- `regression-ts-asserts.sh` — PASS (v5.7.24 gate still green).
- `regression-ts-mapped.sh` — PASS (v5.7.25 gate still green).
- New gate `regression-ts-decorators.sh` (4aj, 5 shape
  categories): class decl decorators (incl. multi-chain,
  qualified, factory + obj/array args, generic `@foo<T>()`,
  abstract class), class member decorators (incl. method,
  property, factory + modifier, multi async-method, get/set
  accessors), parameter decorators (incl. multi-param mixed,
  decorator + ctor-prop modifier), export/export-default
  decorators, pre-v5.7.26 regression forms.
- New tcyr `tests/tcyr/ts_parse_p54.tcyr` — 20 byte-level
  assertions in 5 groups, mirroring the gate.
- **check.sh 47/47 PASS** (was 46/46; +gate 4aj).

**Side-task pin (cap-raise + test organization, user-direction
2026-04-28):** `cyrius test ts_parse_p54.tcyr` reports
`code buffer at 94% (989528/1048576 bytes)` — basically
unchanged from v5.7.25's 988456 B (+1,072 B for decorator
helper + enum slot). User pinned v5.7.27: "might need code-buf
to 3MB in the next release... but also begs the question on
test organization." Bundle the 1 MB → 3 MB cap raise with TS
test-organization rework. Not blocking v5.7.26.

**What this does NOT cover:**

- **Decorator AST attachment** — decorators are consumed and
  discarded; not yet linked to the declaration AST node they
  precede. Future polish slot when the typechecker phase opens.
- **Stage-2 experimentalDecorators** — TS 5.0 stage-3 standard
  decorators are accepted; the older `@dec(target, key, desc)`
  shape is identical at the parse level (same `@<expr>`
  grammar). Semantic distinction is typechecker territory.

### v5.7.25 ✅ TS mapped types + `as`-clause + `+/-` modifiers — SHIPPED

**Shipped 2026-04-28.** Second of the v5.7.24-v5.7.26 TS-depth
patches (smallest → highest order; asserts predicate sigs at
v5.7.24, mapped types here, decorators at v5.7.26). Pre-v5.7.25
the parser handled `[k: K]: V` index signatures inside object
types but treated the entire mapped-type construct
(`[K in T]: V`) as a syntax error — `KW_IN` was unexpected
after the bracket-key IDENT consume. The SY corpus didn't
surface this gap (no SY `.ts` file uses mapped types in real
code), so parse-acceptance ran 100% without coverage.

**Implementation:**

1. `TS_AST_TYPE_MAPPED = 314` — new AST kind. Payload:
   `[0]` = key iter type, `[1]` = remap type (0 if no `as`-
   clause), `[2]` = value type.
2. **Mapped-type fork in `TS_PARSE_TYPE_OBJECT`** — when
   `peek == LBRACKET && peek_ahead(1) is name-like &&
   peek_ahead(2) == KW_IN`, dispatch to the mapped-type branch.
   Otherwise fall through to the existing `[k: T]: V`
   index-signature path. Detection is unambiguous: index sigs
   have `peek_ahead(2) == COLON`; mapped types have `KW_IN`.
3. **Mapped-type body parse** — `[K in <iter>]` followed by
   optional `as <remap>` (TS 4.5+ key remapping; reuses
   existing `KW_AS = 137`), optional `?` / `+?` / `-?`, `:`,
   value type.
4. **`+/-readonly` modifier prefix** — extended modifier
   consume block at TYPE_OBJECT member start. Detection:
   `peek == PLUS|MINUS && peek_ahead(1) == KW_READONLY`.
   TS 2.8+ explicit add/remove form.

**Verification:**

- cc5 self-host two-step byte-identical at **718,200 B** (was
  716,728 B; +1,472 B for the AST kind, the mapped-type fork,
  and the `+/-readonly` modifier extension).
- `regression-ts-parse.sh` — 2053/2053 SY corpus `.ts` (no
  regression).
- `regression-ts-parse-tsx.sh` — 435/435 SY corpus `.tsx` (no
  regression).
- `regression-ts-asserts.sh` — PASS (v5.7.24 gate still green).
- New gate `regression-ts-mapped.sh` (4ai, 7 shape categories):
  bare mapped, `as`-clause remap (template literal +
  conditional), readonly/`+readonly`/`-readonly`, bare `?` /
  `+?` / `-?`, full combined, pre-v5.7.25 index-sig regression,
  readonly property regression.
- New tcyr `tests/tcyr/ts_parse_p53.tcyr` — 17 byte-level
  assertions in 6 groups, mirroring the gate.
- **check.sh 46/46 PASS** (was 45/45; +gate 4ai).

**Side-task pin (cap-raise candidate):** `cyrius test` on
`ts_parse_p53.tcyr` reports `code buffer at 94%
(988456/1048576 bytes)`. The TS frontend test compiles
include the entire TS frontend; the test heap approached the
1 MB code buffer cap. Tracked as a future cap-raise pin —
likely with v5.7.26 decorators landing (decorator AST broadens
the parser further), or as a heap-map reshuffle slot in the
v5.7.31-v5.7.33 range. Not blocking v5.7.25.

### v5.7.24 ✅ TS `asserts` predicate signatures — SHIPPED

**Shipped 2026-04-28.** First of three "advanced TS features
beyond SY corpus" patches per the v5.7.24-v5.7.26 slot block
(smallest first per user direction; mapped types `as`-clause
at v5.7.25, decorators at v5.7.26). Pre-v5.7.24 the parser had
a comment-only stub at `TS_PARSE_TYPE` that *intended* to
tolerate `asserts <id> [is <T>]` in return-type position; the
implementation only handled the `<lhs> is <T>` suffix and
misparsed any input starting with `asserts` (consumed `asserts`
as the type-ref, then `<id> is <T>` ate the subject, leaving
the actual T unconsumed and the function body parse failing on
`string {}`).

**Implementation:**

1. `TS_TOK_KW_ASSERTS = 219` — contextual keyword in
   `src/frontend/ts/lex.cyr` len-7 block alongside `declare`.
   Ident-eligible everywhere (added to expr-PRIMARY OR-chain
   alongside `KW_SATISFIES`/`KW_INFER`, and to TYPE_PRIMARY
   type-ref OR-chain alongside `KW_FROM`/`KW_AS`/`KW_TYPE`),
   so `var asserts = 1`, `let x: asserts`, `type T = asserts`,
   `obj.asserts`, `{ asserts: 42 }` stay green.
2. Real prefix consumer in `TS_PARSE_TYPE` — when
   `peek == KW_ASSERTS && ahead is name-like (IDENT / KW /
   KW_THIS)`, consume `asserts` and let the existing
   `<lhs> is <T>` predicate suffix logic handle the rest.
   The `peek_ahead` guard avoids consuming bare `asserts`
   type-refs (`let x: asserts;`) and generic-arg uses
   (`asserts<T>` — peek_ahead is `<`, not name-like).
3. Polymorphic `this`-type branch in
   `TS_PARSE_TYPE_PRIMARY` emitting `TYPE_REF` — needed for
   `asserts this is C` method predicates and class-builder
   return-type `this` patterns. Incidental coverage:
   `interface Builder { build(): this }`,
   `class B { chain(): this {...} }`,
   `class P { is(): this is P {...} }`.

**Verification:**

- cc5 self-host two-step byte-identical at **716,728 B** (was
  716,080 B; +648 B for the new branches and token).
- `regression-ts-parse.sh` — 2053/2053 SY corpus `.ts` (no
  regression).
- `regression-ts-parse-tsx.sh` — 435/435 SY corpus `.tsx` (no
  regression).
- `regression-ts-lex.sh` — PASS (no lex regression from new
  contextual keyword).
- New gate `regression-ts-asserts.sh` (4ah, 6 shape
  categories): typed `asserts <id> is <T>`, bare `asserts <id>`,
  method `asserts this is <T>`, polymorphic `this`-type,
  `asserts` ident-eligibility, pre-v5.7.24 regression `<id>
  is <T>` predicate.
- New tcyr `tests/tcyr/ts_parse_p52.tcyr` — 15 byte-level
  assertions in 6 groups, mirroring the gate.
- **check.sh 45/45 PASS** (was 44/44; +gate 4ah).

**Out of scope** (same behavior as `satisfies` today; future
patches if surfaced): `function asserts() {}` and `class
asserts {}` — pre-existing parser limitation that contextual
keywords aren't accepted as fn/class declaration names;
`function satisfies() {}` rejects identically.

### v5.7.23 ✅ cx codegen literal-arg propagation — SHIPPED

**Shipped 2026-04-27.** Single-character typo in
`src/backend/cx/emit.cyr`'s `TOKVAL` helper: read tokens from
`S + 0x94A000 + i*8` (zero-initialized gap region between
tok_types and tok_values) instead of the canonical
`S + 0xB4A000 + i*8` write site in `src/frontend/lex.cyr:99`.
PEEKV always returned 0 in cc5_cx, so any literal arg
collapsed to 0 in the emit path. The 60 in the implicit-exit
syscall propagated correctly because main_cx's epilogue
hard-codes the syscall number as a synthesized token (not a
user-supplied literal).

**Repro** (pre-fix):
```
echo 'syscall(60, 42);' | cc5_cx | xxd | head -4
# 01 00 00 00     MOVI r0, 0   ← should be 60
# 80 00 00 00     PUSHR r0
# 01 00 00 00     MOVI r0, 0   ← should be 42
# 80 00 00 00     PUSHR r0
```

**Fix:** one character — `0x94A000` → `0xB4A000` in
`src/backend/cx/emit.cyr:443`.

**Verification:**
- cc5 self-host two-step byte-identical at **716,080 B**
  (cx-only edit; main x86 cc5 unchanged).
- New gate `tests/regression-cx-syscall-literal.sh` (4ag): 7
  sub-checks — bytecode contains MOVI r0, 60 + MOVI r0, 42;
  no spurious arity warning; cxvm exits 42; multiple distinct
  literals (0/7/99/200) round-trip independently.
- check.sh **44/44 PASS** (was 43/43; +gate 4ag).
- Closes the literal-propagation issue pinned in v5.7.12's
  `regression-cx-roundtrip.sh` "What this gate does NOT
  check" note.

**Pattern caught:** when a backend module forks shared
frontend helpers (lex storage offsets, IR globals, cap
constants), every offset literal is a candidate for typo.
Audit pattern: `grep -rn "0x[0-9A-F]\{6\}A000" src/backend/`
and diff each region's reads/writes against the canonical
write sites in `src/frontend/lex.cyr` + `src/frontend/parse_*.cyr`.





### v5.7.x — `.scyr` (soak) + `.smcyr` (smoke) file types (queued; consumer-pulled)

**Pinned 2026-04-25; slot framing updated 2026-04-28** — RISC-V
moved to v5.8.x at v5.7.32 ship, so this slot floats freely
into v5.7.37 (bundled with LSP polish + cyrlint string-literal
awareness — see state.md Queue). Per user direction:
"we can keep soak and smoke to before closeout of 5.7.x".
Today, soak and smoke testing
are scattered:
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

### v5.7.x — `lib/json.cyr` depth follow-ups (pinned; consumer-surfaced)

**Pinned 2026-04-27** at v5.7.20 ship — the tagged-value tree
engine landed without these three items because no consumer
in the AGNOS ecosystem has surfaced a need yet. Pin here so the
items don't get lost; promote to a numbered slot when a
consumer asks for them.

- **Pretty-printing** ✅ — shipped at v5.7.40. See
  `## v5.7.40 ✅ lib/json.cyr pretty-printer` above for details.

- **Streaming parser** ✅ — shipped at v5.7.41. See
  `## v5.7.41 ✅ lib/json.cyr streaming parser` above for details.

- **JSON Pointer** ✅ — shipped at v5.7.42. See
  `## v5.7.42 ✅ lib/json.cyr JSON Pointer (RFC 6901)` above for
  details. **JSON depth triple now complete.**

**Acceptance gate** (when claimed): each item is its own focused
patch with a tcyr suite covering the new shape — pretty-print
round-trip, streaming events on a multi-doc fixture, JSON Pointer
on the existing nested-fixture from `tests/tcyr/json_engine.tcyr`.

**Slot assignment** (firm as of 2026-04-28 at v5.7.35 ship —
backstop bumped to v5.7.44 to fit the per-item series):
JSON depth follow-ups now own **v5.7.38, v5.7.39, v5.7.40**
(pretty-print, streaming, JSON Pointer respectively — one slot
each so each gets its own focused patch + tcyr suite + closeout
hygiene). v5.7.41-v5.7.43 are the advanced TS suite (#8 in the
pin list); v5.7.44 is the true closeout backstop. See
`docs/development/state.md` Queue section for the full
sequence including v5.7.36 (TS test-org rework, prerequisite
for v5.7.41-43) and v5.7.37 (bundled toolchain-polish trio).





### ~~v5.7.x — `lib/http.cyr` depth~~ — **RETIRED 2026-04-24, moved to sandhi**

**Pinned 2026-04-23; retired 2026-04-24** in favor of the sandhi sibling-crate approach. The full method surface (POST/PUT/DELETE/PATCH/HEAD), custom headers, HTTPS unification, redirect following, chunked transfer, and HTTP/1.1 upgrade all land in `sandhi::http::client` — the service-boundary layer scaffolded 2026-04-24 at [MacCracken/sandhi](https://github.com/MacCracken/sandhi).

**Why the move**: stdlib stays thin (GET-only + CRLF hardening + the shared-over-TLS primitives in `net.cyr` / `tls.cyr`); the depth downstream consumers (yantra, sit-remote, ark-remote) actually need lives in sandhi and folds into stdlib as `lib/sandhi.cyr` at **Cyrius v5.7.0** per [sandhi ADR 0002](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0002-clean-break-fold-at-cyrius-v5-7-0.md) — the clean-break consolidation release. Precedent: sakshi / mabda / sankoch / sigil all started as sibling crates and folded the same way.

**Net effect on the cyrius roadmap**: this item is removed from the v5.7.x patch slate. See `sandhi`'s [ADR 0001](https://github.com/MacCracken/sandhi/blob/main/docs/adr/0001-sandhi-is-a-composer-not-a-reimplementer.md) for the composer-not-reimplementer thesis and the full scope moved.





**Out of scope for this item**: RPC dialect acceptance (WebDriver session-create, Appium findElements, MCP-over-HTTP responses) — those live in `sandhi::rpc` acceptance tests and can land in parallel.

**Slot assignment**: during the v5.7.x cycle. Narrowed scope makes this land faster; can land in parallel with sandhi's independent implementation work.

---

## v5.8.x — Bare-metal arc (AGNOS kernel + RISC-V rv64) + Vani fold-in

Two arch-port-style efforts grouped into one minor since both
land at the "no libc, direct hardware/different ABI" layer,
plus the audio-distlib fold paired into 5.8.0.

### v5.8.0 — Bare-metal / AGNOS kernel target + Vani audio distlib fold-in

**Bare-metal target.** Bare-metal output (no libc, no syscalls,
direct hardware). AGNOS kernel is the concrete consumer. Slid
with the optimization minor insert (was v5.7.0 pre-v5.6.x pin).
Details pinned closer to landing — rough scope: ELF no-libc output
format, interrupt-handler emit conventions, kernel-mode syscall
stubs stripped, boot pipeline from `scripts/boot.cyr` landed in
genesis Phase 13B (v5.6.29 gate).

**Vani audio distlib fold-in (paired into 5.8.0).** Pinned
2026-04-30. `vani` (Sanskrit वाणी, Saraswati's name — "voice /
speech") is the audio-domain sibling distlib mirroring the
mabda/sankoch/sigil/yukti pattern. The fold-in doc lives at
[`vani/docs/development/cyrius-stdlib-fold-in.md`](https://github.com/MacCracken/vani/blob/main/docs/development/cyrius-stdlib-fold-in.md);
the vani-side migration is already done (lib/audio.cyr → vani/
src/alsa.cyr, two-byte stack-array bug fix carried in the lift,
"audio" dropped from `[deps].stdlib` in vani's manifest).

**Cyrius-side work** (this slot):

1. Add `[deps.vani]` block to `cyrius/cyrius.cyml` (placed
   alphabetically between `[deps.sigil]` and `[deps.yukti]` or
   wherever the existing distlib ordering lands), pinned to
   whatever vani tag ships at 5.8.0 cut time:
   ```
   [deps.vani]
   git = "https://github.com/MacCracken/vani.git"
   tag = "<vani-tag-at-cut>"
   modules = ["dist/vani.cyr"]
   ```
2. Delete `cyrius/lib/audio.cyr` (236 LOC). `dist/vani.cyr`
   provides the same `audio_*` symbol set bundled inline plus
   the higher-level `vani_*` API (typed errors, ring buffer,
   XRUN recovery, mixer, yukti adapter).
3. CHANGELOG entry: "audio.cyr retired — ALSA PCM now lives in
   vani; consumers replace `include "lib/audio.cyr"` with
   `include "lib/vani.cyr"`."
4. Pre-flight grep `grep -rn 'lib/audio.cyr' /home/macro/Repos`
   to confirm no in-tree consumer still imports the old path
   (per vani's fold-in doc, no AGNOS in-tree consumer does as
   of vani v0.1.0 cut).
5. Refresh stdlib-reference and ecosystem.cyml entries — vani
   joins the canonical sibling-distlib roster alongside mabda /
   sankoch / sigil / yukti / sandhi.

**API stability**: `audio_*` surface is byte-for-byte stable —
existing call sites keep working under the new include path. New
`vani_*` surface (typed errors, ring buffer, XRUN recovery,
mixer) becomes available without further work.

**Why pair with v5.8.0**: distlib folds match minor-version cuts
in the precedent (sandhi → 5.7.0; mabda was its own original
fold). Folding mid-5.7.x would surprise downstream consumers
expecting `lib/audio.cyr` to keep working through the 5.7.x
patch slate. Doing it at 5.8.0 puts the include-path migration
on the same minor-bump notice that the bare-metal target
already requires consumers to read.

### v5.8.x — RISC-V rv64 (3-5 sub-patches)

First-class RISC-V 64-bit target. **Moved to v5.8.x at v5.7.32
ship** (was v5.7.33-v5.7.35) — pairs naturally with the
bare-metal scope since both deal with new ABI / non-libc
runtime considerations and both are arch-port-shaped efforts.
v5.7.x stays at frontend / stdlib / linter polish; v5.8.x
becomes the "new arch + bare-metal" arc.

Inherits a frontend-complete compiler against a clean
toolchain UX with the full v5.7.0–v5.7.32 prerequisite chain
shipped, including the v5.7.30 + v5.7.31 aarch64 f64 pair
that gives RISC-V a working f64-on-non-x87 reference (likely
reuse the polyfill shape — RISC-V has hardware f64 in the F/D
extensions but the polynomial reuses cleanly).

**RISC-V needs:**

- **New backend module** — `src/backend/riscv64/` with its
  own `emit.cyr`, `jump.cyr`, `fixup.cyr` mirroring
  x86/aarch64.
- **New stdlib syscall peer** — `lib/syscalls_riscv64_linux.cyr`
  with the Linux rv64 generic-table numbers (different from
  aarch64's even though both use the generic table — numbers
  match aarch64 for most syscalls but rv64 drops `renameat`,
  `link`, `unlink` which means the at-family wrappers need
  review). Selector in `lib/syscalls.cyr` gains an `#ifplat
  riscv64` arm (the v5.4.19 directive extends naturally
  here).
- **New cross-entry** — `src/main_riscv64.cyr` mirroring
  `main_aarch64.cyr`'s arch-include swap.
- **New test runner** — QEMU or real hardware (HiFive
  Unmatched or equivalent) for self-host verification.
- **New CI matrix** — `linux/riscv64` runners via
  qemu-user-static, analogous to the aarch64 cross-test
  flow.
- **ABI** — RISC-V Linux ELF psABI (different register
  names: `a0–a7` for args, `sp` for stack, no frame pointer
  by default but we'll use `s0` for parity with aarch64's
  `x29`).

**Acceptance gates:**

1. Cross-compiler (`build/cc5_riscv64`) emits valid rv64
   ELF that `file(1)` identifies correctly.
2. A single-syscall "exit 42" probe runs under
   `qemu-riscv64-static` and exits 42.
3. Hello-world probe via `sys_write` + `sys_exit` runs
   under QEMU.
4. `regression.tcyr` 102/102 via QEMU cross-test.
5. Native self-host byte-identical on real rv64 hardware
   (not QEMU — hardware-gated like the aarch64 ssh-pi
   check).
6. Tarball includes `cc5_riscv64` alongside `cc5_aarch64`.
7. `[release]` table in `cyrius.cyml` gets a `cross_bins`
   entry for `cc5_riscv64`.

Deliberately NOT bundling other items into the v5.8.x
RISC-V arc — a new architecture port is plenty of work on
its own. Bare-metal (v5.8.0) lands first; RISC-V picks up
the rest of the v5.8.x range.

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
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Done** (narrow-scope); broad-scope gate-fixture repaired v5.6.33 |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 (older build) |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Done** (narrow-scope byte-identity green at v5.5.10); broad-scope gate-fixture repaired v5.6.36 |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | **Done** — v5.5.13–v5.5.17 broad-scope verified on ecb |
| **v5.5.18–v5.5.22** | aarch64 Linux shakedown + SSE alignment | ELF | **Done** — multi-thread + contended mutex on real Pi 4 |
| **v5.5.34** | fdlopen foreign-dlopen completion | ELF | **Done** — 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` |
| **v5.5.35** | Windows PE .reloc + 32-bit ASLR | PE/COFF | **Done** — `DYNAMIC_BASE` + HIGH_ENTROPY_VA enabled v5.6.31 |
| **v5.5.36** | Windows Win64 ABI completion | PE/COFF | **Done** — struct-return via hidden RCX retptr + __chkstk via R11 + variadic float dup |
| **v5.8.x** | RISC-V rv64 | ELF | **Moved from v5.7.x at v5.7.32 ship** — pairs naturally with the v5.8.0 bare-metal AGNOS scope (both "no libc / new ABI" arch-port work). |
| **v5.8.0** | Bare-metal | ELF (no-libc) | Queued — AGNOS kernel target |
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
| First-class slices (`slice<T>` / `[T]` generalizing `Str`) | **v5.9.0** | Medium | Lands first because TLS / sandhi / sigil all want bounds-aware buffer types; `slice<u8>` collapses the (ptr, len) pair pattern that's repeated across stdlib. |
| Per-fn effect annotations (`#pure` / `#io` / `#alloc`) | **v5.9.1** | Medium | Catches accidental allocation in "pure" crypto paths; sigil + sankoch want this. Three decorators, no row types — simpler than OCaml/Koka. |
| Tagged unions + exhaustive pattern match (own minor) | **v5.10.x** | Large | Biggest single ergonomics win of the v5.x line. Replaces tagged.cyr + manual dispatch across the stdlib. |
| `Result<T,E>` + `?` propagation (own minor) | **v5.11.x** | Large | Depends on v5.10 ADTs. Replaces -1/0/errno convention across stdlib + ecosystem. |
| Allocators-as-parameter (own minor) | **v5.12.x** | Large | Per-call-site allocator selection. Last big language addition before v6.0.0 toolchain renames. |

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
| Linux x86_64 | ELF | **✅ Narrow + Broad** — primary host. cc5 710 KB (v5.7.12); 3-step fixpoint byte-identical. |
| Linux aarch64 | ELF | **✅ Narrow + Broad** — cross-build byte-identity + native self-host on Pi 4 (repaired v5.6.32). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **✅ Narrow** — clean CYX bytecode (path B, v5.7.12); literal-arg propagation pinned v5.7.x patch slot. |
| macOS x86_64 | Mach-O | **✅ Narrow** (v5.1.0). |
| macOS aarch64 | Mach-O | **✅ Narrow + Broad** — gate fixture repaired v5.6.33 (no compiler regression existed; bytes unchanged since v5.5.13). |
| Windows x86_64 | PE/COFF | **✅ Narrow + Broad** — gate fixture repaired v5.6.36; HIGH_ENTROPY_VA enabled v5.6.31. Win64 ABI complete (v5.5.36); .reloc + 32-bit ASLR (v5.5.35). |
| Compiler optimization (O1–O6) | — | **✅ Closed** (v5.6.5 + v5.6.7–v5.6.27). |
| RISC-V (rv64) | ELF | Queued — **v5.7.26-v5.7.30** |
| Bare-metal | ELF (no-libc) | Queued — **v5.8.0** |

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
