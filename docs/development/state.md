# Cyrius — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures (durable);
> this file is **state** (volatile). Bumped via `version-bump.sh` post-hook.

## Version

**5.7.34** (shipped 2026-04-28 — **AARCH64 CODEBUF CAP RAISE
(524288 → 3145728) — phylax-surfaced**. Closes the v5.7.27
ship omission. v5.7.27 grew the codebuf heap region 1 MB → 3 MB
on x86 (`src/backend/x86/emit.cyr:68`) and reshuffled 19
downstream regions to make room, but the matching cap on the
aarch64 backend's `EB()` emit-byte function in
`src/backend/aarch64/emit.cyr:99` was not bumped. Result: any
program that exceeded ~512 KB of emitted machine code on the
aarch64 cross-compiler aborted with `error: codebuf overflow
(.../524288)` while the same source built fine on x86. Phylax
surfaced this when a downstream cross-build of a phylax-shape
program tripped the old cap; the heap region itself had room
(3 MB allocated since v5.7.27), only the function-local cap
check still rejected. **Fix**: trivial constant bump 524288 →
3145728 in `EB()`, plus the matching `/3145728 bytes — program
too large for single compilation` error message (mirroring the
x86 wording so the message is identical from the user's POV).
Comment block flags this as the v5.7.27 follow-up so the next
"grow the codebuf" cycle audits BOTH backend EBs. **Pinned
method** for next codebuf-region grow:
`grep -rn "^\s*if (cp >= [0-9]" src/backend/` enumerates every
EB-class cap in one place before shipping the resize. cc5
self-host two-step byte-identical at **720,640 B** (no compiler
change for x86; aarch64 EB lives in a file `src/main.cyr` does
NOT include — only `src/main_aarch64.cyr` does). **check.sh
53/53 PASS** (was 52/52; +gate 4ap source-checks the cap
constant — fast, no binary build, catches accidental revert
either direction). **Bundled second issue NOT closed**: phylax-
agent surfaced duplicate-fn warnings (`aes_ni_available`,
`_aes_ni_cpuid_probe`, `aes256_encrypt_block_ni`) when building
sigil under cyrius's aarch64 include pipeline. Could not
reproduce locally with phylax/sigil at current pins; cyrius's
include-once table (`PP_ALREADY_INCLUDED` at S+0x1C0000) and
the v5.7.14 closest-wins BFS dedup both look correct on
inspection. Investigation moves to the agnosys side where the
phylax-agent can capture the actual include sequence triggering
the warning. May land at v5.7.35 or v5.7.36 if reproduced
before backstop.)

**5.7.33** (shipped 2026-04-28 — **`cyrius api-surface` —
SNAPSHOT-BASED PUBLIC API DIFF**. New toolchain-quality slot
from the `v5.x — Toolchain Quality` section. Pattern adapted
from `agnosys/scripts/check-api-surface.sh`; cyrius-native
pure-cyrius implementation per the sovereign-toolchain stance.
Catches breaking removals / signature changes before ship;
allows additions (non-breaking). **Why now**: without an
API-surface gate, downstream consumers (mabda / sandhi / sit
/ phylax) can break silently when stdlib renames or removes
a public fn. Agnosys ships a bash-based check; cyrius needed
its own. **Coverage**: top-level `fn NAME(args)` defs in
`src/` + `lib/`, underscore-prefixed names excluded by
convention. Out of scope: top-level vars (covered by
v5.7.32 cyrlint init-order rule), enum/struct types
(future slot if surfaced), local fns (not API surface).
**Implementation**: `programs/api_surface.cyr` (~450 lines)
walks both dirs, extracts public fns + arity, formats as
`module::name/arity`, insertion-sorts byte-wise (deterministic
regardless of host locale — agnosys hard-learned lesson),
diffs against `docs/api-surface.snapshot`. Two modes:
`cyrius api-surface` (diff vs snapshot, rc=1 on breakage)
and `cyrius api-surface --update` (regenerate snapshot).
Wired into cbt at `cbt/commands.cyr` (`cmd_api_surface`) +
`cbt/cyrius.cyr` (dispatch between `deny` and `audit`). Tool
binary added to `cyrius.cyml [release].bins` so install
snapshot ships it. Initial snapshot of cyrius's public API:
**2552 entries** spanning the full stdlib + bundled deps.
cc5 self-host two-step byte-identical at **720,640 B** (no
compiler change — cbt + new program only). New gate
`tests/regression-api-surface.sh` (4ao): three cases —
committed snapshot matches current (no drift), synthetic
extra `_TEST_REMOVED` entry → BREAKING rc=1, deleted entry →
non-breaking addition rc=0. **check.sh 52/52 PASS** (was
51/51; +gate 4ao). LSP semantic-tokens polish (other
toolchain-quality item) not bundled — separate slot when
claimed.)

**5.7.32** (shipped 2026-04-28 — **CYRLINT GLOBAL-INIT-ORDER
FORWARD-REF WARNING (mabda-surfaced)**. Closes silent
miscompile class that cost mabda 30+ minutes hardware-iter
misdiagnosis. **Promoted before RISC-V** at user direction
"rather be 'bug' free before RISCV work." Cyrlint-only patch;
zero compiler change; cc5 byte-identical at 720,640 B.
**What was broken**: cyrius initializes top-level
`var X = expr;` in source declaration order; if `expr`
references a constant declared LATER, the ref resolves to 0
(default zero-init) at the time X is evaluated. No warning,
no error. Mabda hit this in `_NATIVE_PERM_FULL =
AMDGPU_VM_PAGE_READABLE | _WRITEABLE | _EXECUTABLE` at line
117 with the AMDGPU_VM_PAGE_* constants at line 391+; result:
all BOs mapped with `perms=0`; every dispatch TDR'd at the
AMDGPU 10-second timeout looking like a wedged GPU.
**Fixed**: new rule `lint_globals_init_order` in
`programs/cyrlint.cyr` walks file twice. Pass 1 collects
every TOP-LEVEL `var IDENT = ...;` and records (name, line)
in parallel arrays (cap 256). Pass 2 walks every var
initializer, scans expr tokens for IDENT references, emits
warning if def_line > current_line. Mirrors mabda's option
(1) in the filing. Helpers added: `_is_id_start`,
`_is_id_cont`, `_find_eol`, `_find_var_decl_ident`,
`_scan_id_end`, `_eq_substr`. Scope deliberately narrow:
only var→var references (fns/enums/structs are forward-
ref-safe). Per `feedback_grow_compiler_to_fit_language.md`:
language behavior stays unchanged; lint surfaces the
foot-gun without breaking existing stdlib shapes that rely
on declaration order. **Verification**: new gate
`tests/regression-lint-global-init-order.sh` (4an): 3 test
cases — known-bad fixture (3 forward refs → ≥3 warnings),
lib/math.cyr (0 false-positives), lib/string.cyr (0
false-positives). All PASS. cc5 self-host two-step
byte-identical at **720,640 B** (no compiler change).
**check.sh 51/51 PASS** (was 50/50; +gate 4an). Out of
scope (future polish): IDENTs inside string literals (no
suppression yet — no observed false positives but
literal-aware scanner is a future polish).)

**5.7.31** (shipped 2026-04-28 — **AARCH64 f64_exp / f64_ln
POLYFILLS — phylax UNBLOCK**. Originally-named v5.7.30 ask;
split off when v5.7.30 premise verification surfaced the
broader basic-op miscompile (closed by v5.7.30). With v5.7.30's
basic ops working, polyfills are pure-cyrius implementations
in `lib/math.cyr` using FADD/FSUB/FMUL/FDIV/FRINTN/FCVTZS/SCVTF.
**Polyfills**: (1) `_f64_exp_polyfill(x)` — range-reduce
`x = n*ln(2) + r` with `|r| ≤ ln(2)/2`; 11-term Taylor for
`exp(r)`; `2^n` via integer-exponent bit-pack. (2)
`_f64_ln_polyfill(x)` — mantissa/exponent split via bit
masks; remap mantissa to `[√(1/2), √2)`; 8-term inverse-tanh
series `2u·(1 + u²/3 + u⁴/5 + … + u¹⁴/15)`. Both target
~few-ulp accuracy — sufficient for phylax-class statistical
work. **Helper added**: `_FINDFN_CSTR(S, str_ptr, str_len)`
in `parse_fn.cyr` for fn-by-c-string lookup (vs FINDFN's
noff-based lookup). Used by parser polyfill dispatch.
**Dispatch**: `parse_expr.cyr` aarch64 ERR_MSG paths for
`f64_exp` (ptyp 85) and `f64_ln` (ptyp 86) replaced with
fncall emission via `EPUSHR` + `ECALLPOPS(1)` + `ECALLFIX`
to the polyfill fnidx (resolved via `_FINDFN_CSTR`). If
polyfill isn't registered, clear error points at required
`include "lib/math.cyr"`. **Inverse-trig section** in
`lib/math.cyr` (`f64_asin`/`f64_acos`/`f64_atan2`) wrapped in
`#ifdef CYRIUS_ARCH_X86` — uses `f64_atan` builtin (x87
fpatan) with no aarch64 equivalent; not polyfilled in
v5.7.31 (phylax doesn't need it). cc5 self-host two-step
byte-identical at **720,640 B** (was 719,280 at v5.7.30;
+1,360 B for polyfill bodies + helper + dispatch). New gate
`tests/regression-aarch64-f64-polyfill.sh` (4am): cross-
builds smoke test on aarch64, scp's to `$SSH_TARGET`
(default `pi`), runs on real Pi 4 hardware, asserts
bit-accurate within ulp budget for 6 cases (`exp(0)=1.0`
exact, `exp(1)≈e`, `ln(1)=0`, `ln(e)≈1`, `exp(ln(2))≈2`
round-trip, `exp(-1)≈1/e`). All 6 PASS on Pi 4.
**check.sh 50/50 PASS** (was 49/49; +gate 4am).
**Trio v5.7.30 + v5.7.31** closes the v5.4.x-era silent f64
miscompile + the v5.7.0-era hard-reject in one coherent
split. Structural CI gates at both levels (4al basic ops, 4am
polyfill correctness) catch future drift before ship.
**phylax UNBLOCK** — chi-squared p-values + entropy paths
compile + run correctly on aarch64; the "green CI but broken
local aarch64" gap is closed; cc5_aarch64 bundles with
phylax produce a working aarch64 release. Out of scope
(future polyfill slots if surfaced):
`f64_sin/f64_cos/f64_log2/f64_exp2/f64_atan` — same shape,
none phylax-blocking.)

**5.7.30** (shipped 2026-04-28 — **AARCH64 f64 BASIC-OP
IMPLEMENTATION**. Closes a silent miscompile that affected
every aarch64 build using f64 ops. Pre-v5.7.30 every basic
f64 op on aarch64 was a stub (`return 0;` in
`src/backend/aarch64/emit.cyr`) — `f64_add(1.0, 2.0)` returned
2.0 (the second arg, because the parser left it in x0 and
EMIT_F64_BINOP emitted nothing), with stack leak from the
unpopped first arg. Probably broken since v5.4.x when aarch64
cross-build first shipped. Surfaced via phylax's f64_exp
hard-reject; original v5.7.30 ask was "f64_exp polyfill" but
premise verification (per `feedback_verify_slot_premise_first.md`)
turned up that the f64_exp hard-reject was masking
f64_add/sub/mul/div/sqrt/floor/ceil/round/neg + int↔f64 ALL
silently broken on aarch64. Per user direction "you can split
into the two logical pieces": v5.7.30 = basic-op
implementation, v5.7.31 = f64_exp/f64_ln polyfills using these
ops. **Fixed**: 7 stub fns replaced with single-instruction
emits (encodings verified via aarch64-linux-gnu-as) —
EMIT_F64_BINOP (FADD/FSUB/FMUL/FDIV depending on fop), EF64SQRT
(FSQRT), EF64FLOOR (FRINTM), EF64CEIL (FRINTP), EF64ROUND
(FRINTN — round-to-nearest, ties-to-even, IEEE 754 default),
EI2F (SCVTF), EF2I (FCVTZS). Plus `f64_neg` parser ERR_MSG
replaced with FNEG d0,d0 emit (parse_expr.cyr:1104). Each
op: 3 instructions (fmov-d-x bit-cast, op, fmov-x-d extract;
12 bytes total per op). x86-named EMOVQ_*/EUCOMISD/EXORPD_X1/
EMOVAPD_01/EX87PUSH/EX87POP stubs preserved — they're
parser-shared codepath helpers the aarch64 path doesn't need
(fmov ops inlined directly into EMIT_F64_BINOP). cc5
self-host two-step byte-identical at **719,280 B** (was
719,000 at v5.7.29; +280 B for emit code). New gate
`tests/regression-aarch64-f64.sh` (4al): cross-builds 11-case
f64 op smoke test, scp's to `$SSH_TARGET` (default `pi`),
runs on real Pi 4 hardware, asserts bit-exact expected
results against IEEE 754 reference values (each assertion
exits with unique code 1-11 on failure; success = 99).
**check.sh 49/49 PASS** (was 48/48; +gate 4al). Gate
verified: ALL 11 ops bit-exact on Pi 4. Phylax STILL
blocked at v5.7.30 (f64_exp/f64_ln still hard-reject;
v5.7.31 closes that with polyfills using these basic ops).
Out of scope: f64_sin/cos/log2/exp2 (not phylax-blocking;
future slot).)

**5.7.29** (shipped 2026-04-28 — **CX GATE `set -e` REPAIR +
check.sh HYGIENE**. Closes the v5.7.27 fallout chain. v5.7.28
fixed the COMPILER regression (cc5_cx restored); v5.7.29 fixes
the GATE-INFRASTRUCTURE so check.sh can correctly report it.
~50 lines, zero compiler change. **What was broken**: three
`regression-cx-{build,roundtrip,syscall-literal}.sh` gates had
`set -e + pipeline` interaction — cc5_cx returns exit 1 on
parse-error inputs (correct; emits diagnostic + exits non-zero)
but `set -e` aborted the gate before `EXIT=$?` capture, making
the "only flag SIGSEGV ≥128" gate logic unreachable. check.sh
itself had `set -e` at line 4 — when any gate returned
non-zero, the script aborted before `_result=$?` captured, so
the entire audit died at the first failing gate (~25 of 47+).
The verification idiom `sh check.sh 2>&1 | tail -3` returned 0
from `tail` (unset pipefail), masking the abort behind a "47/47
PASS"-shape line that was actually partial-output's last 3
lines. Every "47/47 PASS" report I logged across v5.7.24-v5.7.27
ship was false reassurance. **Fixed**: (1) three cx gates wrap
cc5_cx invocations in `set +e` / `set -e` toggles (matching the
existing pattern around cxvm calls). Plus repaired latent bug
in roundtrip Test 4: `cmd || true; EXIT=$?` was clobbering
EXIT to 0 (`$?` after `|| true` reflects `true`'s exit), making
SIGSEGV-detection unreachable. Replaced with proper capture
pattern. (2) check.sh `set -e` removed at line 4 with block
comment explaining why. The script uses explicit
`_result=$?` + `check "..." "$_result"` reporting throughout;
`set -e` was never load-bearing, just counterproductive. (3)
~25 lines of explanatory comments encode the v5.7.27-era ship
damage so future contributors don't re-add `set -e`.
**Verification**: `sh scripts/check.sh` rc=0, **48/48 PASS**
(was aborting at gate ~25/47 silently); with `pipefail` set,
still rc=0 — verification idiom no longer pipe-masked.
v5.7.28's parity gate (4ak) now reachable; pre-v5.7.29 the
cx-build gate failure aborted check.sh before 4ak ran. cc5
self-host two-step byte-identical at **719,000 B** (no
compiler change). All TS gates PASS, SY corpus unchanged. The
trio (v5.7.27 cap raise + v5.7.28 cx re-sync + v5.7.29 gate
hygiene) closes the v5.7.27 ship-damage chain entirely.)

**5.7.28** (shipped 2026-04-28 — **CX BACKEND TOKEN-OFFSET FIX
(v5.7.27 SHIP REGRESSION) + STRUCTURAL PARITY GATE**.
Mechanical 2-line shift in `src/backend/cx/emit.cyr` to track
v5.7.27's heap reshuffle, plus a new CI gate that catches
lex-write / backend-read offset drift at the source level.
**v5.7.27 silently regressed cc5_cx** — its heap reshuffle
shifted lex's token writes (`tok_types` 0x74A000 → 0x94A000;
`tok_values` 0xB4A000 → 0xD4A000) but the v5.7.27 shift loop
deliberately skipped `src/backend/cx/emit.cyr` (cx has its own
codebuf at 0x54A000 + per-fn at 0x150B000, both unchanged).
The skip OVER-applied — cx backend's `TOKTYP` / `TOKVAL`
definitions read the SAME shared frontend tokens at the SAME
offsets the main backends use. Post-v5.7.27 cx read tok_types
from inside the new codebuf region (garbage) and tok_values
from where tok_types now lives. cc5_cx returned exit 1 with
`error:2: unexpected unknown` on every input. Bug stayed
masked at v5.7.27 ship by (1) the queued v5.7.29 cx-gate
`set -e + pipeline` issue that aborts gates before failure
reporting and (2) the `sh check.sh 2>&1 | tail -3` pipe-mask
that hid check.sh's actual exit code. cc5_cx is byte-identical
when built with v5.7.26 vs v5.7.27 cc5 (both 371,848 B); both
fail today on all inputs. **At v5.7.26 ship cc5_cx worked**;
at v5.7.27 ship silently broken; at v5.7.28 ship restored.
Fix: 2 lines in cx/emit.cyr — TOKTYP 0x74A000 → 0x94A000,
TOKVAL 0xB4A000 → 0xD4A000. Verified end-to-end:
`echo 'syscall(60, V);' | cc5_cx | cxvm` exits with V across
V ∈ {0, 7, 42, 99, 200}. cc5 self-host two-step byte-
identical at **719,000 B** (size unchanged; the cx-emit
constant change doesn't affect cc5 output). New gate
`tests/regression-cx-token-offsets.sh` (4ak) — greps each
backend's `TOKTYP` / `TOKVAL` definitions and the shared lex's
write sites, extracts the hex offsets, asserts they all
agree. Catches drift at the source level in 0.1s with no
compiler build. Validated by deliberately reverting cx
TOKTYP back (gate FAILs with explicit drift message), then
restoring (gate PASSes). **Third instance in v5.7.x of
forked-helper offset drift**: v5.7.23 cx TOKVAL typo
(memory `feedback_audit_forked_helper_offsets.md`), v5.7.27
heap-shift skipped cx, v5.7.28 re-synced + structural gate.
The new gate directly addresses the audit pattern from the
v5.7.23 memory — check.sh now does the diff automatically.
**check.sh still v5.7.27-broken at the cx-build gate**
(`set -e` aborts before the new 4ak gate runs); v5.7.29
fixes the gate-infrastructure so check.sh can complete and
the parity gate actually reaches its check. v5.7.28 ships
the COMPILER fix; v5.7.29 ships the GATE-INFRA fix —
logically distinct per user direction at v5.7.28 start
"you can split into the two logical pieces.")

**5.7.27** (shipped 2026-04-28 — **CODEBUF CAP 1 MB → 3 MB +
19-REGION HEAP RESHUFFLE**. Mechanical cap raise to absorb
cyrius-ts test-compile pressure. User-pinned at v5.7.26 ship:
"might need code-buf to 3MB in the next release... but also
begs the question on test organization." `cyrius test
ts_parse_p52-54.tcyr` was hitting 94% of the 1 MB code-buf cap
(988-989 KB) across the v5.7.24-v5.7.26 advanced-TS trio.
v5.7.27 is the cap raise; the test-organization rework is
SEPARATE per user direction "no retiring my file set... they
would need to grow to be better that SHELLOUTS" (`tcyr` =
real in-process unit tests, shell gates = smoke; new feedback
memory `feedback_no_retire_tcyr_for_shell_gates.md` pinned).
**261 offset references shifted across 21 source files** —
every region from `output_buf` (was 0x74A000, now 0x94A000)
through `brk-with-ts-frontend` (was 0x348C000, now 0x368C000)
moved +0x200000. cx backend (`src/backend/cx/emit.cyr`) is
untouched — it uses its own layout (codebuf at 0x54A000,
per-fn at 0x150B000 inherited from the legacy retired-fixup
gap); main_cx.cyr's brk extension shifted with the rest.
**codebuf cap value 1048576 → 3145728** in 9 sites: main.cyr
+ main_win.cyr cap-warning blocks (3 each) + heap-map
comments, backend/x86/emit.cyr overflow check + error message,
main_aarch64* heap-map comments. aarch64 emit's internal
524288 cap left alone (separate scope; smaller cc5_aarch64
binary doesn't hit it). cc5 self-host two-step byte-identical
at **719,000 B** (size unchanged from v5.7.26 — heap reshuffle
doesn't change emitted code sequence; only data layout. cc5
bytes do differ from v5.7.26 starting at byte 3380 — string-
literal table shifted by the new cap-warning text). Heap-map
audit `sh tests/heapmap.sh` PASS (80 regions, 0 overlaps);
`cyrius test ts_parse_p54.tcyr` 20/20 PASS with code-buf at
**32%** (989528/3145728) — well below the 85% warning
threshold. TS gates all green (asserts / mapped / decorators);
SY corpus unchanged (2053/2053 .ts + 435/435 .tsx).
**Pre-existing bug surfaced (queued v5.7.28)**: cx regression
gates (`regression-cx-{build,roundtrip,syscall-literal}.sh`)
have a `set -e + pipeline` interaction — `cc5_cx` returns
exit 1 on parse-error inputs (correct) which under `set -e`
aborts the script before `EXIT=$?` capture. `check.sh` (also
`set -e`) then aborts at the cx-build gate, never reaching
the new TS gates or summary. **v5.7.24-v5.7.26 ship "47/47
PASS" reports were false reassurance** — `sh check.sh 2>&1
| tail -3` masked check.sh's exit code via the unset-pipefail
pipe. v5.7.26 cc5 reproduces identically (verified directly),
so the bug is at minimum v5.7.26-era; v5.7.27 didn't
introduce it. v5.7.28 fix is ~30 lines: `set +e` / `EXIT=0;
cmd || EXIT=$?` toggles in each cx gate + check.sh hygiene
pass.)

**5.7.26** (shipped 2026-04-28 — **CYRIUS-TS — TS 5.0 STAGE-3
DECORATORS**. Third and final of the v5.7.24-v5.7.26 TS-depth
patches (smallest → highest order: asserts predicate sigs at
v5.7.24, mapped types at v5.7.25, decorators here). Closes the
"advanced TS features beyond SY corpus" pin. Pre-v5.7.26 the
`@` token (`TS_TOK_AT = 35`) was unhandled at every valid
decorator position — class statements, class members, function
parameters — and parses rejected with `code=6 tok=35`
(unexpected statement-leading token) or `code=3 tok=35`
(unexpected token at expected position). The SY corpus didn't
surface this gap (no SY .ts file uses decorators), so parse
acceptance ran 100% without coverage. v5.7.26 adds:
(1) `TS_AST_DECORATOR = 315` AST kind allocated (parse-
acceptance only — AST attachment to following declaration is
a future polish slot for the typechecker phase, same pattern
as v5.7.24 asserts and v5.7.25 mapped types);
(2) `TS_PARSE_DECORATOR_LIST` helper — loops while
`peek == TS_TOK_AT`, consumes `@`, dispatches to existing
`TS_PARSE_CALL_MEMBER` for the expression. The call-member
parser already covers full TS 5.0 grammar: `@foo`, `@foo()`,
`@foo.bar`, `@foo.bar.baz<T>(args)`, `@(<expr>)`,
`@foo({obj})`. No new lex tokens; no new expression parser
primitives. (3) Wire-in at four sites: `TS_PARSE_STMT` (top —
`@foo class X {}`, `@foo abstract class Y {}`),
`TS_PARSE_CLASS_MEMBER` (top, before `SKIP_MODIFIERS` —
`class X { @foo method() {} @bar prop }`),
`TS_PARSE_ARROW_PARAMS` (per-iteration, before
`SKIP_MODIFIERS` — `class X { method(@foo x: T,
@bar.dec() y: U) {} }`), `TS_PARSE_EXPORT` (top + default
branch — `export @foo class X {}` and `export default @foo
class {}`). cc5 self-host two-step byte-identical at
**719,000 B** (was 718,200 B at v5.7.25; +800 B for the
helper + four wire-in sites + the AST kind). New gate
`tests/regression-ts-decorators.sh` (4aj, 5 shape categories):
class decl decorators (incl. multi-chain, qualified, factory
with object/array args, generic `@foo<T>()`, abstract class);
class member decorators (incl. method, property, factory +
modifier, multi-decorator async, get/set accessors); parameter
decorators (incl. multi-param mixed, decorator + ctor-prop
modifier); export/export-default decorators; pre-v5.7.26
regression forms. New tcyr `tests/tcyr/ts_parse_p54.tcyr` —
**20 byte-level assertions** in 5 groups, mirroring the gate.
SY corpus regressions unchanged: `regression-ts-parse.sh`
2053/2053, `regression-ts-parse-tsx.sh` 435/435,
`regression-ts-asserts.sh` PASS, `regression-ts-mapped.sh`
PASS. **check.sh 47/47 PASS** (was 46/46; +gate 4aj).
**Side-task pin (cap-raise + test organization, user-direction
2026-04-28)**: `cyrius test ts_parse_p54.tcyr` reports
`code buffer at 94% (989528/1048576 bytes)` —
basically unchanged from v5.7.25's 988456 B (+1,072 B for
decorator helper + enum slot). User-pinned for v5.7.27:
"might need code-buf to 3MB in the next release... but also
begs the question on test organization." Bundle the
1 MB → 3 MB cap raise with TS test-organization rework.
Not blocking v5.7.26.)

**5.7.25** (shipped 2026-04-28 — **CYRIUS-TS — MAPPED TYPES +
`as`-CLAUSE + `+/-` MODIFIERS (TS 2.1 / 2.8 / 4.5)**. Second of
the v5.7.24-v5.7.26 TS-depth patches (smallest → highest:
asserts predicate sigs at v5.7.24, mapped types here, decorators
at v5.7.26). Pre-v5.7.25 the parser handled `[k: K]: V` index
signatures inside object types but treated the entire mapped-
type construct (`[K in T]: V`) as a syntax error — `KW_IN` was
unexpected after the bracket-key IDENT consume. The SY corpus
didn't surface this gap (no SY .ts file uses mapped types in
real code), so parse acceptance ran 100% without coverage.
v5.7.25 adds: (1) `TS_AST_TYPE_MAPPED = 314` AST kind (payload
`[0]` iter type, `[1]` remap type or 0, `[2]` value type);
(2) mapped-type fork in `TS_PARSE_TYPE_OBJECT` dispatched by
`peek == LBRACKET && peek_ahead(1) is name-like &&
peek_ahead(2) == KW_IN` — index sigs (`peek_ahead(2) == COLON`)
fall through unchanged; (3) full body parse `[K in <iter>]`
plus optional `as <remap>` (TS 4.5+ key remapping; reuses
existing `KW_AS = 137` keyword), optional `?` / `+?` / `-?`
modifier, `:`, value type; (4) `+/-readonly` modifier prefix
in the member-start consume block (TS 2.8+ explicit add/remove)
alongside the bare `readonly` already shipped — detection:
`peek == PLUS|MINUS && peek_ahead(1) == KW_READONLY`. cc5
self-host two-step byte-identical at **718,200 B** (was
716,728 B at v5.7.24; +1,472 B for the AST slot + TYPE_OBJECT
fork + `+/-readonly` modifier extension). New gate
`tests/regression-ts-mapped.sh` (4ai, 7 shape categories):
bare mapped, `as`-clause remap (incl. template literal +
conditional types), `readonly`/`+readonly`/`-readonly`, bare
`?` / `+?` / `-?`, combined (full `-readonly + as + -?`),
pre-v5.7.25 index-sig regression, readonly property
regression. New tcyr `tests/tcyr/ts_parse_p53.tcyr` —
**17 byte-level assertions** in 6 groups, mirroring the gate.
SY corpus regressions unchanged: `regression-ts-parse.sh`
2053/2053, `regression-ts-parse-tsx.sh` 435/435,
`regression-ts-asserts.sh` PASS. **check.sh 46/46 PASS** (was
45/45; +gate 4ai). **Side-task pin (cap-raise candidate)**:
`cyrius test` on `ts_parse_p53.tcyr` reports `code buffer at
94% (988456/1048576 bytes)` — TS frontend test compiles
approach the 1 MB code-buf cap; queue a heap-map reshuffle
slot in v5.7.31-v5.7.33 range or bundle with v5.7.26
decorators (which broaden the parser further). Not blocking.)

**5.7.24** (shipped 2026-04-28 — **CYRIUS-TS — `asserts`
PREDICATE SIGNATURES (TS 3.7+)**. First of three v5.7.x
patches working through TS features beyond the SY corpus
(smallest first per direction; mapped types `as`-clause v5.7.25,
decorators v5.7.26). Pre-v5.7.24 the parser had a comment-only
stub at `TS_PARSE_TYPE` that *intended* to tolerate `asserts
<id> [is <T>]` in return-type position; the implementation only
handled the `<lhs> is <T>` suffix and misparsed any input
starting with `asserts` (consumed `asserts` as the type-ref,
then `<id> is <T>` ate the subject, leaving the actual T
unconsumed). v5.7.24 adds (1) `TS_TOK_KW_ASSERTS = 219`
contextual keyword in `src/frontend/ts/lex.cyr` len-7 block
alongside `declare`; (2) real prefix consumer in
`TS_PARSE_TYPE` — when `peek == KW_ASSERTS && ahead is
name-like (IDENT / KW / KW_THIS)`, consume `asserts` and let
the existing `<lhs> is <T>` predicate suffix logic handle the
rest; (3) polymorphic `this`-type branch in
`TS_PARSE_TYPE_PRIMARY` emitting `TYPE_REF` — needed for
`asserts this is C` method predicates and class-builder
return-type `this` patterns (incidental coverage:
`interface Builder { build(): this }`,
`class B { chain(): this {...} }`,
`class P { is(): this is P {...} }`); (4) `KW_ASSERTS` added to
expr-PRIMARY ident-eligible OR-chain (alongside `KW_SATISFIES` /
`KW_INFER`) and `TYPE_PRIMARY` type-ref OR-chain (alongside
`KW_FROM` / `KW_AS` / `KW_TYPE`) so `var asserts = 1;`,
`let x: asserts;`, `type T = asserts;`, `obj.asserts`,
`{ asserts: 42 }` all stay green — same pattern as `satisfies`
shipped in v5.7.4. cc5 self-host two-step byte-identical at
**716,728 B** (was 716,080 B at v5.7.23; +648 B for the new
branches and token). New gate
`tests/regression-ts-asserts.sh` (4ah, 6 shape categories):
typed predicate `asserts <id> is <T>` (incl. unions and
generic params), bare `asserts <id>`, method `asserts this is
<T>`, polymorphic `this`-type, `asserts` ident-eligibility
(var / type-ref / type alias / property / member access),
pre-v5.7.24 regression `<id> is <T>` predicate. New tcyr
`tests/tcyr/ts_parse_p52.tcyr` — **15 byte-level assertions**
in 6 groups, mirroring the gate. SY corpus regressions
unchanged: `regression-ts-parse.sh` 2053/2053, `regression-
ts-parse-tsx.sh` 435/435, `regression-ts-lex.sh` PASS.
**check.sh 45/45 PASS** (was 44/44; +gate 4ah). Out of
v5.7.24 scope (same behavior as `satisfies` today, future
patches if surfaced): `function asserts() {}` and
`class asserts {}` — pre-existing parser limitation that
contextual keywords aren't accepted as fn/class declaration
names; `function satisfies() {}` rejects identically.)

**5.7.23** (shipped 2026-04-27 — **CX CODEGEN — LITERAL ARG
PROPAGATION**. Single-character typo fix in
`src/backend/cx/emit.cyr:443` — `TOKVAL` helper read tokens
from `S + 0x94A000 + i*8` (a zero-initialized gap region
between `tok_types` and `tok_values`) instead of the canonical
`S + 0xB4A000 + i*8` write site in `src/frontend/lex.cyr:99`.
PEEKV always returned 0 in cc5_cx, so any user-supplied literal
arg in `syscall(N, V)` (and any other typ==1 NUM token) emitted
`MOVI r0, 0` regardless of the source value. The implicit-exit
syscall's `60` propagated correctly because main_cx synthesizes
that token via a hard-coded path, not via lex. Fix: 0x94A000 →
0xB4A000. Closes the issue pinned in v5.7.12's
`regression-cx-roundtrip.sh` "What this gate does NOT check"
note. cc5 self-host two-step byte-identical at **716,080 B**
(cx-backend-only edit; main x86 cc5 unchanged). New gate
`tests/regression-cx-syscall-literal.sh` (4ag, 7 sub-checks):
bytecode for `syscall(60, 42);` contains `MOVI r0, 60`
(`01 00 3c 00`) and `MOVI r0, 42` (`01 00 2a 00`); no spurious
"syscall arity mismatch" on stderr; cxvm round-trip exits 42;
literals 0/7/99/200 each exit with their own code (catches
hypothetical TOKVAL-reads-a-constant regression). **check.sh
44/44 PASS** (was 43/43; +gate 4ag). Pattern caught:
forked-helper drift — when a backend module forks shared
frontend helpers, every offset literal is a typo candidate.
Audit pattern: `grep -rn "0x[0-9A-F]\{6\}A000" src/backend/`
and diff each region's reads/writes against canonical write
sites in `src/frontend/lex.cyr`.)

**5.7.22** (shipped 2026-04-27 — **HYGIENE PASS** — three
bundled tooling fixes. (1) `programs/cyrfmt.cyr` no longer
tracks `{`/`}` inside `#` comments or `"..."` string literals
— closes agnos
[2026-04-27-cyrius-fmt-tracks-braces-in-comments](https://github.com/MacCracken/agnos/blob/main/docs/development/issue/2026-04-27-cyrius-fmt-tracks-braces-in-comments.md)
issue. (2) `scripts/install.sh --refresh-only` now re-links
`~/.cyrius/bin` → `versions/$VERSION/bin` after refreshing
the snapshot — closes the H3 local-dev footgun where
`version-bump.sh` left the PATH-resolved cyrius binary
pointing at a stale version. (3) `scripts/cyriusly`'s
`link_version` uses `rm -rf` instead of `rm -f` so a
stale-directory state at `~/.cyrius/bin` (from older
copy-based installs) gets cleaned out. Bonus: seven stdlib
files (`bench.cyr`, `cyml.cyr`, `dynlib.cyr`, `flags.cyr`,
`hashmap.cyr`, `json.cyr`, `net.cyr`) were re-formatted with
the fixed cyrfmt — semantically a no-op (cyrius lex strips
leading whitespace) but the source matches the formatter
output again. cc5 self-host two-step byte-identical at
**716,080 B** (programs/scripts edits only; compiler
unchanged). New gates: `tests/regression-cyrfmt-comment-braces.sh`
(gate 4ae, 4 cases — agnos repro + string-literal-with-
braces + ordinary code + mixed) and
`tests/regression-install-shim-symlink.sh` (gate 4af —
isolated CYRIUS_HOME, fake old-version snapshot, runs
--refresh-only, asserts symlink re-pointed). **check.sh
43/43 PASS** (was 41/41; +2 gates).)

**5.7.21** (shipped 2026-04-27 — **`cyrius fuzz` MANIFEST-DEPS
AUTO-PREPEND PARITY**. One-line cmd-gate fix in
`cbt/cyrius.cyr`: added `streq(cmd, "fuzz") == 1` to the
`_auto_deps` whitelist that previously contained only
`build / run / test / bench / check`. Pre-v5.7.21 fuzz
harnesses had to hand-include every stdlib module they
used (sibling `.tcyr` / `.bcyr` got auto-prepend from day
one). cmd_fuzz was already calling `compile()` which reads
`_dep_includes`; the gate just wasn't populating it for the
fuzz path. cc5 self-host two-step byte-identical at
**716,080 B** (cbt-only edit; compiler unchanged). New gate
`tests/regression-fuzz-deps-prepend.sh` (gate 4ad): 2 cases
— manifest-with-stdlib (`fuzz/X.fcyr` references `strlen`,
auto-prepend resolves) and no-manifest (self-contained
`.fcyr` still runs cleanly). **check.sh 41/41 PASS** (was
40/40; +gate 4ad). Side-task progress: warning sweep —
manifest-listed stdlib fns referenced from fuzz harnesses
no longer trigger `undefined function` warnings.)

**5.7.20** (shipped 2026-04-27 — **`lib/json.cyr` DEPTH**.
Stdlib baseline JSON engine; RPC-grade scope still owned by
sandhi (`lib/sandhi.cyr`). New `json_v_*` API (~700 LOC of
engine) alongside the existing flat key-value API at the top
of `lib/json.cyr`. Tagged 24-byte heap value with 7 tags
(NULL / BOOL / INT / FLOAT / STR / ARR / OBJ). Recursive-
descent parser handles all 6 value types, arbitrary nesting,
full JSON string escape decoding (`\"` `\\` `\/` `\b` `\f`
`\n` `\r` `\t` `\uXXXX` including surrogate-pair handling
for 4-byte UTF-8), numbers (INT if no `.` `e` `E`; else
FLOAT via custom f64 parser using cyrius's f64 builtins).
Error reporting via `json_last_error` / `json_last_error_pos`.
Compact serializer `json_v_build` re-escapes strings per
JSON spec. Backward compat preserved: `json_parse`,
`json_get`, `json_get_int`, `json_pair_new`, `json_key`,
`json_value`, `json_build`, `json_parse_file` untouched —
existing kybernet (boot-config), argonaut (test_serde),
libro (canonical-json-hash) callers stay green. New gate
`tests/tcyr/json_engine.tcyr`: **71 byte-level assertions**
in 11 groups including primitives, escapes (with surrogate
pair `😀`), arrays, objects (order preserved + missing-key
returns 0), 3-level nesting, floats (decimal + scientific),
build round-trip, error positions, type coercion, flat-API
regression. cc5 self-host two-step byte-identical at
**716,080 B** (lib-only addition). **check.sh 39/39 PASS**
(tcyr 109 → 110; gate count unchanged because tcyr files are
auto-discovered). Two cleanups during build: decorative
box-drawing unicode (`# ── X ──`) tripped `cyrius lint` 120-
byte threshold (U+2500 is 3 bytes UTF-8) — switched to ASCII
separators (`# === X ===`); long `if (...&& load8 == X &&
load8 == Y...)` keyword-parse chains for true/false/null
shortened with `memeq`. Out of scope (deferred): pretty-
printing, streaming parser, JSON Pointer.)

**5.7.19** (shipped 2026-04-27 — **KERNEL-MODE EMIT ORDER FIX**.
Under `kernel;` (kmode == 1), top-level asm (the multiboot
32→64 long-mode boot shim) now emits BEFORE 64-bit gvar-init
code in `src/main.cyr`. Restores the cc3-era ordering
invariant — every agnos kernel release relied on it;
silently dropped at cyrius v5.0.0 (cc4→cc5 IR overhaul).
Path A1 from the [agnos boot-shim regression proposal](https://github.com/MacCracken/agnos/blob/main/docs/development/proposals/2026-04-27-cc5-kernel-boot-shim-regression.md):
agnos 1.23.0 (on cyrius 5.7.12) compiled clean + passed all
in-tree tests but did not boot — multiboot1 hands control in
32-bit protected mode, but cc5 emitted `mov rcx, imm64; mov
[rcx], rax` (REX.W; 64-bit) gvar inits BEFORE the boot shim,
so the CPU triple-faulted on the very first instruction.
Implementation: kmode-conditional split of `EMIT_GVAR_INITS`
and `PARSE_PROG` calls in `src/main.cyr` ~line 982. Non-kmode
path unchanged (executable / object / shared modes still
emit gvar inits before main parse). The undefined-fn warning
loop sits between the two branches, so non-kmode order stays
exactly `EMIT_GVAR_INITS → STI → warnings → PARSE_PROG`.
cc5 self-host two-step byte-identical at **716,080 B** (was
715,920 B; +160 B for the kmode branch). New gate
`tests/regression-kmode-emit-order.sh` (gate 4ab): compiles
a minimal kernel; source with a 4-byte top-level asm marker
(4× HLT) and a single gvar init; asserts the `f4 f4 f4 f4`
marker file offset is LESS than the first `48 b9` (REX.W mov
rcx, imm64) gvar-init signature. **check.sh 39/39 PASS** (was
38/38; +gate 4ab). Reviewing the proposal at v5.7.18 ship
confirmed kmode IS the agnos team's request — v5.7.20
placeholder reclaimed; net cascade since v5.7.18 is +0.
Out of scope: Path A2 (skip `EMIT_GVAR_INITS` entirely under
kmode and emit constants into `.data`) — cleaner long-term
but bigger change; future patch if a kmode consumer earns it.
Downstream: agnos 1.24.0 bumps `cyrius.cyml` toolchain pin
to v5.7.19, removes `continue-on-error: true` from the QEMU
Boot Test job, asserts boot output via `grep -q "AGNOS
kernel v"`.)

**5.7.18** (shipped 2026-04-27 — **FULL REGEX ENGINE** —
Thompson NFA + Pike's matcher in `lib/regex.cyr`. Linear-time
matching, no backtracking. Supports literals + escapes + `.`
+ anchors `^` `$` + character classes (`[abc]` `[^abc]`
`[a-z]`) + predefined classes (`\d \D \w \W \s \S`) +
quantifiers (`* + ? {n} {n,} {n,m}` greedy AND lazy) +
alternation `|` + grouping `(...)` capturing + `(?:...)`
non-capturing + word boundaries `\b \B`. API: `regex_compile`,
`regex_match` (anchored), `regex_search` (find-first),
`regex_search_at`, `regex_group_start`, `regex_group_end`.
~830 LOC engine on top of the existing glob/find_all/
str_replace helpers (backward-compat preserved; existing
`tests/tcyr/regex.tcyr` still green). New gate
`tests/tcyr/regex_engine.tcyr` — **89 byte-level assertions**
in 13 groups: literals, anchors, classes, predefined,
quantifiers (greedy + lazy + brace), alternation (incl.
3-way), grouping, captures, boundaries, common patterns.
Two engine bugs caught + fixed: gen-counter timing
(bumped after step instead of before, blocked first-step
loop adds), and half-open shift target bound (3-way alt's
JMP-to-end-of-fragment missed by `[lo, hi)` bound). cc5
unchanged at **715,920 B** (lib-only addition; compiler
untouched). **check.sh 38/38 PASS** (tcyr 108 → 109; gate
count unchanged). Out of scope (deferred): backreferences,
lookaround, Unicode property classes, multiline flag.
v5.7.19 = kernel-mode emit-order fix
(THE agnos team request — proposal confirmed kmode swap is
the entire ask; reclaimed v5.7.20 placeholder). +1 cascade
absorbed by v5.7.34 backstop (was v5.7.33; bumped at v5.7.20 ship to queue lib/json.cyr follow-ups — pretty-print, streaming, JSON Pointer — pinned in the v5.7.x patch slate).)

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

**v5.7.x slot map (firm as of 2026-04-28, hard upper bound v5.7.37):**

Shipped:
- **v5.7.13** ✅ string-literal escapes (cyim-unblocking)
- **v5.7.14** ✅ `cyrius deps` transitive resolution (BFS walker)
- **v5.7.15** ✅ `cyrius init --lib`/`--bin` library scaffold
- **v5.7.16** ✅ `cyrius init`/`cyrius port` first-party-doc tree
- **v5.7.17** ✅ struct cap 64→256 + dump-on-overflow (kybernet)
- **v5.7.18** ✅ regex engine (Thompson NFA + Pike matcher)
- **v5.7.19** ✅ kernel-mode emit-order fix (agnos boot-shim)
- **v5.7.20** ✅ `lib/json.cyr` depth — tagged-value tree
- **v5.7.21** ✅ `cyrius fuzz` manifest-deps auto-prepend parity
- **v5.7.22** ✅ hygiene pass — cyrfmt comment-brace + install-shim re-link + cyriusly rm-rf
- **v5.7.23** ✅ cx codegen literal-arg propagation (TOKVAL offset typo)
- **v5.7.24** ✅ TS `asserts` predicate signatures (KW_ASSERTS + prefix consumer + this-type)
- **v5.7.25** ✅ TS mapped types + `as`-clause + `+/-readonly` / `+/-?` modifiers (TYPE_MAPPED AST kind + TYPE_OBJECT fork)
- **v5.7.26** ✅ TS 5.0 stage-3 decorators (TS_AST_DECORATOR + DECORATOR_LIST helper + 4 wire-in sites — closes the v5.7.24-v5.7.26 advanced-TS trio)
- **v5.7.27** ✅ codebuf cap 1 MB → 3 MB + 19-region heap reshuffle (261 offset refs shifted across 21 files; cx backend untouched — turned out to be wrong, see v5.7.28)
- **v5.7.28** ✅ cx backend TOKTYP/TOKVAL offset re-sync + structural parity gate (closes the v5.7.27 ship regression where cc5_cx silently broke)
- **v5.7.29** ✅ cx gate `set -e` repair + check.sh hygiene (closes the v5.7.27 fallout chain — check.sh now runs through to 48/48 PASS)
- **v5.7.30** ✅ aarch64 f64 basic-op implementation (FADD/FSUB/FMUL/FDIV/FSQRT/FNEG/FRINT*/FCVTZS/SCVTF — closes silent miscompile that probably dated to v5.4.x)
- **v5.7.31** ✅ aarch64 f64_exp / f64_ln polyfills (closes phylax-block — chi-squared + entropy paths now correct on aarch64)
- **v5.7.32** ✅ cyrlint global-init-order forward-ref warning (closes mabda surfacing — the silent miscompile class)
- **v5.7.33** ✅ cyrius api-surface tooling (snapshot-based public API diff; cyrius-native pure-cyrius impl; 2552-entry initial snapshot)
- **v5.7.34** ✅ aarch64 codebuf cap raise 524288→3145728 (closes the v5.7.27 ship omission — phylax-surfaced; trivial constant bump in `src/backend/aarch64/emit.cyr` `EB()`; bundled dup-fn investigation moved to agnosys side where phylax-agent has the repro context)

Queue:
- **v5.7.35–v5.7.36** — open slots reserved for emergent items.
  RISC-V was originally pinned here but **moved to v5.7.x at
  v5.7.32 ship** per user direction (pairs naturally with the
  v5.8.0 bare-metal scope — both are "no libc / new ABI" arch-
  port work). Candidates if surfaced:
  - lib/json.cyr depth (pretty-print / streaming / JSON Pointer)
  - `.scyr` (soak) + `.smcyr` (smoke) file types
  - TS test organization rework (per-tcyr frontend coupling)
  - warning-sweep side-task floor
  - any consumer-surfaced wildcard correctness items
- **v5.7.37** — **TRUE CLOSEOUT BACKSTOP** (CLAUDE.md 11-step).
  Hard upper bound; anything past forces v5.8.x.

Moved out of v5.7.x:
- **RISC-V rv64** → v5.8.x (paired with bare-metal AGNOS kernel).

**Side-task across v5.7.13–v5.7.26 closeouts**: warning sweep
(3 syscall-arity + 36 unreachable-fn floor + check.sh shell-syntax
warning + cbt/programs/bootstrap shellcheck pass). Cleared
opportunistically each closeout, no dedicated patch slot. Goal:
zero `warning:` lines from cc5 self-build by v5.7.28 (RISC-V
opens after the cap-raise/test-org slot at v5.7.27).

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
