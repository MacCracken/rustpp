# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.7.17** (shipped 2026-04-27 — **STRUCT CAP 64 → 256 +
DUMP-ON-OVERFLOW DIAGNOSTIC**. kybernet 2026-04-27 surfaced
the cc3-era 64-struct ceiling: pulling 3 dep dist bundles
(libro 29 + agnosys 10 + agnostik 9 + argonaut 27) into one
TU exceeded the cap, and the diagnostic blamed the first
user-code struct line even though that file defined exactly
1 struct. v5.7.17 raises the cap to 256 (kybernet's
recommendation), relocates `struct_fcounts` 0x18E830 →
0x18EE30 to make room for the expanded `struct_names` region,
grows `struct_ftypes` and `struct_fnames` from 16 KB to 64 KB
each (in place; ~496 KB free heap above each), and adds a
`DUMP_STRUCTS(S)` helper that prints every registered struct
name to stderr before the cap-overflow ERR_MSG fires —
mirroring the `note: N unreachable fns` pattern. cc5 byte-
identical at **715,920 B** (was 715,312 B; +608 B for
DUMP_STRUCTS + the new error message). New gate
`tests/regression-struct-cap.sh` (gate 4aa): 80-struct
compile clean (would fail at #65 pre-v5.7.17); 200-struct
compile clean (kybernet-class workload); 257-struct overflow
dumps the full `#0..#255` registered name list followed by
the `max 256` error line. **check.sh 38/38 PASS** (was 37/37;
+gate 4aa). **v5.7.x backstop bumped v5.7.28 → v5.7.33** at
this ship — 5-slot extension absorbs the +1 cascade and
restores RISC-V's full 3-5 sub-patch range without forcing
the low end. Out-of-scope per kybernet directions 2 and 3:
struct-level DCE and module-level visibility (bigger
redesigns; revisit if 256 starts feeling tight). Per-file
struct attribution also out-of-scope (current name-only
attribution is enough; revisit if users still struggle).)

**5.7.16** (shipped 2026-04-27 — **`cyrius init` / `cyrius port`
FIRST-PARTY-DOCUMENTATION DOC-TREE**. Closes the v5.7.14-as-
bundle 3-patch split: v5.7.14 transitive deps + v5.7.15 lib-vs-
bin + v5.7.16 doc-tree all shipped 2026-04-27. Both `cyrius
init` and `cyrius port` now scaffold the standard `docs/adr/`
(README + template), `docs/architecture/` (README),
`docs/guides/` (getting-started, shape-aware), `docs/examples/`
(.gitkeep), `docs/development/` (state + roadmap stubs), plus
a default root CLAUDE.md following durable-vs-volatile split
(no inlined state — Current State block points at
docs/development/state.md). Legacy `--agent` flag is now a
deprecated no-op; the v5.7.16 default template subsumes the
three legacy presets (generic/agnos/claude). cc5 unchanged at
**715,312 B** (scripts-only edits — both `cyrius-init.sh` and
`cyrius-port.sh`; compiler untouched). New gate
`tests/regression-init-doctree.sh` (gate 4z): 5 cases —
`--lib` emits 8 doc-tree files; `--bin` emits same;
bare defaults to `--bin` and emits same; `cyrius port`
mirrors; durable-vs-volatile invariant checked
(state.md carries the toolchain pin AND CLAUDE.md must NOT).
**check.sh 37/37 PASS** (was 36/36; +gate 4z).)

**5.7.15** (shipped 2026-04-27 — **`cyrius init --lib`/`--bin`
LIBRARY SCAFFOLD**. `scripts/cyrius-init.sh` grew a `SHAPE`
variable + `--lib`/`--bin` flag parsing. Lib shape emits
`[build] entry = "programs/smoke.cyr" output =
"build/<name>-smoke"` + `[lib] modules = ["src/main.cyr"]`,
header-only `src/main.cyr`, and a `programs/smoke.cyr`
proof program (mabda/sigil/sankoch convention). Bin shape
keeps the existing binary scaffold. Bare `cyrius init <name>`
defaults to `--bin` for backward-compat. README, CI/release
workflows, dry-run listing, and final next-steps all
shape-aware. cc5 unchanged at **715,312 B** (scripts-only
edit; compiler untouched). New gate
`tests/regression-init-lib-bin.sh` (gate 4y): 4 cases —
`--lib` smoke build clean, `--bin` keeps binary, bare =
`--bin`, lib CI targets programs/smoke.cyr. **check.sh 36/36
PASS** (was 35/35; +gate 4y). Second of three patches
splitting the v5.7.14-as-bundle plan from 2026-04-23.
v5.7.16 = doc-tree alignment (last of trio). Agent CLAUDE.md
heredocs in cyrius-init.sh still hardcode binary build hint —
will be folded into v5.7.16 doc-tree work.)

