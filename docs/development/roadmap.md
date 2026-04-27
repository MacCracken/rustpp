# Cyrius Development Roadmap

> **v5.7.12** (shipped 2026-04-27). cc5 710,312 B x86_64. Native aarch64
> cc5 503,328 B (Pi 4). x86_64 + aarch64 cross + Windows PE cross +
> macOS aarch64 cross + cyrius-x bytecode. IR + CFG. Volatile state
> (current cc5 size, in-flight slots, recent shipped releases,
> bootstrap chain) lives in
> [`docs/development/state.md`](state.md); historical narrative for
> shipped work lives in [completed-phases.md](completed-phases.md);
> [CHANGELOG.md](../../CHANGELOG.md) is the source of truth.
>
> **Narrow-scope byte-identity** (3-step fixpoint
> `cc5_a → cc5_b → cc5_c; b == c`) holds on every target — load-
> bearing invariant, check.sh verifies on every commit. **Broad-
> scope self-host** (target binary runs + reproduces itself on
> native hw) holds on Linux x86_64 + Linux aarch64 cross-built-
> runs-on-Pi. Broken on Linux aarch64 native-self-host-on-Pi
> (pinned v5.6.32, ✅ shipped), macOS arm64 Mach-O (pinned
> v5.6.33 — platform drift, bytes unchanged since v5.5.13, ✅
> shipped), Windows 11 24H2 PE (pinned v5.6.34 — platform drift,
> bytes unchanged since v5.5.10, ✅ shipped). See
> `docs/architecture/cyrius.md` §"Self-hosting: two scopes of
> byte-identity" for the full definition.
>
> **v5.6.x (closed, 46 patches)** — Polish + Optimization Arc + Bug
> Fixes. Phase O1–O6 optimizer (cc5 526 KB → 487 KB, self-host time
> 405 → 355 ms), default-on regalloc, NOP-harvest compaction,
> sandhi-blocking codegen + ABI fixes, cross-platform tooling
> drift repairs. Per-patch summaries in
> [completed-phases.md § v5.6.0–v5.6.45](completed-phases.md#v560v5645--polish--optimization-arc--bug-fixes-closed).
>
> **v5.5.x (closed, 40 patches)** — longest minor in cyrius history.
> Platform completion (Windows PE end-to-end, Apple Silicon, aarch64
> Linux shakedown), NSS/PAM, fdlopen, parser/lexer refactor, cc3
> retirement.
>
> **v5.7.x (active)** — Sandhi fold + cyrius-ts frontend + tooling
> polish + cyim-unblocking + bug/UX patch slate + RISC-V port +
> closeout. Shipped to v5.7.12; one-liners in
> [completed-phases.md § v5.7.0–v5.7.12](completed-phases.md#v570v5712--sandhi-fold--cyrius-ts-frontend--tooling-polish).
> RISC-V slid to v5.7.23-v5.7.26 to clear the bug/UX patch slate
> first (2026-04-27 user direction: "correctness over new features
> always"). **Hard upper bound: v5.7.28 = v5.7.x closeout.**
>
> **What's next (v5.7.13–v5.12.x):**
> - **v5.7.13**: string-literal escape sequences (`\x##`, `\u####`,
>   full set) — cyim-unblocking. **Budgeted 1-2 patches**: audit-
>   first may split into v5.7.13 (audit + `\x##` + `\a/\b/\f/\v`
>   if missing) and v5.7.14 (`\u####` + `\u{…}` UTF-8 codepoint
>   encode + surrogate-range rejection). Slot numbers below assume
>   v5.7.13 ships as one patch; if it splits, everything cascades
>   +1 (closeout target → v5.7.28).
> - **v5.7.14**: bundle — full project-setup workflow:
>   `cyrius deps` transitive resolution (sit-blocking onboarding)
>   + `cyrius init` library-vs-binary awareness (`--lib` / `--bin`
>   flags) + `cyrius init` / `cyrius port` first-party-
>   documentation alignment (ADR / architecture / guides / examples
>   doc-tree scaffold + CLAUDE.md template). All three flow
>   together: `cyrius init --lib foo` → resolve transitive deps →
>   emit shape-aware doc-tree.
> - **v5.7.15**: basic regex primitives (`lib/regex.cyr`) — Thompson
>   NFA, ~300-500 LOC. Unblocks cyim `--find` and downstream
>   ad-hoc state-machine churn.
> - **v5.7.16**: `lib/json.cyr` depth (stdlib baseline) — nested
>   objects, arrays, booleans, null, floats, escape handling,
>   error reporting. RPC-grade scope is owned by sandhi.
> - **v5.7.17**: `cyrius fuzz` stdlib auto-prepend parity. Small
>   refactor; `cmd_fuzz` walks the same manifest-deps codepath as
>   `cmd_test` / `cmd_bench`.
> - **v5.7.18**: cx codegen literal-arg propagation — fixes
>   `syscall(60, 42)` emitting `movi r0, 0` instead of the literal.
>   Pre-existing bug surfaced during v5.7.12 path-B testing.
> - **v5.7.19-v5.7.21**: advanced TS features beyond SY corpus
>   (**hard cap 3 slots**; overflow → v5.8.x). Surfaces per
>   downstream consumer: mapped types full grammar, `asserts`
>   predicates, decorators, `as const`, variadic tuple types,
>   const type parameters, `satisfies` postfix, conditional
>   type corpus, `never`/`unknown` audit.
> - **v5.7.22-v5.7.26**: RISC-V rv64 (3-5 sub-patches). Likely
>   breakdown: backend module + cross-entry; syscall peer + QEMU
>   exit-42 probe; `regression.tcyr` 102/102 via QEMU; native
>   self-host on rv64 hardware; tarball + `[release]` table wire-
>   in. Bundles compress 3 sub-patches; granular ships 5.
> - **v5.7.25/26/27**: `.scyr` (soak) + `.smcyr` (smoke) file types —
>   replaces Python 3 dependency in `tests/regression-capacity.sh`.
>   Lands the patch immediately after RISC-V wraps. Slot floats:
>   v5.7.25 if RISC-V = 3 sub-patches, v5.7.26 if 4, v5.7.27 if 5.
> - **v5.7.26/27/28**: v5.7.x closeout (CLAUDE.md "Closeout Pass"
>   11-step). Lands the patch after soak/smoke. **Hard upper bound
>   v5.7.28**; anything past this forces v5.8.x boundary. Add +1 to
>   each downstream slot if v5.7.13 splits into two patches.
>
> **Side-task across v5.7.13–v5.7.18 closeouts**: warning sweep
> (3 syscall-arity warnings + 36 unreachable-fn floor + check.sh
> shell-syntax warning + cbt/programs/bootstrap shellcheck pass).
> Cleared opportunistically each closeout, no dedicated slot.
> Goal: zero `warning:` lines from cc5 self-build by v5.7.22+.
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
> - **v5.10.x**: tagged unions (algebraic data types) + exhaustive
>   pattern match — own minor. Biggest single-ergonomics language
>   addition of the v5.x line.
> - **v5.11.x**: `Result<T,E>` + `?` propagation operator — own
>   minor, depends on v5.10 ADTs. Replaces -1/0/errno convention
>   across stdlib.
> - **v5.12.x**: allocators-as-parameter convention (Zig-style) —
>   own minor. Every allocating fn takes `Allocator`; failing-
>   allocator harness falls out; retires `alloc_init()` global
>   singleton.
> - **v5.13.x**: **polymorphic codegen** — security hardening (code
>   diversification / anti-ROP defense; post-v1.0 work per
>   `docs/development/threat-model.md`). **Pre-v6.0** per the
>   original plan: last v5.x feature minor before the `cc5 → cyc`
>   rename, so the rename doesn't have to also re-baseline a
>   hardening minor. Detailed scope/acceptance gates live in
>   `docs/development/threat-model.md`.
>
> aarch64 port remains fully online at the narrow-scope level
> (cross-build byte-identity; `regression.tcyr` 102/102 on real
> Pi; per-arch asm via `#ifdef CYRIUS_ARCH_{X86,AARCH64}` from
> v5.3.16). Native aarch64 self-host on Pi: ✅ repaired at
> v5.6.32. Apple Silicon Mach-O broad-scope: ✅ gate-fixture
> repaired at v5.6.33 (no compiler regression existed).
> Windows 11 24H2 PE broad-scope: ✅ gate-fixture repaired at
> v5.6.36.
>
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5. Closure
> verified. **78+ test suites**, 14 benchmarks, 5 fuzz harnesses.
> **65 stdlib modules** (includes 6 deps).

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

No active bugs at present.

When a new bug surfaces: add a row pinned to a concrete v5.7.x
slot here. No "investigate" / "future work" phrasing without a
patch number. If an investigation doesn't yield, STOP and ask —
never slip, defer, or re-slot unilaterally.

| Bug | Impact | Pinned slot |
|-----|--------|-------------|
| _(empty)_ | | |

For shipped work see [CHANGELOG.md](../../CHANGELOG.md) (source of
truth) and the high-level phase summaries in
[completed-phases.md](completed-phases.md).

---

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

1. **RISC-V (v5.7.22-v5.7.26) lands and adds 4th backend**, making
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

## v5.7.13 — string-literal escape sequences (`\x##`, `\u####`, full set)

**Pinned 2026-04-26; promoted to v5.7.13 2026-04-27** — cyim-
unblocking. RISC-V slid to v5.7.22-v5.7.26 to clear the bug/UX patch
slate first.

cyim v1.1.x uses `"\x1b[?1049h"` and family for ANSI/VT escape
sequences in `lib/tty.cyr`-equivalent code, with hardcoded
byte-length arguments to `syscall(write)` that assume the lex
decodes `\x1b` → byte `0x1b`. Cyrius's lex today appears to
**strip the leading `\` but emit the next character verbatim**,
so `"\x1b[?1049h"` becomes the 10-byte string `x1b[?1049h`;
the syscall's hardcoded length (`8`) then truncates to
`x1b[?104`, which the terminal renders as literal text instead
of executing the alt-screen-enter command. cyim is currently
**unusable interactively** because of this — agent-drive
(`--write` / `--replace[-all]` / `--grep`) works (no escape
sequences in that path), but the TTY editor surface is a
stream of literal `\x1b[…` characters on screen.

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
buffer. ~30 LOC; ugly, but unblocks the editor surface.

---

## v5.7.22-v5.7.26 — RISC-V rv64 (3-5 sub-patches; bounded series)

First-class RISC-V 64-bit target. Slid across v5.6.0 → v5.7.22-v5.7.26
as the optimization arc, sandhi fold, fixup-cap bumps,
cyrius-ts frontend, JSX work, tooling polish, fn-collision
rule, input_buf reshuffle, cx-build/correctness, and the
v5.7.13–v5.7.21 cyim-unblocking + bug/UX patch slate took
priority. Inherits a frontend-complete compiler against a
clean toolchain UX with the full v5.7.0–v5.7.21 prerequisite
chain shipped.

RISC-V needs:

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

Deliberately NOT bundling other items into v5.7.22-v5.7.26 — a new
architecture port is plenty of work on its own.

---

## v5.7.x — patch slate (interleaved with RISC-V)

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

### v5.7.19-v5.7.21 — advanced TS features beyond SY corpus (hard cap 3 slots; overflow → v5.8.x)

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
across v5.7.13–v5.7.18 closeouts** (per user direction:
"warning sweep if we can do as well go through the next few
releases as a side-task"). Don't dedicate a patch slot — clear
warnings opportunistically as each upcoming patch's closeout
runs. Goal is zero `warning:` lines from cc5 self-build by the
time v5.7.22 RISC-V opens.

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

### v5.7.18 — cx codegen literal-arg propagation

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
debug pass). Slot is now v5.7.18 (was unscheduled "when RISC-V wraps") or earlier if a
cx consumer surfaces.

### v5.7.15 — basic regex primitives in the stdlib

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

### v5.7.17 — `cyrius fuzz` stdlib auto-prepend parity

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

### v5.7.27 — `.scyr` (soak) + `.smcyr` (smoke) file types (post-RISC-V; floats up if RISC-V finishes in 3-4 sub-patches)

**Pinned 2026-04-25; slot framing updated 2026-04-27** — lands
right after RISC-V wraps. Worst-case slot is v5.7.27 (assumes
RISC-V uses all 5 sub-patches v5.7.22-v5.7.26); floats up to
v5.7.25 or v5.7.26 if RISC-V finishes in 3 or 4 sub-patches
respectively. Per user direction: "we can keep soak and smoke
to before closeout of 5.7.x". Today, soak and smoke testing
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

### v5.7.14 — `cyrius deps` transitive resolution (bundled with cyrius init lib-vs-bin + init/port doc-tree alignment)

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

### v5.7.14 — `cyrius init` library-vs-binary awareness (bundled with cyrius deps transitive + doc-tree alignment)

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

### v5.7.14 — `cyrius init` / `cyrius port` first-party-documentation alignment (bundled with cyrius deps transitive + lib-vs-bin)

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

### v5.7.16 — `lib/json.cyr` depth (stdlib baseline)

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
| **v5.3.0–v5.3.18** | macOS aarch64 | Mach-O | **Done** (narrow-scope); broad-scope gate-fixture repaired v5.6.33 |
| **v5.4.2–v5.4.8** | Windows x86_64 (PE foundation) | PE/COFF | **Done** — hello-world end-to-end on real Win11 (older build) |
| **v5.5.0–v5.5.10** | Windows x86_64 (full PE + native self-host) | PE/COFF | **Done** (narrow-scope byte-identity green at v5.5.10); broad-scope gate-fixture repaired v5.6.36 |
| **v5.5.11–v5.5.17** | macOS aarch64 libSystem + argv | Mach-O | **Done** — v5.5.13–v5.5.17 broad-scope verified on ecb |
| **v5.5.18–v5.5.22** | aarch64 Linux shakedown + SSE alignment | ELF | **Done** — multi-thread + contended mutex on real Pi 4 |
| **v5.5.34** | fdlopen foreign-dlopen completion | ELF | **Done** — 40/40 round-trip `dlopen("libc.so.6")+dlsym("getpid")` |
| **v5.5.35** | Windows PE .reloc + 32-bit ASLR | PE/COFF | **Done** — `DYNAMIC_BASE` + HIGH_ENTROPY_VA enabled v5.6.31 |
| **v5.5.36** | Windows Win64 ABI completion | PE/COFF | **Done** — struct-return via hidden RCX retptr + __chkstk via R11 + variadic float dup |
| **v5.7.22-v5.7.26** | RISC-V rv64 | ELF | Queued (3-5 sub-patches; pending v5.7.13–v5.7.21 patch slate; v5.7.x closeout at v5.7.26-v5.7.28) |
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

**Pinned arc:**

| Feature | Pinned | Effort |
|---------|--------|--------|
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
| Linux x86_64 | ELF | **✅ Narrow + Broad** — primary host. cc5 710 KB (v5.7.12); 3-step fixpoint byte-identical. |
| Linux aarch64 | ELF | **✅ Narrow + Broad** — cross-build byte-identity + native self-host on Pi 4 (repaired v5.6.32). Three libs (`lib/hashmap_fast`, `lib/u128`, `lib/mabda`) still contain ungated x86 asm — arch-gating queued. |
| cyrius-x bytecode | .cyx | **✅ Narrow** — clean CYX bytecode (path B, v5.7.12); literal-arg propagation pinned v5.7.x patch slot. |
| macOS x86_64 | Mach-O | **✅ Narrow** (v5.1.0). |
| macOS aarch64 | Mach-O | **✅ Narrow + Broad** — gate fixture repaired v5.6.33 (no compiler regression existed; bytes unchanged since v5.5.13). |
| Windows x86_64 | PE/COFF | **✅ Narrow + Broad** — gate fixture repaired v5.6.36; HIGH_ENTROPY_VA enabled v5.6.31. Win64 ABI complete (v5.5.36); .reloc + 32-bit ASLR (v5.5.35). |
| Compiler optimization (O1–O6) | — | **✅ Closed** (v5.6.5 + v5.6.7–v5.6.27). |
| RISC-V (rv64) | ELF | Queued — **v5.7.22-v5.7.26** |
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