**5.7.14** (shipped 2026-04-27 — **`cyrius deps` TRANSITIVE
RESOLUTION** — `cbt/deps.cyr` grew a BFS recursive walker that
processes each resolved dep's own `cyrius.cyml`. `_dep_visited`
(closest-wins de-dup) + `_dep_queue` (resolved manifest dirs to
walk) + `_process_named_deps(buf, n, manifest_dir)` extracted
from cmd_deps's Phase 2 body. Phase 3 drains the queue. Cycles
break naturally (re-encountered names hit visited). Diamonds
collapse to single-symlink. Relative `path = "..."` resolves
against the transitive manifest's directory, not the consumer's
cwd. cc5 unchanged at **715,312 B** (cbt-only edit; compiler
untouched). build/cyrius now **152,320 B**. New gate
`tests/regression-deps-transitive.sh` (gate 4x): 4 cases —
3-level chain, diamond, cycle, relative-path. **check.sh 35/35
PASS** (was 34/34; +gate 4x). First of three patches splitting
the v5.7.14-as-bundle plan from 2026-04-23: v5.7.15 = init
lib-vs-bin, v5.7.16 = doc-tree alignment. Per user direction
+2 cascade through closeout; v5.7.28 hard cap now requires
RISC-V to land at the 3-sub-patch low end. Three known
limitations deferred (stdlib transitive expansion, self-package
detection, version-conflict warnings).)

**5.7.13** (shipped 2026-04-27 — **STRING-LITERAL ESCAPE
SEQUENCES** — `\x##`, `\u####`, `\u{...}`, plus the previously-
missing C-family escapes `\a` `\b` `\f` `\v` `\'`. cyim-
unblocking: `"\x1b[?1049h"` and family now decode to actual
escape bytes; pre-v5.7.13 lex stripped the `\` and emitted the
next byte verbatim, so cyim's interactive surface rendered
literal `x1b[?1049h` text and was unusable. cc5 710,312 →
**715,312 B** (+5,000 B for the new decoders + helpers + error
messages). New `_LEX_HEX_VAL` (ASCII hex digit -> [0..15] / -1)
and `_LEX_EMIT_UTF8` (codepoint -> 1-4 byte UTF-8) helpers in
`src/frontend/lex.cyr`. Surrogate codepoints (D800-DFFF) and
codepoints > U+10FFFF are lex errors; bad-hex / wrong-arity /
empty `\u{}` / 7+ digit `\u{}` / missing close-brace all
produce explicit lex errors with `error:LINE: ...` shape.
TS lex left untouched (records source spans without decoding).
Acceptance: `tests/tcyr/string_escapes.tcyr` (77 byte-level
assertions covering all classic + new forms across UTF-8
boundaries U+007F / U+0080 / U+07FF / U+0800 / U+FFFF /
U+10000 / U+10FFFF + the canonical cyim alt-screen sequence)
and `tests/regression-string-escapes.sh` (gate 4w; 11 reject
cases). cc5 self-host byte-identical fixpoint at 715,312 B.
**check.sh 34/34 PASS** (was 33/33; +gate 4w). RISC-V remains
slid to v5.7.22-v5.7.26; closeout target unchanged at
v5.7.28.)

**5.7.12** (shipped 2026-04-27 — **CYRIUS-X BYTECODE PATH B**.
Stops `parse_*.cyr` from emitting raw x86 instruction bytes
into the CYX bytecode stream. cc5 709,776 → **710,312 B**
(+536 B for the `_TARGET_CX` flag + 7 path-B guards). cc5_cx
output is now clean CYX bytecode — pre-v5.7.12 had
`4889 5df8 4c89 65f0 ...` (x86 callee-save chains) leaked
through from regalloc save/restore. Inventory: 67 raw
direct-emit hits in `parse_*.cyr` collapsed to ~10 logical
sites; 7 guarded with `_TARGET_CX == 0`, 3 already
arch-conditional. Path A (named-op refactor across 3
backends) **pinned long-term** in roadmap — trigger when
RISC-V or 2+ new direct-emit sites make path B unwieldy. cx
output `CYX\0` magic + valid CYX opcodes only, zero x86
bytes. New `tests/regression-cx-roundtrip.sh` (gate 4v)
verifies path B holds: greps cc5_cx output for known x86
instruction-byte signatures (`4889 5df8`, `4c8b 65f0`); fails
if any leak. **check.sh 33/33 PASS**, x86 fixpoint clean.
Two pre-existing limitations documented for follow-up: (a)
syscall arg literal-propagation bug — cc5_cx's EMOVI on
syscall args emits `movi r0, 0` instead of `movi r0, N` for
literal N (pin v5.7.x patch slot); (b) f64 ops on cx still
emit raw x87/SSE bytes (none in v5.7.12 acceptance gates,
pin if consumer surfaces). **v5.7.13 (string-literal escape
sequences `\x##` / `\u####` — cyim-unblocking) is now next;
RISC-V slid to v5.7.22-v5.7.26 to clear the bug/UX patch slate
first.**)

**5.7.11** (shipped 2026-04-27 — **`main_cx.cyr` DRIFT FIX +
CI GATE**. Smaller-slot scope per user 2026-04-27
("correctness over new features always"). v5.7.10's cross-arch
verify surfaced `error: undefined variable 'IR_RAW_EMIT'` on
the cyrius-x bytecode entry. Investigation showed accumulated
silent drift: 4 missing pieces, 2 dead colliding stubs, an
undersized brk. **No CI gate ever built cx**, so each frontend
addition silently broke it. Fixes: `include "src/common/ir.cyr"`
added (was added to main.cyr at v5.6.12, never propagated);
`var _AARCH64_BACKEND = 0` + `_TARGET_MACHO = 0` +
`_TARGET_PE = 0` + `_flags_reflect_rax = 0` + 4 peephole-
tracker globals (`_last_push_cp`, `_last_emovca_cp`,
`_last_movca_popr_cp`, `_INLINE_OK`, `_LOOPVAR_OK`) added to
`backend/cx/emit.cyr`; 2 dead `PF64BIN`/`PF64CMP` cx stubs
deleted (v5.7.9 duplicate-fn warning surfaced — collided with
parse_expr.cyr authoritative versions); brk bumped 5.5 MB →
39 MB to reach tok_types at `S+0x74A000`. **CI gate (the
durable fix):** `tests/regression-cx-build.sh` (gate 4u in
check.sh) runs 3 checks: cc5 builds main_cx.cyr cleanly, cc5_cx
exits clean on empty input, cc5_cx exits clean on trivial
input. cc5 unchanged at 709,776 B (cx-only edits); cc5_cx now
builds at 365,696 B. **check.sh 32/32 PASS**, x86 fixpoint
clean. **Bytecode SEMANTIC correctness explicitly cascaded to
v5.7.12** — parse_*.cyr emits raw x86 via `E3(S, 0xC18948)`-
style calls in shared codepaths; cx interpreter sees x86 noise
interleaved with valid CYX opcodes. Multi-session
parser-to-emit re-architecture work, not a wedge. RISC-V
cascaded v5.7.12 → v5.7.13.)

**5.7.10** (shipped 2026-04-26 — **`input_buf` 512 KB → 1 MB
HEAP-MAP RESHUFFLE** — load-bearing unblock; hisab was at 96 %
of cap and censoring upstream, every consumer of hisab via
`cyrius deps` auto-prepend inherited 505 KB before its own
source could land. cc5 unchanged at **709,776 B** (heap-only
change; instruction encoding bytes unaffected). Cap value
(524288 → 1048576) bumped at 3 sites/file × 6 main_*.cyr files
+ 1 PP IFDEF copy-back site in `lex_pp.cyr`. **Heap shift +
0x100000** on 95 distinct region addresses originally in
0x80000..0xFFFFF — they land in 0x180000..0x1FFFFF, clearing
the existing 6-digit squatters at 0x104000-0x14A000 (which had
to stay put). +0x100000 not +0x80000 because the +0x80000
naive shift would collide with 3 existing addresses
(0x10C000 / 0x11A000 / 0x122000); +0x100000 lifts cleanly into
the empty 0x180000..0x1FFFFF range. Bare-hex comment refs
shifted in the same sweep (96 occurrences); 4 boundary
comments over-shifted by the sweep (where 0x80000 was the
input_buf END, not a region address) hand-corrected back to
0x100000 (new input_buf end) or 0x80000 (tok_names overlay
end). **brk unchanged** at 0x348C000 (52.5 MB) — the +0x100000
shift packs into already-allocated heap; no `SYS_BRK` size
change. Error message `"input exceeds 512KB buffer..."` (68 B)
→ `"input exceeds 1MB buffer..."` (66 B); write length operand
updated. New regression `tests/regression-input-1mb.sh` (gate
4t in check.sh) compiles a 639 KB comment-padded source
through cc5; pre-v5.7.10 would have errored. **check.sh
31/31 PASS**, 3-step fixpoint clean, 5/5 main_*.cyr cross-arch
builds pass (x86 ELF, aarch64 ELF, aarch64-native,
aarch64-mach-o, Win64 PE). main_cx.cyr cyrius-x entry is
*pre-existingly broken* on `IR_RAW_EMIT undefined` (same shape
as v5.6.32 native-aarch64 missing-include); out of v5.7.10
scope, deserves its own slot. v5.7.11 RISC-V is now next.)

**5.7.9** (shipped 2026-04-26 — **SILENT FN-NAME COLLISION
INVESTIGATION**. cc5 709,688 → **709,776 B** (+88 B net —
warning emit code +312 B; dead `EADDIMM_X1` imm8-form removal
−224 B). Lifted from v5.7.10 → v5.7.9 same day when the
v5.7.10 input_buf reshuffle audit showed it deserves its own
slot. **Audit:** `docs/audit/2026-04-26-stdlib-fn-collisions.md`
— 66 names appear duplicated across `lib/*.cyr`, **only
`json_build` is genuine cross-module** (rest are arch-
conditional, one variant per build via `#ifdef`). **Resolution
rule:** option (b) warn + last-wins (arity-aware overload
resolution is a separate language addition, no slot pinned).
**cc5 change:** `parse_fn.cyr:601` checks `FINDFN` result; if
slot already has non-`-1` body offset, emit `warning:
<file>:<line>: duplicate fn '<name>' (last definition wins)`.
Forward decls (offset stays `-1` until body lands) do NOT
trigger. **Internal collision surfaced + fixed:** dead
imm8-form `EADDIMM_X1` deleted from `src/backend/x86/emit.cyr`
(imm32-form had been winning silently for unknown number of
versions; bytes unchanged at call sites because imm32 handles
all small values). **First ecosystem collision resolved at
source:** patra v1.8.3 → **v1.9.0** rename `fn json_build/6` →
`fn patra_json_build/6`; `cyrius.cyml` `[deps.patra]` pin
bumped 1.8.3 → 1.9.0. **Regression:** new
`tests/regression-fn-collision.sh` (3 cases: same-arity dup,
diff-arity dup, forward-decl no-false-positive) wired as
check.sh gate 4s; check.sh **30/30 PASS**. RISC-V rv64
remains at v5.7.11; v5.7.10 = `input_buf` 512KB → 1MB heap
reshuffle (load-bearing — hisab at 96% of cap) follows.)

**5.7.8** (shipped 2026-04-26 — **`cyrius check` REPAIR +
`cyrius deps` ERGONOMICS + SYSCALL ARITY WARNING FIX**. cc5
709,544 → **709,688 B** (+144 B). Bundle of silent-failure /
UX fixes surfaced during cyrius-bb wiring:
**(1)** `cyrius check`: `/dev/null.tmp.<pid>` open-fail bug
fixed by switching to PID-suffixed `/tmp` path; default-on
`--skip-deps` (parse standalone, not against manifest deps);
new `--with-deps` opt-in for legacy auto-prepend; "is a
module" tautology removed; `lex.cyr:95` token-cap message
length off-by-one (37 written as 36) fixed.
**(2)** Syscall arity: `_SC_ARITY(112)` SYS_SETSID 1 → 0
(closes `lib/syscalls_x86_64_linux.cyr:358` warning);
structural skip for `sc_num=2 && got=4` cross-arch openat
sentinel pattern (closes `lex.cyr:227+240+<source>:7`
warnings). cc5 self-build emits ZERO arity warnings.
**(3)** `cyrius deps` P1-P5: P1 silent dangling symlinks
now hard-error (`error: [deps.X] modules entry "..." not
found at tag in ...`); P2 `--help` branches added; P3
`deps`/`update` listed in top-level `cyrius help`; P4
`copied` counts distinct deps (one per `[deps.NAME]` block
that succeeded), not per-module operations — cold/warm
match; P5 `cyrius.lock` written by default after every
successful resolve, `--no-lock` opt-out; lockfile flag
family documented.
**(4)** `cyrius build --no-deps` flag added (closes the
v5.7.7 carry-forward pin). `_had_error` exit-code
infrastructure added but no error path writes to it yet
(deliberate: undefined-fn-with-call-site reverted because
tests rely on the historical "warn, don't abort, partial
includes are common in test files" semantics).
3-step fixpoint clean. check.sh 29/29.
RISC-V rv64 (was v5.7.8) cascaded → v5.7.11; v5.7.9 =
`input_buf` 512 KB → 1 MB; v5.7.10 = silent fn-name collision
investigation.)

**5.7.7** (shipped — fixup-cap 1MB+ + tool-issue bundle.
cc5 704,976 → **709,544 B**. Fixup table 262K → 1M; lint
UFCS Pascal-prefix exemption; `cyrius build` atomic-output.)

**5.7.6** (shipped — **CYRIUS-TS JSX INNER-EXPR TOKENIZATION
(P4.3d)**. Closes v5.7.5's empty `JSX_EXPR_CONTAINER` deferral.
Lex now tokenizes `{...}` JSX expression bodies via mode-stack
dispatch (modes 4=JSX_TAG, 5=JSX_TEXT, 8=JSX_EXPR on the
existing template stack); main TS_LEX loop dispatches to per-
mode helpers `TS_LEX_JSX_TAG` / `TS_LEX_JSX_TEXT`. Parser
consumes real expressions inside `JSX_EXPR_CONTAINER` /
`JSX_ATTRIBUTE` / `JSX_SPREAD_ATTR`. v5.7.3 post-`>` `(`
generic-arrow disambig REMOVED — the pre-flight `BYTE_SKIP`
check correctly rejects generic arrows while accepting
paren-prefixed JSX text (`<span>(optional)</span>`).
`TS_LOOKAHEAD_IS_ARROW` COLON-branch extended with JSX
scope-terminator tokens (was the root cause of the v5.7.5
P4.3d-2 attempt's 57-file regression that triggered rollback).
`IS_PRIMARY_CONTEXT` whitelist extended for JSX_CLOSE_END /
JSX_SELF_CLOSE / JSX_FRAGMENT_CLOSE. `.tsx`: 429 → **430/435 =
98.85%**. Threshold 429 → 430. `.ts`: held at
2033/2053 = 99.03%. cc5 697,840 → **704,976 B** (+7,136 B);
3-step self-host fixpoint clean.
`regression-ts-parse-tsx.sh` threshold 429 → 430.)
**5.7.5** (shipped — **CYRIUS-TS REAL JSX AST**. Closes the v5.7.0–
v5.7.5 cyrius-ts arc by replacing v5.7.3's `TOK_INT` placeholder
with structured JSX tokens + AST nodes. Lex emits 13 JSX token
kinds in block 300-312 (`OPEN_START`/`TAG_NAME`/`ATTR_NAME`/
`ATTR_VALUE_STRING`/`OPEN_END`/`CLOSE_START`/`CLOSE_END`/
`SELF_CLOSE`/`TEXT`/`EXPR_OPEN`/`EXPR_CLOSE`/`FRAGMENT_OPEN`/
`FRAGMENT_CLOSE`); parser builds 9 JSX AST kinds in block 700-708
(`JSX_ELEMENT`/`JSX_FRAGMENT`/`JSX_OPENING`/`JSX_CLOSING`/
`JSX_ATTRIBUTE`/`JSX_SPREAD_ATTR`/`JSX_EXPR_CONTAINER`/`JSX_TEXT`/
`JSX_NAME`) via `TS_PARSE_JSX_ELEMENT` invoked from `PRIMARY`.
`TS_LEX_JSX_SKIP` and `TS_LEX_JSX_SKIP_INNER` deleted (256 LOC).
New `TS_LEX_JSX_BYTE_SKIP` (catches generic types like
`Foo<HTMLParagraphElement>` mis-firing as JSX via stray-`}` bail);
`TS_LEX_JSX_SKIP_WS` extended to skip `//` + `/* */` comments
inside JSX tags. `.tsx` parse acceptance 428 → **429/435 = 98.6%**;
`.ts` held at 2033/2053 = 99.03%. cc5 687,088 B → **697,840 B**
(+10,752 B); 3-step self-host fixpoint clean. New tcyrs:
`ts_lex_p43.tcyr` (49 assertions, 12 groups) + `ts_parse_p43.tcyr`
(11 groups). `regression-ts-parse-tsx.sh` threshold 425 → 429.
check.sh 29/29. Inner-expr tokenization deferred to v5.7.6 — empty
`JSX_EXPR_CONTAINER` in this iteration; mode-stack-driven prototype
reverted at end of v5.7.5 work for clean cut. 6 sticky `.tsx`
failures remain (non-JSX TS feature gaps: generic method types,
`!:`, multi-arg generics, computed-key destructure, multi-line
JSX block comment, one cumulative shape) — each its own slot.)

**5.7.4** (shipped — **CYRIUS-TS CLEANUP PASS**. .ts parse acceptance
crossed 99% (2020 → **2033/2053 = 99.03%**). .tsx held at
**428/435 = 98.4%** (the 7 sticky JSX edges cascade to v5.7.5's real
JSX AST work). Async modifier now recorded as bit 48 of SPAN on
DECL_FUNCTION / EXPR_ARROW / DECL_METHOD nodes via the new
`TS_AST_CONSUME_ASYNC` / `TS_AST_IS_ASYNC` helpers + the
`TS_PS_PENDING_ASYNC` parser-state slot — wired into 9 AST_PUSH sites
+ 8 async-consume sites. P4.1: `typeof import("...")` composite type,
template-interp brace tracking fix (object literals inside `${...}`
now balance correctly; P1.4 test updated 7-tok → 8-tok), broader
PRIMARY ident-equivalent list (KW_OVERRIDE/DECLARE/NAMESPACE/READONLY
/INFER/SATISFIES/PUBLIC/PRIVATE/PROTECTED/STATIC/ABSTRACT/IMPLEMENTS
accepted as variable names). P4.5: `async <T>(x) => ...` generic
arrow now parses. New `tests/tcyr/ts_parse_p44.tcyr` (25 assertions).
Thresholds: `regression-ts-parse.sh` 2000 → 2030;
`regression-ts-parse-tsx.sh` 420 → 425. cc5 687,088 B (+3,280 from
v5.7.3); self-host byte-identical. check.sh 29/29.). .ts parse acceptance
crossed 99% (2020 → **2033/2053 = 99.03%**). .tsx held at
**428/435 = 98.4%** (the 7 sticky JSX edges cascade to v5.7.5's real
JSX AST work). Async modifier now recorded as bit 48 of SPAN on
DECL_FUNCTION / EXPR_ARROW / DECL_METHOD nodes via the new
`TS_AST_CONSUME_ASYNC` / `TS_AST_IS_ASYNC` helpers + the
`TS_PS_PENDING_ASYNC` parser-state slot — wired into 9 AST_PUSH sites
+ 8 async-consume sites. P4.1: `typeof import("...")` composite type,
template-interp brace tracking fix (object literals inside `${...}`
now balance correctly; P1.4 test updated 7-tok → 8-tok), broader
PRIMARY ident-equivalent list (KW_OVERRIDE/DECLARE/NAMESPACE/READONLY
/INFER/SATISFIES/PUBLIC/PRIVATE/PROTECTED/STATIC/ABSTRACT/IMPLEMENTS
accepted as variable names). P4.5: `async <T>(x) => ...` generic
arrow now parses. New `tests/tcyr/ts_parse_p44.tcyr` (25 assertions).
Thresholds: `regression-ts-parse.sh` 2000 → 2030;
`regression-ts-parse-tsx.sh` 420 → 425. cc5 687,088 B (+3,280 from
v5.7.3); self-host byte-identical. check.sh 29/29.)

**5.7.3** (shipped — **CYRIUS-TS COMPLETION + JSX**. Continues the
v5.7.2 cyrius-ts arc: 80% → **98.4%** SY .ts parse acceptance via
16 iterative fix batches against the diag harness, plus a new
JSX-aware lex skip that lifts SY .tsx parse acceptance from 0.5%
(2/435) to **98.2%** (427/435). check.sh active gates 28 → 29
(new `regression-ts-parse-tsx.sh`). P3.1: async object-method
modifier, nested-generic call consume, broadened param-name
acceptance, `import("./mod").T` types, `for await` loops,
generator `*` markers (function/method/object), `yield`/`yield*`
in UNARY, broadened binding-pattern names, computed property
names, array destructure holes, FLOAT lex (frac + exponent —
`1e-7` no longer lexes as 4 tokens), TYPE_OBJECT method sigs,
function-overload bodies optional, `declare global { ... }`,
`new () => T` constructor types, `value is T` predicates,
`override`/`declare` modifiers, import attributes
`with { type: 'json' }`. P3.3: `TS_LEX_JSX_SKIP` byte-level scanner
recognizes `<IDENT`/`<>` in expression context (via
`TS_IS_PRIMARY_CONTEXT` walk-back), walks balanced JSX tags +
fragments + `{...}` exprs (with template-literal awareness) +
nested JSX, emits one `TOK_INT` placeholder per JSX expression.
Generic-arrow disambiguation (`<T extends U>(args) => body`)
recognized as not-JSX via post-`>` `(` lookahead. cc5 683,808 B
(+17,600 from v5.7.2); self-host byte-identical. Remaining
~8 .tsx + ~33 .ts edge cases slated for v5.7.4 (final cyrius-ts
cleanup).)

**5.7.2** (shipped — **CYRIUS-TS FOUNDATIONAL**. TypeScript
frontend for the Cyrius compiler shipped as 7 phases (P1.1–P1.7
lex + P2.1–P2.7 parse). 462 lex assertions + 367 parse assertions
all green; 100% SY .ts lex acceptance; 1642/2053 (80%) SY .ts
parse acceptance via new `regression-ts-parse.sh` gate (≥ 1600
threshold). Iterative triage on the SY corpus delivered 196 → 1642
PASS through ~15 fix batches: trailing commas, broadened
keyword-as-name acceptance, async/import.meta/dynamic-import,
`as`/`satisfies` postfix, generic-call lookahead with
depth-aware nested paren/brace/bracket disambiguation, top-level
enum/namespace/declare decls, conditional types, `infer T`,
`value is T` predicates, abstract methods, computed member names,
object method shorthand, constructor parameter properties,
destructure rename + default. Children-array sentinel pattern
(children[0] = -1) lets payload-stored "0" unambiguously mean
"no list". Heap-relative offsets via `ts_base` decouple TS
frontend from main.cyr's heap layout. Diagnostic `--parse-ts`
emits `code=N line=L tok=T cur_idx=X err_idx=Y`. cc5 666,208 B
(+34,624 from v5.7.1); self-host byte-identical. check.sh 27 → 28
active gates. Remaining ~411 SY edge cases (mapped types,
`asserts` predicates, JSX in .tsx, complex destructure) slated
for v5.7.3.)

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

- **cc5 (x86_64)**: **704,976 B** (+7,136 B from v5.7.5's 697,840;
  +166,256 B vs v5.6.45's 531,584 — v5.7.5 added the structured
  JSX lex tokens, JSX AST nodes + parser, BYTE_SKIP for nested-JSX
  brace-balance, comment-aware tag whitespace skip; deleted 256 LOC
  of v5.7.3 SKIP placeholder).  `cc5 --version` reports `cc5 5.7.5`.
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

- **check.sh**: 29/29 PASS (Linux x86_64 daily-driver + cross-platform skip-stubs)
- **`tests/tcyr/*.tcyr`**: 69 files (v5.7.5 added `ts_lex_p43.tcyr` + `ts_parse_p43.tcyr`; v5.7.0 fold deleted `http_server.tcyr`)
- **`fuzz/*.fcyr`**: 5 harnesses
- **`benches/*.bcyr`**: 14 benchmarks
- **Stdlib**: 60 modules (53 first-party + 7 vendored/deps: 6 via `cyrius deps`
  symlinks — sakshi, patra, sigil, yukti, mabda, sankoch — plus
  `lib/sandhi.cyr` vendored from `cyrius distlib` at sandhi v1.0.0)

## In-flight

**v5.7.13 (string-literal escape sequences `\x##` / `\u####` /
full set) — cyim-unblocking.** v5.7.12 closed the cyrius-x
bytecode path-B work; user direction 2026-04-27 was to slide
RISC-V down and clear the bug/UX patch slate first. v5.7.13
grows the lex's escape-sequence set so cyim's TTY editor surface
stops emitting literal `\x1b[…` characters. Per the "compiler
grows to fit the language, never the other way around" rule
(`feedback_grow_compiler_to_fit_language.md`).

**v5.7.x slot map (firm as of 2026-04-27, hard upper bound v5.7.28):**

- **v5.7.13** — string-literal escape sequences (cyim-unblocking).
  **Budgeted 1-2 patches** (audit-first may split into v5.7.13
  `\x##` + audit, v5.7.14 `\u####`/`\u{…}` UTF-8). If splits,
  everything below cascades +1.
- **v5.7.14** — bundle: full project-setup workflow.
  `cyrius deps` transitive resolution (sit-blocking) + `cyrius
  init` library-vs-binary awareness (`--lib` / `--bin`) + `cyrius
  init` / `cyrius port` first-party-documentation alignment
  (ADR / architecture / guides / examples doc-tree + CLAUDE.md
  template). All three flow together: `cyrius init --lib foo` →
  resolve transitive deps → emit shape-aware doc-tree.
- **v5.7.15** — basic regex primitives (`lib/regex.cyr`,
  Thompson NFA, ~300-500 LOC). Unblocks cyim `--find`.
- **v5.7.16** — `lib/json.cyr` depth (stdlib baseline — nested
  objects, arrays, booleans, null, floats, escape handling,
  error reporting). RPC-grade scope owned by sandhi.
- **v5.7.17** — `cyrius fuzz` stdlib auto-prepend parity (solo;
  small refactor walking the same manifest-deps codepath as
  `cmd_test` / `cmd_bench`).
- **v5.7.18** — cx codegen literal-arg propagation
  (`syscall(60, 42)` emits `movi r0, 0` instead of literal).
- **v5.7.19-v5.7.21** — advanced TS features beyond SY corpus
  (**hard cap 3 slots**; overflow → v5.8.x).
- **v5.7.22-v5.7.26** — RISC-V rv64 (3-5 sub-patches).
- **v5.7.25/26/27** — `.scyr` + `.smcyr` file types (lands
  patch immediately after RISC-V wraps; floats with RISC-V
  actual sub-patch count).
- **v5.7.26/27/28** — v5.7.x closeout (CLAUDE.md 11-step).
  **Hard upper bound v5.7.28.**

**Side-task across v5.7.13–v5.7.18 closeouts**: warning sweep
(3 syscall-arity + 36 unreachable-fn floor + check.sh shell-syntax
warning + cbt/programs/bootstrap shellcheck pass). Cleared
opportunistically each closeout, no dedicated patch slot. Goal:
zero `warning:` lines from cc5 self-build by v5.7.22 (RISC-V
opens).

**v5.7.0 (sandhi fold) — cyrius side ✅ shipped.** Cyrius-side
acceptance gates 1, 2, 3, 5, 6 closed (CHANGELOG enumerates the
deleted/added symbol delta + downstream audit). Open work
(separate, user-organized):

- ⏳ Downstream consumer sweep — gate 4 of v5.7.0. Only **vidya**
  actually `include`s `lib/http_server.cyr` (in `src/main.cyr`).
  yantra and sit have orphan pre-fold copies of
  `lib/http_server.cyr` (regular files, not `cyrius deps`
  symlinks — likely manual copies from early sandhi M0 era) that
  need deletion for cleanliness. hoosh / ifran / daimon / mela /
  ark have no v5.7.0 work.
- ⏳ Vyakarana grammar refresh for sandhi syntax (469 fns now in
  stdlib).
- ⏳ Vidya per-minor refresh (language.toml / dependencies.toml /
  ecosystem.toml updates for the v5.7.0 stdlib reshape).

Sandhi repo enters maintenance mode per ADR 0002.

**Long-term considerations (no version pin)**: copy propagation +
cross-BB extended dead-store elimination — both recon-evaluated at
v5.6.18/v5.6.19-attempt, both bail (zero direct savings on stack-
machine IR; cross-BB versions need regalloc liveness data first).
Path A parser-to-emit named-op refactor pinned long-term post-
v5.7.12; trigger is RISC-V (4th backend) or 2+ new direct-emit
sites slipping past the gate. See `roadmap.md §Long-term
considerations` for full recon data + revisit criteria.

## Recent shipped (one-liner per release)

- **v5.7.6** — **CYRIUS-TS JSX INNER-EXPR TOKENIZATION (P4.3d)**.
  Closes v5.7.5's empty `JSX_EXPR_CONTAINER` deferral. Mode-stack-
  driven lex (modes 4=TAG, 5=TEXT, 8=EXPR on existing template stack)
  dispatched from main TS_LEX loop; `TS_LEX_JSX_TAG`/`TS_LEX_JSX_TEXT`
  helpers; parser consumes real exprs inside `JSX_EXPR_CONTAINER` /
  `JSX_ATTRIBUTE` / `JSX_SPREAD_ATTR`. v5.7.3 generic-arrow disambig
  REMOVED (false-positived on `<span>(optional)</span>`); pre-flight
  `BYTE_SKIP` handles both cases. `TS_LOOKAHEAD_IS_ARROW` COLON-branch
  extended with JSX scope terminators (was root cause of v5.7.5 P4.3d-2
  rollback). `.tsx` 429 → 430/435 (98.85%); threshold raised 429 → 430.
  cc5 697,840 → 704,976 B. Inner-expr tokenization shipped — empty
  JSX_EXPR_CONTAINER no longer needed.
- **v5.7.5** — **CYRIUS-TS REAL JSX AST**. v5.7.3's `TOK_INT` JSX
  placeholder replaced with 13 structured JSX token kinds (block
  300-312) + 9 JSX AST kinds (block 700-708) built by
  `TS_PARSE_JSX_ELEMENT` from PRIMARY. `TS_LEX_JSX_SKIP` +
  `TS_LEX_JSX_SKIP_INNER` deleted (256 LOC). New `BYTE_SKIP`
  bails on stray `}` to catch generic types
  (`Foo<HTMLParagraphElement>`) mis-firing as JSX. JSX tag
  whitespace skip extended to handle `//` + `/* */` comments
  between attrs (eslint-disable pragmas). `.tsx` 428 → 429/435
  (98.6%); `.ts` held at 2033/2053 (99.03%); threshold raised
  425 → 429. New tcyrs: ts_lex_p43 (49 assertions, 12 groups) +
  ts_parse_p43 (11 groups). cc5 687,088 → 697,840 B (+10,752 B).
  3-step fixpoint clean. Inner-expr tokenization deferred to
  v5.7.6 — empty `JSX_EXPR_CONTAINER` in this iteration; the
  mode-stack-driven prototype reverted at end of v5.7.5 work for
  clean cut. 6 sticky `.tsx` failures triaged as non-JSX TS
  feature gaps.
- **v5.7.4** — **CYRIUS-TS CLEANUP PASS**. `.ts` 99.03%, async
  modifier tracked as bit 48 of SPAN on DECL_FUNCTION/EXPR_ARROW/
  DECL_METHOD. P4.1 `typeof import()` types + template-interp
  brace fix + broader PRIMARY ident-equivalent list; P4.5
  `async <T>(x) =>` generic arrow. `tests/tcyr/ts_parse_p44.tcyr`
  added. Thresholds 2000→2030 / 420→425. cc5 +3,280 B.
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
