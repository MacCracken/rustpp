# Changelog

All notable changes to Cyrius are documented here.
This is the **source of truth** for all work done.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [4.8.1] — 2026-04-14

### Added
- **`base64url_encode` / `base64url_decode`** in `lib/base64.cyr`
  (RFC 4648 §5, "URL- and filename-safe" alphabet). The URL variant
  swaps `+` / `/` → `-` / `_` and typically drops `=` padding. JWT
  tokens (RFC 7515 §3.5), OAuth 2.0 PKCE / `state`, capability URLs
  all use this — bote 2.2's `auth_validator_jwt_hs256` needs it.
  - Encoder emits no padding (per the common URL convention).
  - Decoder accepts both padded and unpadded input.
  - Signature mirrors `base64_encode` / `base64_decode` exactly, so
    consumers can swap one for the other by transport context.
  The code landed during the 4.8.0 cycle but without tests or
  changelog; this patch documents + verifies it.

### Fixed
- **`tests/tcyr/method_dispatch.tcyr` + `tests/tcyr/u128.tcyr` CI
  failures (exit code != 0)**. Both files ended with
  `assert_summary();` as a bare statement. In executable mode cyrius's
  top-level epilogue loads the *last declared var* (not the last
  expression) into `rax` before `syscall(60, rax)` — so the exit
  code was the low byte of whatever the final `var` pointed at
  (a heap address, e.g. `0x30` == `48`). Locally `scripts/check.sh`
  reads the `"N failed"` summary line and didn't catch it; the CI
  step checks `$ec -ne 0`. Fixed by ending each test with
  `var _exit_code = assert_summary(); syscall(60, _exit_code);` —
  matching the pattern in `regression.tcyr`.
- **18 undocumented fns in `lib/u128.cyr`**. Several helpers
  (`u128_hi`, the `*eq` family, bitwise ops, unsigned compares,
  `u128_div`/`mod`/`diveq`/`modeq`) were grouped under a single
  section comment; the doc checker requires a `# ...` line directly
  above each `fn`. Added one-liners. `cyrius doc --check lib/u128.cyr`
  now reports `0 undocumented`.

### Validation
- **30 assertions** in `tests/tcyr/base64.tcyr` (up from 11) cover
  base64url:
  - RFC 4648 §10 vectors: `""`, `"f"` → `"Zg"`, `"fo"` → `"Zm8"`,
    `"foo"`, `"foob"`, `"fooba"`, `"foobar"`.
  - Padding tolerance: `"Zm9vYg"` and `"Zm9vYg=="` both decode to
    `"foob"`.
  - JWT header: `base64url_decode("eyJ0eXAiOiJKV1QiLA0KICJhbGciOiJIUzI1NiJ9", 40)`
    → 30 bytes.
  - Invalid char: `base64url_decode("Zm9*Yg", 6)` → `0`.
  - URL-safety: bytes `0xFB 0xFF 0xBF` → `-_-_` via
    `base64url_encode`, vs `+/+/` via standard `base64_encode`.
  - Round-trip on `"The quick brown fox"`.
- cc3 self-host byte-identical (two-step bootstrap).
- `scripts/check.sh` 7/7 PASS.
- CI-style exit-code loop over all 43 `.tcyr` files: 43 / 0.
- `cyrius doc --check lib/base64.cyr` → `4 documented, 0 undocumented`.
- `cyrius doc --check lib/u128.cyr` → `0 undocumented`.

## [4.8.0] — 2026-04-14

### Arc summary
Eight-alpha incremental land of the `u128` track from the 4.8.x
roadmap. Parser + heap work on one side, a complete unsigned-128
stdlib on the other.

- **alpha1** — `u128` recognized as scalar type in `PARSE_GVAR_REG`
  (pass 1); 16-byte var slot with zero init.
- **alpha2** — `_` separator in hex + decimal literals
  (`0xDEAD_BEEF_CAFE_BABE`).
- **alpha3** — Fixed `PARSE_VAR`'s global-fallback path (truncated
  u128 to 8 bytes when pass 1 terminated before the declaration,
  e.g. after a top-level `alloc_init();`). Shipped `lib/u128.cyr`
  with set / copy / access / equality.
- **alpha4** — `u128_add` / `u128_sub` / `*eq` via 32-bit chunk
  carry propagation.
- **alpha5** — `u128_mul` (+ `u128_muleq`) via schoolbook.
  `a·b mod 2^128 = a_lo·b_lo + (a_hi·b_lo + a_lo·b_hi)·2^64`.
- **alpha6** — shifts (`u128_shl` / `u128_shr`) + bitwise
  (`and` / `or` / `xor` / `not`) + `*eq`. Private `_u128_lshr64`
  helper to work around cyrius's arithmetic `>>`.
- **alpha7** — unsigned compare (`ugt` / `uge` / `ult` / `ule`) +
  `u128_divmod` (128-iter shift-subtract) + `u128_div` /
  `u128_mod` + `*eq`. Closes the stdlib.

### u128 stdlib — at-a-glance
| Category | Functions |
|---|---|
| Construction | `u128_set(dst, lo, hi)`, `u128_from_u64(dst, lo)`, `u128_copy(dst, src)` |
| Inspection | `u128_lo(ptr)`, `u128_hi(ptr)`, `u128_eq(a, b)`, `u128_is_zero(ptr)` |
| Arithmetic | `u128_add`, `u128_sub`, `u128_mul`, `u128_divmod`, `u128_div`, `u128_mod` (+ `*eq` in-place) |
| Bit-level | `u128_shl`, `u128_shr`, `u128_and`, `u128_or`, `u128_xor`, `u128_not` (+ `*eq` in-place) |
| Compare | `u128_ugt`, `u128_uge`, `u128_ult`, `u128_ule` |

Convention throughout: pointer arguments (cyrius's single-register
ABI doesn't carry u128 values).

### Validation
- **96 assertions** in `tests/tcyr/u128.tcyr` across 11 groups — zero
  / one / max wrap / cross-limb / round-trip invariants for each op.
- cc3 self-host byte-identical.
- 7/7 check.sh PASS.

### Known limits (for subsequent alphas)
- `u128` as a fn-param or fn-return type — not yet. Callers pass
  pointers. Would require ABI work (register pair or stack) and
  compiler surgery.
- `u128` as a struct field — not yet; only `var` declarations.
- `u128` locals inside fns — same issue as above (8-byte stack slot).
- No literal syntax for 128-bit constants — users must combine two
  `u64`s via `u128_set`. Alpha-future work.

### What's next in 4.8.x
| Track | Scope |
|---|---|
| **4.8.1** | Jump tables for enum dispatch — lower switch density threshold, add `match`, auto-convert if-chains. |
| **4.8.2** | Register allocation (`#regalloc`) on top of the CFG from 4.4.0. |
| **4.8.3** | `defmt` — compile-time format string interning. |

After 4.8.x closes, 5.0 opens with the cc5 uplift + macOS / Windows.

## [4.8.0-alpha7] — 2026-04-14 (unreleased)

### Added
- **Unsigned 64 + 128-bit compare helpers**:
  - Private `_u64_ugt(a, b)` / `_u64_uge(a, b)` — treat both i64s as
    unsigned. Four-case split on whether each operand has bit 63 set
    (cyrius's signed `>` disagrees with unsigned when bit 63 differs).
  - Public `u128_ugt` / `u128_uge` / `u128_ult` / `u128_ule` —
    lexicographic compare on (hi, lo).
- **`u128_divmod(qdst, rdst, a, b)`** — 128-iteration shift-subtract
  long division. Writes quotient to `qdst` and remainder to `rdst`.
  On `b == 0`, emits `u128: division by zero\n` to stderr and exits
  1. Body operates on scalar limbs (locals) — no u128 local types
  needed yet (deferred to later alpha).
- **`u128_div` / `u128_mod`** — quotient-only / remainder-only
  wrappers using a module-level `_u128_discard: u128` scratch slot.
- **`u128_diveq` / `u128_modeq`** — in-place.

### Validation
- `tests/tcyr/u128.tcyr` grew to **96 assertions**. New coverage:
  - Unsigned compare: equality, `max_u64 > 1` (signed says
    `-1 < 1`, but unsigned 0xFFFF.. > 1), cross-limb ordering, both
    hi "negative" regime.
  - Divmod: `0/1`, `42/5 = (8, 2)`, `100/10 = (10, 0)`,
    `max_u128 / 1 = (max_u128, 0)`, `2^64 / 2 = 2^63`, divisor >
    dividend (q=0, r=a), cross-limb `(0xDEAD_BEEF, 1) / 0x10000`
    with `r = 0xBEEF`, and a `q*b + r == a` round-trip invariant.
  - `u128_div` / `u128_mod`: `101 / 7 = (14, 3)`.
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS.

### u128 stdlib surface — complete
Construction: `u128_set`, `u128_from_u64`, `u128_copy`.
Inspection: `u128_lo`, `u128_hi`, `u128_eq`, `u128_is_zero`.
Arithmetic: `u128_add`, `u128_sub`, `u128_mul`, `u128_divmod`,
`u128_div`, `u128_mod`, `u128_muleq` (etc.).
Bit-level: `u128_shl`, `u128_shr`, `u128_and`, `u128_or`, `u128_xor`,
`u128_not`, `u128_shleq` (etc.).
Compare: `u128_ugt`, `u128_uge`, `u128_ult`, `u128_ule`.

### Next
Tag **4.8.0** — u128 MVP shipped. Remaining 4.8.x roadmap items
(jump tables, register alloc, defmt) are independent tracks — each
opens with its own alpha.

## [4.8.0-alpha6] — 2026-04-14 (unreleased)

### Added
- **`u128_shl` / `u128_shr`** — bit-level shift by 0..127 (counts ≥
  128 yield 0). Three regimes per direction: `n == 0` (copy),
  `n >= 64` (whole-limb shift + zero the vacated limb), `0 < n < 64`
  (spill between limbs with a companion shift on the other limb).
- **`_u128_lshr64(x, n)`** — logical right shift helper. Cyrius `>>`
  sign-extends, so doing `(x >> 1) & 0x7FFFFFFFFFFFFFFF` once clears
  bit 63, then `>> (n-1)` finishes the job without re-introducing
  sign-extended bits. Private to the library (underscore prefix).
- **`u128_and` / `u128_or` / `u128_xor` / `u128_not`** — per-limb
  bitwise ops.
- **In-place**: `u128_shleq`, `u128_shreq`, `u128_andeq`, `u128_oreq`,
  `u128_xoreq`.

### Validation
- `tests/tcyr/u128.tcyr` now **72 assertions**. New coverage:
  - `shl 0` identity, `1 << 63` within lo, `1 << 64` crosses limbs,
    `1 << 127` top bit of hi, `1 << 128 = 0`, inter-limb spill
    (`0x8000…0001 << 1 = (2, 1)`).
  - `shr 0` identity, `max_u128 >> 1` leaves hi as `0x7FFF…` (logical,
    not sign-extended), `0x8000…0000 hi >> 1 = 0x4000…0000`, `shr 64`
    pulls hi into lo, `shr 127` of top bit = 1, `shr 128 = 0`, and
    `shl 70; shr 70` round-trip.
  - AND / OR / XOR with alternating patterns, `~0 = max_u128`,
    `~~x == x`.
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS.

### u128 stdlib surface after alpha6
Construction: `u128_set`, `u128_from_u64`, `u128_copy`.
Inspection: `u128_lo`, `u128_hi`, `u128_eq`, `u128_is_zero`.
Arithmetic: `u128_add`, `u128_sub`, `u128_mul` + `*eq` variants.
Bit-level: `u128_shl`, `u128_shr`, `u128_and`, `u128_or`, `u128_xor`,
`u128_not` + `*eq` variants.

### Next (alpha7 / final u128 patch)
- `u128_divmod` — the only remaining arithmetic gap. Either shift-
  subtract (128 iterations, clean but slow) or Knuth D (faster but
  thornier). Shift-subtract is the right first cut — it's about 30
  LOC and makes the stdlib feature-complete for the "u128 as
  primitive" use case.

## [4.8.0-alpha5] — 2026-04-14 (unreleased)

### Added
- **`u128_mul`** in `lib/u128.cyr` — schoolbook multiply that wraps at
  `2^128`. Derivation:
  `a·b mod 2^128 = a_lo·b_lo + (a_hi·b_lo + a_lo·b_hi)·2^64`
  (the `a_hi·b_hi·2^128` term wraps away). The full 128-bit product
  `a_lo·b_lo` is assembled from four 32×32 partial products with
  per-chunk carry propagation; cross terms `a_hi·b_lo + a_lo·b_hi`
  contribute only to the high limb and use natural i64 wrap for the
  mod-2^64 part.
- **`u128_muleq`** — in-place `dst *= src`.

### Validation
- `tests/tcyr/u128.tcyr` now at **43 assertions**:
  - `0 * x = 0`, `1 * x = x`, `2 * 2 = 4`
  - `2^32 * 2^32 = (0, 1)` — pure chunk-carry path
  - `max_u64 * max_u64 = (1, max_u64 - 1)` — full 128-bit product
  - `2^64 * 2^64 = 0` — high-limb-only product wraps
  - `(1, 1) * (2, 3) = (2, 5)` — mixed cross terms
  - `u128_muleq(&sq, &seven)` with `sq = 7` → `49`
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS.

### Next (alpha6)
- Shifts / bitwise: `u128_shl`, `u128_shr`, `u128_and`, `u128_or`,
  `u128_xor`, `u128_not`. Straightforward once add/mul are stable.
- `u128_divmod` is the last big piece — scope it in alpha7 if needed.

## [4.8.0-alpha4] — 2026-04-14 (unreleased)

### Added
- **`u128_add` / `u128_sub`** in `lib/u128.cyr` — two-limb add/subtract
  with carry/borrow correctly propagating across the low→high boundary.
  Signature: `u128_add(dst, a, b)` / `u128_sub(dst, a, b)`, all pointer
  arguments. Compiler has no unsigned primitive yet, so carry/borrow
  detection goes through 32-bit chunk addition (each half stays in the
  positive i64 range; bit-32 of the partial sum is the carry bit).
  Wraps modulo 2^128: `max_u128 + 1 = 0`, `0 - 1 = max_u128`.
- **`u128_addeq` / `u128_subeq`** — in-place convenience wrappers
  (`dst += src` / `dst -= src`).

### Validation
- `tests/tcyr/u128.tcyr` grew to 31 assertions — covers 0+0, 1+1,
  `max_u64+1` (crosses limb boundary), `max_u128+1` (full wrap),
  `2-1`, `(0,1)-(1,0)` (borrow across limb), `0-1` (full wrap to
  `max_u128`), and a round-trip `(a+b)-b == a` with non-trivial
  patterns. Plus `u128_addeq`/`u128_subeq`. All green.
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS.

### Next (alpha5)
- `u128_mul` via schoolbook (3-mul variant: `lo·lo`, `hi·lo + lo·hi`,
  carry). Division is `u128_divmod` in alpha6.

## [4.8.0-alpha3] — 2026-04-14 (unreleased)

### Fixed
- **`u128` var-slot truncation in PARSE_VAR** (`src/frontend/parse.cyr`).
  Alpha1 added `u128` detection and 16-byte allocation in
  `PARSE_GVAR_REG` (pass 1). But pass 1 terminates at the first
  top-level expression statement (e.g. `alloc_init();`) — any var
  declarations *after* that point get registered by PARSE_VAR's
  global-fallback path (line 2113+), which hardcoded `var_sizes = 8`
  for `scalar_type >= 8`. Result: a `u128` var declared after a
  top-level call got only 8 bytes, silently overlapping its hi limb
  with the next var's lo. Manifested in the stdlib tests as
  `u128_set(&a, lo, hi)` writing hi at `&a+8` — but `&a+8` already
  pointed into the next var's space, so `load64(&a+8)` returned that
  var's value instead. Fixed by routing `scalar_type` (8 or 16)
  through rather than hardcoding.

### Added
- **`lib/u128.cyr`** — 128-bit unsigned stdlib helpers built on the
  16-byte var slot: `u128_set(dst, lo, hi)`, `u128_from_u64(dst, lo)`,
  `u128_copy(dst, src)`, `u128_lo(ptr)`, `u128_hi(ptr)`, `u128_eq(a, b)`,
  `u128_is_zero(ptr)`. Pointer-based — no u128 pass-by-value through
  the single-register ABI yet. Arithmetic (`+`, `-`, `*`) lands in
  alpha4+.
- **`tests/tcyr/u128.tcyr`** — 14 assertions covering zero-init,
  set/read, from_u64, copy, equality, zero-test, plus a regression
  guard that `&g2 - &g1 == 16` for consecutive u128 vars declared
  *after* a top-level call (the pre-alpha3 failing case).

### Validation
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS. 43 `.tcyr` suites green (added u128).

## [4.8.0-alpha2] — 2026-04-14 (unreleased)

### Added
- **Underscore separators in numeric literals**
  (`src/frontend/lex.cyr`). `LEXHEX` and `LEXDEC` now skip `_`
  silently between digits:
  ```
  var a = 0xDEAD_BEEF_CAFE_BABE;   # = 0xDEADBEEFCAFEBABE
  var b = 1_000_000;               # = 1000000
  var c = 0xFF_FF;                 # = 0xFFFF
  ```
  Trailing / doubled underscores are tolerated. Prereq for the
  128-bit hex literal parse in alpha3 (e.g.
  `0xDEAD_BEEF_CAFE_BABE_1234_5678_9ABC_DEF0`).

### Validation
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS.

## [4.8.0-alpha1] — 2026-04-14 (unreleased)

### Added
- **`u128` type annotation** (`src/frontend/parse.cyr`). Global and
  local vars can now be declared `: u128` and receive a 16-byte slot
  (two 64-bit limbs, little-endian in memory). Zero-initialized.
  Recognized alongside `i8` / `i16` / `i32` / `i64` as a scalar type.
  ```
  var x: u128 = 0;
  store64(&x, 42);       # low limb
  store64(&x + 8, 100);  # high limb
  ```
- **16-byte var allocation**. `var_sizes` entry = 16 for u128 vars;
  the slot is addressable via pointer arithmetic (`&x`, `&x + 8`)
  just like any other struct-sized region.

### Known limits (alpha1)
- No arithmetic — alpha3 lands `+` / `-` via `ADD` + `ADC`, alpha4
  does `*`. Today, operations touching a u128 var treat it as i64
  (low limb only).
- No literal syntax beyond `0` — alpha2 adds `0xDEAD_BEEF_CAFE_BABE_...`
  parsing.
- Struct fields and fn params can't be typed `u128` yet — alpha1
  only covers `var` declarations. Follow-up patches extend coverage.

### Regression tests added this cycle
- `tests/regression-shared.sh` — C harness dlopens a `.so` produced
  by `shared;`, validates `dlsym` + call on add / rodata / mutable
  data / DT_INIT initializer.
- `tests/regression-linker.sh` — two cross-module link scenarios:
  fn resolution (exit 43) and cross-module `.data` + init ordering
  (exit 44).
- `tests/tcyr/method_dispatch.tcyr` — ~20-module include pressure
  (pushes `tok_names` well past the 30 K mark that pre-4.7.1
  `BUILD_METHOD_NAME` clobbered) + struct method dispatch with a
  mix of receivers and arg counts.
- `scripts/check.sh` wires all three into the standard audit.

### Validation
- cc3 self-host byte-identical (two-step bootstrap).
- 7/7 check.sh PASS (added Shared-object + Linker sections).

## [4.7.1] — 2026-04-14

### Fixed
- **`BUILD_METHOD_NAME` scratch corruption** (`src/frontend/parse.cyr`).
  Method dispatch pre-4.7.1 wrote the mangled name `StructName_method`
  at a fixed `tok_names` offset of 30 000 bytes. Any program with
  more than ~30 KB of identifier data had real tokens pointing into
  that region; the scratch write silently overwrote them, and later
  parsing mis-read the corrupted bytes. This is what bote's
  *"4.6.1 diagnostic fix doesn't cover our path"* report surfaced —
  the `lib/assert.cyr:3: expected '=', got string` error came from a
  token whose noff pointed at bytes that had been clobbered by a
  method-name scratch write elsewhere in the unit. Fix: scratch now
  starts at `GNPOS(S)` (past the current live identifiers) with an
  `NPOS_GUARD(S, 256)` and does *not* advance npos — lookup-only,
  bytes past npos are safe because the next `LEXID` will just
  overwrite them.

### Changed
- **Function table cap raised 2048 → 4096** (`src/frontend/parse.cyr`,
  `src/main.cyr`, `src/main_cx.cyr`, `src/common/util.cyr`,
  `src/backend/x86/fixup.cyr`, `src/backend/aarch64/fixup.cyr`).
  Bote sits at ~1800 / 2048 before `lib/ws_server.cyr` lands, and
  `ws_server.cyr` adds 16 fns — we'd tip over with no realistic
  remediation ("split into compilation units" isn't an option while
  the linker is per-compilation-unit).
  - All 8 fn tables relocated from `0xC0000–0xE4000` to
    `0xE8A000–0xECA000` (the 256 KB scratch region past the runtime
    fixup table at `0xE4A000+16384×16`). Each table doubled from
    16 KB to 32 KB, holding 4096 entries:
    - `fn_names` → `0xE8A000`
    - `fn_offsets` → `0xE92000`
    - `fn_params` → `0xE9A000`
    - `fn_body_start` → `0xEA2000`
    - `fn_body_end` → `0xEAA000`
    - `fn_inline` → `0xEB2000`
    - `fn_param_str_mask` → `0xEBA000`
    - `fn_code_end` → `0xEC2000`
  - `REGFN` cap updated to `4096`; error message reports `/4096`.
  - Old `0xC0000–0xE4000` region (144 KB) is now free, available for
    a future reorg.
  - Bridge compiler unaffected (maintains its own heap layout; does
    not reference these addresses).

### Validation
- 3500-fn stress test (short names to avoid ident buffer): previously
  hit the fn cap at 2048; now compiles through to 4096, then reports
  the clean diagnostic `error: function table full (4096/4096) —
  split into separate compilation units`.
- 3500-fn stress with long names: hits the 128 KB identifier buffer
  first with `error: identifier buffer full (130819/131072 bytes)
  — reduce included modules or split into separate unit`.
- Bote's `cyrius-4.5.1-repro.cyr` (2000 long-named fns) compiles
  clean; was previously near the ceiling.
- cc3 self-host byte-identical (two-step bootstrap).
- 5/5 check.sh PASS.

### Why a patch release
Addresses the two downstream items bote flagged after 4.6.1/4.6.2:
(1) a real corruption bug in `BUILD_METHOD_NAME` that the diagnostic
patch couldn't cover because the overflow *path* was corruption, not
buffer growth; (2) cap headroom for the fn table. Both fixes are
contained: (1) is a one-site change, (2) moves addresses but doesn't
change the compiler's external contract.

## [4.7.0] — 2026-04-14

### Added (GA highlights)
- **`shared;` produces real dlopen-able `.so`s end-to-end.**
  Before 4.7.0: ET_DYN header scaffolded in v3.4.12 but no dynamic
  metadata, no dlsym resolution, no PIC correctness for data refs,
  no way to run initializers. 4.7.0: all four gaps closed.
- **`DT_INIT` runs top-level initializers on dlopen**
  (`src/main.cyr`, `src/backend/x86/fixup.cyr`). The `_cyrius_init`
  wrapper that object mode already uses is now emitted in shared
  mode too; `EMITELF_SHARED` adds a `DT_INIT` entry in `.dynamic`
  pointing at its VA. The dynamic loader fires it on every `dlopen`,
  so `var counter = 100;` actually lands in `.data` as 100 by the
  time the consumer's first `dlsym` call runs.
- **Dynamic section + symbol table** — `.dynsym` (STT_FUNC /
  STB_GLOBAL), `.dynstr`, SysV `.hash` (nbucket=1, single chain),
  `.dynamic` (`DT_INIT` / `DT_HASH` / `DT_SYMTAB` / `DT_STRTAB` /
  `DT_STRSZ` / `DT_SYMENT` / `DT_NULL`), `PT_DYNAMIC` + `PT_GNU_STACK`
  program headers.
- **PIC-safe addressing in shared mode** — `EVADDR` / `ESADDR` /
  `EVADDR_X1` / fn-pointer LEA all go through the object-mode path
  that emits `lea rax, [rip+disp32]`. `FIXUP` patches ftype 0 / 1 / 3
  as 4-byte PC-relative displacements (`target − (entry+coff+4)`) in
  `kmode==2`. Shared `entry = 232` (64 B ELF + 3 × 56 B PHs).

### Fixed
- **Shared-mode fn body elision** — cc3's name-bitmap DCE was skipping
  function bodies in `shared;` mode when no in-module caller existed,
  same pattern as the 4.6.0-beta2 object-mode fix. Every exported
  symbol pointed at the fallback `xor eax,eax; ret` stub, so every
  `dlsym`'d call returned 0. DCE now skipped when
  `kernel_mode == 2` just like `== 3`.
- **Shared-mode epilogue** was emitting `syscall(60, ...)` (exit) at
  the end of top-level code — fine for an executable, disastrous for
  a library being called by the dynamic loader. Now `leave; ret`
  like object mode so `DT_INIT` can return.

### Validation
- Three end-to-end `.so` tests, all green:
  - **Calls**: C `dlopen`/`dlsym` → `add(17,25) = 42`,
    `multiply(7,6) = 42`. Python `ctypes.CDLL` same.
  - **Strings**: `greeting()` returns `.rodata`-backed literal —
    `strcmp` vs the raw text = 0 after load-bias.
  - **Data + init**: `var counter = 100; fn get() { ... }
    fn inc() { ... } fn reset() { ... }`. After `dlopen`: `get() = 100`
    (DT_INIT ran the `= 100` initializer), `inc()` → 101, 102, `get()
    = 102` (mutation persists), `reset()` → 0.
- cc3 self-host byte-identical (two-step bootstrap).
- 5/5 check.sh PASS. 41 test suites green.
- `build/cc3` = 361 KB.

### Known limits (4.7.0)
- Single `PT_LOAD RWX`. `W^X` not enforced; splitting text/data into
  RX + RW segments is a layout refactor deferred.
- No `.gnu.hash` (SysV `.hash` only). GNU hash is faster for large
  symbol tables but SysV works everywhere; not a blocker.
- No `DT_SONAME` — library can't self-identify. Easy add when needed.
- Section headers still omitted; `readelf --dyn-syms` empty but the
  loader reads `PT_DYNAMIC` directly, so `dlsym` resolves fine.
- `DT_INIT` takes void; we don't hook `DT_INIT_ARRAY` (argc, argv,
  envp). Not needed for cyrius's init model today.

### Shipped in the 4.7.0 arc
- alpha1: dynsym / dynstr / hash / dynamic / PT_DYNAMIC / PT_GNU_STACK.
- alpha2: PIC-safe LEA patches for data + string refs + fn pointers.
- GA: DT_INIT for initializers + exit→ret fix.

### Next
- 4.8.0 per roadmap: types + codegen (u128, defmt, jump tables for
  enum dispatch, register allocation).
- After that: cc5 uplift + multi-platform for 5.0.

## [4.7.0-alpha2] — 2026-04-14 (unreleased)

### Fixed
- **PIC-safe data + string refs in shared mode** (`src/backend/x86/emit.cyr`,
  `src/backend/x86/fixup.cyr`). Alpha1 produced loadable `.so`s where
  *calls* worked (already PC-relative rel32) but any access to a
  string literal or a global variable crashed with SIGSEGV at a random
  address — the absolute VA bakedby `mov rax, imm64` didn't survive
  the dynamic loader's random bias.
  - `_IS_OBJ(S)` now returns 1 for both object mode (3) *and* shared
    mode (2). This flips `EVADDR` / `ESADDR` / `EVADDR_X1` /
    `PARSE_EXPR` fn-pointer emission to `lea rax, [rip+disp32]`.
  - `FIXUP` patches for ftype 0 (var addr), 1 (string addr), 3 (fn
    addr) now emit 4-byte PC-relative displacements in shared mode,
    computed as `target_va − (entry + coff + 4)`. Matches the LEA
    instruction's next-instruction base.
  - Shared-mode `entry` set to `232` (3 × 56-byte PHs + 64-byte ELF
    header), reflecting where code starts in the `.so` layout with
    `p_vaddr=0`.

### Validation
- C `dlopen` + `dlsym` + call round-trip:
  - `greeting()` returns a string literal → pointer in loader's
    mapping, `strcmp` vs literal = 0, text prints correctly.
  - `inc()` / `get()` / `reset()` on a `.data`-backed counter —
    mutations visible across calls, state persists.
- Python `ctypes` round-trip (alpha1 tests still pass): `add(100,200)
  = 300`, `multiply(6,7) = 42`.
- cc3 self-host byte-identical.
- 5/5 check.sh PASS.

### Known limits (alpha2)
- **No data initializers in shared mode** — `var counter = 100;` ends
  up as 0 at load time because `shared;` skips the `_cyrius_init`
  wrapper that would run the assignment. Would be addressed with a
  `DT_INIT`/`DT_INIT_ARRAY` mechanism in a later alpha, or by
  precomputing the `.data` contents at compile time for simple
  constant initializers.
- Still a single `PT_LOAD RWX` — `W^X` not enforced. Cleanly splitting
  text/data into RX/RW segments is a layout-sensitive change deferred
  to post-GA.

### Next (GA)
- Decide: data-initializer strategy (constant-fold at compile time
  vs. runtime `DT_INIT`).
- Package a .tcyr or .bcyr test that spawns a `.so` build + Python
  ctypes round-trip so this path is continuously covered by the suite.

## [4.7.0-alpha1] — 2026-04-14 (unreleased)

### Added
- **Real shared-object (`.so`) emission** (`src/backend/x86/fixup.cyr`).
  `shared;` directive now produces a `dlopen`-able ET_DYN with proper
  dynamic metadata — not just the ET_DYN header that v3.4.12 scaffolded.
  New path: `EMITELF_SHARED` (replaces `EMITELF_USER(S, 3)` routing).
  Emits:
  - `.dynsym` — one `Elf64_Sym` per exported global fn (+ null entry),
    `STT_FUNC | STB_GLOBAL`, `st_value` = code file offset, `st_shndx=1`
    (loader doesn't need section table when `PT_DYNAMIC` is present).
  - `.dynstr` — null-separated names.
  - `.hash` — SysV hash table, `nbucket=1` (all syms chain from
    bucket 0; hash fn kept but chain is a single linked list).
  - `.dynamic` — `DT_HASH`/`DT_SYMTAB`/`DT_STRTAB`/`DT_STRSZ`/
    `DT_SYMENT`/`DT_NULL`.
  - **3 program headers**: `PT_LOAD` (file body, RWX), `PT_DYNAMIC`
    pointing at `.dynamic`, `PT_GNU_STACK` with `p_flags=R|W`
    (opts out of Linux's default "exec stack required" assumption —
    without this, `dlopen` fails with *"cannot enable executable stack
    as shared object requires: Invalid argument"*).
  - `p_vaddr=0` throughout. All internal refs (LEA [rip+disp32], CALL
    rel32) are already PC-relative, so code runs at any load bias.
- **Exported fn filter** — skips names starting with `_` (e.g.,
  `_cyrius_init`). Every other global fn is exported.
- **SysV hash helper** `SYSV_HASH(name_ptr)` in `fixup.cyr`.

### Fixed
- **Shared-mode body elision** (`src/main.cyr`). Same pattern as the
  4.6.0-beta2 object-mode fix: cc3's name-bitmap DCE was skipping
  function bodies in `shared;` mode when no in-module call existed —
  the exported symbol pointed to the `xor eax,eax; ret` fallback stub
  and every call via `dlsym` returned 0. DCE now also skipped when
  `kernel_mode == 2`.

### Validation
- `/tmp/lib.cyr` with `shared; fn add(a,b) { return a+b; } fn multiply(a,b) { return a*b; }`:
  - C round-trip via `dlopen`/`dlsym` + call — `add(17,25)=42`,
    `multiply(7,6)=42`. Green.
  - Python `ctypes.CDLL` round-trip — `add(100,200)=300`,
    `multiply(6,7)=42`, `add(-1,1)=0`. Green.
- cc3 self-host stable.
- 5/5 check.sh PASS.
- `/tmp/libtest.so` = 592 bytes. Minimal, but real.

### Known limits (alpha1)
- Single `PT_LOAD RWX`. `W^X` not enforced (data + code + dynamic
  metadata all in one segment). Will split into RX/RW segments in
  a later alpha.
- No section headers in output — `objdump -d`/`readelf --dyn-syms`
  can't display from section table; direct `dlopen` works because the
  loader reads `PT_DYNAMIC`.
- No `.rela.dyn` — ET_DYN is purely PC-relative for now. If we ever
  emit absolute 64-bit addresses into the binary, they'd need
  load-time relocation via `.rela.dyn` + `R_X86_64_RELATIVE`.
- No `DT_INIT`/`DT_FINI` — no constructors/destructors on dlopen.
- No `DT_SONAME` — the library can't self-identify by name.

### Next (alpha2)
- Audit for any absolute-address leaks; add `.rela.dyn` if needed.
- Test with a .so that references internal string data
  (`"hello\n"` in `.rodata`) — verify the `[rip+disp32]` LEA
  actually resolves at random load bias.

## [4.6.2] — 2026-04-14

### Changed
- **`tok_names` region raised from 64 KB to 128 KB**
  (`src/main.cyr`, `src/main_aarch64.cyr`, `src/main_cx.cyr`,
  `src/common/util.cyr`, `src/backend/x86/fixup.cyr`,
  `src/backend/aarch64/fixup.cyr`, `src/frontend/lex.cyr`).
  Bote (and any future mid-size project that pulls in 15+ stdlib
  modules + vendored deps) was hitting the identifier buffer ceiling
  in routine builds — 4.6.1 fixed the diagnostic, 4.6.2 lifts the
  ceiling. `str_pos` and `data_size` moved from `S+0x70000`/`0x70008`
  to `S+0x8FCC8`/`0x8FCD0` (unused slot between `scope_depth` and
  `current_module`) so `tok_names` can span `0x60000–0x80000`. Still
  nested inside `input_buf`'s footprint — that region is free by the
  time LEX runs.
- **`LEXID` entry check + `NPOS_GUARD`** updated to the new 128 KB
  ceiling (threshold 130800; 272-byte slack before the 131072 wall).
  Error message now reports `/131072 bytes`.

### Why a patch release
Heap-layout change, but scoped + tested: two-step bootstrap byte-
identical, 5/5 check.sh PASS, heap audit clean. Downstream code
that never read `S+0x70000` directly (everything except `bridge.cyr`,
which keeps its own independent layout) is unaffected.

### Validation
- Two-step bootstrap: cc3 compiles itself → cc4; cc4 compiles itself
  → cc5; cc4 == cc5 byte-identical (353920 bytes, unchanged).
- Heap audit clean (47 regions, 0 overlaps, 0 warnings after
  `(nested in input_buf …)` marker added to `tok_names`).
- 5/5 check.sh PASS. 41 test suites green.
- Bote repro (`cyrius-4.5.1-repro.cyr`, 2000 functions with long
  names): previously hit identifier buffer at ~1700 fns. Now the
  limiting factor is the function table (2048 fns) — identifier
  buffer has ~60 KB of headroom.

### Next
- `4.7.x` per roadmap (PIC codegen).
- Separately: raise the 2048 function table cap if real projects
  start hitting it (bote is close; cyrius compiler itself is at
  ~1400 fns).

## [4.6.1] — 2026-04-14

### Fixed
- **Clean diagnostic on identifier buffer overflow**
  (`src/frontend/lex.cyr`, `src/frontend/parse.cyr`, `src/main.cyr`).
  Bote (v1.5.0) surfaced that overflow of `tok_names`
  (the 64 KB identifier region at `S+0x60000`) could report a
  cascading parse error (`error:lib/assert.cyr:3: expected '=', got
  string`) instead of the buffer-full message. Two root causes:
  - `LEXID`'s entry check at `npos >= 65500` left only 36 bytes of
    slack; long mangled identifiers (`libro_patra_store_open_with_
    capacity` et al.) exceeded it and the inner write loop continued
    past `0x70000`, corrupting `str_pos`/`data_size` and downstream
    token values. Threshold tightened to `65300` (236-byte slack).
  - Every mangled-name writer in `parse.cyr` / `main.cyr`
    (enum-variant ctors, `alloc`-call synthesis, closure names,
    `BUILD_OP_NAME`, `for-in` helper names, module-prefix mangling,
    `use`-alias mangling) wrote to `S+0x60000+cwp` with no bounds
    check. Added `NPOS_GUARD(S, need)` helper (in `lex.cyr`) and
    invoked it before each site so overflow errors cleanly from
    where it actually occurs rather than propagating silent
    corruption into later tokens.

### Validation
- Bote repro (`cyrius-4.5.1-repro.cyr`, 2033 lines, ~2000 long fn
  names): emits the clean diagnostic — `error: identifier buffer
  full (65530/65536 bytes) — reduce included modules or split into
  separate unit`.
- cc3 self-host stable (two-step bootstrap byte-identical).
- 5/5 check.sh PASS.

### Why a patch release
Fix is purely diagnostic — code paths that USED to overflow still
overflow, they just report accurately. Cap raise (moving
`str_pos`/`data_size` off `S+0x70000` and expanding `tok_names` to
128 KB) is scoped as 4.6.2; it needs a heap-layout change and
two-step bootstrap verify.

## [4.6.0] — 2026-04-14

### Added
- **Cross-unit DCE with compaction** (`programs/cyrld.cyr`).
  cyrld now rebuilds merged `.text` keeping only functions reachable
  from some `_cyrius_init` root, remaps intra-module `E8`/`E9 rel32`
  targets against the new layout, and re-applies every `.rela.text`
  entry whose patch site lives in a surviving fn. Output is the same
  merged-segment ELF layout as beta2 (text + data + rodata + stub)
  but with dead code physically gone.
  Example on a 5-fn test where 2 fns are unreached:
  ```
  dce: 5 fns, 3 reached, 2 dead (76 bytes)
  compacted: 272 → 186 bytes (-86)
  ```
  The extra 10 bytes past the analysis delta come from entry-jump +
  fallback-stub preambles (5 + 3 bytes) attached to each dropped fn.
- **Compaction-aware symbol resolution**. `resolve_sym_va` now uses the
  FN table (`FN_MERGED_OFF`) for function symbols. Data / rodata
  section refs continue to use `MOD_DATA_BASE` / `MOD_RODATA_BASE`
  (those layouts don't change during compaction). `find_local_sym`
  (used for `_cyrius_init` entry lookup) also routes through FN table.
- **`remap_intra_module_calls`** — post-compaction pass that walks
  each reached fn's bytes, decodes each `E8`/`E9 rel32`, locates the
  original target fn in the same module from the old module-local
  offset, and writes the new rel32 against the compacted layout.
  Cross-module calls and data/rodata LEAs are re-patched by
  `apply_relocations` in a follow-up pass (those sites had their bytes
  reset to 0 by the copy-from-original step in `compact_text`).
- **Compaction-aware `apply_relocations`** — patch offset is derived
  from the host fn's `FN_MERGED_OFF` rather than a stale per-module
  `MOD_TEXT_BASE`. Relocations whose patch site falls in a dead fn are
  skipped entirely (bytes aren't in the output anyway).

### Shipped in this 4.6.0 cycle
- **Multi-file linker** (alpha1 → alpha3 → beta1 → beta2 → beta3 →
  GA): parse N `.o` files, merge symbol tables, resolve cross-unit
  references, apply relocations, emit runnable ET_EXEC with `_start`
  stub driving every module's `_cyrius_init`.
- **`.data` / `.rodata` merging** with section-symbol relocation
  resolution — mutable globals, initialized globals, and string
  literals survive cross-module linking.
- **cc3 object-mode fn body fix** — functions referenced only
  externally (no in-module caller) now emit full bodies in `.o`
  output. The name-bitmap DCE in `src/main.cyr` is now skipped in
  object mode (`kernel_mode == 3`).
- **Cross-unit DCE, analysis + compaction** — reachability from every
  `_cyrius_init` root via byte-scanned call graph; dead fns physically
  removed from the output.

### Validation
- Three end-to-end link tests all pass:
  - minimal cross-module call (`greet` + `call_greet`): exit 43.
  - data merge with init ordering (`counter`, `inc_counter`): exit 44.
  - rodata string literal (`"hi\n"` from one module, called from
    another): prints `hi`, exit 7.
- DCE correctness test: 3 functions in `d.cyr`
  (`inc_counter`, `never_called`, `also_never`), only `inc_counter`
  called from `m.cyr` — linked binary compacts text 272 → 186 bytes,
  still exits 44. Live functionality preserved after bytes shift.
- cc3 self-host stable (two-step bootstrap byte-identical).
- 5/5 check.sh PASS. 41 test suites green.
- `build/cyrld` = 891 KB (FN tables still at fixed 8192 slots — known
  follow-up item; migration to `alloc()` is a bookkeeping cleanup).

### Known limits (4.6.0)
- Single `PT_LOAD RWX` — W^X not enforced. Multi-segment layout
  (separate RX / RW / RO PT_LOADs) comes in a later minor.
- Section headers omitted from output; `objdump -d` returns empty.
  Binary runs correctly — this is cosmetic.
- `.bss` not merged (cc3 currently zero-inits via `.data`).
- cyrld's FN tables live in `var T[8192]` static storage (~530 KB).
  Migration to `alloc()` deferred.

### Next
- 4.6.1: RELOC bookkeeping cleanup (alloc-backed FN tables, section
  headers in ET_EXEC output).
- 4.7.0: PIC codegen (per roadmap).
- 4.8.0: Types + register allocation.

## [4.6.0-beta3] — 2026-04-14 (unreleased)

### Added
- **Cross-unit DCE — analysis pass** (`programs/cyrld.cyr`).
  After merging + relocating, cyrld now builds a function table from
  every module's symtab, derives the call graph by byte-scanning the
  merged `.text` for `E8`/`E9 rel32` instructions, and BFS-marks
  reachability starting from every module's `_cyrius_init` (all roots,
  since `_start` calls them all). Reports unreachable functions + total
  dead bytes in the merge summary:
  ```
  dce: 5 fns, 3 reached, 2 dead (76 bytes)
  ```
- **Function table**: `FN_NAMEP` / `FN_MODULE` / `FN_MOD_OFF` /
  `FN_MOD_END` / `FN_MERGED_OFF` / `FN_MERGED_END` / `FN_REACHED` /
  `FN_IS_INIT` (indexed 0..`FN_COUNT-1`, max 8192). Includes
  end-offset computation — for each fn, its end is the next fn's
  start in the same module, or the module's `.text` size.
- **Naive E8/E9 byte scan** — walks every reached function's byte
  range, picks up both intra-module calls (cc3 patches these at fixup
  time; no `.rela.text` entry) and inter-module calls (patched by
  `apply_relocations`). Over-approximates reachability when immediate
  bytes happen to match `E8`/`E9`, which is safe for DCE (we keep
  more than strictly needed, never drop a live function).

### Why analysis-only for beta3
The analysis itself is the hard part. Compaction is bookkeeping on
top — reassigning new offsets per reached fn, copying bytes, fixing
up intra-module rel32s that now cross different gaps, re-applying
`.rela.text` against the new layout + new DATA_VA / RODATA_VA.
Shipping analysis first means:
- Users see which of their functions are unused *right now*.
- We validate the call graph against real downstream binaries (the
  over-approximation should mark everything reachable in
  correctly-written code; any incorrect "dead" flag surfaces a bug).
- Compaction lands as an isolated follow-up (GA or 4.6.1) with
  confidence the reachability set is correct.

### Validation
- Test with 3 globals in `d.cyr` (`inc_counter`, `never_called`,
  `also_never`) and 2 `inc_counter()` calls from `m.cyr`:
  `5 fns, 3 reached, 2 dead (76 bytes)`. `never_called` and
  `also_never` are correctly identified as unreachable; the linked
  binary still exits `44` with the two live functions wired up.
- cc3 self-host stable (two-step bootstrap byte-identical).
- 5/5 check.sh PASS. stdlib untouched — compiler fix was in
  4.6.0-beta2.
- `build/cyrld` = 820 KB (the FN table at 8192 slots is ~530 KB of
  static data; known gotcha, to be migrated to `alloc()` later).

### Next
- Compaction pass: rebuild merged `.text` keeping only reached fns,
  update all in-text rel32s + re-apply `.rela.text` against the new
  layout. Target binary size win visible on kybernet (486 KB → est.
  150-200 KB).
- Migrate `FN_*` tables off `var T[N]` to `alloc()`.

## [4.6.0-beta2] — 2026-04-14 (unreleased)

### Added
- **`.data` / `.rodata` merge** (`programs/cyrld.cyr`).
  cyrld now concatenates each module's `.data` and `.rodata` in the
  merged output, assigns per-module bases, and wires section-symbol
  relocations into final VAs. Layout of the emitted ELF:
  `[text | data | rodata | _start]` — 8-byte aligned, single `PT_LOAD RWX`
  segment at `0x400000`. Mutable globals, initialized globals, and string
  literals now survive cross-module linking.
- **Section-symbol reloc resolution** — `resolve_sym_va` recognizes
  `STT_SECTION` and maps `st_shndx` to the module's `.text`, `.data`,
  or `.rodata` merged base. Addend encodes the in-section offset (cc3
  convention: `.data + N`, `.rodata + N`).
- **Multi-init `_start`** — the stub now calls every module's
  `_cyrius_init` in *reverse* cmdline order (deps first, cmdline-arg-0
  last). The last call's return value pipes to `exit`. This makes
  cmdline-arg-0 the de-facto "main" and ensures dep globals are
  initialized before main code runs.
- **`MOD_TEXT_SHNDX` / `MOD_DATA_SHNDX` / `MOD_RODATA_SHNDX`** —
  per-module section index lookup, populated during `load_module` so
  reloc resolution can ask "is section N in module `mi` the data
  section?" in one compare.

### Fixed (cc3 writer bug surfaced by beta1)
- **Object-mode function bodies no longer elided** (`src/main.cyr`).
  cc3's name-bitmap DCE was dropping the body of any function whose name
  didn't appear as a non-`fn` identifier in the token stream — fine for
  whole-program compiles, fatal for `.o` files where callers live in
  other modules. The symbol was emitted pointing to the
  `xor eax,eax; ret` fallback stub. Now: DCE is skipped entirely in
  object mode (`kernel_mode == 3`). Fixed:
  `fn greet() { return 42; }` now links + runs correctly without a
  dummy in-module caller as crutch.

### Validation
- Minimal two-file cross-module test: `a.cyr` defines
  `fn greet() { return 42; }`, `c.cyr` defines `call_greet` and top-level
  `var result = call_greet()`. Linked with `cyrld -o linked c.o a.o`,
  exits `43`. No more `greet_twice` crutch needed.
- `.data` test: `d.cyr` has `var counter = 42; fn inc_counter() { ... }`,
  `m.cyr` has `var r1 = inc_counter(); var r2 = inc_counter(); var r = r2;`.
  Linked exits `44` (d's init runs first, sets counter to 42; m's
  two calls bump to 43, 44; `r = r2 = 44`).
- `.rodata` test: `syscall(1, 1, "hi\n", 3)` from one module called by
  another — `hi` prints, program exits cleanly.
- cc3 self-host stable (two-step bootstrap: cc3 → cc4, cc4 → cc5,
  cc4 == cc5 byte-identical).
- 5/5 check.sh PASS.

### Known limits (beta2)
- `.bss` not merged yet (no cc3 emission either — cc3 currently puts
  zero-init globals in `.data`).
- Single `PT_LOAD RWX` — data is executable, code is writable. Doesn't
  matter for correctness but loses W^X. Multi-segment layout (RX + RW
  + RO) comes later.
- Section headers still omitted from the output; `objdump -d` returns
  empty. Only relevant for debugging — the binary runs.

### Next
- Cross-unit DCE against the final symbol graph (4.6.0 GA target).
- Multi-segment PT_LOAD (RX text + RW data + RO rodata).

## [4.6.0-beta1] — 2026-04-14 (unreleased)

### Added
- **cyrld emits runnable ET_EXEC** (`programs/cyrld.cyr`).
  `cyrld -o <out> a.o b.o ...` now produces an executable binary that
  loads at VA `0x400000` and actually runs.
  - 64 B ELF header + 56 B program header (single `PT_LOAD` RWX at
    `0x400000`, `p_align=0x1000`) + merged `.text` + 14 B `_start` stub.
  - `_start` stub: `call _cyrius_init` of the first module, then
    `mov edi, eax; mov eax, 60; syscall` — return status of top-level
    code becomes the exit code. Needed because `_cyrius_init` ends with
    `leave; ret`; returning to the kernel-supplied stack top (argc)
    would SIGSEGV.
  - `find_local_sym(mi, name)` — resolves a `STB_LOCAL` symbol (needed
    because 4.6.0-alpha2 made `_cyrius_init` module-private).
  - `emit_executable(out_path)` — writes the file via
    `sys_open(O_WRONLY|O_CREAT|O_TRUNC, 0755)` + `sys_write` loop +
    `sys_close`, `chmod +x` best-effort.
- **`-o` CLI flag** — without it, cyrld just dumps + validates
  (alpha3 behavior preserved).

### Validation
- Merge of `a.o` (`greet` returns 42, kept live by `greet_twice`)
  and `c.o` (`call_greet` = `greet() + 1`, top-level
  `var result = call_greet()`): linked binary exits `43`.
  Cross-module call resolves correctly; entry stub wires
  `_cyrius_init` return → exit status.
- cc3 self-host stable (two-step bootstrap: cc3 compiles itself
  byte-identical).
- Build: 353KB compiler unchanged; cyrld = 217KB.

### Known limits (beta1)
- Code-only — `.data`/`.rodata`/`.bss` not merged. Top-level globals
  work *only* if they stay within the caller's stack frame (currently
  the case for simple `var x = fn()` because cc3 emits the global's
  address as a PC-relative LEA that, with no `.data` section, resolves
  to the start of `.text`; harmless for read-and-return flow).
- Multi-globals that cross modules will break until `.data` merging lands
  in beta2. Same story for string literals / `.rodata`.
- Surfaced `cc3` object-mode bug: functions only referenced externally
  (no in-module caller) get an elided body — the symbol points to the
  fallback `xor eax,eax; ret` stub. Fix tracked for 4.6.0-beta2.

### Next (beta2)
- Merge `.data` / `.rodata` / `.bss` into separate segments
  (RW and RO PT_LOADs).
- Fix cc3 object-mode elision of externally-referenced functions.
- Emit real section headers so `objdump -d` works without warnings.

## [4.6.0-alpha3] — 2026-04-14 (unreleased)

### Added
- **cyrld builds merged `.text` + applies relocations** (`programs/cyrld.cyr`).
  After symbol merge, cyrld now:
  - Allocates `MERGED_TEXT` of size = sum of all per-module `.text` sizes.
  - Concatenates each module's `.text` at its assigned base offset.
  - Walks every module's `.rela.text`, resolves the target symbol to a
    final VA (`ENTRY_VA=0x400078 + merged_text_offset`), and patches the
    rel32/i64 value at the patch site.
  - Supports `R_X86_64_PC32`, `R_X86_64_PLT32` (formula `S + A - P`),
    `R_X86_64_64` (formula `S + A`).
  - Errors on `R_X86_64_GOTPCREL` — requires a GOT, not supported in
    static-link alpha. Other unknown types also flagged.
- **`resolve_sym_va(mi, sym_idx)`** — maps a module-local symbol index
  to its final VA, via the global symbol table for cross-unit refs or
  directly for module-local `STB_LOCAL` symbols.
- **Tail-16 hex dump** in the merge report — quick eyeball check that
  epilogue bytes (`C9 C3`) and recent reloc patches look sane.

### Validation
- Merge of `a.o` (defines `greet`, `add`) and `c.o` (calls `greet`):
  1 relocation applied, exits 0. Epilogue `C9 C3` visible in tail dump.
- cc3 self-host unchanged.
- 5/5 check.sh.

### Next (beta1)
- Wrap `MERGED_TEXT` in a PT_LOAD ET_EXEC ELF header, select the right
  entry point (`_cyrius_init` from the first module, or a user-specified
  `_start`), write the executable to disk. That's the first run-capable
  linker output.

## [4.6.0-alpha2] — 2026-04-14 (unreleased)

### Added
- **cyrld multi-file merge** (`programs/cyrld.cyr`). Loads N .o files,
  concatenates `.text` (assigns each module a base offset in merged
  output), walks every module's symtab to build a combined global
  symbol table, and classifies each symbol as defined/weak/undefined.
  Reports the merge plan — per-module .text sizes + bases, total merged
  size, per-symbol resolution (`def/weak/UND [mod + offset → final]`).
- **Error detection**: unresolved reference (symbol UND in every module
  that mentions it), duplicate-strong definition (two GLOBAL defs of the
  same name). Strong beats weak beats unresolved in the merge rules.

### Fixed (cc3 writer bugs surfaced by the linker)
- **Undefined symbols now emit `SHN_UNDEF`** (`src/backend/x86/fixup.cyr`).
  `EMITELF_OBJ` was emitting every function symbol with `st_shndx=1`
  regardless of whether the fn had a definition in the module, pointing
  "undefined" references at .text offset 0. A merged binary with two
  such .o files looked like duplicate-strong definitions of the same
  extern. Now: `st_shndx=0, st_value=0` when `fn_offset < 0` (true undef).
- **`_cyrius_init` is now `STB_LOCAL`** — it's module-private (each .o
  has its own init wrapper for top-level code), not a cross-unit symbol.
  Was GLOBAL; merging two objects showed two `_cyrius_init` as duplicate.
  (ELF requires locals before globals; cyrld tolerates the current tail
  placement. Strict reorder is alpha3+.)

### Next
- **alpha3**: apply relocations against the merged symbol table.
- **beta1**: wrap output in PT_LOAD ET_EXEC, runnable binary.

## [4.6.0-alpha1] — 2026-04-14 (unreleased)

### Added
- **`programs/cyrld.cyr`** — multi-file linker scaffold. alpha1 scope:
  parse ET_REL (.o) files written by `EMITELF_OBJ`, validate ELF64
  header, walk section headers, dump symtab + relocation table.
  Handles all sections `cyrius build -c` produces: `.text`, `.data`,
  `.rodata`, `.symtab`, `.strtab`, `.rela.text`. Output matches
  `readelf -S`/`-s`/`-r` on the same files.
- Reloc-type classification: `R_X86_64_64`, `R_X86_64_PC32`,
  `R_X86_64_PLT32`, `R_X86_64_GOTPCREL` (the four types cc3 emits).
- Symbol-type classification: bind (LOCAL/GLOBAL/WEAK) and type
  (NOTYPE/FUNC/SECTION) from `st_info`; `UND` for undefined symbols.

### Next alphas
- **alpha2**: read N .o files, merge symtabs, resolve cross-unit
  references, flag unresolved + duplicate-strong.
- **alpha3**: apply relocations on the merged .text.
- **beta1**: emit ET_EXEC executable (ET_DYN / PIC stays with v4.7.0).
- **4.6.0**: cross-unit DCE, `cyrius build -c` workflow, docs + tests.

## [4.5.1] — 2026-04-14

### Added
- **`lib/ws_server.cyr`** — WebSocket server primitives in the stdlib.
  Companion to `lib/ws.cyr` (client-only, sends MASKED) and
  `lib/http_server.cyr` (HTTP — landed in 4.5.0). Server-side inverts
  the masking rule: reads MASKED frames (RFC 6455 client→server), sends
  UNMASKED frames (server→client).
  Surface:
  - `ws_server_handshake(cfd, req_buf, req_len)` — validates upgrade
    request, computes `Sec-WebSocket-Accept = base64(sha1(key + magic))`,
    sends 101 Switching Protocols, returns a 24-byte ws handle (or 0 on
    bad request).
  - Frame I/O: `ws_server_recv_frame` (unmasks in place),
    `ws_server_send_frame`, high-level `ws_server_recv` / `_send_text`
    / `_send_binary` / `_send_ping` / `_send_pong` / `_send_close`.
  - Self-contained SHA-1 (~85 LOC) — used only for the Accept computation,
    avoids pulling in `lib/sigil.cyr` for one consumer.
  - Integration: runs INSIDE an `http_server_run` handler — upgrade +
    WS lifetime happen on the same cfd, no changes to `http_server.cyr`
    needed. Handler returns → socket closes.
- **Doc coverage** — 13 documented / 16 total (per-symbol prose for every
  public function; accessors, frame helpers, lifecycle).

### Why
bote v1.5+ MCP WebSocket transport needed server-side WS; so will majra
(push events over WS), vidya (live API), and any future RPC service.
Same "every project would hand-roll ~320 LOC of the same handshake +
frame plumbing" argument that justified `http_server.cyr` in 4.5.0.

Reference impl from `bote/docs/proposals/cyrius-stdlib-ws-server.md`,
landed after a `cyrfmt` normalization pass.

### Validation
- Smoke compile + run clean.
- End-to-end: spawned `ws_server_run` on `127.0.0.1:34568`, Python
  client completed the upgrade (got `101 Switching Protocols` with a
  valid `Sec-WebSocket-Accept`), sent a masked TEXT frame, received
  unmasked `echo: hello` back (opcode=1, len=11).
- cc3 self-host unchanged (stdlib-only addition; compiler not touched).
- 5/5 check.sh PASS.


## [4.5.0] — 2026-04-14

### Added
- **`lib/http_server.cyr`** — HTTP/1.1 server primitives in the stdlib.
  Companion to the existing `lib/http.cyr` (HTTP/1.0 client-only).
  Surface:
  - Status constants (`HTTP_OK`, `HTTP_NOT_FOUND`, `HTTP_INTERNAL`, …)
  - Request parsing: `http_get_method`, `http_get_path`, `http_find_header`
    (case-insensitive), `http_body_offset`, `http_content_length`
  - Path + query helpers: `http_path_only`, `http_url_decode`,
    `http_get_param` (auto-decoded), `http_path_segment`
  - Response builders: `http_send_status`, `http_send_response`,
    `http_send_204`
  - Chunked / SSE: `http_send_chunked_start`, `http_send_chunk`,
    `http_send_chunked_end`
  - Content-Length-aware request reading: `http_recv_request`
  - Server lifecycle: `http_server_run(addr, port, handler_fp, ctx)`
- **`tests/tcyr/http_server.tcyr`** — 31 assertions covering status codes,
  method/path/header parsing, body-offset detection, Content-Length
  parsing, case-insensitive header lookup, path-only stripping, URL
  decoding (alphanumeric, `%20`, `+`, `%2F`, lowercase hex), query-param
  extraction (with/without query string), path segmentation.

### Why
bote + vidya independently hand-rolled ~750 LOC of HTTP plumbing.
Shapes were nearly identical (`make_crlf`, parse path, send response,
accept loop). Lifting the common primitives into stdlib:
- Removes ~250 LOC from bote's `transport_http.cyr` and similar from
  `bridge.cyr` and vidya's `cmd_serve`.
- Gives every cyrius project Content-Length-aware reads, percent
  decoding, path segmentation, and chunked/SSE responses for free.
- Shrinks per-project fn counts — relevant to the libro-integration
  heisenbug where the cumulative allocator state at boundary was
  size-sensitive.

Reference impl authored by the bote team's proposal in
`bote/docs/proposals/cyrius-stdlib-http-server.md`; landed verbatim
after a `cyrfmt` normalization pass.

### Validation
- Unit tests: 31/31 pass on pure-parse helpers.
- End-to-end: spawned server on `127.0.0.1:34567`, verified `/hello`,
  `/echo?msg=hello%20world` (URL-decoded), and `/missing` (404 status).
- cc3 self-host: byte-identical.
- 5/5 check.sh PASS.

### Deferred (noted in proposal § "Open questions")
- Keep-alive responses (currently `Connection: close` on every reply) —
  needs non-blocking accept, target 4.6.0.
- Per-thread request buffers — currently process-global; revisit when
  Cyrius grows a threading story.
- Socket errors silently close the connection; future rev could log
  via `sakshi_warn` when `lib/sakshi.cyr` is in scope.

## [4.4.6] — 2026-04-13

### Closeout (4.4.x)
Last patch of the 4.4.x series before 4.5.0 opens the multi-file linker
cycle. Per CLAUDE.md's closeout-pass doctrine.

- **Self-host verified** — cc3 compiles itself byte-identical (353,280
  bytes, two-step bootstrap clean).
- **Bootstrap closure verified** — seed (29KB) → cyrc (12KB) → asm → cc3.
- **Heap map clean** — 47 regions, 0 overlaps, `tests/heapmap.sh` PASS.
- **Dead code count**: 6 unreachable fns (4,824 bytes) with the v4.4.5
  decoder-validated DCE. Down from the 4.2.5 closeout baseline of 266,
  driven by the byte-scan call graph + tail-call E9 detection added in
  4.4.0.
- **Downstream sync**: all 10 projects (kybernet, argonaut, nein, sigil,
  libro, daimon, hoosh, agnoshi, bote, kavach) pinned to 4.4.5 ahead
  of this closeout.
- **Security re-scan**: 1 `sys_system` caller (cyrius deps git clone,
  CVE-01 validated), all `READFILE` callers in compiler paths with
  bounded buffers. No new attack surface since the 4.2.x audit.
- **Doc sync** — `docs/architecture/cyrius.md` refreshed from v4.0.0
  stats (303KB cc3, 8 modules, 36 tests, 6 downstream) to current
  state (353KB, 9 modules, 40 tests, 10 downstream).
- **5/5 check.sh** — all lint, format, test, heap, self-host checks PASS.

### Summary of 4.4.x cycle
- 4.4.0: fn_end tracking, byte-scan call graph, mark-and-sweep DCE,
  opt-in NOP-fill gated on `CYRIUS_DCE=1`.
- 4.4.1: `&&`/`||` short-circuit fix (bote silent-miscompile),
  `cyrius deps` absolute symlink fix (kavach porting).
- 4.4.2: `var buf[N]` overflow names offending var, `<source>` file
  map marker for parse errors outside includes.
- 4.4.3: `fmt_int_fd`/`efmt_int`, cyrlint rule for `is_err` clash.
- 4.4.4: Third DCE safety gate (epilogue `C9 C3`) — **2× bytes NOPed**
  on libro, -41% gzip cumulative.
- 4.4.5: x86-64 length decoder, DCE validator uses it, foundation
  for 4.5.x CFG work.
- 4.4.6: closeout.

## [4.4.5] — 2026-04-13

### Added
- **x86-64 length decoder** (`src/backend/x86/decode.cyr`, ~280 lines).
  Port of Nomade040's ldisasm scoped to Cyrius's emission subset.
  Public functions: `DECODE_LEN(buf, off)` returns instruction byte
  length (0 = undecodable), `CLASSIFY_CF(buf, off)` returns control-flow
  class {fallthrough, JMP, Jcc, CALL, RET, indirect/unknown}, and
  `CF_TARGET(buf, off, kind)` extracts the rel32/rel8 target for
  branches. Full prefix + REX handling, ModR/M length tables, common
  immediate sizings. Foundation for the byte-walking CFG (4.5.x),
  PatraStore Heisenbug diagnosis, and future register allocation.
- **DCE validation pass uses the decoder**
  (`src/backend/x86/fixup.cyr`). Before NOP-filling a fn whose safety
  gate passed, the validator walks its body with `DECODE_LEN`. If any
  byte position is undecodable OR the walk overshoots `fn_end` (partial
  instruction), the fn is REFUSED for NOPing. Fail-safe: protects
  against `asm{}` blocks, future codegen we don't recognize yet, or
  stray bytes that shouldn't be inert.
- **`tests/tcyr/decode.tcyr`** — DCE-with-validator smoke test. 3
  assertions confirming the live path stays correct when surrounding
  dead fns get NOPed.

### Results
- libro under CYRIUS_DCE=1: 187,499 → **177,809 bytes NOPed** (slightly
  more conservative — validator skips ~10KB of fns containing bytes
  outside the decoder's subset). All 204 tests still pass.
- libro gzip: 39,220 → 40,984 bytes (small regression, acceptable trade
  for fail-safe).
- cc3 self-host: byte-identical at 353,280 bytes.
- 5/5 check.sh PASS.

### Deferred (still open)
- libro PatraStore Heisenbug diagnosis. Decoder is in place; using it
  to walk from main entry and trace data flow into the corrupted Str
  is heavier than a single 4.4.x patch. Stays parked for 4.5.x where
  the linker work provides cross-unit symbol visibility.

## [4.4.4] — 2026-04-13

### Added
- **Third DCE safety-gate rule: epilogue-terminator check**
  (`src/backend/x86/fixup.cyr`). Every Cyrius function ends with
  `C9 C3` (`leave; ret`) — EFNEPI emits this unconditionally. The new
  check accepts a fn for NOP-fill when its last two bytes at
  `fn_end - 2` are `C9 C3`. Combined with the byte-scan reachability
  already confirming no caller reaches the fn, the body is provably
  inert. This covers the ~half of eligible-but-skipped fns that lacked
  the pre-body safety patterns (RET-before or JMP-over preamble) —
  mostly pass-1-emitted fns and enum constructors.

### Results
- **libro DCE actioned bytes: 94,292 → 187,499 (+99%)**. All 204 tests
  still pass.
- **libro gzip: 54,627 → 39,220 bytes (-28%)**. Cumulative vs 4.3.x
  baseline: 66,525 → 39,220 (-41%).
- cc3 self-host: byte-identical.
- 5/5 check.sh PASS.

### Why this is the right fix (not a full length decoder)
- Researched (vidya `instruction_encoding`) the ldisasm-style minimal
  length decoder as Plan A. Implementation would be ~150 Cyrius lines.
- Empirical observation on cc3's own emitted binary: every fn body
  ends with `C9 C3` exactly. No exceptions across 315 fns.
- A 4-line pattern match on the terminator captures the same signal
  with zero decoder complexity. Full ldisasm stays in the back
  pocket for when we need per-instruction boundaries (register alloc,
  PatraStore Heisenbug diagnosis in 4.5.x).

## [4.4.3] — 2026-04-13

### Added
- **`fmt_int_fd(fd, n)` and `efmt_int(n)` in `lib/fmt.cyr`** (bote
  feedback item 7). `fmt_int` always writes to stdout; mixing it with
  stderr diagnostic writes produces interleaved output in logs. The new
  variants route decimal output to an arbitrary fd — `efmt_int(n)` is
  the stderr shorthand for `fmt_int_fd(2, n)`. Non-breaking addition.
- **`cyrlint` rule for `is_err` naming clash** (`programs/cyrlint.cyr`,
  bote feedback item 5). When a file includes BOTH `lib/syscalls.cyr`
  (where `is_err(ret)` checks `ret < 0`) and `lib/tagged.cyr` (which
  exposes `is_err_result(r)` for tagged Results), every bare `is_err(`
  call is ambiguous — applying the syscalls version to a Result heap
  pointer silently never catches errors. The new rule pre-scans for
  both includes, then warns on each `is_err(` usage with a disambiguation
  hint. Guarded against false-flagging `is_err_result` via preceding-
  identifier-char check.

## [4.4.2] — 2026-04-13

### Fixed
- **`var buf[N]` overflow error names the offending variable**
  (`src/backend/x86/fixup.cyr`). When total output exceeds 1MB, the error
  now walks the `var_sizes` table to find the top 3 largest vars by
  size and prints their names alongside byte counts. Previously the
  error just showed aggregate totals (`code:N data:M strings:K`) leaving
  the user to grep their source for the culprit. Surfaced by bote
  feedback item 4.
- **`file:line` for parse errors in main source without includes**
  (`src/frontend/lex.cyr`). `PP_PASS` now emits an initial `#@file
  "<source>"` marker at the top of preprocessed output unconditionally,
  so `FM_LOOKUP` always finds a file-map entry for main-source lines —
  not just when at least one include fires. Previously, errors in
  main source could fall through to the raw preprocessed line number
  (e.g. `error:1729: expected '=', got string`) with no file prefix.
  Surfaced by bote feedback item 6.

## [4.4.1] — 2026-04-13

### Fixed
- **`&&` / `||` now short-circuit** (`src/frontend/parse.cyr`). The prior
  impl in `PCMPE` evaluated both operands unconditionally via bitwise
  AND/OR — a silent miscompile of documented short-circuit semantics.
  Guarded null checks like `if (p != 0 && vec_len(p) > 0)` now skip the
  right side correctly when the left short-circuits. Implementation: each
  chain step emits `cmp rax, 0; je/jne skip_right; eval right; cmp 0;
  setne al; movzx; jmp end; skip_right: mov rax, 0-or-1; end:`. The
  previously-unreachable `ECOND_AND` / `ECOND_OR` paths remain (now
  trivially unreachable in a more obvious way). Surfaced by bote feedback
  item 2.
- **`cyrius deps` now creates absolute symlinks** (`programs/cyrius.cyr`).
  A relative `path = "../sigil"` in cyrius.toml used to produce a symlink
  `lib/sigil.cyr -> ../sigil/dist/sigil.cyr` that resolved against `lib/`'s
  parent, not the project root — so the target pointed at
  `{proj}/sigil/dist/sigil.cyr` (wrong) instead of the sibling repo.
  Silent failure: build passed, but calling into the dep gave
  `warning: undefined function 'hmac_sha256'`. New `_abs_path()` helper
  uses `getcwd(2)` to make every symlink target absolute before
  `symlink(2)`. Surfaced during kavach porting.

### Added
- **`tests/tcyr/short_circuit.tcyr`** — 13 assertions covering `&&` / `||`
  short-circuit semantics: side-effect ordering, guarded null check pattern
  (the bote regression), chain evaluation, expression-context use.
- **`tests/tcyr/shadowing.tcyr`** — 11 assertions covering fn-local scoping:
  reassignment, nested if / while / bare-block shadowing, sibling blocks,
  multi-layer nesting. Documents that top-level `var` creates globals
  (no scoping) — wrap in a fn for proper shadowing.
- **`benches/bench_shortcircuit.bcyr`** — 6 microbenchmarks measuring the
  short-circuit win: skip paths run ~21% faster than full-evaluation paths
  (413 vs 522 ns for `&&`, 404 vs 520 ns for `||`). Scales with RHS cost.

## [4.4.0] — 2026-04-13

### Added
- **`fn_code_end` tracking** (`src/common/util.cyr`, `src/frontend/parse.cyr`):
  `PARSE_FN_DEF` records `GCP` at function-body emission end into a new table
  at heap offset `0xE0000`. Paired with `fn_code_start` at `0xC4000`, this
  gives exact `[start, end)` ranges for every emitted function. New accessors
  `SFNE(S, fi, v)` / `GFNE(S, fi)`.
- **Byte-scan call graph** (`src/backend/x86/fixup.cyr`): scans the emitted
  code buffer for `E8 rel32` (direct call) AND `E9 rel32` (tail call /
  branch-to-fn) instructions, decoding their targets and matching against
  the fn_start table. This catches calls that `ECALLTO` emits directly
  without going through the fixup table — the fixup table alone is not a
  complete call graph.
- **Mark-and-sweep DCE** (`src/backend/x86/fixup.cyr`): reachability from
  entry using the byte-scan call graph. Seeds the live set from calls in
  entry/top-level code (outside all fn bodies) and type-3 (address-taken)
  fixups as conservative roots. Propagates through the call graph to
  fixpoint, then NOP-fills dead fn bodies when a safety gate is satisfied.
  Runs AFTER the fixup-patching loop so `rel32` bytes are resolved when
  decoded.
- **Two-pattern NOP-fill safety gate**: a dead fn body is safe to NOP
  when EITHER (a) the byte at `fn_start - 1` is `0xC3` (previous fn's RET
  — no fallthrough possible) OR (b) `fn_start - 5` holds `E9 rel32` whose
  target ≥ fn_end (explicit JMP-over). Either proves execution cannot enter
  the body via linear fallthrough.
- **`CYRIUS_DCE=1`** env var gate: opt-in NOP-fill. Off by default —
  report-only until the pass is battle-tested across downstream ports.
- **`tests/tcyr/dce.tcyr`** — smoke test verifying DCE-on compilation still
  runs correctly when unused fns are NOPed.

### Changed
- Roadmap reordered: multi-file linker → 4.5.0, PIC codegen → 4.6.0,
  Types (u128/defmt/jump-tables) → 4.7.0, macOS → 4.8.0, Windows → 4.9.0.
  Platform ports pushed back one slot each so PIC codegen lands before the
  platform emitters that need it. See `docs/development/roadmap.md`.
- Dead-function report replaced with mark-and-sweep `unreachable fns` count
  plus eligible-bytes estimate.

### Results
- **cc3 self-host**: 4 unreachable fns, 695 bytes eligible. Byte-identical
  self-host under `CYRIUS_DCE=1` on both sides.
- **libro**: 719/1160 fns unreachable (62%), 187KB eligible, 94KB actually
  NOPed under `CYRIUS_DCE=1`. All 204 tests pass. Gzipped binary: 66521 →
  54572 bytes (18% smaller release artifact).
- **5/5 check.sh** pass with the default (report-only) path.

### Known limitations (tracked for 4.4.x / 4.5.0)
- NOP-fill does not shrink binary size on disk (preserves offsets and
  self-host byte-identity). True shrinking via code-shifting relaxation
  is deferred — would break `cc3==cc3` byte-identity unless fully
  deterministic.
- Safety gate is conservative: dead fns without RET-before or JMP-over
  preamble (~half of eligible cases in libro) are skipped. A proper
  instruction-length decoder (researched in vidya `instruction_encoding`)
  would verify fallthrough safety for those cases too.
- libro PatraStore Heisenbug remains open — same 4.3.1 localization
  holds, fix waits on full byte-walking CFG.

## [4.3.3] — 2026-04-13

### Added
- **Named-field struct initializer syntax** (`src/frontend/parse.cyr`):
  `var p = Point { x: 10, y: 20 }` alongside the existing positional form
  `Point { 10, 20 }`. Fields can appear in any order; each must appear
  exactly once. Errors clearly at compile time: `unknown struct field in
  initializer`, `struct field initialized twice`, `missing struct field
  in initializer` — all with file:line via FM_LOOKUP. Nested-struct
  fields still require positional form (flattening by name is v4.4.0+).
- `GETFNAME(S, si, fi)` + `STREQTOK(S, a, b)` helpers for field-name
  lookup. Identifiers are interned by the lexer so direct offset equality
  usually hits; STREQTOK is the defensive fallback.
- **`.gitignore` scaffolding in `cyrius port`** (`scripts/cyrius-port.sh`):
  fresh ports get the standard cyrius `.gitignore` (mirrors
  `cyrius-init.sh`). If a Rust-project `.gitignore` is already present,
  `/rust-old/target/` and `/build/` are appended — prevents `cargo build`
  in the preserved Rust tree from dropping hundreds of MB of untracked
  artifacts into the port.

## [4.3.2] — 2026-04-13

### Fixed
- **`cyrius deps` now re-resolves when the cyrius.toml tag changes**
  (`programs/cyrius.cyr`). Previously the resolver cloned to an
  un-versioned cache path (`/tmp/cyrius_deps/{name}`) and bailed if the
  directory existed, so a tag bump in cyrius.toml left the stale cache
  in place and `lib/{name}.cyr` pointed at the old version. Cache layout
  is now tag-versioned: `$CYRIUS_HOME/deps/{name}/{tag}/` (falls back to
  `/tmp/cyrius_deps/{name}_{tag}` when CYRIUS_HOME is unset). Different
  tags produce different cache directories so a tag bump naturally
  triggers a fresh clone.

### Changed
- **Dep resolver creates symlinks into `lib/`** (`programs/cyrius.cyr`)
  instead of byte copies. Matches the legacy shell resolver's behavior
  and lets `scripts/check.sh` / `cyrius audit` correctly skip dep files
  as upstream-owned. Falls back to a byte copy if `symlink()` fails
  (e.g., FAT filesystems). Writes both `lib/{name}_{basename}`
  (namespaced, collision-safe) and — when the module basename exactly
  matches `{name}.cyr` — `lib/{name}.cyr` (canonical path for single-
  module deps like sigil, patra, yukti).

### Closeout (4.3.x)
- Self-host verified (cc3 = cc3, 325,936 bytes)
- Bootstrap closure verified (seed → cyrc → asm)
- Heap map clean (46 regions, 0 overlaps)
- Dead function count: 267/311 (86%, stable)
- check.sh: 5/5 PASS

## [4.3.1] — 2026-04-13

### Added
- **Symbol dump via `CYRIUS_SYMS` env var** (`src/backend/x86/fixup.cyr`):
  when set to a file path, cc3 writes `VA name\n` per function during
  fixup. Maps crash RIPs from coredumpctl/gdb to function+offset. Zero
  overhead when unset (env read skipped). Enabled the libro PatraStore
  Heisenbug localization: crash traced in minutes from `0x400219` →
  `memeq + 0x71`, caller → `str_eq`, chain → `test_patrastore_append_load`
  comparing corrupt `entry_hash()` results. Root cause still open (tracked
  for 4.4.0 CFG pass), but diagnosis is now a tool away.
- **`_read_env(name)`** helper in backend/x86/fixup.cyr: reads
  `/proc/self/environ`, returns pointer to NUL-terminated value or 0.
  Uses a 256-byte static scratch buffer (no heap needed in cc3).

## [4.3.0] — 2026-04-13

### Added
- **cyrius-lsp** (`programs/cyrius-lsp.cyr`): Language Server Protocol
  implementation in Cyrius. JSON-RPC 2.0 over stdio. Forks cc3 on
  didOpen/didSave/didChange, parses stderr for errors and warnings,
  sends LSP diagnostics. 44KB binary, zero dependencies.
- **`\r` escape sequence** (`src/frontend/lex.cyr`): string literals now
  support `\r` (carriage return, byte 13). Joins `\n \t \0 \\ \"`.
- **`cyrius lsp`** subcommand (`programs/cyrius.cyr`): builds and installs
  cyrius-lsp to CYRIUS_HOME/bin/.
- **Editor configs** (`editors/`): VS Code extension (language grammar,
  LSP client, bracket matching) and Neovim LSP configuration.

## [4.2.5] — 2026-04-13

### Changed
- **Closeout pass** — stale version comments cleaned (aarch64 heap map,
  util.cyr). Self-host verified, bootstrap closure verified, 5/5 check.sh.
  Dead code: 266/310 unused functions in compiler (86% — DCE motivation).
  Closeout process formalized in CLAUDE.md for all future minor/major bumps.

## [4.2.4] — 2026-04-13

### Security
- **CVE-06: String data bounds checking** (`src/frontend/lex.cyr`): lexer
  now checks `spos >= 262144` before every string literal byte write.
  Errors instead of silently corrupting the next heap region.
- **CVE-09: Jump target table overflow warning** (`src/backend/x86/jump.cyr`):
  warns when table hits 1024 entries. LASE automatically disabled for that
  function (overflow count > 1024 prevents IS_JUMP_TARGET false negatives).

## [4.2.3] — 2026-04-13

### Security
- **CVE-02: Path traversal protection** (`src/frontend/lex.cyr`): `READFILE`
  now rejects paths containing `..` components. Prevents `include "../../../etc/passwd"`.
- **CVE-03: Include-once table overflow** (`src/frontend/lex.cyr`): was
  silent return on overflow (65th file ignored). Now errors with message.
  Prevents silent duplicate symbol corruption.
- **CVE-04: Dep write path validation** (`programs/cyrius.cyr`): `_dep_copy_file`
  rejects destinations containing `..`. Prevents crafted cyrius.toml from
  writing outside `lib/`.

## [4.2.2] — 2026-04-13

### Security
- **CVE-01: Git URL sanitization** (`programs/cyrius.cyr`): dep resolver
  rejects git URLs/tags containing shell metacharacters (`;|`$&()`).
  Prevents command injection via malicious `cyrius.toml`.
- **CVE-08: Direction flag safety** (`lib/string.cyr`): `cld` before
  `rep movsb`/`rep stosb`. Prevents corruption if DF set by signal handler.
- **CVE-10: Temp file race fix** (`programs/cyrius.cyr`): PID-based temp
  path (`/tmp/cyrius_cpp_{pid}`) replaces predictable path.

### Added
- **Security audit report** (`docs/audit/2026-04-13-security-audit.md`):
  13 findings — 3 critical, 3 high, 4 medium, 3 low. Action items
  organized into v4.2.2–v4.2.4 and v4.3.x.

## [4.2.1] — 2026-04-13

### Changed
- **`cyrius port` updated** (`scripts/cyrius-port.sh`): generates modern
  project structure — `cyrius.toml` with `[package]`/`[build]`/`[deps]`,
  `.cyrius-toolchain`, CI + release workflows, no manual stdlib includes.
  Source skeleton uses auto-include. `--dry-run` support. Next steps point
  to `cyrius build` not raw cc3.
- **`cyrius init` updated** (`scripts/cyrius-init.sh`): generates test
  (`tests/{name}.tcyr`), bench (`tests/{name}.bcyr`), and fuzz
  (`tests/{name}.fcyr`) files. Source skeleton uses auto-include (no manual
  stdlib includes). Removed old shell script build/test files. Toolchain
  default updated to 4.2.1.
- **`install.sh` updated** (`scripts/install.sh`): builds `cyrius` tool from
  `programs/cyrius.cyr` (not shell script copy), fallback version 1.8.5→4.2.1,
  stale cc2 naming fixed.

## [4.2.0] — 2026-04-13

### Added
- **Jump target tracking** (`src/backend/x86/jump.cyr`): `EJMP` and `EPATCH`
  now record jump targets at `S+0x9E000` (up to 1024 per function). Table
  reset per function in PARSE_FN_DEF. Foundation for basic-block analysis.
- **LASE — load-after-store elimination** (`src/frontend/parse.cyr`): eliminates
  redundant `mov rax, [rbp-N]` immediately after `mov [rbp-N], rax` when the
  load is NOT a jump target. Uses the jump target table to safely skip loads
  that are loop back-edge targets. Fixes the v3.8.1 LASE bug that broke loops.
- **`IS_JUMP_TARGET(S, off)`** helper for codebuf offset lookup.

### Notes
- This is the beginning of control-flow analysis. Jump targets = basic block
  entry points. The data structure enables future register allocation and
  the Heisenbug diagnosis.
- Two-step bootstrap required (LASE changes the compiler's own codegen).

## [4.1.3] — 2026-04-13

### Changed
- **Cleanup/audit pass**: stale version-tagged comments cleaned across parse.cyr,
  lex.cyr, util.cyr (removed `v3.5.0`, `v3.6.0`, `v3.6.1`, `v3.4.16` tags —
  replaced with descriptive labels). Heap map in main.cyr updated with file_map
  regions (0x9A108, 0x9D000). Bootstrap closure verified. No dead util functions.
  5762 lines across parse.cyr + lex.cyr (was 5765 — minor comment cleanup).

## [4.1.2] — 2026-04-13

### Changed
- **Fast memcpy/memset** (`lib/string.cyr`): replaced byte loops with `rep
  movsb` / `rep stosb` inline assembly. Hardware-optimized on modern x86 CPUs.
  ~30x faster for 128-byte copies (369ns → ~10ns). Every program that copies
  buffers benefits — alloc, vec, str, hashmap all use memcpy/memset internally.

## [4.1.1] — 2026-04-13

### Added
- **Dead function warning** (`src/backend/x86/fixup.cyr`): reports the number
  of defined-but-uncalled functions at fixup time. Uses a bitmap scan of the
  fixup table to identify which functions have call sites. Output:
  `note: 101 unused functions (102 total)`. Quantifies the dead code tax
  from included-but-unused stdlib. Foundation for future dead-code elimination.

## [4.1.0] — 2026-04-13

### Added
- **File:line error messages** (`src/frontend/lex.cyr`, `src/common/util.cyr`,
  `src/frontend/parse.cyr`): errors and warnings now show the source file and
  line number instead of raw expanded line indices. The preprocessor emits
  `#@file "filename"` markers before each included file's content. `FM_BUILD`
  scans the preprocessed buffer to build a file map with line ranges.
  `FM_LOOKUP` resolves any expanded line to `file:line` at error time.
  A `#@file "<source>"` marker is emitted before the user's code to
  distinguish it from included files.
  - `error:lib/alloc.cyr:42: undefined variable 'x'` — error in stdlib
  - `error:<source>:7: unexpected '{'` — error in user's code
  - All 12 error/warning call sites updated (util.cyr + parse.cyr + aarch64 emit)

### Stats
- **cc3: 309KB** (was 303KB — file map + marker emission adds ~6KB)
- 102 regression assertions, 5/5 check.sh

## [4.0.0] — 2026-04-13

Major release. The toolchain is complete — compiler, build tool, dep system,
CI scaffolding, undefined function diagnostic, compound assignment, negative
literals. 6 downstream projects shipping on the toolchain. Bootstrap verified.

### Since 3.6.3 (last major arc boundary)

**Language:**
- `#derive(accessors)` — auto-generate field getters/setters (v3.7.1)
- `return (a, b)` / `var x, y = fn()` — native multi-return (v3.7.2)
- `case N: { ... }` — switch case blocks with scoped variables (v3.7.4)
- Defer on all exit paths — per-defer runtime flags (v3.8.0)
- `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=` (v3.10.3)
- Negative literals: `-1`, `-x`, `-(expr)` (v3.10.3)
- Undefined function diagnostic at fixup time (v3.10.0)

**Toolchain:**
- `cyrius build` auto-resolves deps from `cyrius.toml` + auto-prepends includes
- `cyrius deps` — stdlib + named deps, namespaced `lib/{depname}_{basename}`
- `cyrius init` — scaffolds project with `.cyrius-toolchain`, CI, release workflows
- `--dry-run` on build/run/test/init/port/deps/clean
- `-v` verbose flag (compiler path, binary size)
- `#skip-lint`, line limit 100→120, brace tracking skips strings/comments
- `CYRIUS_HOME` env var, git clone fallback for CI deps
- Release pipeline builds cyrius tool from source, follows lib symlinks

**Compiler internals:**
- DSE pass extracted, derive struct parser dedup (-147 lines)
- aarch64 heap map synced with x86, arch-agnostic codegen helpers
- Bootstrap compiler renamed: stage1f → **cyrc**

**Ecosystem:**
- kybernet 1.0.1, argonaut 1.2.0, ai-hwaccel 2.0.0, hadara 1.0.0, hoosh 2.0.0, avatara 2.3.0

### Stats
- **cc3: 302,824 bytes** (was 290,040 at v3.6.3)
- **102 regression assertions** (was 70)
- **36 test suites**, 5 fuzz harnesses, 5/5 check.sh
- **Bootstrap:** seed (29KB) → cyrc (12KB) → bridge → cc3 (303KB). Closure verified.
- **Self-compile:** 117ms
- **aarch64:** 268KB cross-compiler, 0 undefined functions

## [3.10.3] — 2026-04-13

### Added
- **Compound assignment operators** (`src/frontend/parse.cyr`): `+=`, `-=`,
  `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`. Works in assignments
  and `for` loop steps (`for (var i = 0; i < n; i += 1)`). Fixes Gotcha #6.
- **Negative integer literals** (`src/frontend/parse.cyr`): unary minus in
  expression position. `-1`, `-x`, `-(a + b)`. Constant folding for `-NUM`.
  Fixes Gotcha #7.
- 15 new regression assertions (102 total).

## [3.10.1] — 2026-04-13

### Fixed
- **aarch64 width-aware load encodings** (`src/backend/aarch64/emit.cyr`):
  `EFLLOAD_W` used wrong opcode bit (`0x3850` instead of `0x3840` for ldurb).
  Invalid instruction caused SIGSEGV under QEMU. Caught by the v3.10.0
  undefined function diagnostic during the release build.
- **`cyrius build` auto-creates output directory** (`programs/cyrius.cyr`):
  `cyrius build src/main.cyr build/app` now creates `build/` if missing.
  Previously failed silently when the output directory didn't exist.
- **Release aarch64 smoke test** (`.github/workflows/release.yml`): tests
  cross-compiler output instead of native-under-QEMU. Native binary tested
  on real ARM hardware.

### Added
- **Compound assignment operators** (`src/frontend/parse.cyr`): `+=`, `-=`,
  `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`. Desugars at parse time:
  load var, push, eval expr, op, store. Works in assignments and `for` loop
  steps (`for (var i = 0; i < n; i += 1)`). Fixes Known Gotcha #6.
  9 new regression assertions.
- **Negative integer literals** (`src/frontend/parse.cyr`): unary minus in
  expression position. `-1`, `-x`, `-(a + b)` now work directly. Constant
  folding for `-NUM`. General case emits `0 - rax` via push/sub. Fixes
  Known Gotcha #7. 6 new regression assertions.

### Changed
- **Recommended minimum: v3.10.0** — auto-include, `cyrius deps`,
  `.cyrius-toolchain`, undefined function diagnostic. All downstream
  projects updated: kybernet 1.0.1, argonaut 1.2.0, ai-hwaccel 2.0.0,
  hadara 1.0.0, hoosh 2.0.0, avatara 2.2.0.

## [3.10.0] — 2026-04-13

### Added
- **Undefined function diagnostic** (`src/backend/*/fixup.cyr`): the fixup
  pass now scans for functions that are called but never defined. Previously,
  calling a non-existent function compiled silently and crashed at runtime
  (SIGILL/SIGSEGV jumping to address 0). Now emits:
  `error: undefined function 'bad_func' (will crash at runtime)`
  Implemented as a warning (binary still emitted for backward compat) —
  downstream projects can grep stderr for "undefined function" in CI.
  Catches typos like `assert_report()` vs `assert_summary()` that previously
  took hours to debug.

### Fixed
- **aarch64 backend: missing width-aware functions** (`src/backend/aarch64/emit.cyr`):
  `EFLLOAD_W`, `EFLSTORE_W`, `EVLOAD_W`, `EVSTORE_W`, `_IS_OBJ` were only
  defined in the x86 backend. The aarch64 cross-compiler crashed (SIGSEGV
  under QEMU) because these functions were called from shared `parse.cyr` but
  resolved to address 0. The new undefined function diagnostic caught this —
  first real bug found by the diagnostic.

### Stats
- **cc3: 299,448 bytes**, 36 test suites, 5/5 check.sh

## [3.9.8] — 2026-04-13

### Added
- **`cyrius init` generates `.cyrius-toolchain`** — pins the Cyrius version
  for CI/release workflows. Both `ci.yml` and `release.yml` read from this
  file: `CYRIUS_VERSION="${CYRIUS_VERSION:-$(cat .cyrius-toolchain)}"`.
  Override with `CYRIUS_VERSION` env var for manual pinning.
- **`cyrius init` generates `release.yml`** — complete GitHub release workflow
  with CI gate, version verification, build, and `softprops/action-gh-release`.
- **Updated `ci.yml` template** — uses release tarball instead of cloning and
  bootstrapping. Includes `cyrius deps` + `cyrius build` with auto-include.
- **Updated `cyrius.toml` template** — proper `[package]`/`[build]`/`[deps]`
  sections matching the v3.9+ format.

## [3.9.7] — 2026-04-12

### Added
- **`--dry-run` flag** on `build`, `run`, `test`, `init`, `port`, `deps`,
  `clean`. Shows what would happen without executing. Examples:
  `cyrius build --dry-run src/main.cyr build/app` → prints compile plan.
  `cyrius clean --dry-run` → lists files that would be deleted.
  `cyrius init --dry-run myproject` → lists files that would be created.

### Fixed
- **Release tarball stdlib packaging** (`scripts/release-lib.sh`): extracted
  lib staging into a shared script. Copies real files, follows valid symlinks,
  fetches dep bundles from GitHub when broken (CI). Replaces inline `cp -rL`
  that failed on broken symlinks pointing to local-only dep installs.

## [3.9.6] — 2026-04-12

### Fixed
- **`cyrius` tool reads `CYRIUS_HOME` env var** (`programs/cyrius.cyr`):
  `find_tools()` was reading only 256 bytes of `/proc/self/environ` — CI
  runners have large environments and `HOME` wasn't in the first 256 bytes.
  Now reads 32KB and also checks `CYRIUS_HOME` which overrides the default
  `~/.cyrius` path. Fixes "cc3 not found" on GitHub Actions CI.
- **`cyrius deps` git clone fallback**: when `path` in `[deps.name]` doesn't
  exist (CI environment), falls back to `git clone --depth 1 -b {tag} {git}`
  into `/tmp/cyrius_deps/{name}`. Enables dep resolution without sibling repos.
- **`cyrius deps` path fallback**: when `lib/libro/error.cyr` doesn't exist,
  tries `lib/error.cyr` (flat layout). Handles layout differences between
  tagged releases and local dev repos.
- **Release tarball follows symlinks** (`.github/workflows/release.yml`):
  `cp -r` → `cp -rL` when copying `lib/` to release stage. Fixes broken
  symlinks for dep bundles (sakshi, sigil) in the tarball.
- **`sys_system()` helper** added to `programs/cyrius.cyr` for running shell
  commands via fork+execve `/bin/sh -c`.
- **`cyrius deps` no longer requires cc3** — `find_tools()` sets `_cc = 0`
  instead of `sys_exit(1)` when cc3 is missing. Non-compile commands (deps,
  clean, init, version, help) work without a compiler installed. `compile()`
  fails gracefully with a clear error message when cc3 is needed but absent.

## [3.9.5] — 2026-04-12

### Changed
- **Bootstrap compiler renamed: stage1f → cyrc** (`bootstrap/cyrc.cyr`):
  the bootstrap compiler now has a proper name — `cyrc` (Cyrius Compiler).
  Renamed across 23 files: source, bootstrap scripts, bridge compiler,
  docs, README, CLAUDE.md, CI workflows, build tool. Bootstrap chain is
  now: `seed → cyrc → bridge → cc3`. The 29KB seed binary is unchanged.
  Bootstrap closure verified: seed→cyrc→asm→cyrc_check byte-identical.
- **Stale stage1e comments cleaned** in cyrc.cyr — section headers updated
  from historical stage names to descriptive labels.

## [3.9.4] — 2026-04-12

### Fixed
- **Release pipeline builds `cyrius` tool from source** (`.github/workflows/release.yml`):
  release.yml was copying `scripts/cyrius` (shell script) instead of compiling
  `programs/cyrius.cyr` (the Cyrius binary with auto-include, deps, -v).
  Downstream CI failed because the shipped `cyrius build` didn't have
  auto-include. Now compiles `programs/cyrius.cyr` via cc3 in the build step.
  All three release binaries (cc3, cyrius, cyrlint) rebuilt fresh.

## [3.9.3] — 2026-04-12

### Added
- **Auto-include from cyrius.toml** (`programs/cyrius.cyr`): `cyrius build`
  now prepends `include` statements for all resolved deps before compilation.
  Developers declare deps in `cyrius.toml` and write ONLY their project
  includes in source files — no more manual stdlib/dep includes. The build
  tool creates a temp file with dep includes + source, then compiles it.
- **Namespaced dep resolution**: all named deps (`[deps.name]`) are always
  prefixed with the dep name: `lib/{depname}_{basename}`. No collision
  possible. Stdlib deps remain unprefixed (`lib/{name}.cyr`).

### Stats
- **Kybernet 1.0.0**: builds from `cyrius build` with zero explicit includes
- **Hadara 1.0.0**: 329 tests pass via `cyrius build` auto-include

## [3.9.2] — 2026-04-12

### Added
- **`cyrius deps` command** (`programs/cyrius.cyr`): reads `cyrius.toml` and
  resolves dependencies into `lib/`. Two modes:
  - `[deps] stdlib = ["string", "fmt", ...]` — copies from installed cyrius stdlib
  - `[deps.name] path = "../repo" modules = [...]` — copies from sibling repos
  Handles name collisions by prefixing with dep name (e.g. `argonaut_types.cyr`).
  Stream-copies in 32KB chunks (handles large deps like sigil 131KB).
- **Auto-deps on build/run/test/bench/check**: if `cyrius.toml` has a `[deps]`
  section, deps are auto-resolved before compilation. Skips files that are
  already present and same size (size-based freshness check). First build
  prints "N deps resolved", subsequent builds are silent.

### Stats
- **Kybernet 1.0.0**: 447KB binary, 140 tests pass, deps resolved via `cyrius deps`
- **Hadara 1.0.0**: 234KB binary, 329 tests pass, deps resolved via `cyrius deps`

## [3.9.1] — 2026-04-12

### Changed
- **Derive struct parser dedup** (`src/frontend/lex.cyr`): extracted shared
  `PP_PARSE_STRUCT_DEF` function used by both `PP_DERIVE_SERIALIZE` and
  `PP_DERIVE_ACCESSORS`. Struct name parsing, field extraction, offset
  computation, and derive table registration now happen once in shared code.
  Results passed via heap state (S+0x97400..S+0x97950). **-147 lines**,
  **-5.4KB** binary size.
- **aarch64 heap map rewrite** (`src/main_aarch64.cyr`): full sync with
  main.cyr v3.9.1. All buffer sizes, token limits, and region offsets now
  match x86: input 512KB, codebuf 1MB, output 1MB, str_data 256KB, tokens
  262K, fixups 16384, structs 64, brk 0xECA000 (14.8MB). Was stuck at
  v2.0.0-dev limits (input 256KB, tokens 65K, str_data 8KB).

### Stats
- **cc3: 298,760 bytes** (was 304,192 — 5.4KB reduction from dedup)
- **lex.cyr: 1,834 lines** (was 1,981 — 147 lines removed)
- **check.sh: 5/5 pass**

## [3.9.0] — 2026-04-12

### Changed
- **Extracted DSE pass** (`src/frontend/parse.cyr`): dead-store elimination
  moved from inline in PARSE_FN_DEF (250 lines) to standalone `DSE_PASS(S,
  fn_start)` function. PARSE_FN_DEF reduced by ~55 lines. No semantic change.

### Notes
- Derive struct parser dedup (PP_DERIVE_SERIALIZE / PP_DERIVE_ACCESSORS)
  attempted but reverted — variable scoping across the refactored boundary
  caused undefined-variable errors. Needs a heap-based shared state approach
  with fresh variable declarations in each handler. Tracked for future.
- PARSE_FACTOR (412 lines) audited — f64 builtins are already compact
  one-liners, SIMD already extracted. Main split opportunity is store/load
  builtins (~100 lines) but low payoff vs risk.
- Stale comments audited — codebase is clean, no action needed.

### Stats
- **cc3: 304,192 bytes**, 36 test suites (87 regression assertions)
- **check.sh: 5/5 pass**

## [3.8.1] — 2026-04-12

### Fixed
- **Linter brace tracking skips string literals and comments**
  (`programs/cyrlint.cyr`): `"}"` inside strings and `# '{'` in comments
  were counted as real braces, producing false "unclosed braces" warnings.
  Now skips characters between double quotes (with backslash escapes) and
  everything after `#` on a line. Fixes false positive on ai-hwaccel
  `model_format.cyr` (comments containing `{` inflated brace depth).

### Notes
- Load-after-store elimination (LASE) investigated as peephole optimizer.
  Adjacent `store [rbp-N]; load [rbp-N]` pattern identified but unsafe to
  eliminate without jump-target analysis — loop back-edges make the load
  a branch target reachable from paths where rax holds a different value.
  Deferred to future release with proper control-flow analysis.

## [3.8.0] — 2026-04-12

### Fixed
- **aarch64 backend: abstracted arch-specific instructions** in `parse.cyr`:
  raw x86 bytes for `test rax,rax`, `mov rdx,rax`, `mov rax,rdx` replaced
  with backend-agnostic helpers (`ETESTAZ`, `EMOVRDXRAX`, `EMOVRA_RDX`)
  defined in all backends (x86, aarch64, cx, bridge, cc). Fixes 5 aarch64
  CI test failures (fn, fn_recurse, fn_6args, enum, complex) caused by
  ret2/rethi/multi-return and defer flag checks emitting x86 opcodes.
- **Defer on all exit paths** (`src/frontend/parse.cyr`): deferred blocks now
  only execute if the `defer` statement was actually reached at runtime.
  Previously, ALL compiled defer blocks ran at function exit regardless of
  whether execution reached them — early returns before a `defer` statement
  still triggered that defer's cleanup code. Fix uses per-defer runtime flags
  (hidden locals initialized to 0 via backpatch trampoline, set to 1 when
  defer is reached) checked at the epilogue before each block. Eliminates
  a class of resource double-free and use-after-free bugs.

### Added
- **Bare block statement** (`src/frontend/parse.cyr`): `{ ... }` now valid
  as a standalone statement anywhere. Scoped — variables declared inside
  don't leak. (Also part of v3.7.4 switch case blocks.)
- **Defer exit-path regression test** in `regression.tcyr`: 2 assertions
  covering early return with partial defer registration.
- **`-v` verbose flag** (`programs/cyrius.cyr`): `cyrius build -v`,
  `cyrius run -v`, `cyrius test -v` display compiler path, source/output
  paths, defines, and binary size on stderr.
- **`#skip-lint` directive** (`programs/cyrlint.cyr`): lines containing
  `#skip-lint` are exempt from all lint rules. For unavoidable long strings
  (nvidia-smi paths, format strings) in downstream projects.
- **Lint line limit raised 100 → 120** (`programs/cyrlint.cyr`).
- **Arch-agnostic codegen helpers** (`ETESTAZ`, `EMOVRDXRAX`, `EMOVRA_RDX`)
  added to all backends. Fixes 5 aarch64 CI failures from raw x86 bytes in
  ret2/rethi/multi-return/defer flag checks.
- **Defer init jmp backpatch** uses `EPATCH` with temporary CP instead of
  raw x86 rel32 encoding. Fixes aarch64 crash in all functions (the no-defer
  jmp placeholder was patched with x86 offset encoding).

### Stats
- **cc3: 304,144 bytes**, 36 test suites (87 regression assertions)
- **check.sh: 5/5 pass** — first time all checks green (lint false positives fixed)

## [3.7.4] — 2026-04-12

### Added
- **Switch case block bodies** (`src/frontend/parse.cyr`): `case N: { ... }`
  now supported. Adds bare block statement (`{ ... }`) to `PARSE_STMT` and
  fixes the switch pre-scan to track brace depth so inner `}` doesn't
  terminate the case early. Blocks have their own scope (variables declared
  inside don't leak). Mixed inline/block cases work in the same switch.
- **Switch block regression test** in `regression.tcyr`: 4 assertions covering
  block body, mixed block/inline, default block, nested control flow in block.

### Stats
- **cc3: 301,800 bytes**, 36 test suites (85 regression assertions)

## [3.7.2] — 2026-04-12

### Added
- **Native multi-return** (`src/frontend/parse.cyr`): `return (a, b)` emits
  rax:rdx register pair (same codegen as `ret2(a, b)` builtin). Parser scans
  ahead for comma at depth 1 to distinguish `return (a, b)` from
  `return (a + b)`.
- **Destructuring bind** (`src/frontend/parse.cyr`): `var x, y = fn()` binds
  the rax:rdx pair from a multi-return function call. First value goes to x
  (rax), second to y (rdx via `mov rax, rdx`). Functions only.
- **Multi-return regression test** in `regression.tcyr`: 7 assertions covering
  divmod, swap, conditional multi-return, and rethi() backward compat.

### Stats
- **cc3: 301,112 bytes**, 36 test suites (81 regression assertions)

## [3.7.1] — 2026-04-12

### Added
- **`#derive(accessors)`** (`src/frontend/lex.cyr`): auto-generates field
  getters and setters for heap-allocated structs. Same preprocessor codegen
  pattern as `#derive(Serialize)`. For each field, generates:
  - `Name_field(p)` — returns `load64(p + offset)`
  - `Name_set_field(p, v)` — calls `store64(p + offset, v)`
  Supports typed fields (`: Str`, nested structs) via derive table offset
  lookup. Saves ~30 lines per struct across downstream projects.
- **Derive accessors regression test** in `regression.tcyr`: 12 assertions
  covering 2-field scalar struct, mixed Str+scalar struct, getters/setters.

### Stats
- **cc3: 298,752 bytes**, 36 test suites (74 regression assertions)

## [3.7.0] — 2026-04-12

### Fixed
- **Float literal lexer bug** (`src/frontend/lex.cyr`): the float literal
  detection (`0.6`, `0.85`, etc.) read the next character from `S + np`
  (the stale input buffer at S+0) instead of `S + 0x44A000 + np` (the
  preprocess buffer where LEX actually reads). In small programs, the
  copy-back coincidentally placed matching data at S+0 so floats worked.
  In large programs (avatara, 695KB expanded), the stale buffer had
  different bytes and float detection failed — the lexer tokenized `0.6`
  as three tokens (`0`, `.`, `6`) instead of one FLOAT token, producing
  `expected ')', got '.'`. Same bug family as LEXHEX (Bug #33, v3.3.17).
  **Unblocks avatara** (was the real blocker, not the string data limit).
- **Fixup table expanded 8192 → 16384** (`src/backend/*/emit.cyr`,
  `src/frontend/parse.cyr`): avatara's 709 functions exceeded the 8192
  fixup entry limit. Table relocated from `0xA0000` → `0xE4A000` (past
  brk). Brk extended to `0xECA000` (14.8MB).

### Added
- **Float literal regression test** in `regression.tcyr`: 4 assertions
  covering `0.5`, `0.25`, float in `store64`, float after ptr arithmetic.

### Stats
- **cc3: 290,240 bytes**, 36 test suites (70 regression assertions)
- Fixup limit: 16384 (was 8192)
- Heap: 14.8MB

## [3.6.10] — 2026-04-12

Pre-3.7.0 cleanup pass. Heap map rewritten, latent overlap bug fixed,
docs synced.

### Fixed
- **struct_fcounts overlap with struct_names** (`src/frontend/parse.cyr`):
  when the struct limit was expanded 32→64 in v3.6.6, the struct_names
  table (at 0x8E630) was allowed to hold 64 entries (512 bytes) but
  struct_fcounts started at 0x8E730 — only 256 bytes later. Programs with
  >32 structs had struct_names[32+] overwriting struct_fcounts[0+],
  corrupting field count data. Relocated struct_fcounts from 0x8E730 →
  0x8E830. **This was likely contributing to kybernet's mysterious errors
  after the struct limit fix.**

### Changed — Cleanup
- **Heap map fully rewritten** (`src/main.cyr`): the authoritative heap map
  had accumulated 15+ stale entries across the v3.5-3.6 release series
  (str_data at old address, token arrays at old addresses, struct tables
  at old addresses, input_buf size wrong, brk wrong). Rewritten from
  scratch with correct addresses, sizes, and version annotations. Verified
  by `tests/heapmap.sh`: 43 regions, 0 overlaps, 0 warnings.
- **Open Limits table updated**: added Structs (64), fixed Input buffer
  (512KB), Output buffer (1MB).
- **Intentional input_buf/tok_names overlap documented**: tok_names at
  0x60000 is inside the 512KB input_buf range (0x00000-0x80000). This is
  tolerated because tok_names is rebuilt by LEX after preprocessing
  consumes the input. Marked as `(nested)` in the heap map so
  `heapmap.sh` doesn't flag it.

### Stats
- **cc3: 290,256 bytes**, 36 test suites, 0 heap overlaps
- Heap map: 43 regions (was 47 — stale/dead entries removed)

## [3.6.9] — 2026-04-12

### Fixed
- **String data buffer expanded 32KB → 256KB** (`src/frontend/lex.cyr`):
  avatara hit the 32KB string literal limit. The buffer at `0x14A000`
  (relocated in v3.6.7) has 1MB of available space from the old tok_types
  region. Raised the cap check from 32768 to 262144. Avatara now compiles
  past the string limit (hits a parse error in its own code, not a compiler
  limit).

### Stats
- **cc3: 290,224 bytes**, 36 test suites
- String data: 256KB (was 32KB)

## [3.6.8] — 2026-04-12

### Changed
- **Error messages improved**: "undefined variable" now includes hint
  `(missing include or enum?)` to guide users toward the most common cause.
- **`scripts/check.sh`**: test output captured with `tr -d '\0'` to strip
  null bytes that caused garbled bash warnings on some test binaries.
- **Starship prompt integration** (`scripts/install.sh`): installer now
  auto-configures `[custom.cyrius]` in `~/.config/starship.toml` if
  starship is available. Shows toolchain version (`cc3 --version`) in
  downstream Cyrius projects, project version (`VERSION` file) in the
  compiler repo itself. Detection via `bootstrap/asm` (unique to the
  compiler repo).

## [3.6.7] — 2026-04-12

### Fixed
- **Input buffer expanded 256KB → 512KB** (`src/main.cyr`,
  `src/main_aarch64.cyr`, `src/main_cx.cyr`): kybernet's dep-resolved
  input was 277KB, exceeding the 256KB stdin buffer. `str_data` relocated
  from `0x40000` → `0x14A000` (the free old tok_types region) to make
  room. Input buffer now spans `S+0x00000` to `S+0x80000`. Truncation
  error updated to "exceeds 512KB". Brk unchanged at `0xE4A000`.
  Kybernet now compiles past the input-buffer stage (hits a kybernet-side
  parse error at line 10169, not a compiler limit).

### Stats
- **cc3: 290,224 bytes**, 36 test suites
- Input buffer: 512KB (was 256KB)

## [3.6.6] — 2026-04-12

### Fixed
- **Struct limit expanded 32 → 64** (`src/frontend/parse.cyr`): kybernet
  with argonaut + agnostik deps defined 36 structs, exceeding the old max.
  `struct_ftypes` relocated from `0x8A000` → `0xD4A000`, `struct_fnames`
  from `0xD8000` → `0xDCA000` (past the token arrays). Brk extended to
  `0xE4A000` (14.3MB). Struct names/fcounts tables stay at their original
  locations with room for 64 entries. Three-step bootstrap verified.

### Added
- **`tests/tcyr/many_structs.tcyr`** — regression test with 38 struct
  definitions (4 assertions). Test suite #35.

### Stats
- **cc3: 290,224 bytes**, 35 test suites, 495 assertions
- Heap: 14.3MB (brk at 0xE4A000)
- Struct limit: 64 (was 32)

## [3.6.5] — 2026-04-12

### Fixed
- **PP_IFDEF_PASS copy-back overflow eliminated** (`src/frontend/lex.cyr`):
  the ifdef pass previously copied the entire preprocessed source from
  `S+0x44A000` to `S+0` before processing. For programs >256KB of expanded
  source, this overflowed into `tok_names`, `struct_ftypes`, and the
  compiler state scalars at `S+0x8C100` (BL/CP/VCNT/fn_count/etc.),
  causing either compile-time crashes (SIGSEGV) or corrupted runtime
  binaries (bad string literal addresses). Fix: allocate a 1MB temp
  buffer via `mmap(MAP_ANONYMOUS)`, copy source there, read from temp
  during processing, write output to `S+0x44A000`, `munmap` at end.
  Zero overflow. Programs of any size now preprocess correctly.
  **Closes Bug #35** — the longest-running bug family in the compiler
  (first reported v3.4.5, workarounds in v3.4.7, v3.6.2).

### Added
- **`tests/tcyr/large_source.tcyr`** — regression test for >256KB expanded
  source. Includes 44 stdlib modules + 3 dep bundles (697KB expanded),
  verifies string literals work at runtime (the specific failure mode of
  the copy-back corruption). 7 assertions. Test suite #34.

### Stats
- **cc3: 290,224 bytes**, 34 test suites, 498 assertions
- Self-hosting verified (three-step, byte-identical)

## [3.6.4] — 2026-04-12

### Fixed
- **`lib/patra.cyr` lazy-init**: `patra_open()` now calls `_sql_init()` if
  not already initialized, preventing SIGSEGV when `patra_init()` is
  omitted. Same silent-failure pattern as the input_buf truncation (v3.4.19).
- **cyrlint false positives**: cffi one-liner functions no longer flagged.

## [3.6.3] — 2026-04-12

### Added
- **`lib/cffi.cyr`** — C struct layout helpers for foreign struct interop
  (stdlib module #41). Computes field offsets with C alignment/padding rules:
  `cffi_struct_new`, `cffi_field`, `cffi_field_struct`, `cffi_field_array`,
  `cffi_offset`, `cffi_sizeof`, `cffi_set8/16/32/64`, `cffi_get8/16/32/64`.
  Type constants `CFFI_U8` through `CFFI_PTR/CFFI_USIZE`. 18 functions, all
  documented (cyrdoc 18/18). 23-assertion test suite including a
  WGPUTextureDescriptor-like 14-field layout verified at 80 bytes. Needed for
  tarang codec ports and any project doing C FFI struct interop.

## [3.6.2] — 2026-04-12

### Changed
- **Token limit expanded 131,072 → 262,144** (`src/frontend/lex.cyr`,
  `src/backend/*/emit.cyr`, `src/common/util.cyr`). Token arrays relocated
  from `0x14A000` → `0x74A000` (tok_types), `0x24A000` → `0x94A000`
  (tok_values), `0x34A000` → `0xB4A000` (tok_lines). Each array doubled
  from 1MB to 2MB. Brk extended to `0xD4A000` (13.3MB total). Unblocks
  argonaut's full 52-include compilation (was hitting 131K ceiling).
- **Comprehensive post-preprocess re-initialization** (`src/main.cyr`):
  the ifdef copy-back for programs >256KB of expanded source overwrites
  compiler state scalars (BL, CP, VCNT, fn_count, etc.). All 27 affected
  scalars are now re-initialized after PREPROCESS returns, mirroring the
  full init block at compiler startup. Argonaut's main.cyr (409KB) and
  the 52-include mega-test (600KB) both compile successfully.

### Added
- **Regression tests** for v3.5-3.6 features: +15 assertions in
  `regression.tcyr` (string interning 5, auto-coercion 8, syscall arity 2).
- **`fuzz/str_coerce.fcyr`** — 1000-iteration fuzz harness for Str/cstr
  auto-coercion (eq, contains, starts_with, cat, empty strings).
- **`benches/bench_interning.bcyr`** — pointer-identity vs str_eq vs streq
  comparison. ptr_eq 414ns vs str_eq 595ns (30% faster).

### Known limit
- Argonaut's 52-include mega-test compiles but the binary crashes at
  runtime on first string access (SIGSEGV). The ifdef copy-back corrupts
  str_data content that the lexer uses for string literals. Proper fix
  (eliminating the copy-back) deferred.

## [3.6.1] — 2026-04-12

### Added
- **Compile-time string interning** (`src/frontend/lex.cyr`): identical
  string literals now share the same address. `"hello" == "hello"` is true
  (pointer-identity comparison, 1 CPU cycle vs memcmp). Always-on
  deduplication in the lexer — zero downstream code changes needed.
  Compiler binary shrank ~80 bytes from deduplication of its own literals.
  Classification chains (`if (cmd == "get") ...`) can now use pointer
  comparison instead of `streq`.

### Fixed
- **Reverted `sb` ifdef copy-back change** that caused `undefined variable
  'ptr'` regression in argonaut (409KB expanded source). The `sb = 0x44A000`
  direct-read path introduced in v3.5.2 broke variable resolution for
  programs >256KB. Restored the original always-copy-back behavior which
  works because the lexer re-initializes corrupted regions before use.

## [3.6.0] — 2026-04-12

### Added
- **Str/cstr auto-coercion**: functions with `: Str` parameter annotations
  auto-wrap string literal arguments in `str_from()` at call sites. No
  downstream code changes needed beyond adding `: Str` to function
  signatures. New heap region `0xDC000` for `fn_param_str_mask` (2048
  entries). Lazy `str_from` function lookup via `_STR_FROM_NOFF` cache.
- **`lib/str.cyr` annotated**: `str_eq`, `str_cat`, `str_contains`,
  `str_starts_with`, `str_ends_with`, `str_split`, `str_join`,
  `str_builder_add` — all take `: Str` params now.

### Fixed
- **`str_starts_with` body** used `strlen(prefix)` (cstr operation) on a
  param now annotated `: Str`. Updated to use `str_len`/`str_data` for
  consistent Str operations.

### Impact
- 748 `str_from("literal")` wrappers across argonaut (382), libro (291),
  and stdlib (75) can now be removed by annotating function params `: Str`.

## [3.5.2] — 2026-04-12

### Fixed
- **Codebuf + output_buf expanded 512KB → 1MB each** (`src/backend/x86/emit.cyr`,
  `src/backend/x86/fixup.cyr`, `src/main.cyr`): programs with >512KB of generated
  machine code hit the old codebuf ceiling. Output_buf shifted from `0x5CA000`
  → `0x64A000`, brk extended from `0x64A000` → `0x74A000` (7.3MB total heap).
  Both x86 cap checks and error messages updated to 1MB. No other heap regions
  shifted. Three-step bootstrap verified.
- **PP_IFDEF_PASS copy-back overflow eliminated** (`src/frontend/lex.cyr`):
  the ifdef preprocessing pass copied the entire expanded source from the 1MB
  preprocess buffer (`S+0x44A000`) back to the 256KB input buffer (`S+0`)
  before processing. For programs with >256KB of expanded source (argonaut's
  600KB), this overflowed past `S+0x40000` and corrupted `str_data`, `tok_names`,
  and the compiler state scalars at `S+0x8C100` — presenting as garbage codebuf
  overflow values (quintillion-range numbers). Fix: for programs that fit in
  256KB, the copy-back still runs (helpers read from `S+0`). For oversized
  programs, the ifdef pass reads directly from `S+0x44A000` via a source-base
  offset (`sb = 0x44A000`), eliminating the copy entirely. Bug #35 family,
  same root cause pattern as the v3.4.7 `str_pos`/`data_size` re-init fix
  but covering the full copy-back path.

### Known limit
- **Token limit**: 131,072 tokens. Argonaut's 52-file mega-compilation test
  (`cc3_readfile_cap.tcyr`) exceeds this after the above fixes unblock it.
  The token arrays are 1MB each (3MB total); expanding requires a v4.0
  heap reorganization.

## [3.5.1] — 2026-04-12

### Fixed
- **READFILE include-read cap raised 512KB → 1MB** (`src/frontend/lex.cyr`
  lines 1061, 1209): last two stale 524288 constants in the include
  read-budget calculation. Argonaut's 19-libro-module test now compiles.

## [3.5.0] — 2026-04-11

**Cyrius 3.5.0 — Expression Power.** Four low-risk codegen improvements,
no new syntax complexity, no heap changes, no bootstrap risk.

### Added
- **Expression-position comparisons**: `==`/`!=`/`<`/`>`/`<=`/`>=` now
  return 0/1 as values in **any** expression position — var init, function
  call arguments, store values, return statements, `&&`/`||` chains.
  Eliminates the expand-to-if workaround (`var r = 0; if (a == b) { r = 1; }`)
  that every downstream port hits. Implementation: 81 `PEXPR(S)` call sites
  in `parse.cyr` upgraded to `PCMPE(S)`. 11 regression tests added.
- **`#assert` compile-time check**: `#assert EXPR, "msg"` — evaluates a
  constant expression (number literals, `sizeof(T)`, comparisons) at parse
  time and aborts compilation on failure. Catches struct layout drift and
  enum value mismatches. Token 107 added to lexer, `_EVAL_CONST_ATOM` +
  `PARSE_STMT` handler in parser.
- **Syscall arity warnings**: 40-entry lookup table of common Linux x86_64
  syscall numbers → expected arg count. Warns at compile time when the arg
  count doesn't match. Silent for unknown syscall numbers.

### Fixed
- **aarch64 `ESETCC` GT/LE/GE encodings** (`src/backend/aarch64/emit.cyr`):
  GT and LE `cset` condition codes were swapped, GE used LT's encoding.
  Pre-existing since the aarch64 backend was written — never caught because
  comparisons in condition positions used branch instructions that bypassed
  `ESETCC`. The PCMPE-everywhere change in 3.5.0 exposed the bug by routing
  all comparisons through `ESETCC` for the first time. Fixed all three
  encodings. aarch64 CI tests (`for`, `fn_recurse`, `complex`) now pass.

### Notes
- `sizeof(StructName)` was already implemented (since v2.0) — verified
  working, no changes needed.
- cc3 binary grew from 250KB to 288KB. The growth is from PCMPE dispatch
  at every expression site (the compiler itself is a large program that
  exercises every code path) + `#assert` evaluator + syscall arity table.

## [3.4.20] — 2026-04-11

P(-1) scaffold-hardening pass + libro review before v3.5.0. Two latent
stale-cap bugs fixed, a silent `cyrius build` misconfiguration fixed,
dead bench files cleaned up, compiler heap map comment drift cleaned up,
and libro's multi-month "still struggling to get out" state narrowed to
three missing-include bugs + uncommitted WIP.

### Fixed
- **Stale preprocess_out cap** (`src/frontend/lex.cyr:1077`): cap was
  hard-coded at 524,288 bytes (512 KB) but the preprocess output buffer
  was expanded to 1 MB in v3.4.5. The cap had been stale for **five
  releases**. Large expanded programs (anything touching >512 KB after
  include/macro expansion) hit a phantom limit and bailed with
  "expanded source exceeds 512KB" even though the buffer had headroom.
  Raised the cap to 1,048,576 bytes to match the actual buffer. Error
  message updated to "1MB" so future drift is visible. Same class of
  bug as v3.4.19's silent stdin truncation and v3.3.17's LEXHEX
  raw-vs-preprocessed buffer mismatch — fixed-size buffers in cc3 are
  worth a blanket audit for stale caps before v3.5.0.
- **`cyrius build` / `cyrius test` / `cyrius bench` auto-prepended
  Cyrius's own `[deps]` to every compile target** (`scripts/cyrius`
  `compile()`): when invoked from a project whose `cyrius.toml` declares
  downstream deps (i.e. Cyrius itself with sakshi + patra + sigil +
  yukti + mabda), `resolve_deps()` prepended all of them to the
  stdin stream for every build. Bench files (which already declare
  their own `include`s) got ~400 KB of unrelated source bolted on,
  tripped the preprocess cap (above), and all reported `FAIL (compile)`.
  Fixed: `compile()` now skips dep resolution for `.bcyr` / `.tcyr` /
  `.fcyr` targets — these are self-contained by convention and must
  not inherit the project's dep overlay. Regular source builds are
  unchanged. Tests, fuzz, and benches can be invoked via the dispatcher
  again from the Cyrius repo root.
- **`scripts/cyrius` sourced from `~/.cyrius/bin/cyrius`** reinstalled
  so `cyrius bench` uses the fixed dispatcher. Both copies stay in sync.

### Changed — Benches
- **`bench_fmt.bcyr` SIGSEGV fixed**: `fmt_sprintf(&buf, "x=%d y=%d",
  42, 99)` passed the two int args positionally where `fmt_sprintf`
  expects a `vec` of args (pulled via `vec_get`). Cyrius silently
  accepts extra args to a 3-param function, so `42` was interpreted
  as a vec pointer and `vec_get(42, 0)` dereferenced address 42 →
  crash. Rewrote to use a proper `vec_new` + `vec_push` args vector.
  Bench now reports clean numbers (~645 ns for sprintf, the slowest
  in the fmt suite).
- **`tests/bcyr/compile.bcyr` deleted**: referenced `./build/cc2`
  (renamed to cc3 in v3.2.5) and was missing its include list. Dead
  since cc2 → cc3. Removed. `tests/bcyr/` directory removed (now empty).

### Changed — Compiler internals
- **Stale heap-layout comment in `src/frontend/parse.cyr`** rewritten.
  The top-of-file struct support block referenced `var_types` at
  `0x8DE30 [256 bytes, 32 entries]` (five locations stale — actual is
  `0x13A000 [65,536 bytes, 8192 entries]`) and `struct_fnames` at
  `0x8E830 [4096 bytes, 16 fields]` (actual is `0xD8000 [8192 bytes,
  32 fields]`). Replaced with a "see src/main.cyr for authoritative
  map" pointer + a correct quick reference of the regions parse.cyr
  actually touches.

### P(-1) Scaffold Audit — findings & observations

Before opening 3.5.0 work, ran the full scaffold-hardening pass:

1. **Cleanliness baseline**: stdlib is clean (`cyrius audit` reports
   5/5 pass). Compiler source (`src/`) has ~395 lint warnings + ~10
   format diffs, but all are cyrlint/cyrfmt style-convention mismatches
   (uppercase fn names like `GLVAR`/`SFINL` vs snake_case rule,
   nested-if flat indent vs add-indent-per-brace, 100-char lines in
   ASM emission). Not bugs — tooling doesn't understand the compiler's
   conventions. Deferred; worth either tuning cyrlint with a
   `# cyrlint: ignore` directive or documenting an exclusion.
2. **Test sweep**: 32/32 .tcyr suites green (442 assertions), 4/4
   .fcyr fuzz harnesses pass, heap audit 47 regions / 0 overlaps /
   0 warnings, self-host byte-identical.
3. **Benchmark baseline** (post-fix): captured for future comparison.
   Highlights: `alloc/8B` 421 ns, `alloc/64B` 427 ns, `alloc/1KB` 439
   ns, f64 arithmetic 394-415 ns, `fmt/int_small` 421 ns, `fmt/sprintf`
   645 ns, `hashmap/lookup_hit` 593 ns, `str/from+len` 463 ns,
   `vec/push_1000` 15 µs, `vec/get` 403 ns, `tagged/Ok` 431 ns. All
   stable compared to prior informal measurements.
4. **Dead code scan**: 296 uppercase-prefixed compiler fns, zero with
   ≤1 call sites. Prior cleanup in v3.4.16 (GLVR/SLVR/GFBE/GPUB/SPUB/
   TWIDTH removal) held — no new dead accessors accumulated.

### Libro review — unblocked

Libro's been "still struggling to get out" for months. Root cause
identified — three missing includes in `libro/src/main.cyr`, plus a
WIP test-suite addition that breaks the suite even after the
include fix:

1. **Missing `include "lib/patra.cyr"`** — libro's main.cyr referenced
   `patra_init()`, `patrastore_open()`, etc. without ever including
   patra's source. Cyrius emits "undefined function" warnings for
   these and generates stub bodies that jump to NULL at call time.
   First patrastore call → SIGSEGV.
2. **Missing `include "lib/fmt.cyr"`** — patra internally calls
   `fmt_int_buf` during SQL execution. Without fmt.cyr, this is
   another NULL stub → SIGSEGV mid-exec.
3. **Missing `include "src/patra_store.cyr"`** — the `patrastore_*`
   wrapper functions were defined in a file that was never included
   from main.cyr. Same NULL-stub crash pattern.
4. **Uncommitted WIP** (~385 new lines in "Gap coverage" test group)
   crashes when run as part of the full suite, even with includes
   fixed. Tests run fine in isolation. Triggering condition is
   cumulative — something in the prior test groups leaves state that
   breaks the PatraStore append_load path. Classic heisenbug signature.

**Result with includes fixed (committed main.cyr only, WIP stashed):
202/202 tests PASS, exit 0.** Libro is unblocked as soon as the
include fix is committed and the WIP is either completed or reverted.
See `docs/development/issues/libro-unblock.md` for the full diagnosis.

### Related findings (for future cleanup, not fixed here)

- **`lib/patra.cyr` silently SIGSEGVs when used without `patra_init()`**.
  `sql_tokenize` dereferences `_sql_toks = 0` on first call if
  `patra_init()` → `_sql_init()` was never called. Same family of
  silent-failure bug as v3.4.19's input_buf truncation — patra
  should lazy-init or `patra_open()` should call `patra_init()`
  unconditionally. Upstream fix for a future patra release.
- **Other fixed-size buffers worth auditing for stale caps**:
  `tok_names` (64 KB at 0x60000), `preprocess_out` (1 MB at 0x44A000
  — cap now matches), `fixup_tbl` (128 KB at 0xA0000, 8192 entries
  cap), `_fl_arena` (64 KB segments). Pattern: fixed-size buffer +
  silent overflow + downstream corruption = delayed misdiagnosis at
  scale. Add probe-based overflow checks to all of them.
- **`cyrlint` / `cyrfmt` don't understand compiler conventions**:
  395 warnings on src/, none of them real bugs. Either teach the
  tools the conventions or add a per-file ignore mechanism before
  gating CI on compiler-source cleanliness.

### Stats
- **cc3: 250,536 bytes** (unchanged — only source comment edit + stale
  cap fix, both zero-byte)
- **40 stdlib modules + 5 deps**, 32 test suites (442 assertions)
- **Heap audit: 47 regions, 0 warnings**
- **Bench harness: 9 benches × multiple measurements = ~50 data points
  captured for baseline comparison**
- Self-hosting verified (two-step cc3==cc3a byte-identical)
- Libro: **202/202 tests pass** with include fix on committed main.cyr

## [3.4.19] — 2026-04-11

Mabda stdlib inclusion, start to finish. **Mabda (GPU foundation layer) is
now a first-class Cyrius stdlib dep** alongside sakshi/patra/sigil/yukti.
This single release absorbs three iterations of in-flight work (internal
tags 3.4.17 and 3.4.18 never shipped publicly and have been collapsed into
this entry): the initial staging, a blocking cc3 buffer bug that surfaced
on first activation, and the mabda 2.1.1 → 2.1.2 fold-in.

### Why mabda ships now with a transitional C backend

Mabda wraps wgpu-native through a C launcher + function-pointer table.
Upstream projects (soorat, rasa, ranga, bijli, aethersafta, kiran) are
blocked on mabda; waiting for a pure-Cyrius GPU driver would delay every
one of them by a year or more. Instead mabda ships now with the public
API frozen — the C shim is explicitly **transitional scaffolding** at
the consumer's edge (their launcher + wgpu-native download), not inside
the Cyrius toolchain. Cyrius itself stays dependency-free. When the
native backend lands (future work, deliberately unscoped), consumers
bump their `[deps.mabda]` tag and their C launcher requirement
disappears. Nothing else changes. The `# @public` / `# @internal`
surface marking in mabda 2.1.1 is the contract that survives the
eventual backend swap.

### Fixed
- **`input_buf` expanded 128 KB → 256 KB** (`src/main.cyr`,
  `src/main_aarch64.cyr`, `src/main_cx.cyr`). This was the blocking cc3
  change. Mabda's `dist/mabda.cyr` bundle is 141,912 bytes — the old
  128 KB stdin buffer silently truncated it at byte 131,072, producing
  `error:3719: unexpected end of file` far from the actual truncation
  point. The expansion absorbs the adjacent reclaimable region at
  `0x20000` (free since v3.3.7 when codebuf moved to `0x54A000`).
  **No downstream heap offsets shift** — the expansion fills previously
  unused space. Heap audit still reports 47 regions / 0 warnings.
- **Silent stdin truncation is now a hard error.** The old read loop
  accepted up to 131,072 bytes and stopped — anything beyond vanished
  without a diagnostic. The new loop probes for a trailing byte after
  the buffer fills and exits with:
      error: input exceeds 256KB buffer (raise input_buf in src/main.cyr)
  Clear, actionable, at the boundary where the problem happens. Same
  family of silent-overflow bug as #32 (7+ arg stack offset), #33
  (LEXHEX raw-vs-preprocessed buffer), #35 (ifdef copy-back overflow).
  Remaining fixed-size buffers (`tok_names`, `preprocess_out`,
  `fixup_tbl`) are worth the same treatment before v3.5.0.

### Changed
- **`[deps.mabda] = "2.1.2"` activated** in `cyrius.toml`. Alongside
  sakshi/patra/sigil/yukti. Mabda 2.1.2 is a repo-hygiene release (the
  `rust-old/` reference tree was removed, leaving a clean Cyrius-only
  repository); the `dist/mabda.cyr` bundle bytes are unchanged from
  2.1.1. Inline comment in `cyrius.toml` records the activation history
  and the input_buf prerequisite.
- **`cyrius.toml` `[package] version`** synced to `3.4.19` (the version
  field had been drifting since before v3.4.14; v3.4.16's permissive
  bump-script sed handles it now).
- **`docs/development/roadmap.md`** stdlib table: new **GPU (dep)** row
  for mabda. The pre-v3.4.19 "Pending inclusion" row has been cleared —
  nothing else is pending.
- **`docs/development/roadmap.md`** Open Limits table: `Input buffer`
  corrected from the long-stale documented value to **256 KB** with a
  note that overflow is now a hard error, not silent truncation.

### Mabda release story (absorbed into this release)

- **Mabda v2.0.0** — Rust → Cyrius port, all 24 Rust modules ported,
  GPU FFI operational via C launcher + struct-packing shims, 89
  standalone tests + 4 GPU integration tests.
- **Mabda v2.1.0** — feature-complete against Rust v1.0 surface.
  27 lib modules + 4 FFI + 1 cache helper, ~3,700 lines, **290
  assertions**, full FFI path including texture + render-pipeline +
  surface creation on GPU. Fixed a latent cache-dangling-pointer bug
  that shipped in v2.0, plus a batch of v29 enum-drift corrections
  (texture formats, sampler modes, present modes, primitive topology,
  cull mode, shader sType — all re-derived from `webgpu.h`).
- **Mabda v2.1.1** — stdlib-inclusion release. `dist/mabda.cyr`
  single-file bundle (141,912 bytes), `scripts/bundle.sh` reproducible
  bundler, `[lib]` section in `cyrius.toml`, `cyrius-version = "3.4.19"`
  pin, `# @public` / `# @internal` surface marking as the backend-swap
  stability contract, consumer example.
- **Mabda v2.1.2** — repo hygiene. `rust-old/` reference tree removed.
  Bundle bytes unchanged. This is the tag Cyrius v3.4.19 activates.

### The lesson — silent truncation is the worst failure mode

When the mabda bundle first hit cc3, the debugging agent guessed
"banner comments at scale confuse cc3" based on symptoms and codified
stripping banners as the fix. The guess was wrong, but the workaround
happened to work because stripping banners shaved enough bytes to fit
under 131,072. Any future bundle growth would have re-hit the wall and
re-mystified the next debugger.

The real cause was a silent cap in cc3's raw stdin read loop — bytes
past the limit vanished without a diagnostic, the parser ran out of
tokens mid-function, and the error report pointed at a token position
that had nothing to do with the truncation. One clear diagnostic at
the read boundary would have pointed straight at the real cause. This
release adds that diagnostic.

Mabda's `scripts/bundle.sh` header has been updated to explicitly flag
the old "banner handling" explanation as a red herring so the next
reader doesn't rebuild their mental model around it.

### Stats
- **cc3: 250,536 bytes** (+232 bytes from v3.4.16's 250,304 — the cost
  of the truncation probe + error message string)
- **40 stdlib modules + 5 deps** — sakshi, patra, sigil, yukti, mabda
- **32 test suites (442 assertions)**, 4 fuzz harnesses
- **Heap audit: 47 regions, 0 warnings**
- **`input_buf`: 256 KB** (was 128 KB since the earliest compiler drafts)
- Self-hosting verified (three-step cc3 → cc3a → cc3b byte-identical
  during the input_buf expansion, subsequent two-step re-verifies
  after the 2.1.2 fold-in)
- Mabda 2.1.2 bundle (141,912 bytes) compiles cleanly → 63,199 byte ELF

## [3.4.16] — 2026-04-11

Final polish release before v3.5.0 — compiler cleanup, dead-code removal, heap
map alignment. Zero new features. Heap audit now reports **0 warnings**
(47 regions), down from 1 warning in v3.4.15.

### Fixed
- **`cc3 --version` was stuck at `3.4.10`** (critical): The `version-bump.sh`
  sed regex matched the literal previous version string, so when the source
  drifted the bump silently failed. Every release between 3.4.11 and 3.4.15
  shipped with `cc3 --version` reporting `3.4.10` (with no trailing newline,
  because the syscall length was hard-coded to 10 bytes instead of 11). The
  version string is now pinned to `3.4.16\n` with the correct 11-byte length,
  and `scripts/version-bump.sh` was rewritten to use a permissive regex
  (`"cc3 [0-9]+\.[0-9]+\.[0-9]+\\n"`) plus an auto-computed length so this
  class of bug is structural from now on.

### Changed — Compiler Cleanup
- **Dead accessors removed from `src/common/util.cyr`** (~16 bytes off the
  compiler binary, 250320 → 250304):
    - `GLVR` / `SLVR` — loop-var register cache getters for the r12 opt
      reverted in v3.3.12 (2x perf regression). Zero callers.
    - `GFBE` — inline body-end *getter*. The inliner only writes this slot
      via `SFBE`; nothing reads it.
    - `GPUB` / `SPUB` — `pub` visibility accessors scaffolded in
      `docs/development/module-manifest-design.md` but never wired into
      parse/lex. Dead since they were added.
    - `TWIDTH` — multi-width type→byte-width helper. Every call site inlines
      the 1/2/4/8 dispatch directly now; the function was unreferenced.
- **Heap gap closed at 0x8F898**: `ptr_scale` ended at `0x8F898` but
  `continue_count` started at `0x8F8A0`, leaving an 8-byte hole that the
  heap audit flagged every run. Moved `continue_count` → `0x8F898` and
  `continue_patches` (the 64-byte table) → `0x8F8A0`. Mass rename across
  `src/main.cyr`, `src/main_aarch64.cyr`, `src/main_cx.cyr`, and
  `src/frontend/parse.cyr` (~22 references). Two-step bootstrap verified
  byte-identical. Heap audit: 47 regions, **0 warnings**.

### Changed — Heap Map Alignment
- **Stale `local_depths [512]` comment at `0x8FCC8` removed**: Only the
  heap-map comment referenced it — the live `local_depths` table lives at
  `0x91800` (see `GLDEP`/`SLDEP`). The 0x8FCC8 slot was phantom reservation
  from an earlier compiler revision. Now marked `(reserved)` so it isn't
  counted as a live region.
- **0x903F8 dual-use documented**: The slot holds `init_offset` (for the
  `_cyrius_init` entry point in object mode) up until `FIXUP` runs, then
  `EMITELF` overwrites it with `elf_out_len`. The slot swap was coded
  correctly (init_offset is consumed by the symbol-table write before
  FIXUP overwrites it) but undocumented; new comment in `src/main.cyr`
  calls out the ordering contract for future edits.
- **Reclaimable regions marked**: `0x20000-0x40000` (128KB, was codebuf
  before v3.3.7) and `0xDA000-0x11A000` (256KB, was output_buf before
  v3.3.7) are now labelled `(unused)` in the heap map with pointers at
  the relocations that freed them. Future allocations can reuse these
  without searching git history to see why they're empty.
- **Heap map version marker bumped** from `v2.1.2` → `v3.4.16` (was
  five major versions behind).

### Stats
- **cc3: 250,304 bytes** (down 16 bytes from v3.4.15's 250,320)
- **40 stdlib modules + 5 deps**, 32 test suites (442 assertions)
- **Heap audit: 47 regions, 0 warnings** (was 48 regions / 1 warning)
- Self-hosting verified (two-step cc3==cc3 byte-identical)

## [3.4.15] — 2026-04-11

### Changed — Tooling
- **`cyriusup` renamed to `cyriusly`** ("Language Yare"): The version manager is
  now `cyriusly` — *yare* (adj., "quick, agile, responsive — the ship answers
  the helm") fits the tool better than the rustup-style `-up` suffix. All CLI
  commands, help text, and install.sh output updated. Existing installs keep
  working until re-installed; run the installer to pick up the new binary name.
- **Shared audit walkers** (`scripts/lib/audit-walk.sh`): The fmt/lint
  skip-symlink loops in `scripts/check.sh` and the `cyrius audit` dispatcher
  were duplicated. Extracted into a shared `audit_fmt_walk` / `audit_lint_walk`
  helper that both scripts source, with inline fallbacks for standalone
  installs. `scripts/install.sh` now ships the helper under `bin/lib/`
  alongside the dispatcher.

### Fixed
- **`scripts/check.sh` skips symlinked dep files**: The audit was reporting
  `format FAIL` + `lint FAIL (24 warnings)` even though the non-dep stdlib was
  clean — all 24 warnings came from the symlinked dep files (sigil 14, sakshi 4,
  sakshi_full 3, patra 3) which are owned by upstream and track a slightly
  different formatter baseline. The `cyrius audit` dispatcher in
  `~/.cyrius/bin/cyrius` already did `[ -L "$f" ] && continue` for both checks;
  `scripts/check.sh` now mirrors that logic (via the shared walker above).
  `sh scripts/check.sh` reports 5/5 passing again (3/5 before this patch).

### Changed — Doc Alignment
- **Stats sweep across all docs**: The compiler binary is **~250KB** (was drifting
  between 233KB/243KB/245KB in different files). Test counts aligned to **32
  suites / 442 assertions**. Stdlib module count aligned to **40 stdlib + 5 deps**
  (patra, sakshi, sakshi_full, sigil, yukti). Files touched:
  `CLAUDE.md`, `README.md`, `docs/benchmarks.md`, `docs/architecture/cyrius.md`,
  `docs/cyrius-guide.md`, `docs/adr/001-assembly-cornerstone.md`,
  `docs/development/roadmap.md`.
- **CHANGELOG `[3.4.14]` stats line corrected**: Said `45 stdlib + 5 deps`, but
  the release only bumped the compiler for `_cyrius_init` export — no new stdlib
  modules. Corrected to `40 stdlib + 5 deps`.
- **Roadmap Gotcha #5 rewritten**: Said "No mixed `&&`/`||` in conditions". In
  reality, parenthesized mixed forms like `if (a > 0 && (b > 0 || c > 0))` work
  (verified with cc3 3.4.14); the limitation is that precedence-based
  disambiguation is not supported — explicit parens are required. Gotcha updated
  to reflect actual behavior.

### Docs
- **`docs/development/issues/parser-overflow-large-codebase.md`**: Bug #32 was
  resolved in v3.3.17 by the `str_data` → `0x40000` relocation + `LEXHEX`
  preprocessed-buffer fix. Issue doc updated from "Open (blocking shravan)" to
  "Resolved in v3.3.17" with the root cause and fix recorded for historical
  reference.

### Stats
- **40 stdlib modules + 5 deps**, 32 test suites (442 assertions), cc3 ~250KB

## [3.4.14] — 2026-04-11

### Added
- **`_cyrius_init` export in `object;` mode**: Top-level code (enum values, global
  var initializations) is now wrapped in a callable `_cyrius_init()` function when
  compiling with `object;`. C launchers call `_cyrius_init()` then `alloc_init()` to
  properly initialize all Cyrius globals before calling application functions. The
  function has a proper prologue/epilogue (`push rbp; mov rbp,rsp; sub rsp,4096` +
  `leave; ret`) and is exported as a global symbol in the `.o` symbol table.
  Resolves the object-mode enum initialization bug that blocked mabda GPU port.
  Self-hosting verified (byte-identical two-step bootstrap).

### Stats
- **40 stdlib modules + 5 deps**, 32 test suites (442 assertions)

## [3.4.13] — 2026-04-11

### Changed
- **Yukti dep updated to 1.2.0**: Adds GPU device discovery module (`gpu.cyr`).
  `enumerate_gpus()` walks `/sys/class/drm/` to detect GPU devices with vendor ID,
  driver name, PCI slot. Known vendors: AMD, Intel, NVIDIA, VirtIO. 485 tests pass.
  New `DC_GPU` device class. Unblocks mabda GPU pre-flight detection.

### Stats
- **40 stdlib modules + 5 deps**, 32 test suites

## [3.4.12] — 2026-04-11

### Changed
- **PIC-safe relocations in `object;` mode**: Data references (variables, strings,
  function pointers) now emit `LEA reg, [rip+disp32]` with `R_X86_64_PC32` relocations
  instead of `MOV reg, imm64` with `R_X86_64_64`. Eliminates DT_TEXTREL in linked
  binaries. Required for glibc 2.38+ which refuses `dlopen()` from TEXTREL binaries.
  Affects: `EVADDR`, `ESADDR`, `EVLOAD`, `EVSTORE`, `EVLOAD_W`, `EVSTORE_W` in emit.cyr,
  and function pointer fixups (type 3) in parse.cyr. Relocation generation updated in
  `EMITELF_OBJ` (fixup.cyr). Self-hosting verified (byte-identical two-step bootstrap).
  Unblocks mabda GPU port (wgpu-native Vulkan loading via dlopen).
- **`lib/mmap.cyr`**: Functions renamed to `cyr_mmap`, `cyr_munmap`, `cyr_mprotect`
  to avoid symbol clashes when linking Cyrius .o files with C/libc. Standalone Cyrius
  binaries are unaffected (no libc). All stdlib consumers updated (dynlib.cyr).

### Stats
- **40 stdlib modules + 4 deps**, 32 test suites

## [3.4.11] — 2026-04-11

### Added
- **`lib/dynlib.cyr`**: Pure Cyrius dynamic library loader. Opens ELF .so files via
  `mmap`, parses ELF64 headers, walks `.dynsym`+`.dynstr` to resolve exported symbols.
  Supports GNU hash table (fast O(1) average lookup) with linear scan fallback.
  API: `dynlib_open(path) → handle`, `dynlib_sym(handle, name) → fnptr`,
  `dynlib_close(handle)`. No libc, no dlopen — pure syscalls. Module #40.
  Unblocks FFI to wgpu-native for mabda GPU library port.

### Stats
- **40 stdlib modules + 4 deps**, 32 test suites

## [3.4.10] — 2026-04-11

### Fixed
- **Bug #36: Comparisons in function call arguments** (P0): `_cfo` (constant folding
  optimization flag) leaked across comparison operators in function call arguments.
  `assert(ps != 0, "msg")` generated wrong code because constant folding state from
  evaluating `0` persisted into the next argument's evaluation. Reset `_cfo` before
  and after comparison in `PCMPE`. Fixes `assert(expr op val, "msg")` pattern that
  crashed in large binaries. Libro+patra PatraStore: 202/202 pass. Also resolves
  Known Gotcha "No Comparisons in Args" for most patterns.

### Stats
- **32/32 cyrius, 202/202 libro+patra**

## [3.4.9] — 2026-04-11

### Added
- **`lib/log.cyr`**: Structured logging wrapper over sakshi. log_debug/info/warn/error/fatal
  with ISO-8601 timestamps, level filtering, key=value context. Module #37.
- **`lib/ws.cyr`**: WebSocket client (RFC 6455). Handshake, framing, masking, ping/pong,
  close. Client-side over TCP. Module #38.
- **`lib/tls.cyr`**: TLS 1.3 client scaffold (RFC 8446). Record layer, ClientHello with
  SNI + supported_versions. Key exchange requires X25519 (not yet in sigil) — scaffold
  only, handshake does not complete. Module #39.

### Changed
- **Patra dep updated to 0.14.0**.
- **Gotcha #6 confirmed resolved**: Nested while + load8 CSV parsing pattern now works.
  Root cause was single-slot break (multi-break linked-list fix in 3.4.6 resolved it).
  Regression test added.
- **Roadmap cleaned up**: Bugs #34, #35 marked resolved. fncall3-6, mmap marked done.
  Gotcha #6 removed from Known Gotchas.

### Stats
- **39 stdlib modules + 4 deps**, 32 test suites, 442 assertions

## [3.4.8] — 2026-04-11

### Changed
- Patra dep updated to 0.14.0. Gotcha #6 regression test added. Roadmap cleanup.

## [3.4.7] — 2026-04-11

### Fixed
- **Bug #35: SIGSEGV on large multi-lib programs** (libro+patra+sigil): The ifdef pass
  copy-back (462KB from `0x44A000` to `S+0`) overwrote `str_pos` at `0x70000` and
  `data_size` at `0x70008`. The lexer then used garbage string write positions, producing
  corrupt binaries or segfaults. Fix: re-initialize `str_pos` and `data_size` after
  preprocessing, before lexing. Two lines. Libro+patra: 343KB, 240/240 tests pass.
  Unblocks libro PatraStore (SQL-backed audit persistence).

### Stats
- **32/32 cyrius, 240/240 libro+patra**

## [3.4.6] — 2026-04-11

### Added
- **`tests/tcyr/regression.tcyr`**: Comprehensive regression test suite — 35 assertions
  covering all fixed bugs: 7+ stack args, multi-break, nested break, for-break, hex
  parsing, derive duplicate var, fncall3-6, inlining, DSE, constant folding, defer LIFO.

### Fixed
- **Multi-break re-applied** (Blocker #4): Linked-list break patching was accidentally
  reverted in 3.3.15 debug session. Re-applied for all loop types. Multiple `break`
  statements in same loop now all work. Caught by regression test.

### Stats
- **32/32 cyrius (incl regression), 240/240 libro**

## [3.4.5] — 2026-04-11

### Added
- **`lib/audio.cyr`**: ALSA PCM audio device I/O via direct ioctls. Pure syscall
  interface — no libasound, no C FFI. Playback + capture on `/dev/snd/pcmC*D*`.
  `audio_open_playback`, `audio_write`, `audio_read`, `audio_drain`, state queries.
  Module #36. Shared foundation for shravan playback and tarang audio pipeline.

### Changed
- **Codebuf/output relocated**: Codebuf moved `0x4CA000` → `0x54A000`, output
  `0x54A000` → `0x5CA000`. Preprocess buffer expanded 512KB → 1MB at `0x44A000`.
  Brk extended to 6.3MB.
- **`elf_out_len` relocated**: Moved from `0x5C130` (was inside new codebuf range)
  to `0x903F8`. Prevented code generation from overwriting output length at ~33KB CP.
- **Fixup pfx scratch relocated**: Moved from codebuf+128KB to output_buf+128KB.
  Prevented variable prefix sums from overwriting generated code.

### Fixed
- **aarch64 fixup codebuf address**: Was reading from old `0x4CA000` instead of new
  `0x54A000`. Caused all 26 aarch64 CI tests to fail.

### Known Issues
- **Bug #35 still open**: Preprocessor copy-back overflow for ~600KB expanded source.
  Ifdef pass converted to in-place filtering (safe), but macro/ref pass copy-backs
  still use `S+0` which overflows at ~565KB. Needs dedicated refactor session.
  *(Resolved in 3.4.7 via `str_pos`/`data_size` re-init after preprocessing.)*

## [3.4.4] — 2026-04-11

### Fixed
- **Bug #34: `#derive(Serialize)` duplicate variable**: The `_from_json_str` codegen
  declared `var _neg`, `var _iv`, `var _vs` inside each field's branch. Structs with
  multiple integer/string fields triggered "duplicate variable" on the second field.
  Fixed by declaring all locals once at function top, using assignment in branches.
  Argonaut serde tests: 39/39 pass. Unblocks argonaut and agnostik.
- **Bug #35: libro SIGSEGV at ~14.5K lines**: Resolved — was likely the same derive
  duplicate-variable issue. Libro 240/240 passes with patra+sigil included.

### Stats
- **31/31 cyrius, 240/240 libro, 39/39 argonaut serde**

## [3.4.3] — 2026-04-11

### Added
- **`fncall3`–`fncall6` in fnptr.cyr**: Indirect function calls with 3-6 arguments via
  System V ABI registers (rdx, rcx, r8, r9). Same inline asm pattern as fncall0-2.
  Unblocks tarang video codec APIs that need multi-arg indirect calls.
- **`lib/mmap.cyr`**: Memory-mapped I/O via direct syscalls. `mmap`, `munmap`, `mprotect`
  plus convenience wrappers `mmap_file_ro`, `mmap_file_rw`, `mmap_anon`. Foundation for
  dynlib.cyr (dynamic library loading) and zero-copy file access. Module #35.

### Known Issues
- **Gotcha #6 persists**: Nested while loops with shared counter + 4+ break iterations
  produce wrong results. 2-3 iterations work, 4+ fail. Linked-list break chain may
  corrupt on 4th link. Under investigation.

## [3.4.2] — 2026-04-11

### Changed
- **Patra dep updated to 0.13.0**: Now uses `dist/patra.cyr` (bundled 3,013-line single
  file, no SHA-256, no stdlib baked in). Resolves libro include conflicts.
- **`cyrius.toml` version synced to 3.4.1**.
- **Roadmap cleanup**: patra/libro moved to Done, shravan added, blocker #6 resolved,
  `cyrius deps` marked Done, stale counts/versions corrected.

## [3.4.1] — 2026-04-11

### Added
- **`_from_json_str` single-pass deserializer**: `#derive(Serialize)` now also generates
  `Name_from_json_str(json)` — O(json_length) single-pass parser that scans raw JSON
  once with inline field matching. Handles integers (including negative), strings, and
  whitespace/comma skipping. Complements existing `_from_json(pairs)` (O(n²) via json_get).
  Unblocks agnostik performance target (~2us regardless of field count).

### Fixed
- **`cyrius audit` lint/format**: Skips symlinked dep files. Shows which specific files
  have warnings. Reports dep file skip count. Better failure messages with file names.
- **Roadmap stale entries**: Bug #32/#33 marked resolved. Open Limits table corrected
  (512KB codebuf, 64KB tok_names).

## [3.4.0] — 2026-04-11

### Changed — Code Cleanup & Refactors
- **Dead loop var code removed**: All `_LOOPVAR_OK` checks, `GLVR`/`SLVR` calls,
  `ELVRINIT` calls, and r12 store-path branches removed from parse.cyr. ELVR emit
  functions retained as stubs (avoid undefined function warnings). ~1KB binary reduction.
- **Heap map cleanup**: `loop_var_slot` at `0x903F8` marked unused, init removed.
  47 regions, 0 overlaps, 1 minor gap warning.
- **Version string length fixed**: Corrected for single-digit minor versions.

### Stats
- **cc3: 243KB** (x86_64), 211KB (aarch64 cross)
- **31/31 cyrius, 240/240 libro**
- **Shravan unblocked** (284KB binary compiles with tok_names 64KB)

## [3.3.17] — 2026-04-11

### Fixed
- **LEXHEX wrong buffer** (Bug #33): Hex literal parser read from `S + p` (raw input
  buffer) instead of `S + 0x44A000 + p` (preprocessed buffer). For programs where the
  preprocessed source offset exceeded the raw input size, hex digits after position ~19KB
  read garbage. Masked for years because the compiler source was small enough that
  raw and preprocessed buffers overlapped. Exposed by the str_data move.
- **tok_names expanded 32KB → 64KB** (Bug #32): Moved `str_data` from `0x68000` (nested
  inside tok_names) to `0x40000` (unused region). tok_names now has full 64KB at
  `0x60000-0x70000`. Libro uses 26KB, self-compile uses 6KB. Unblocks shravan (~35KB+
  estimated for 565 functions + 2500 variables).

### Stats
- **31/31 cyrius, 240/240 libro, aarch64 cross: 212KB**

## [3.3.16] — 2026-04-11

### Fixed
- **Stale cc3 binary with r12 prologue**: The 3.3.12 r12 revert never fully committed
  to `build/cc3`. The binary still had `push r12`/`pop r12` in every function, causing:
  (a) 2x performance regression, (b) 7+ arg stack corruption (Bug #32 symptoms),
  (c) aarch64 cross-compilation failure. Rebuilt from 3.3.8 bootstrap root to get
  clean binary chain without r12.
- **aarch64 cross-compilation restored**: 212KB cross-compiler builds successfully.
- **r12 fully removed from source**: `_LOOPVAR_OK = 0`, prologue back to `push rbp;
  mov rbp, rsp`, epilogue `leave; ret`, tail call path matches.

### Added
- **Bug #32 filed**: Parser overflow at ~12K expanded lines (blocking shravan).
  Issue doc at `docs/development/issues/parser-overflow-large-codebase.md`.

## [3.3.15] — 2026-04-10

### Fixed
- **Multi-break in nested loops** (Blocker #4, final fix): Two-step landing —
  first, the 3.3.9 array-based patch table was reverted back to single-slot at
  `0x8F840` after libro's 240 tests hung in `entry_compute_hash`; the array
  approach subtly corrupted codegen around nested-loop save/restore. Then
  reimplemented using a linked list through codebuf rel32 fields — each `break`
  chains the previous break's patch offset into its jmp placeholder, and at
  loop exit the chain is walked patching each one. Zero extra heap, no
  save/restore state to corrupt. Linked-list approach passes libro 240/240 +
  multi-break + nested break tests.
- **Version string length**: Fixed `cc3 --version` output length for 2-digit
  minor versions.

### Stats
- **31/31 cyrius, 240/240 libro, multi-break + nested break all pass**
- **0 open compiler blockers**

## [3.3.14] — 2026-04-10

### Changed
- **`lib/bench.cyr` overhead documented**: Measured framework costs — clock_gettime ~120ns,
  fncall dispatch ~6ns, direct call ~3ns, inline ~2ns. Projects measuring sub-1us ops
  should use `bench_batch_start`/`bench_batch_stop` with batch_size >= 1000.
- **Break patch array initialized**: Explicit `S64(S + 0x20080, 0)` at startup.

### Known Issues
- **Libro hangs during Entry tests** (3.3.9+ regression): `entry_compute_hash` infinite
  loops when compiled with 3.3.9+. Works on 3.3.8. Under investigation for 3.3.15.
- **Gotcha #6** (nested while + load8): CSV parsing pattern with shared loop variable
  across nested while loops still produces wrong results. Separate from the libro hang.

## [3.3.13] — 2026-04-10

### Changed
- **`lib/bench.cyr` overhead documented**: Measured and documented framework costs:
  clock_gettime ~120ns, fncall dispatch ~6ns, direct call ~3ns, inline ~2ns.
  Projects measuring sub-1us ops (doom fixed_mul, shravan DSP) should use
  `bench_batch_start`/`bench_batch_stop` with batch_size >= 1000, not per-iteration
  `bench_start`/`bench_stop` or `bench_run_batch` with small batches.
  The ~650ns floor reported in cyrius-doom benchmarks was 2× clock_gettime overhead,
  not a compiler regression.

## [3.3.12] — 2026-04-10

### Fixed — Performance Regression
- **Reverted r12 loop var caching**: The `push r12`/`pop r12` added to every function
  prologue/epilogue in 3.3.5 caused a **2x performance regression** across cyrius-doom
  benchmarks (render_frame: 2.2ms → 4.3ms, fixed_mul: 435ns → 662ns). The overhead of
  2 extra instructions per function call vastly exceeded the savings from caching one
  loop counter in a register. Prologue restored to `push rbp; mov rbp, rsp`, epilogue
  to `leave; ret`. Stack arg offset reverted to `[rbp+16]`. `_LOOPVAR_OK` set to 0.
  Infrastructure preserved for future per-function opt-in approach.
- **Heap map audit**: 48 regions, 0 overlaps, 2 minor gap warnings (pre-existing).

### Root Cause Analysis
The r12 optimization (3.3.5) was tested for correctness but not benchmarked. It also
shifted the stack frame, breaking 7+ arg functions (Bug #32, fixed in 3.3.11). A proper
loop register allocator needs to be per-function (only push/pop r12 for functions with
cacheable loops), not global. Filed for future work.

### Stats
- **cc3: 245KB** (down from 247KB in 3.3.11)
- Heap map clean, 31/31 tests pass

## [3.3.11] — 2026-04-10

### Fixed
- **7+ arg stack parameter offset** (Bug #32): The `push r12` added in 3.3.5 (loop var
  register caching) shifted the stack frame by 8 bytes, but `ESTORESTACKPARM` still read
  stack args at `[rbp+16]`. Corrected to `[rbp+24]`. All stack-passed arguments (7th+)
  were reading garbage values. Affected any function with > 6 parameters. Discovered via
  cyrius-doom and shravan (FLAC encoder crash). Four-step bootstrap verified.
- **FLAC bitwriter bounds check** (shravan): `flac_bw_write_bits` now grows the buffer
  when at capacity instead of writing past the allocation.

## [3.3.10] — 2026-04-10

### Fixed
- **`cyrius audit` compile check**: Was compiling every `src/*.cyr` file individually,
  causing false failures on modules that depend on includes. Now compiles the build
  entry point from `cyrius.toml` (`[build] src`), falling back to `src/lib.cyr` or
  `src/main.cyr`.

## [3.3.9] — 2026-04-10

### Fixed
- **`break` in nested while/if** (Blocker #4): Break patches expanded from single slot
  to 16-entry array. Multiple `break` statements per loop now all patch correctly.
  Previously only the last `break` was patched — earlier breaks jumped to garbage.
  Updated while, for-in, for-each, and C-style for loops. Resolves the oldest open
  compiler bug (reported in 3.2.6, workaround via flag variables).

### Changed
- **Sigil dep updated to 2.0.1**: Now fetches bundled `dist/sigil.cyr` (4,259 lines,
  self-contained) instead of `src/lib.cyr` (include manifest). Fixes downstream
  include resolution failures.

### Stats
- **0 known compiler bugs remaining** (Blockers #1-5 all resolved)

## [3.3.8] — 2026-04-10

### Changed
- Version bump for codebuf 512KB release (binary rebuild).

## [3.3.7] — 2026-04-10

### Changed
- **Codebuf 256KB → 512KB**: Code buffer and output buffer doubled. Moved from low heap
  (`0x20000`/`0xDA000`) to high heap (`0x4CA000`/`0x54A000`) to avoid shifting 100+
  hardcoded mid-heap offsets. Brk extended from 4.8MB to 5.8MB. Unblocks shravan (audio
  codec, 277KB binary) and other large programs. Updated in emit.cyr, fixup.cyr, jump.cyr
  for x86, aarch64, and cx backends. Four-step bootstrap verified.
- **Patra dep updated to 0.12.0**: Hand-rolled SHA-256 removed from patra, crypto
  responsibility delegated to sigil.

## [3.3.6] — 2026-04-10

### Changed
- **Dependency system fixed**: `resolve_deps()` was shadowed by a broken second definition
  that only wrote comment lines. Removed the shadow — git fetch + symlink into `lib/` now
  works. `lib.cyr` → `<depname>.cyr` rename prevents collisions. `fetch_git_dep` handles
  empty dirs and clone failures gracefully.
- **Vendored libs removed**: `lib/patra.cyr`, `lib/sakshi.cyr`, `lib/sakshi_full.cyr`,
  `lib/sigil.cyr` replaced by proper `[deps]` in `cyrius.toml`. `cyrius deps` fetches
  from git repos and symlinks into `lib/`.
- **`cyrius deps` subcommand**: Now actually resolves — fetches git deps, creates symlinks,
  reports status. Was display-only before.
- **Patra dep updated to 0.12.0**: Hand-rolled SHA-256 removed from patra, crypto
  responsibility moved to sigil.
- **CI updated**: All jobs run `cyrius deps` before tests. Format/lint/doc checks skip
  symlinked dep files. AGNOS container skips dep-dependent tests if git unavailable.

### Fixed
- **`cyrlint` snake_case rule**: Was scaffold (detection existed, `warn()` call missing).
  Now detects actual camelCase (lowercase→uppercase transition). Allows POSIX macros
  (`WIFEXITED`), type methods (`Str_new`), and `_`-prefixed internals. 0 warnings on stdlib.
- **`doc --serve`**: Was saving raw markdown as `.html`. Now wraps in proper HTML with
  styling and back-link to index.
- **`cyrius.toml` added**: Cyrius itself now has a manifest with `[deps]` declarations
  for sakshi (0.9.0), patra (0.12.0), sigil (2.0.0).

### Stats
- **34 stdlib modules + 3 deps**, 31 test suites, 375 assertions

## [3.3.5] — 2026-04-10

### Added
- **Sigil v2.0.0 available as dep**: System-wide trust verification for AGNOS.
  Ed25519 keypair/sign/verify (RFC 8032), SHA-256, SHA-512, HMAC-SHA256, integrity
  verification, revocation lists, audit logging, trust policy engine.
- **Small function inlining expanded**: Parameter limit raised 1→2, body token limit 6→16.
  2-param functions like `u256_limb(a, i)` now inline at call sites. Param names packed as
  `pn1<<32 | pn0` in fn_inline slot. Call site handles p0_slot + p1_slot with proper
  name registration and invalidation.
- **Loop variable register caching (x86)**: `r12` reserved as loop counter register. Function
  prologue/epilogue save/restore r12. At `while(...)`, if condition starts with a local
  variable, it's cached in r12. Loads emit `mov rax, r12` (3 bytes) instead of
  `mov rax, [rbp-N]` (7 bytes). Stores write both r12 and stack for call safety.
  Gated by `_LOOPVAR_OK` flag (x86 only, stubs on aarch64/cx).

### Fixed
- **`lib/bigint.cyr` u256_sub borrow propagation**: When `b_limb = 0xFFFFFFFFFFFFFFFF`
  and `borrow_in = 1`, overflow to 0 silently lost the borrow. Fixed with `_sub_limb`
  helper. Also unrolled `u256_add` into `_add_limb` helpers. Critical for Ed25519
  modular reduction where p's limbs 1,2 are all-F.

### Changed
- **Roadmap updated**: Cleaned up stale entries. `doc --serve` marked done. Function limit
  corrected to 2048. Sigil moved to done. Dead store elimination and constant folding
  marked as completed features.

### Stats
- **38 stdlib modules, 31 test suites, 375 assertions**
- **cc3: 246KB** (x86_64), self-hosting verified (three-step bootstrap for codegen change)

## [3.3.4] — 2026-04-09

### Changed
- Roadmap cleanup and documentation alignment.

## [3.3.3] — 2026-04-09

### Added
- **`lib/bigint.cyr`**: 256-bit unsigned integer arithmetic for cryptography.
  4-limb (4 × 64-bit) representation, little-endian. Core operations:
  `u256_add`, `u256_sub`, `u256_mul`, `u256_mod`, `u256_cmp`, `u256_shl1/shr1`,
  `u256_addmod`, `u256_submod`, `u256_mulmod`, `u256_to_hex`, `u256_from_hex`.
  64×64→128-bit multiplication via 32-bit half splitting (4 partial products).
  Unsigned comparison via XOR-high-bit trick (no unsigned type in Cyrius).
  Module #37. 21 assertions in bigint.tcyr. Unblocks sigil (Ed25519/secp256k1).

### Stats
- **37 stdlib modules, 31 test suites, 406 assertions**

## [3.3.2] — 2026-04-09

### Added — Dead Store Elimination
- **Post-emit DSE pass**: After function body compilation, scans codebuf for consecutive
  stores to the same `[rbp-N]` offset. First store NOPped (7 bytes → 0x90 sled).
  Pattern: `mov [rbp-N], rax` followed by load + `mov [rbp-N], rax` with same N.
  Eliminates `var x = 0; x = 42;` dead initialization stores.
  Applied per-function after epilogue emission, before frame size patching.
  Self-hosting verified, 30/30 tests pass.

## [3.3.1] — 2026-04-09

### Added — ISO-8601 in chrono.cyr
- **`iso8601(epoch)`**: Format epoch seconds as `2026-04-09T15:30:00Z`.
- **`iso8601_now()`**: Format current time as ISO-8601.
- **`iso8601_parse(str)`**: Parse ISO-8601 string to epoch seconds.
- **`epoch_to_date(epoch)`**: Convert to {year, month, day, hour, min, sec} struct.
- **`is_leap_year(y)`**: Leap year check (400-year cycle).
- **chrono.tcyr expanded**: +13 assertions (format, parse, roundtrip, leap year).
  Total: 21 chrono assertions.
- Unblocks sigil (trust/signing needs canonical timestamps).

### Changed — Expanded Constant Folding
- **Removed 16-bit result limit**: Constant folding for `+`, `-`, `*` now accepts any
  non-negative result (was limited to `cfr < 0x10000`). `50 * 1000 = 50000` now folds
  at compile time instead of emitting `imul` at runtime. EMOVI handles 32-bit and 64-bit
  immediates, so the restriction was artificial.
- **`x - 0` identity**: Subtraction by zero now elided (like `x + 0` and `x * 1`).
- **Removed input range limit for multiply/add/sub**: `crv < 0x10000` input restriction
  removed for `*`, expanded for `+` and `-`. Any positive literal can now participate
  in constant folding.
- **Impact**: Math-heavy code (hisab, doom, bsp) gets compile-time evaluation for
  expressions like `320 * 65536`, `4096 + 128`, `PAGE_SIZE - HEADER`.

## [3.3.0] — 2026-04-09

### Added
- **Minimum version enforcement**: `cyrius.toml` now supports `cyrius = "3.2.5"` field.
  `cyrius build` checks `cc3 --version` against the requirement and errors early:
  `error: this project requires Cyrius >= 3.2.5 (you have 3.1.0)`.
  Includes install command in error message. Uses `version_gte` comparison function.
  Like Rust's `rust-version`, Go's `go` directive, Zig's `minimum_zig_version`.

## [3.2.7] — 2026-04-09

### Added
- **`cc3 --version`**: Compiler now responds to `--version` flag with `cc3 X.Y.Z`.
  Reads `/proc/self/cmdline` for argv[1], checks for `--ve` prefix. Version string
  hardcoded at compile time, auto-updated by `scripts/version-bump.sh`.
  No more agents confused by raw ELF output when trying to check compiler version.
- **`cyrius --version`** already worked (shell script reads VERSION file).

## [3.2.6] — 2026-04-09

### Added
- **`#derive(Serialize)` 2-arg composable form**: `Name_to_json_sb(ptr, sb)` writes to
  caller's string builder for nested struct serialization. 1-arg `Name_to_json(ptr)` is
  now a wrapper that creates sb, calls _to_json_sb, returns built string. Backward
  compatible. Nested struct fields use _to_json_sb for zero-copy composition.
  Unblocks agnostik dropping 9 manual _to_json implementations (~200 lines).

### Fixed
- **lib/json.cyr**: `json_parse` failed to delimit non-string values (integers, booleans)
  in cc3. Chained `if (vc == 44) { break; }` inside `while` loop did not break — cc3
  codegen bug with `break` inside chained `if` blocks within `while`. Workaround: replaced
  with flag variable + `||` conditional. Discovered via argonaut serde round-trip tests.
  All 22 argonaut test suites (545 assertions) now pass on cc3.

---

## [3.2.5] — 2026-04-09

### Changed — cc2 → cc3 Rename
- **Compiler binary renamed**: `cc2` → `cc3`, signaling the 3.x generation.
  `cc2_aarch64` → `cc3_aarch64`, `cc2cx` → `cc3cx`, `cc2-native-aarch64` → `cc3-native-aarch64`.
  All source files, scripts, CI, release workflows, docs updated.
  Backward compat: `~/.cyrius/bin/cc2` symlinks to `cc3`.
  Downstream repos (agnostik, argonaut, libro, bsp, cyrius-doom) updated.
  Bootstrap chain: `asm → stage1f → bridge → cc3 (233KB)`.

### Changed — Cleanup & Docs Sync
- **All docs synchronized to v3.2.5**: Compiler size 233KB, 36 stdlib modules,
  30 test suites, 372 assertions updated across README.md, CLAUDE.md, roadmap,
  benchmarks, architecture docs, ADRs, and cyrius-guide.
- **patra.cyr formatted**: Auto-formatted via cyrfmt on import.
- **Roadmap defer status**: Updated to "Done (v3.2.0)".
- **Vidya updated**: 223 entries (+16 since 3.0).

### Added
- **`lib/patra.cyr`**: Structured storage and SQL queries. Single-file distribution of
  Patra v0.8.0 (2496 lines). SQL subset: CREATE TABLE, INSERT, SELECT (WHERE, ORDER BY,
  LIMIT), UPDATE, DELETE. B-tree indexed pages in .patra files, flock concurrency.
  Zero external dependencies. Module #36. 212 assertions pass in patra repo.

### Stats
- **36 stdlib modules** (was 35)

## [3.2.4] — 2026-04-09

### Added
- **`strstr(haystack, needle)`** (string.cyr): Substring search using `memeq`. Returns
  index or -1. Workaround for nested while loop codegen bug — use `memeq`-based functions
  instead of manual byte loops with `load8` comparisons.

### Known Issue — Documented
- **Nested while loop codegen bug**: `load8` comparisons inside inner while loops produce
  wrong results. Affects: substring search, byte-by-byte matching in nested loops.
  Root cause: expression register clobbered by loop condition evaluation.
  Workaround: use `memeq()`, `strchr()`, `strstr()` — all use single function calls
  that avoid the nested loop pattern. Filed as Known Gotcha #6.

## [3.2.3] — 2026-04-09

### Fixed
- **`#derive(Serialize)` Str field support**: Fields annotated `: Str` now serialize as
  quoted JSON strings (`"alice"`) instead of raw pointer addresses. Both `_to_json` and
  `_from_json` handle Str fields correctly. Integer fields remain bare numbers (`42`).
  Combined with 3.2.2's integer fix, derive now generates correct JSON for mixed structs:
  `{"id":42,"name":"alice","level":5}`.
- **Function table 1024→2048**: (from 3.2.2) Unblocks agnostik `_from_json` generation.

## [3.2.2] — 2026-04-09

### Fixed
- **`#derive(Serialize)` emits bare integers**: Scalar fields now serialize as `42`
  instead of `"42"`. Removed quote-wrapping from PP_DERIVE_SERIALIZE codegen.
  `{"x":10,"y":20}` is now valid JSON with correct numeric types.
- **version_from_str prerelease+build parsing** (agnostik): `2.0.0-rc.1+build.42`
  now correctly parses patch=0, pre="rc.1", build="build.42". Root cause: `load8` + `==`
  comparison in while loop failed silently in large compilation units. Workaround:
  replaced with `strchr` for separator detection. Filed as compiler codegen investigation.

### Changed — Hashmap Cleanup & Stdlib Refactor
- **hashmap.cyr**: Removed unused `HASHMAP_ENTRY_SIZE` var. Added `map_get_or(m, key, default)`
  for safe lookup (distinguishes not-found from zero-value). Added `map_size(m)` alias.
- **hashmap_fast.cyr**: Added `fhm_get_or(m, key, default)` and `fhm_size(m)` for
  API parity with hashmap.cyr. Both hashmaps now have identical public API surface.
- **hashmap_ext.tcyr**: +6 assertions (get_or, size alias for both hashmaps).
  Total: 20 hashmap assertions.

### Stats
- **30 test suites, 372 assertions** (was 366)
- Format/lint/doc 100% clean

### Changed
- **Function table expanded 1024→2048**: Six function tables (names, offsets, params,
  body_start, body_end, inline) each doubled from 8KB to 16KB. All downstream regions
  relocated (struct_fnames, output_buf, var tables, token arrays, preprocess buffer).
  brk increased from 4.7MB to 4.8MB. Two-step bootstrap verified.
  Unblocks agnostik `_from_json` deserialization (was hitting 1024 function ceiling).
- **cc2**: 232KB (was 231KB)

## [3.2.1] — 2026-04-09

### Changed
- **Sakshi updated to v0.8.0**: Both `lib/sakshi.cyr` (slim) and `lib/sakshi_full.cyr`
  (full) updated from v0.7.0 to v0.8.0. Changes: constants converted from vars to enums,
  `match` for level dispatch, `_sk_level_str` helper centralized. Slim profile now uses
  proper enum types (bug #16 workaround removed). All 26 sakshi assertions pass.

## [3.2.0] — 2026-04-09

### Added — Language Feature
- **`defer` statement**: `defer { body }` executes body at function return in LIFO order.
  Token 106. Deferred blocks compiled inline (jumped over during normal flow), chained
  at epilogue via jmp→block→jmp→block→epilogue. Return value preserved (push/pop rax
  around defer chain). Max 8 defer blocks per function. Zig/Odin parity.
  4 assertions in defer.tcyr.

### Added — Tooling
- **`cyrius doc --serve [port]`**: Generate HTML docs for all .cyr files and serve
  locally via Python's http.server. Creates build/docs/ with index.html.
  `cyrius doc --serve 8080` for browsing stdlib and project documentation.

### Changed
- **Roadmap rewritten**: Cleaned up for 3.x — removed completed v2.0 plan, archived
  bug history, organized active work into Compiler/Platform/Stdlib/Tooling/Ports sections.

### Stats
- **30 test suites, 366 assertions** (was 29/362)

## [3.1.0] — 2026-04-09

### Added — Stdlib
- **`lib/csv.cyr`**: RFC 4180 CSV parser and writer. `csv_parse_line(line)` returns vec
  of fields. Handles quoted fields, escaped quotes, commas in quotes. `csv_escape(field)`
  and `csv_write_line(fields)` for output. Module #34. 12 assertions.
- **`lib/http.cyr`**: Minimal HTTP/1.0 client. URL parser, request builder, response
  parser (status code + body extraction). `http_get(url)` for simple requests via
  net.cyr TCP sockets. Module #35. 5 assertions.

### Added — Platform Stubs
- **`src/backend/macho/emit.cyr`**: Mach-O emitter stub for macOS x86_64 + aarch64.
  Documents format differences from ELF (load commands, sections, macOS syscalls).
  Three-phase plan: .o → executable → syscall shim.
- **`src/backend/pe/emit.cyr`**: PE/COFF emitter stub for Windows x86_64.
  Documents format differences (DOS stub, import directory, Win32 API).
  Three-phase plan: .obj → executable → kernel32 imports.

### Stats
- **35 stdlib modules** (was 33)
- **29 test suites, 362 assertions** (was 27/345)

## [3.0.0] — 2026-04-09

**Cyrius 3.0** — Sovereign, self-hosting systems language. Assembly up.

### Release Summary

231KB compiler. Self-hosting on x86_64 + aarch64. 33 stdlib modules.
27 test suites (345 assertions), 4 fuzz harnesses. Zero open bugs (#14-#31 all resolved).
8 downstream repos pass (agnostik, agnosys, argonaut, sakshi, majra, libro, bsp, cyrius-doom).
Soak test clean. Format/lint/doc 100% clean.

### Since v2.0

**Compiler:**
- Multi-width types (i8/i16/i32), sizeof, unions, bitfields, expression type propagation
- FINDVAR last-match (var buf[N] sharing fix), >6 args on x86+aarch64
- Constant folding (x+0, x*1, x*0), prefix-sum fixup optimization
- ELF .o relocatable output (`object;` directive)
- cyrius-x bytecode VM with recursion, syscall string output
- String data buffer 8KB→32KB, globals 256→1024, tokens 65536→131072
- Error messages with variable names, output-too-large diagnostics
- All ERR_MSG string lengths verified

**Stdlib (33 modules):**
- base64, chrono, sakshi_full, freelist, flock (file_lock/unlock/append_locked)
- hashmap_fast with full API (delete, keys, values, clear)
- str_replace bug fixed, atoi added, str_join bug fixed
- All modules documented (cyrdoc --check 0 undocumented)

**Tooling:**
- `cyrius` build tool (renamed from cyrb), `cyriusup` version manager
- `cyrius test` with .tcyr auto-discovery
- `cyrius fuzz` with .fcyr harnesses + --compiler mutation mode
- `cyrius soak` overnight validation (self-host + tests + fuzz + 6 repos)
- `cyrius watch` file watcher + auto-recompile
- `cyrius deps` manifest dependency viewer
- `cyrius audit` quality gate

**Quality:**
- P(-1) scaffold hardening process formalized
- Port validation: 8/8 downstream repos compile and test clean
- 186 vidya entries documenting every feature and bug

## [2.9.0] — 2026-04-09

### Added — Stdlib
- **`lib/base64.cyr`**: RFC 4648 base64 encode/decode. `base64_encode(buf, len)` returns
  null-terminated string. `base64_decode(encoded, enc_len)` returns {ptr, len} pair.
  Module #32. 12 assertions in base64.tcyr.
- **`lib/chrono.cyr`**: Time and duration utilities. `clock_now_ns()`, `clock_now_ms()`,
  `clock_epoch_secs()`, `dur_new/secs/nsecs/to_ms/between`, `sleep_ms()`.
  Module #33. 8 assertions in chrono.tcyr.

### Added — Tooling
- **`cyrius watch`**: File watcher — polls .cyr files, recompiles on change.
  `cyrius watch src/main.cyr build/app`. Configurable interval via CYRIUS_WATCH_INTERVAL.

### Changed — Compiler Optimizations
- **Prefix-sum variable offsets**: FIXUP walk for variable addresses now O(n) instead of
  O(n²). Precomputes cumulative offsets in a single pass before the fixup loop.
- **Fixup bounds check**: Variable fixup index validated against GVCNT before access.
  Prevents silent corruption from invalid fixup entries.
- **Constant fold `x + 0`**: Addition with zero elided — no EADDR emitted, keeps
  constant folding active for further optimizations in the expression.
- **Constant fold `x * 1` and `x * 0`**: Multiply by 1 elided (identity). Multiply
  by 0 replaced with `EMOVI(S, 0)`. Both keep constant fold chain active.

### Stats
- **33 stdlib modules** (was 31)
- **27 test suites, 345 assertions** (was 25/325)
- **cc2**: 231KB, self-hosting verified

## [2.8.2] — 2026-04-09

### Fixed
- **Bug #31: struct field access on undefined var no longer segfaults**: Root cause:
  error handler called `PRLINE(S)` which didn't exist as a function — the compiler
  generated a call to address 0, causing SIGSEGV. Replaced all 4 instances with
  `syscall(SYS_WRITE, 2, "error:", 6); PRNUM(GTLINE(S, GTI(S)))`. Now correctly
  shows `error:N: undefined variable 'name'` for `q.x` where `q` is undefined.

**No open bugs.** All reported issues (#14-#31) fixed or resolved.

## [2.8.1] — 2026-04-09

### Added
- **`sakshi_full.tcyr` test suite**: 20 assertions covering log levels, error handling,
  error context, spans (enter/exit/depth), output routing (buffer/file), ring buffer
  (put/count/clear), and err_at_span. Total: 25 suites, 325 assertions.
- **Improved "output too large" error**: Now shows code/data/strings breakdown and
  suggests `alloc()` for large buffers. Warns at >128KB static data.

### Fixed
- **Argonaut sakshi_full issue documented**: Large static `var buf[N]` arrays (64KB+)
  exhaust the 262KB output buffer. Fix: heap-allocate via `alloc()` for buffers >4KB.
  Compiler now shows actionable diagnostics when this happens.

## [2.8.0] — 2026-04-09

### Changed — Cleanup/Audit/Refactor
- **hashmap_fast.cyr**: Added `fhm_delete`, `fhm_keys`, `fhm_values`, `fhm_clear` —
  now has API parity with hashmap.cyr. 8 new assertions in hashmap_ext.tcyr.
- **str.cyr**: Documented `str_starts_with` takes C string (vs `str_ends_with` takes Str).
  Kept for backward compatibility.
- **sakshi.cyr**: Updated stale comment — bug #16 workaround note now says "fixed in v2.1.0,
  kept as vars for compatibility".
- **Stdlib audit**: 31 modules, 451+ functions audited. Zero dead code found.
  Missing-include documentation is by design (consumer provides stdlib).
  Hashmap grow "leak" is by design (bump allocator, no individual free).
- **Total**: 24 suites, 305 assertions, 0 failures.

## [2.7.5] — 2026-04-09

### Added
- **File locking** (io.cyr): `file_lock(fd)`, `file_unlock(fd)`, `file_trylock(fd)`,
  `file_lock_shared(fd)` — flock(2) wrappers. Plus `file_append_locked(path, buf, len)`
  for atomic append-only log writes. Constants: LOCK_SH, LOCK_EX, LOCK_UN, LOCK_NB.
  Enables libro's audit chain without a database — JSON Lines + flock.
- **io.tcyr expanded**: +6 assertions for lock/unlock, trylock, append_locked.
  Total: 15 assertions in io.tcyr.
- **`resolve_deps` scaffolding**: `compile()` in shell script now reads `[deps.*]`
  from `cyrius.toml` and calls `resolve_deps` before compilation. Stub implementation —
  full include path resolution planned for 3.0.

### Changed
- **Downstream CI fully cleaned**: agnosys (was 1.9.2 + cyrb), argonaut (cyrb + cyrb.toml),
  sakshi release.yml — all updated to standard pattern with 2.7.2.
  `cyrb.toml` → `cyrius.toml` in agnosys and argonaut.

### Known Issues
- **Struct field access on undefined var segfaults**: `var r = q.x;` where `q` is
  undefined crashes instead of showing an error. The FINDVAR check inside
  PARSE_FIELD_LOAD fires but PRSTR crashes on the name offset. Filed for 3.0.

## [2.7.4] — 2026-04-09

### Fixed
- **Undefined variable errors show variable name**: 4 remaining FINDVAR call sites
  in parse.cyr (address-of, field load, field store, assignment) now print the
  variable name instead of generic "syntax error". All agents benefit from clearer
  error messages during development.

### Added
- **`cyrius deps` command**: Reads `[deps.*]` sections from `cyrius.toml`, displays
  dependency map with path resolution and existence check. Phase 1 of manifest-based
  dependency management for multi-repo builds.

### Changed
- **Downstream CI fully cleaned**: agnosys, argonaut, sakshi — all `cyrb` references
  removed, standard `$HOME/.cyrius/` install pattern, 2.7.2 pinned. `cyrb.toml`
  renamed to `cyrius.toml` in agnosys and argonaut.

## [2.7.3] — 2026-04-09

### Added
- **`cyrius soak` command**: Overnight validation loop for v3.0 readiness. Each iteration:
  two-step self-hosting, full .tcyr suite, all .fcyr fuzz harnesses, compile 6 downstream
  repos (agnostik, agnosys, argonaut, majra, libro, cyrius-doom). `cyrius soak 100` for
  100 iterations. Custom repos: `cyrius soak 10 "repo1 repo2"`.

### Changed
- **Port validation sweep**: All 8 downstream repos verified — 646 assertions across
  5 tested repos, 0 failures. agnostik (223), majra (144), libro (193), bsp (74),
  sakshi (12). argonaut, agnosys, cyrius-doom compile clean.
- **`cmd_test` temp path**: Changed from `/tmp/cyrius_test` to `/tmp/cyrius_test_bin`
  to avoid collision with stale directories.

## [2.7.2] — 2026-04-09

### Fixed
- **cyrius-x syscall string output**: VM now copies .cyx data section (vars + strings)
  into VM memory at bytecode offsets. Syscall handler translates virtual addresses to
  real pointers for write/read/open syscalls. `syscall(1, 1, "hello", 5)` now works.
  cx compiler fixup patching corrected (coff-2 for movi immediate bytes).
- **Argonaut bug #23 resolved**: Tests split into 15 suites (395 assertions), all pass.
  Original single-file heap exhaustion no longer triggered.

### Added
- **`process.tcyr` test suite**: fork+waitpid and fork+pipe tests (4 assertions).
  Total: 24 test suites, 291 assertions.
- **`cyrius test` auto-discovery** (binary): Discovers `tests/tcyr/*.tcyr` when no
  file argument given. Binary compile path needs further debugging.

## [2.7.0] — 2026-04-09

### Fixed
- **`return fn(>6 args)` tail call bug**: Tail call optimization destroyed the stack
  frame before jumping, clobbering stack-passed arguments (7th+). Now falls through
  to normal call+return for >6 args. Tail call still used for ≤6 args.
  `return f7(1,2,3,4,5,6,7)` now returns 28 (was 22). Bug #27 workaround no longer
  needed for >6 arg functions.
- **String data overflow detection**: Added bounds check in lexer. Programs exceeding
  the 16KB string literal buffer now fail with a clear error message instead of
  silently corrupting adjacent compiler state.

### Added
- **`atoi` function** (string.cyr): Parse null-terminated decimal string to integer.
  Handles negative numbers. Returns 0 for invalid input.
- **`args.tcyr` test suite**: 11 assertions covering argc, argv, and atoi.
  Total: 23 test suites, 287 assertions.

## [2.6.4] — 2026-04-09

### Added — Multi-file Compilation (Phase 1)
- **`object;` directive**: New keyword triggers ELF .o relocatable output (kernel_mode=3).
  Token 79 in lexer. Pass 1 and pass 2 handle it like `kernel;` and `shared;`.
- **`EMITELF_OBJ` function**: Emits proper ELF relocatable with 7 sections:
  `.text` (code), `.data` (variables), `.rodata` (strings), `.symtab` (symbols),
  `.strtab` (symbol names), `.rela.text` (relocations), null section header.
- **Symbol table**: All functions emitted as `STT_FUNC / STB_GLOBAL` symbols with
  their `.text` offsets. Section symbols for .text/.data/.rodata.
- **Relocation table**: Fixup entries converted to ELF relocations:
  type 0 (var) → R_X86_64_64 vs .data, type 1 (string) → R_X86_64_64 vs .rodata,
  type 2 (fn call) → R_X86_64_PC32, type 3 (fn ptr) → R_X86_64_64.
- **FIXUP skip for .o mode**: Internal fixup resolution skipped — addresses left
  unresolved for the linker. Only totvar computed for .data sizing.
- **Verified with readelf**: Sections, symbols, relocations all parse correctly.
  Phase 2 (minimal linker) is next.

### Changed
- **Binary size audit**: 215KB (220008 bytes), 35KB margin to 250KB target. 75-80%
  code, 18-20% variable data, 2-3% strings. No urgent action needed. Monitor at 230KB.

## [2.6.3] — 2026-04-09

### Fixed
- **ERR_MSG string length errors**: 5 error messages had wrong length args (off by 1-3
  bytes), causing reads past string boundary. Fixed in parse.cyr (4) and cx/emit.cyr (1).
  Two-step self-hosting verified, cc2 updated.
- **cyrius-x fp save on call stack**: Function prologue/epilogue now saves fp to the
  call stack (new opcodes 0x62 pushc, 0x63 popc) instead of the data stack. Prevents
  data stack corruption when function calls occur between pushed expression temps.
- **cyrius-x tail call disabled**: ETAILJMP now emits normal call+epilogue. The tail
  call path in parse.cyr skips ret_patches, causing `return f(x, g(x-1))` to jump
  to wrong address. Known limitation: use `var r = f(...); return r;` workaround
  (same as x86 `return fn7()` bug).
- **majra sha1 buffer overflow**: `var w[80]` was 80 bytes for 640 bytes of data.
  Changed to heap-allocated `alloc(640)`. Test expectation corrected (was wrong RFC
  example, verified with Python).

### Added
- **toml.tcyr test suite**: 25 assertions covering parse, sections, key lookup,
  comments, empty input, constructors, file parsing.
  Total: 22 test suites, 276 assertions.

### Changed
- **All docs synchronized**: Binary sizes (215KB), module counts (31), test counts,
  heap map (ADR-003 rewritten from v0.9.5 to v2.6), roadmap header updated.
- **vidya updated**: +12 entries across language.toml, implementation.toml, ecosystem.toml
  covering v2.1–v2.6 features and bugs.

## [2.6.2] — 2026-04-09

### Fixed
- **aarch64 >6 function arguments**: ECALLPOPS now saves extras to x9-x12, pops 6
  register args, pushes extras back for callee. ESTORESTACKPARM loads extras from
  caller stack frame via [x29+offset]. ESTOREPARM dispatch fixed (was checking pidx<8,
  now pidx<6 to match the 6-register convention). ECALLCLEAN adjusts sp after call.
  Verified: f7(1..7)=28, f9(1..9)=45. 14/14 aarch64 tests pass.

## [2.6.1] — 2026-04-09

### Fixed
- **stdlib crashes resolved (math, matrix, regex)**: All three modules now work
  correctly. Root cause was the FINDVAR fix in v2.1.0 — the crashes were already gone
  but never re-tested. Removed from "known broken" list.
- **str_replace bug** (regex.cyr): Used `strlen()` on Str arguments instead of
  `str_len()`/`str_data()`. First replacement matched garbage memory. Fixed to use
  proper Str accessors. str_replace_all also fixed (delegates to str_replace).

### Added
- **3 new .tcyr test files**: math (11 assertions), matrix (12), regex (20).
  Total: 21 test suites, 251 assertions.

## [2.6.0] — 2026-04-09

### Added — Tests & Benchmarks
- **5 new .tcyr test files**: str_ext (27 assertions), freelist (13), trait (9),
  fs (13), io (9). Total: 18 test suites, 208 assertions.
- **2 new .bcyr benchmarks**: bench_str (6 benchmarks), bench_freelist (3 benchmarks).
  Total: 9 benchmark files.
- **1 new .fcyr fuzz harness**: freelist stress test (100 alloc/free cycles, mixed
  ordering). Total: 4 fuzz harnesses.

### Fixed
- **str_join bug**: Was calling `str_builder_add_cstr(sb, sep)` on a Str argument.
  Fixed to `str_builder_add(sb, sep)`.
- **CLAUDE.md rewritten**: Added P(-1) Scaffold Hardening phase, Consumers section,
  Key Principles, Quick Start commands. Removed stale tool inventory and fixup entries.
- **P(-1) audit fixes**: Compiler size corrected (205→215KB across all docs), README
  test metrics updated, roadmap cyrius-x targets updated to reflect v2.5.0 reality,
  package-format.md TODO placeholder resolved.

## [2.5.0] — 2026-04-08

### Fixed — cyrius-x VM
- **Recursion now works**: VM memory-backed stack frames. sp (r254) initialized to top
  of 64KB data segment, stack grows downward. fp/sp frame pointer chain enables proper
  nested function calls. fib(10)=55, fact(5)=120 verified.
- **VM heap-allocated state**: Registers, memory, data stack, call stack all heap-allocated
  via alloc() instead of global arrays. Avoids code buffer overflow. Data stack expanded
  to 1024 entries, call stack to 1024 entries.
- **Remaining emitter issues**: Nested recursive calls (ack) have register clobber in
  argument passing. Syscall string addresses need virtual→real translation. Both are
  cx/emit.cyr issues, not VM.

## [2.4.0] — 2026-04-08

### Changed
- **Initialized globals expanded 256→1024**: `gvar_toks` buffer expanded from 2048 to
  8192 bytes (0x98000). `gvar_cnt` relocated from 0x98800 to 0x9A000. Unblocks large
  programs with many global variables. Two-step self-hosting verified.

## [2.3.3] — 2026-04-08

### Fixed
- **Version manager → `cyriusup`**: Install script was writing a version manager to
  `~/.cyrius/bin/cyrius`, stomping on the build tool. Version manager renamed to
  `cyriusup` (like rustup). `cyrius` is now exclusively the build tool.
- **Install script symlink fix**: `rm -f` on directories replaced with `rm -rf` so
  fresh installs don't fail when `~/.cyrius/bin` and `~/.cyrius/lib` are directories
  instead of symlinks.

## [2.3.2] — 2026-04-08

### Added
- **`.fcyr` fuzz file format**: New file extension for fuzz harnesses. `cyrius fuzz`
  auto-discovers `fuzz/*.fcyr` files. Ships with 3 harnesses: hashmap, vec, string.
- **`cyrius fuzz` in binary**: Native Cyrius binary now supports `cyrius fuzz` command
  alongside the shell script.

### Changed — cyrb → cyrius rename
- **Build tool renamed**: `cyrb` → `cyrius`. The command is now `cyrius build`,
  `cyrius test`, `cyrius fuzz`, etc. Matches the language name.
- **Shell script**: `scripts/cyrb` → `scripts/cyrius`. All helper scripts renamed
  (`cyrius-init.sh`, `cyrius-coverage.sh`, etc.).
- **Binary source**: `programs/cyrb.cyr` → `programs/cyrius.cyr`. Builds to `build/cyrius`.
- **Manifest file**: `cyrb.toml` → `cyrius.toml` for project configuration.
- **All docs, CI, release workflows updated**. Historical CHANGELOG entries preserved.

## [2.3.1] — 2026-04-08

### Changed — Refactor & Cleanup
- **hashmap.cyr**: Fixed include placement (fnptr.cyr moved after header comment block),
  updated Requires comment, fixed map_print indentation.
- **hashmap_fast.cyr**: Extracted `_fhm_ctz()` helper — deduplicated 5 identical
  lowest-set-bit scan loops across fhm_get/fhm_set/fhm_has. Updated Requires comment.
- **sakshi_full.cyr**: Fixed usage comment (referenced sakshi.cyr instead of sakshi_full.cyr).
- **Module count corrected**: 28→31 across all docs (CLAUDE.md, README.md, roadmap.md,
  architecture/cyrius.md). Added sakshi + sakshi_full to stdlib table.
- **README.md**: Updated compiler architecture version (v1.11.1→v2.3.1), added toml/matrix/
  vidya/sakshi to stdlib table.
- **SECURITY.md**: Updated supported versions (0.9.x→2.x supported, 1.x best-effort).
- **Roadmap**: Added Platform Targets section (Linux x86_64/aarch64 done, macOS Mach-O +
  Windows PE planned for v3.0). Added Mach-O/PE emitters to v3.0 release checklist.
- **cyrius-doom release.yml**: Fixed `*.tar.gz` glob that included Cyrius toolchain tarball
  in release artifacts. Now uses `cyrius-doom-*.tar.gz` and cleans toolchain tarball before archive.

## [2.3.0] — Unreleased

### Added — Testing
- **7 new .tcyr test files**: sakshi, tagged, hashmap_ext, callback, json, float,
  stdlib tests expanded. Total: 13 test files, 139 assertions.
- **Coverage tool fixed**: `cyrb coverage` now accurately counts unique function
  coverage per module. Excludes private functions (_prefix). Uses test corpus
  (tcyr + bcyr + programs). Coverage: 20/31 modules, 29% functions.
- **Coverage gaps identified**: json, math, matrix, regex crash at runtime (FINDVAR
  interaction with internal buffers). async, thread, net need runtime testing.
  Filed for 3.0 audit.

## [2.2.2] — 2026-04-08

### Fixed
- **gvar_toks expanded 64→256**: Deferred global variable init table relocated from
  0x8FA98 to 0x98000 (2048 bytes). Unblocks cyrius-doom and other large programs with
  >64 initialized globals. Bounds check updated.
- **`cyrb audit` works in any project**: Generic audit runs compile check, .tcyr tests,
  lint, and format when no project-specific `scripts/check.sh` exists. Agents in
  agnosys, sakshi, doom can now use `cyrb audit`.
- **`cyrb fmt` available**: cyrfmt, cyrlint, cyrdoc, cyrc built and installed to
  `~/.cyrius/bin/`. All toolchain commands work from any directory.
- **`cyrb fuzz`**: Mutation-based compiler fuzzer. 5 strategies: random ASCII, seed
  mutation, deep nesting, long expressions, keyword spam. Catches SIGSEGV/SIGABRT.
  `cyrb fuzz 1000` — 500 iterations, 0 crashes on initial run.

## [2.2.1] — 2026-04-08

### Fixed — cyrius-x
- **Conditional jumps**: EJCC now emits comparison instruction (gt/lt/eq) before
  the conditional jump. x86 flag-based jumps mapped to explicit compare + jz/jnz.
- **EPATCH for jz/jnz**: Offset written to bytes 2-3 (not 1-3) to avoid clobbering
  the register field. jmp/call still use bytes 1-3.
- **Separate call/data stacks**: VM now uses `_cx_cstack` for call/ret and
  `_cx_dstack` for push/pop. Prevents return address corruption from expression temps.
- **Status**: Simple conditionals and non-recursive functions work correctly.
  Recursion broken — VM needs memory-backed stack frames (fp/sp point into _cx_mem).

### Cleanup
- Removed stale files: kernel/, -D, *.core, docs/vcnt-deferred.md, docs/cargo-codepaths.md
- Removed stale binaries: build/cc, build/cyrb (binary), rebuilt cc2-native-aarch64
- Pinned sakshi stdlib to v0.7.0
- **Bench files renamed to .bcyr**: `benches/*.cyr` → `benches/*.bcyr`. Matches .tcyr convention.
- **`cyrb bench` improved**: No args runs all 3 tiers with history tracking. `--tier1/2/3`
  runs specific tier. `REPO_ROOT` resolved properly from installed cyrb.

## [2.2.0] — 2026-04-08

### Fixed
- **cyrb version sync**: `cyrb version` now shows correct version when installed.
  VERSION file copied into version directory during install. cyrb checks
  `$SCRIPT_DIR/../../VERSION` as fallback. `version-bump.sh` updated.

- **assert.cyr auto-includes**: Now includes `string.cyr` and `fmt.cyr` directly.
  Programs no longer need explicit includes for assert.cyr deps. Fixes SIGSEGV
  when assert_eq was called without fmt.cyr (undefined fmt_int → call to -1).
- **Bug #26 resolved**: Not a compiler bug — missing include.

### Changed — cyrius-x
- **Function calls fixed**: ESUBRSP now emits `movi r15, size; sub sp, sp, r15`
  instead of broken single-instruction encoding. ESTOREPARM/EFLLOAD/EFLSTORE
  use r14/r15 as temps to avoid clobbering arg registers r3-r8.
  `add(20,22)` → 42, `fact(5)` → 120, `max(42,10)` → 42. Recursion (fib)
  still has conditional jump issues — work in progress.

- **Bug #24: `#ref` directive fixed**: `PP_REF_PASS` was never called from
  `PREPROCESS` — removed during a refactor and never caught. One-line fix:
  added `PP_REF_PASS(S);` before `PP_PASS(S);`. `#ref "file.toml"` now
  correctly emits `var key = value;` for each TOML entry. Unblocks defmt.

### Added — Tooling
- **`cyrb serve`**: Dev server with file watching. Watches .cyr files, recompiles
  and restarts on change. Uses `inotifywait` if available, falls back to polling.
  `cyrb serve src/main.cyr` — one command, full dev loop.
- **Inotify syscall wrappers** (`lib/syscalls.cyr`): `sys_inotify_init`,
  `sys_inotify_add_watch`, `sys_inotify_rm_watch`, `InotifyEvent` enum.

- **Bug #27: >6 function args fixed**: ECALLPOPS now correctly separates stack args
  from register args. Pops extras (7th+) into r11-r14, pops 6 register args, pushes
  extras back for callee. Supports up to 10 args (4 stack + 6 register). Unblocks
  sakshi_full span tracking (7-arg `_sk_fmt_span`).
- **`lib/sakshi.cyr`**: Tracing and error handling library incorporated into stdlib.
  Minimal profile (176 lines, zero heap, stderr output). Provides: sakshi_info/warn/error/debug,
  sakshi_err_new/err_with_ctx/err_code/err_category, `#if` log level gating. From sakshi v0.5.0.
- **`lib/sakshi_full.cyr`**: Full tracing library with spans, ring buffer, UDP output.
  28 tests pass. Includes: span enter/exit with timing, ring buffer events, structured
  error handling, per-level output routing. 31st stdlib module.
- **Bug #28: "undefined variable" error message**: Assignment to or use of an undefined
  variable now prints `error:N: undefined variable 'name'` instead of the cryptic
  `unexpected ';'`. Fixed in both PARSE_STMT (assignment) and PARSE_FACTOR (expression).

### Focus: defmt, cyrius-ts scaffold

## [2.1.3] — 2026-04-08

### Fixed
- **Heap map duplicate entries**: Removed stale scattered detail sections that caused
  heapmap.sh to report false overlaps (6 false positives on CI).

### Changed
- **Install symlinks**: `~/.cyrius/bin` and `~/.cyrius/lib` are now directory-level
  symlinks pointing to the active version, not per-file symlinks. `cyrius use <version>`
  swaps both atomically. Simpler, no file list maintenance.
- **Heap consolidation**: Compacted heap layout, 6.8MB → 4.7MB (2MB saved).
  132 offset references relocated. Clean heap map rewritten from scratch.

## [2.1.2] — 2026-04-08

### Fixed
- **Bug #25: Include path fallback**: `include "lib/..."` now falls back to
  `$HOME/.cyrius/lib/` when the local path fails. Reads HOME from
  `/proc/self/environ` at startup. Projects with their own `lib/` directory
  (sakshi, vidya) no longer shadow the Cyrius stdlib — local files take
  priority, stdlib fills gaps.
- **hashmap_fast.cyr**: Added doc comments to fhm_cap, fhm_count, fhm_has.
  Fixes CI doc coverage check (3 undocumented → 0).

### Changed — Compiler (Optimization)
- **Heap consolidation**: Relocated fixup table, fn tables, output buffer, var tables,
  token arrays, and preprocess buffer to compact layout starting at 0xA0000. Eliminated
  1.9MB of dead space from previous relocations. Heap reduced from 6.8MB to 4.7MB
  (2MB savings). 132 offset references updated across all source files.

## [2.1.1] — 2026-04-08

### Added — Standard Library
- **`lib/hashmap_fast.cyr`**: SIMD-accelerated hashmap (Swiss table inspired). Uses
  SSE2 `pcmpeqb` + `pmovmskb` to probe 16 metadata slots simultaneously. Separate
  metadata/key/value arrays. Currently slower than scalar for small maps (function call
  overhead), optimal for large tables with long probe chains.

### Known Issues
- **Bug #24: `#ref` directive broken** — emitted var declarations cause parse errors.
  Pre-existing (never tested in .tcyr suite). Blocks #ref_fn perfect hash feature.

### Added — cyrius-x
- **Bytecode emitter** (`src/backend/cx/emit.cyr`): Full implementation of the compiler
  backend interface (EMOVI, EVLOAD, EVSTORE, EFNPRO, EFNEPI, ECALLFIX, etc.) targeting
  cyrius-x bytecode instead of x86 machine code. Emits 4-byte fixed-width instructions.
- **CX compiler** (`src/main_cx.cyr`): Compiler entry point that includes cx backend
  instead of x86. Outputs .cyx files (CYX header + raw bytecode). 185KB binary.
- **Float/asm stubs**: All float and inline asm functions stubbed for bytecode target.
- **Status**: Compiles and runs `syscall(60, 42)` → exit 42 through full pipeline.
  Function calls need debugging (register spill/restore mismatch).
- **Token limit expanded 65536→131072**: Token arrays (tok_types, tok_values, tok_lines)
  relocated from 0xA2000 to 0x346000 (end of heap). Each array now 1MB (131072 entries
  × 8 bytes). Preprocess buffer relocated to 0x646000. brk extended to 0x6C6000 (6.8MB).
  Unblocks argonaut + system stdlib combined compilation.

## [2.1.0] — 2026-04-08

### Fixed
- **Bug #21: bitset/bitclr crash at top level**: Now emits clear error message
  ("must be called inside a function") instead of SIGSEGV. These builtins use
  local stack slots (EFLSTORE) which require a function frame.
- **Bug #18: bridge.cyr stale heap map**: Rewrote heap map comments to match
  actual code (tok_types at 0xA2000, tok_values at 0xE2000, brk at 0x122000).
- **Bug #20: bridge.cyr dead code**: Removed unused EMOVC function.
- **VCNT expanded 4096→8192**: Variable table (var_noffs, var_sizes, var_types)
  relocated to end of heap (0x316000/0x326000/0x336000). Each array now 65536 bytes
  (8192 entries × 8). brk extended to 0x346000. Unblocks vidya + sakshi combined
  compilation which exceeded the 4096 limit.

### Added — Language
- **`#if` value-comparison directive**: `#if NAME >= VALUE`, `#if NAME == VALUE`,
  etc. Supports ==, !=, <, >, <=, >=. Works with `#define NAME VALUE` (integer).
  `#endif` closes the block (shared with `#ifdef`). Enables compile-time dead code
  elimination based on config values. Unblocks sakshi log level gating:
  `#if sk_cfg_log_level >= 3` compiles out debug/trace calls entirely.
- **`#define NAME VALUE`**: Now stores integer values alongside presence flags.
- **Bug #16/#22: `var buf[N]` shared across functions**: Root cause found and fixed.
  `var buf[N]` inside functions registered as globals with the raw name — two functions
  with `var buf[N]` shared the same buffer, clobbering each other's data. This caused
  garbled output when `fmt_int` (which has `var buf[24]`) was called between other
  functions that also had `var buf[N]`. Fix: FINDVAR now returns the LAST match
  (reverse scan), so each function's array shadows previous ones. Three-step bootstrap
  required (semantic change to variable resolution).
- **Bug #19: aarch64 module/DCE gap**: main_aarch64.cyr pass 1 and pass 2 synced
  with main.cyr. Now supports mod/pub/use, impl blocks, unions, enum constructors,
  shared library mode. Module system init + reset added. aarch64 cross-compiler
  can now compile programs using the full v2.0 language.
- **cyrius-x VM interpreter** (`programs/cxvm.cyr`): Register-based bytecode VM.
  32-bit fixed-width instructions, 32 registers, 4KB memory, 512-byte call stack.
  Supports: arithmetic (add/sub/mul/div/mod), bitwise (and/or/xor/shl/shr),
  comparison (eq/ne/lt/gt), memory (load8/load64/store8/store64), control flow
  (jmp/jz/jnz/call/ret), syscall passthrough, push/pop, movhi/movhh for large
  constants. Reads .cyx files (CYX\0 header + bytecode). 109KB binary.
  `PP_GETVAL(S, pos)` looks up the stored value. Backward compatible — `#define NAME`
  without a value stores 0 (still works with `#ifdef`).

## [2.0.0] — 2026-04-08

### Added — Language
- **Multi-width types** (i8, i16, i32): Type annotations on variables now produce
  width-correct codegen. `var x: i8 = 42;` allocates 1 byte in data section and
  uses `movzx` for loads, `mov byte` for stores. Works for both globals and locals.
  - `i8`: 1 byte, movzx rax, byte [addr]
  - `i16`: 2 bytes, movzx eax, word [addr]
  - `i32`: 4 bytes, mov eax, [addr] (zero-extends)
  - `i64`: 8 bytes (default, same as untyped)
  - Backward compatible: untyped variables remain i64. Self-hosting unchanged.
  - New emit functions: EVLOAD_W, EVSTORE_W, EFLLOAD_W, EFLSTORE_W
  - Struct type IDs disambiguated from scalar types via var_sizes check
- **`sizeof(Type)` operator**: Compile-time constant returning byte size of any type.
  `sizeof(i8)`=1, `sizeof(i16)`=2, `sizeof(i32)`=4, `sizeof(i64)`=8,
  `sizeof(StructName)`=recursive field size. Token 100, handled in PARSE_FACTOR.
- **Struct field width**: Struct fields now support type annotations for width-correct
  layout. `struct Pkt { tag: i8; len: i16; data: i32; payload; }` — fields are packed
  at their declared width. FIELDOFF, STRUCTSZ, sizeof all respect actual widths.
  Field loads use movzx for i8/i16. Field stores use byte/word/dword instructions.
  Untyped fields remain 8 bytes (backward compatible).
- **`union` keyword**: `union Value { as_int; as_ptr; }` — all fields share offset 0,
  size = max field size. Token 101. Parsed like struct, uses high bit of field count
  as union flag. FIELDOFF returns 0 for all fields. STRUCTSZ returns max. Init
  requires all fields (same as struct init syntax). ISUNION(S, si) accessor added.
- **Bitfield builtins**: Three compile-time bitfield operations:
  - `bitget(val, offset, width)` — extract bits: `(val >> offset) & mask`
  - `bitset(val, offset, width, new)` — insert bits: clear + OR
  - `bitclr(val, offset, width)` — clear bits: AND with inverted mask
  Tokens 102-104. Inline shift/mask codegen, no function call overhead.
  Replaces manual `(pte >> 12) & 0xFFFFF` patterns in kernel code.
- **Expression type propagation**: PARSE_FACTOR sets expr_width when loading typed
  variables. Assignments warn on narrowing (e.g., i32 value → i8 variable):
  `warning:N: narrowing assignment (value may truncate)`. GEXW/SEXW at 0x903F0.

### Added — Tooling
- **`.tcyr`/`.bcyr` auto-discovery**: `cyrb test` with no args discovers and runs
  all `.tcyr` files in `tests/`, `src/`, and `.`. Reports pass/fail per file.
  `cyrb bench` with no args discovers `.bcyr` files in `benches/`, `tests/`, `.`.
- **Enhanced .tcyr test runner**: `cyrb test` now parses `assert_summary()` output
  from .tcyr files, reports per-file assertion counts. Supports metadata comments:
  `# expect: N` (expected exit code), `# skip: reason` (skip test). Shows individual
  FAIL lines on assertion failures.
- **New assert helpers** (`lib/assert.cyr`): `assert_lt`, `assert_gte`, `assert_lte`,
  `assert_nonnull`, `assert_streq`, `test_group(name)` for organized test output.
- **New .tcyr test suite** (7 files, 95 assertions): `core`, `types`, `structs`,
  `enums`, `bitfields`, `stdlib`, `advanced`. Replaces shell-based test scripts.
- **Removed legacy shell tests**: `compiler.sh`, `programs.sh`, `assembler.sh`,
  `aarch64-hardware.sh` removed. Clean break for v2.0. `heapmap.sh` retained.
- **`cyrb build` enhanced**: Shows binary size + compile time (ms). `-v`/`--verbose`
  flag shows warnings. Counts and reports warnings on stderr.
- **`cyrb test` enhanced**: `--verbose` shows full test output. `--filter NAME`
  runs only matching .tcyr files. Parses assertion summaries from test output.
- **`cyrb audit` rewritten**: Runs self-hosting (two-step), heap map audit,
  full .tcyr test suite, format check, lint check. 5 audit stages.

### Fixed — Code Audit
- **aarch64 heap map synced**: Complete rewrite of main_aarch64.cyr heap map to
  match main.cyr. Fixed stale output_buf offset (was 0x6A000, now 0x2D6000),
  fixup table size (was 4096, now 8192), added all missing regions.
- **callback.cyr**: Added missing `include "lib/syscalls.cyr"` dependency.
- **tagged.cyr**: Added fmt.cyr to Requires documentation.
- **syscalls.cyr**: Fixed stale path in header (was agnosys/syscalls.cyr).
- **main.cyr heap map**: Added 5 undocumented regions (fn_local_names, local_depths,
  local_types, inline_depth, expr_width).
- **CLAUDE.md**: Updated compiler size, test counts, feature list for v2.0.
- **Test coverage expanded**: Added float.tcyr (7 assertions) and json.tcyr
  (5 assertions) — f64 arithmetic and string builder operations now tested.
  Total: 9 files, 107 assertions.

### Added — Research & Scaffolding
- **cyrius-x bytecode design**: vidya entry with register VM design, 32-bit fixed-width
  instruction encoding, ~30 opcodes, .cyx file format. Backend stub at `src/backend/cx/emit.cyr`.
  Full implementation target: v2.1.
- **Multi-file compilation design**: vidya entry with ELF .o emission plan, fixup→relocation
  mapping, symbol table design, minimal linker architecture. Implementation target: v2.0.
- **u128 type annotation**: `var x: u128 = 0;` parsed with type_id 16, var_sizes 16.
  `sizeof(u128)` returns 16. Token 105. Arithmetic TBD.
- **sizeof lexer fix**: Moved sizeof from keyword (token 100) to identifier-based detection
  in PARSE_FACTOR. The klen=6 lexer keyword block had a code size issue that silently
  dropped sizeof recognition. Identifier approach is more robust.

## [1.12.1] — 2026-04-07

### Fixed — Standard Library
- **Bug #17: `fncall2` undefined warning**: `hashmap.cyr` now includes `fnptr.cyr`
  directly. Programs that include `hashmap.cyr` without `fnptr.cyr` no longer get
  the "undefined function 'fncall2'" warning. Include-once dedup prevents double
  inclusion for programs that include both.

## [1.12.0] — 2026-04-07

### Added — Compiler Hardening
- **Heap map audit tool** (`tests/heapmap.sh`): Parses heap map comments from
  `src/main.cyr`, builds interval map, flags overlaps and tight gaps (<16 bytes).
  Entries marked `(nested` are intentionally inside larger regions and skipped.
  Found and fixed: `use_from` overlapped `include_fname` by 464 bytes.
- **Fixed overlap**: `include_fname` relocated from 0x90000 to 0x90400 to eliminate
  collision with `use_from[64]` (0x8FFD0-0x901D0). Previously, >6 `use` aliases
  would silently overwrite the preprocessor filename scratch buffer.
- **Heap map accuracy**: Corrected `tok_names` declared size from 64KB to 32KB
  (upper half is used by str_data/str_pos/data_size). Marked 4 intentionally
  nested regions (elf_out_len, str_data, str_pos, data_size) in heap map comments.
- **Port dependency chain**: Documented majra → libro → ai-hwaccel blocking path.
- **Struct field limit expanded 16→32**: Relocated `struct_fnames` from 0x8E830
  (4096 bytes, stride 128) to 0x2CE000 (8192 bytes, stride 256). `struct_ftypes`
  stride also expanded to 256. brk extended from 0x2CE000 to 0x2D6000.
  Bounds check now errors at 32 fields. argonaut's ServiceDefinition (21 fields)
  no longer silently overflows into loop state.
- **Output buffer relocated**: Moved `output_buf` from 0x6A000 (128KB, inside tok_names
  region, overflowed into struct_ftypes) to 0x2D6000 (256KB, end of heap). brk extended
  to 0x316000. Overflow check in EMITELF_USER errors if output exceeds 256KB. Old
  0x6A000 region freed. DCE bitmap scratch also moved to new location.

## [1.11.5] — 2026-04-07

### Changed — Compiler (Hardening)
- **Overflow guards**: Added bounds checks to 4 previously unenforced arrays:
  - `ADDXP`: extra_patches for `&&` chaining (max 8) — error instead of silent overflow
  - `continue` patches in for-loops (max 8) — error instead of silent drop
  - `ret_patches`: return statements per function (max 64) — error instead of overflow
  - `REGSTRUCT`: struct definitions (max 32) — error instead of overflow
- **DCE optimization**: Dead code elimination reduced from O(N×T) to O(T+N) using a
  referenced-name bitmap (8KB in output_buf scratch). For argonaut (358 functions,
  36K tokens), this eliminates ~13M iterations per compilation.
- **Stale comments cleaned**: Fixed outdated heap map comments in main.cyr (fn_local_names)
  and main_aarch64.cyr (local_types). Documented DCE bitmap scratch in output_buf.
- **Roadmap reorganized**: Added v1.12 compiler hardening plan (heap audit, region
  consolidation, output buffer, DCE) as pre-2.0 foundation. v2.0 features (multi-width
  types, unions, multi-file compilation) depend on v1.12 cleanup.

## [1.11.4] — 2026-04-07

### Fixed — Compiler
- **Bug #14: Compiler segfault on ~6000+ line programs** (P1): The `&&` chaining
  extra_patches array (0x8F848) overlapped with the `continue` forward-patch counter
  (0x8F850) and patches (0x8F858). When `a && b && c` chained 2+ conditions inside a
  for-loop, ADDXP wrote the second patch to 0x8F850, overwriting the continue counter
  with a code buffer offset. At loop close, the corrupted counter caused iteration through
  unmapped memory → SIGSEGV. Fixed: relocated continue data from 0x8F850/0x8F858 to
  0x8F8A0/0x8F8A8, eliminating the overlap. Argonaut (6257 lines, 204KB) now compiles.

## [1.11.3] — 2026-04-07

### Changed — Codegen (Performance)
- **Inline disabled** (`_INLINE_OK = 0`): Token replay inlining generated larger code per
  call site than the 5-byte `call` it replaced, hurting I-cache. Binary: 194KB → 193KB.
- **Removed `_rsl` variable**: Dead code from reverted R12 spill. Cleaned ESPILL/EUNSPILL.

## [1.11.2] — 2026-04-07

### Changed — Codegen (Performance)
- **Reverted R12 register spill**: The push rbx + push r12 in every function prologue
  added 7 bytes and 4 stack ops per function call. Benchmarks showed 19-125% regressions
  vs 1.9.0 on heap allocations, syscalls, and I/O. Reverted to push/pop for all expression
  temps. ESPILL/EUNSPILL are now aliases for push rax / pop rax.
  - Prologue: `push rbp; mov rbp, rsp` (original, 4 bytes)
  - Epilogue: `leave; ret` (original, 2 bytes)
  - ETAILJMP: `mov rsp, rbp; pop rbp; jmp` (original)
  - Stack param offset: +16 (original)
  - Binary size: 205KB → 194KB (-11KB, -5.4%)

## [1.11.1] — 2026-04-07

### Fixed — Compiler
- **Bug #14: Silent compilation failure with thread.cyr**: `MAP_FAILED` constant was
  removed from enum but still referenced. Fixed: use `< 0` check instead.
- **Bug #15: Dual `#derive(Serialize)` + `#derive(Deserialize)`**: Two fixes —
  (a) PP_DERIVE_SERIALIZE now skips intervening `#derive(...)` lines before the struct.
  (b) PP_DERIVE_DESER is now a no-op (Serialize already emits `_from_json`).
  Both derives on same struct now compiles and runs correctly.

### Added — Language
- **Enum namespacing in expressions**: `Foo.BAR` now works in function call args,
  assignments, return values, and all expression contexts. The parser resolves the
  second identifier as a global variable (enum variant). Falls back to struct field
  access if not found as a global.
- **Relaxed fn ordering**: `fn` definitions may now appear after top-level statements.
  PARSE_PROG emits a `jmp` over the fn body, compiles it, then patches the jump.
  Enables patterns like `alloc_init(); fn helper() { ... } var x = helper();`.

## [1.11.0] — 2026-04-07

### Added — Standard Library
- **`lib/freelist.cyr`**: Segregated free-list allocator with `fl_free()`.
  9 size classes (16-4096), large allocs via mmap. `fl_alloc`/`fl_free`/`fl_calloc`.

### Fixed — Compiler
- **Bug #12: `#derive(Serialize)` empty output**: Was already fixed in 1.10.3.
- **Bug #13: Multiple `continue` in one loop**: Forward-patch array (up to 8) at
  S+0x8F858. Fixed in all three loop types (C-style, for-in range, for-in collection).

## [1.10.3] — 2026-04-07

### Fixed — Compiler
- **Bug #12: `#derive(Serialize)` runtime segfault**: Generated `_to_json` function took
  two args `(ptr, sb)` but callers passed one. Uninitialized `sb` → segfault. Fixed: function
  now takes `(ptr)`, creates its own `str_builder_new()`, returns `str_builder_build(sb)`.
  Nested struct fields use `str_builder_add(sb, Nested_to_json(ptr + offset))`.
  Derive now fully functional: `var j = Pt_to_json(&p);` returns valid JSON string.

## [1.10.2] — 2026-04-07

### Added — Compiler
- **Fixup table expanded**: 4096 → 8192 entries. Fn tables relocated from 0x2B2000 to
  0x2C2000. Unblocks ai-hwaccel and argonaut full test coverage without binary splitting.
- **`f64_atan(x)` builtin** (token 99): Arc tangent via x87 `fld1; fpatan`. Handled in
  PARSE_SIMD_EXT. PARSE_STMT range extended to 99.

### Added — Standard Library
- **`lib/math.cyr`**: Extended f64 math — `f64_sinh`, `f64_cosh`, `f64_tanh`, `f64_pow`,
  `f64_clamp`, `f64_min`, `f64_max`. Composed from existing f64 builtins (exp, ln, neg).

### Fixed — Compiler
- **Bug #11: `continue` in for-loops** (P1): `continue` inside C-style `for`, `for-in`
  range, and `for-in` collection loops now correctly jumps to the step/increment expression
  instead of the condition check. Uses forward-patch mechanism at S+0x8F850 — `continue`
  emits a placeholder jump, patched to the step code after the body is compiled.
- **Bug #8: `#derive(Serialize)` field name truncation** (P2): Field name buffer expanded
  from 16 to 32 bytes per field. Fields up to 31 characters now work correctly.

## [1.10.1] — 2026-04-07

### Added — Standard Library
- **`lib/thread.cyr`**: Thread creation, joining, mutex, and channels.
  - `thread_create(fp, arg)` — spawn thread via clone+mmap stack
  - `thread_join(t)` — futex-based wait for thread completion
  - `mutex_new/lock/unlock` — futex-based mutual exclusion
  - `chan_new/send/recv/close` — bounded MPSC channel with futex wait/wake
  - `mmap_stack/munmap_stack` — mmap-based thread stack allocation

### Added — Syscalls
- `SYS_CLONE`, `SYS_FUTEX`, `SYS_MUNMAP`, `SYS_GETTID`, `SYS_SET_TID_ADDRESS`, `SYS_EXIT_GROUP`
- `CloneFlag` enum: CLONE_VM, CLONE_FS, CLONE_FILES, CLONE_SIGHAND, CLONE_THREAD, etc.
- `MmapConst` enum: PROT_READ, PROT_WRITE, MAP_PRIVATE, MAP_ANONYMOUS
- `FutexOp` enum: FUTEX_WAIT, FUTEX_WAKE, FUTEX_PRIVATE_FLAG

### Added — Standard Library (continued)
- **`lib/async.cyr`**: Cooperative async runtime with epoll event loop.
  - `async_new()` / `async_spawn(rt, fp, arg)` / `async_run(rt)` — task scheduler
  - `async_sleep_ms(ms)` — timerfd-based sleep
  - `async_read(fd, buf, len)` — non-blocking read via O_NONBLOCK
  - `async_await_readable(fd)` — epoll wait for fd readability
  - `async_timeout(fp, arg, ms)` — run function with timeout via fork+epoll

### Fixed — Standard Library
- **Bug #9: `getenv()` returns wrong values** (`lib/io.cyr`): Variables `eq` and `ci`
  declared inside while loop leaked scope across iterations, causing false matches.
  Moved declarations outside the loop. `getenv("HOME")` now returns `/home/macro`.
- **Bug #10: `exec_capture()` hangs/crashes** (`lib/process.cyr`): `var pipefd[2]` was
  only 2 bytes but `pipe()` writes two 32-bit ints (8 bytes). Buffer overflow corrupted
  stack. Fixed: `pipefd[16]` + `load32` for fd extraction. Also fixed in `run_capture()`.

## [1.10.0] — 2026-04-07

### Added — Compiler
- **Inline small functions**: Token replay inlining for 1-param functions with ≤6 body
  tokens. State accessors like `GCP(S)`, `GFLC(S)` are inlined at call sites, eliminating
  call/ret overhead (~20 bytes saved per call). New metadata tables at 0x2C8000-0x2D2000
  track body token ranges and inline eligibility. Tail call optimization disabled inside
  inline replay. Max inline depth 3.
- **`ret2(a, b)`**: Return two values in rax:rdx. Enables returning 2-field structs
  without heap allocation. Statement form — emits return jump after packing registers.
- **`rethi()`**: Read rdx from last function call. Expression form — `mov rax, rdx`.
  Must be called immediately after the function call before rdx is clobbered.
- **SIMD expand**: 4 new packed f64 operations:
  - `f64v_div(dst, a, b, n)` — SSE2 `divpd`, packed division
  - `f64v_sqrt(dst, src, n)` — SSE2 `sqrtpd`, packed square root
  - `f64v_abs(dst, src, n)` — SSE2 `andpd` with sign mask, packed absolute value
  - `f64v_fmadd(dst, a, b, c, n)` — `mulpd` + `addpd`, fused multiply-add (SSE2, no FMA3)
- **`LEXKW_EXT` helper**: Extended keyword checks (tokens 93-98) in separate function
  to avoid LEXID code size overflow.
- **`PARSE_SIMD_EXT` handler**: Dispatch for tokens 93-98 in separate function to keep
  PARSE_TERM within code generation limits.

### Added — Language
- **`#ref` directive (Phase 1)**: `#ref "file.toml"` loads TOML at compile time, emitting
  `var key = value;` for each key-value pair. Skips comments (#), sections ([]), blank lines.
  Runs as PP_REF_PASS before include/ifdef processing. Supports integer and string values.

### Added — Codegen
- **Register allocation (R12 spill)**: Expression temporaries use callee-saved R12
  instead of stack push/pop for the first nesting level. Counter-based ESPILL/EUNSPILL
  correctly handles nested expressions. Deeper levels fall back to push/pop.
  Prologue saves rbx+r12, epilogue restores. ETAILJMP updated to match.
  Stack parameter offset adjusted (+16) for the extra pushes.
  aarch64 has ESPILL/EUNSPILL stubs (stack-only, no register optimization).

### Fixed — Compiler
- **PARSE_STMT expression range**: Extended f64/SIMD builtin statement range from
  `typ <= 92` to `typ <= 98`, fixing "unexpected unknown" errors for new builtins
  used as statements.

### Fixed — aarch64
- **Missing `EMIT_F64V_LOOP` stub**: aarch64 cross-compiler failed with "undefined function"
  warning and segfaulted under qemu. Added stub alongside existing UNARY/FMADD stubs.
- **Native aarch64 segfault from inline metadata**: Writes to fn_body_start/fn_body_end/fn_inline
  tables (0x2C8000+) caused memory corruption on ARM. Fixed with `_INLINE_OK` flag — set to 1
  in x86 emit, 0 in aarch64 emit. Inline metadata only written on x86.

### Removed — Dead Code
- `src/cc/` (5 files) — superseded by modular `src/frontend/` + `src/backend/x86/` + `src/common/`.
- `src/cc_bridge.cyr` — identical copy of `src/bridge.cyr`.
- `src/compiler.cyr` — superseded by `src/main.cyr`.
- `src/compiler_aarch64.cyr` — superseded by `src/main_aarch64.cyr`.
- `src/arch/aarch64/` (3 files) — superseded by `src/backend/aarch64/`.

### Changed — Compiler
- Binary size: 194KB x86_64 (up from 189KB due to inline metadata + new builtins).
- Heap brk extended from 0x2C8000 to 0x2D2000 (inline metadata tables).
- 267 tests passing, self-hosting byte-identical.

### Changed — Standard Library
- **Hashmap simplified** (`lib/hashmap.cyr`): Removed enum indirection, extracted
  `_map_lookup()` helper, used `elif` in probe loop, inlined accessor calls in internals.
- Fixed `arena_free` documentation in `lib/alloc.cyr` (function doesn't exist).

## [1.9.5] — 2026-04-07

## [1.9.4] — 2026-04-07

### Added — Compiler
- **`f64_round(x)`**: SSE4.1 `roundsd` mode 0 (round to nearest, banker's rounding).
  Token 92. Completes the set: floor/ceil/round.

### Fixed — Compiler
- **`#derive(Serialize)` works inside included files**: Added derive handling to PP_IFDEF_PASS
  (the second preprocessor pass that processes included content). Previously only worked in
  the main source file, not in `include`d modules.

### Added — Standard Library
- **`fmt_float(val, decimals)` + `fmt_float_buf`** (`lib/fmt.cyr`): Format f64 as
  "integer.fraction" with configurable decimal places. Zero-padded fractional part.
  Handles negative values. `fmt_float(pi, 6)` → `3.141593`.
- **`getenv(name)`** (`lib/io.cyr`): Read environment variable by name. Parses
  `/proc/self/environ`. Returns heap-allocated C string or 0 if not found.
  Required for PATH lookup in ai-hwaccel hardware detection.

### Fixed — Documentation
- **json.cyr requires io.cyr**: Added to Requires comment (was undocumented dependency
  for `json_parse_file` → `file_read_all`).

## [1.9.3] — 2026-04-07

### Fixed — Compiler
- **SIMD frame slot collision**: `f64v_add/sub/mul` stored args at hardcoded frame slots 0,1,2
  which overwrote caller's local variables. Heap-allocated buffers produced zeros, chained
  operations produced wrong results. Fixed by using `GFLC()` for fresh slots and passing
  `vbase` to `EMIT_F64V_LOOP` for correct `[rbp-N]` offsets.

### Fixed — Release
- **Release tarball ships shell cyrb**: Workflow was compiling `programs/cyrb.cyr` (old binary
  without -D/deps/pulsar). Now copies `scripts/cyrb` (shell dispatcher with full feature set).

### Changed — Roadmap
- Marked Bug #5 (release cyrb -D) and #6 (naming ambiguity) as fixed.
- New perf item #7 from abaco: SIMD expand (f64v_div, f64v_sqrt, f64v_abs, fmadd for MAC).

## [1.9.2] — 2026-04-07

### Improved — Tooling
- **Dependency `modules` filter**: Path and git deps now support `modules = ["lib/syscalls.cyr"]`
  to include only specific files instead of the entire project. Without `modules`, all lib/ + src/
  are included (existing behavior). Prevents pulling in 20+ unused modules from large dependencies.
- **`cyrb pulsar` installs shell cyrb**: Was installing stale compiled binary (0.6.0). Now installs
  the shell script with deps/pulsar support. Nuking `~/.cyrius` and running `cyrb pulsar`
  reconstitutes a clean install.

## [1.9.1] — 2026-04-07

### Added — Tooling
- **Dependency management in `cyrb.toml`**: New `[deps]` section declares project dependencies.
  Three dependency types supported:
  - **stdlib**: `stdlib = ["string", "fmt", "alloc", "vec"]` — resolved from installed Cyrius
  - **path**: `[deps.agnosys] path = "../agnosys"` — local project dependencies
  - **git**: `[deps.kybernet] git = "https://github.com/MacCracken/kybernet" tag = "0.3.0"` —
    remote dependencies cloned to `~/.cyrius/deps/<name>/<tag>/`, supports GitHub/GitLab/any git
  `cyrb build` auto-resolves all deps and prepends includes before compilation.
  Include-once prevents duplicate processing when deps share stdlib modules.
- **`cyrb deps`**: Shows resolved dependency tree from cyrb.toml — stdlib modules, path deps,
  git deps with cache status, and the full resolved include list.

### Fixed — Tooling
- **`cyrb pulsar` now writes `~/.cyrius/current`**: Version manager and dep resolution
  use this file to find the active stdlib. Was stale after pulsar runs.

## [1.9.0] — 2026-04-07

### Added — Compiler
- **SIMD batch operations: `f64v_add`, `f64v_sub`, `f64v_mul`**: SSE2 packed f64 builtins
  that process 2 elements per iteration. `f64v_add(dst, a, b, n)` adds n f64 elements from
  arrays a+b into dst. 2x throughput for array operations vs scalar loop.

### Improved — Standard Library
- **Stack-allocated str_builder**: Replaced vec-of-Str design with direct buffer approach.
  64-byte inline buffer, single final `alloc` on build. Eliminates N heap allocations per
  string construction (one per `add_cstr`/`add_int` call).

### Added — Tooling
- **`cyrb pulsar`**: One command to rebuild cc2 + cc2_aarch64 + cc2-native-aarch64 + tools
  from source, install to ~/.cyrius, purge old versions, verify. Auto two-step bootstrap.
  Full toolchain rebuild in ~410ms.
- **`cyrb --aarch64 --native`**: Uses the native aarch64 compiler (runs under qemu on x86)
  instead of the cross-compiler. Three clear binaries: `cc2` (x86→x86), `cc2_aarch64`
  (x86→aarch64 cross), `cc2-native-aarch64` (aarch64→aarch64 native).

### Fixed — Tooling
- **install.sh stale fallback version**: 0.9.1 → 1.8.5. Added cc2-native-aarch64 to bin lists.
  Source bootstrap now copies all cyrb-*.sh scripts.
- **Scripts cleanup**: All scripts verified using correct paths (src/main.cyr, src/bridge.cyr).
  check.sh passes all 10 checks.

## [1.8.5] — 2026-04-07

### Verified — Tooling
- **cyrb `-D` flag confirmed working for aarch64**: Bug #4 reported `-D` not reaching
  cc2_aarch64, but this was from pre-v1.8.4 cyrb. Verified: `cyrb build --aarch64 -D X`
  produces correct ifdef-gated output. Size differs with/without flag (328 vs 0 bytes).

## [1.8.4] — 2026-04-07

### Fixed — Compiler
- **Codebuf expanded 192KB→256KB**: Moved tok_names from 0x50000 to 0x60000, codebuf now
  extends to 0x60000. Fixes aarch64 cross-compiler codebuf overflow that blocked native
  aarch64 binary generation. aarch64 tarball now ships native ARM ELF via two-step self-host.
- **aarch64 backend: ESETCC + float stubs**: Added comparison expression codegen (cmp + cset)
  and float function stubs to aarch64 emit.cyr. Required for PCMPE and f64 builtin references
  in shared parse.cyr.

### Fixed — Tooling
- **`cyrb build/run/test -D NAME` flag support**: `-D NAME` prepends `#define NAME` to source
  before compilation. Works with `--aarch64`. Supports multiple flags (`-D A -D B`).
  Both `-D NAME` (space) and `-DNAME` (attached) forms supported. Fixes AGNOS aarch64 kernel
  build (`cyrb build --aarch64 -D ARCH_AARCH64 agnos.cyr`).

### Changed — Release
- **aarch64 tarball ships native ARM binary**: Release workflow now self-hosts — x86 cc2 builds
  cross-compiler, cross-compiler builds native aarch64 ELF. Architecture verified via `file`.

## [1.8.3] — 2026-04-07

### Added — Standard Library
- **`lib/matrix.cyr` — dense matrix library**: `mat_new`, `mat_get`, `mat_set`, `mat_identity`,
  `mat_add`, `mat_sub`, `mat_scale`, `mat_mul`, `mat_transpose`, `mat_dot`, `mat_print`.
  Row-major f64 storage. Unblocks hisab DenseMatrix port. Const generics not needed —
  Cyrius runtime-sized alloc covers all bhava/hisab Matrix patterns.

- **Arena allocator** (`lib/alloc.cyr`): `arena_new(capacity)`, `arena_alloc(a, size)`,
  `arena_reset(a)`, `arena_used(a)`, `arena_remaining(a)`. Independent memory pools — resetting
  one arena doesn't invalidate pointers from others or the global allocator. Closes Bug #2.
- **`#derive(Serialize)` now generates both `_to_json` AND `_from_json`**: Single directive
  produces serialization and deserialization. `Name_from_json(pairs)` takes a vec of JSON
  key-value pairs (from `json_parse`) and populates a struct. Scalar values emitted as quoted
  strings for json roundtrip compatibility. DCE stubs whichever function isn't used.

### Fixed — Standard Library
- **`#derive(Serialize)` outputs quoted numeric values**: `{"x":"42"}` instead of `{"x":42}`.
  Ensures `json_parse` roundtrip works correctly (json_parse numeric value parsing has a
  known issue with unquoted numbers in some contexts).

### Added — Standard Library
- **Vidya content loader + search** (`lib/vidya.cyr`): Loads TOML content from vidya corpus
  directory. Supports both `[[entries]]` format (cyrius) and `concept.toml` format (topics).
  Registry with hashmap index by name. Full-text search across name, description, and content.
  Tested against full vidya corpus: 209 entries loaded, search working.

### Fixed — Standard Library
- **`str_ends_with` was comparing against Str fat pointer**: Used `strlen(suffix)` and raw
  `suffix` pointer instead of `str_len(suffix)` and `str_data(suffix)`. Caused `path_has_ext`
  and `find_files` to always return no matches.
- **`str_contains` used C string needle**: Changed to accept Str needle via `str_len`/`str_data`.

### Changed — Documentation
- **Roadmap cleaned up**: Collapsed 9 resolved bugs, updated header to v1.8.3/168KB,
  marked derive macros done, added vidya port progress, new perf items from abaco benchmarks.

## [1.8.2] — 2026-04-07

### Added — Standard Library
- **`lib/toml.cyr` — TOML parser**: Parses TOML files with string values (`key = "value"`),
  triple-quoted multi-line strings (`key = '''...'''`), arrays of tables (`[[section]]`),
  and comments. Returns vec of sections, each with name + pairs vec. Includes `toml_parse`,
  `toml_parse_file`, `toml_get`, `toml_get_sections`. Tested against vidya corpus: 108 entries
  across implementation.toml (59), ecosystem.toml (35), strings/concept.toml (14).
  Unblocks vidya port to Cyrius (TOML content loader + search + registry).

### Fixed — Compiler
- **VCNT expanded 2048→4096**: Relocated var_noffs/var_sizes from 0x60000/0x64000 to
  0x2B8000/0x2C0000 (after fn tables). Brk extended to 0x2C8000. agnosys 20 modules
  have ~3400 enum variants — now fits comfortably.
- **Parenthesized comparisons in conditions**: `while (x && (load8(p) == 32 || load8(p) == 9))`
  now works. PARSE_FACTOR's paren handler calls PCMPE (not PEXPR), allowing comparisons
  and `&&`/`||` inside parenthesized subexpressions. ECONDCMP handles boolean values
  without a comparison operator (treats non-zero as true via `cmp rax, 0; jne`).
- **agnosys `else if` → `elif`**: Fixed 1 instance in src/ima.cyr.

## [1.8.1] — 2026-04-07

### Fixed — Compiler
- **Preprocessor output buffer expanded 256KB→512KB**: agnosys 20 modules (262KB expanded)
  exceeded the 256KB limit. Buffer at 0x222000 now uses the full gap to 0x2A2000 (fixup table).
  Unblocks full-project compilation for large codebases.

### Changed — Documentation
- **README.md rewritten**: Updated to 164KB/267 tests, v1.8.0 architecture diagram, features
  list (20 f64 builtins, #derive, include-once, jump tables), new bootstrap chain.
- **Internal docs updated**: CLAUDE.md, cyrius-guide.md, benchmarks.md, roadmap — all stale
  references to 136KB/263 tests/src/cc/ paths corrected.
- **Vidya updated**: language.toml and implementation.toml synced to v1.8.0 with heap map,
  include-once, restructure, and transcendental entries.
- **Roadmap**: Added agnosys blocker items (#8 VCNT overflow, #9 256KB limit now fixed).
  New performance items from abaco benchmarks (u128, SIMD, compile-time perfect hash).

### Changed — Installation
- **~/.cyrius updated to 1.8.0**: cc2 (168KB) + 21 stdlib modules installed.

## [1.8.0] — 2026-04-07

### Changed — Compiler Structure
- **Directory restructure**: `src/cc/` → `src/frontend/` + `src/backend/x86/` + `src/common/`.
  `src/arch/aarch64/` → `src/backend/aarch64/`. Clear frontend/backend/common separation.
- **Entry point renames**: `compiler.cyr` → `main.cyr`, `compiler_aarch64.cyr` → `main_aarch64.cyr`,
  `cc_bridge.cyr` → `bridge.cyr`.
- **Float extraction**: SSE2/SSE4.1/x87 float ops extracted from `emit.cyr` into `float.cyr`.
  emit.cyr drops from 576 to 509 lines.
- **Include order**: `common/util → backend/emit → backend/float → backend/jump → frontend/lex → frontend/parse → backend/fixup`.
- Updated all references in: tests/compiler.sh, scripts/*, .github/workflows/*, docs/, CLAUDE.md.

### Added — Compiler
- **Include-once semantics**: Preprocessor tracks included filenames (up to 64). Duplicate
  `include "file.cyr"` directives are silently skipped. Prevents duplicate enum errors,
  wasted tokens/identifiers, and simplifies downstream project include management.
  Works in both PP_PASS and PP_IFDEF_PASS.

## [1.7.9] — 2026-04-07

### Improved — Standard Library
- **hashmap.cyr: enum constants for state values**: Replaced magic numbers 0/1/2 with
  `HASH_EMPTY`, `HASH_OCCUPIED`, `HASH_TOMBSTONE` enum. Clearer intent, grep-friendly.
- **hashmap.cyr: `map_iter(m, fp)`**: Zero-alloc iteration via function pointer callback.
  Calls `fncall2(fp, key, value)` for each occupied entry. No vec allocation needed.
- **hashmap.cyr: formatting cleanup**: Fixed `map_print` indentation, updated header docs.

### Changed — Compiler
- **PARSE_CMP_EXPR renamed to PCMPE**: Internal rename to reduce tok_names pressure.
  Freed ~90 bytes of identifier buffer for the dedup bootstrap chain.

## [1.7.8] — 2026-04-07

### Added — Compiler
- **f64 transcendentals: `f64_sin`, `f64_cos`, `f64_exp`, `f64_ln`, `f64_log2`, `f64_exp2`**:
  x87 FPU instructions via rax↔stack↔x87 bridge. sin/cos via `fsin`/`fcos`, ln via
  `fldln2; fyl2x`, log2 via `fld1; fyl2x`, exp via `fldl2e; fmulp; frndint; f2xm1; fscale`,
  exp2 via `frndint; f2xm1; fscale`. Unblocks abaco DSP (amplitude_to_db, midi_to_freq,
  constant_power_pan, filter coefficients).
- **Identifier deduplication in LEXID**: Before storing a new identifier in tok_names,
  scans for an existing identical string and reuses its offset. Reduces tok_names usage
  ~50% for the compiler source (65500→~30000 bytes). Required two-step bootstrap
  (rename PARSE_CMP_EXPR→PCMPE to fit within old limit, compile, then add dedup).

## [1.7.7] — 2026-04-07

### Added — Compiler
- **Constant folding for `+`, `-`, `&`, `|`, `^`**: Same proven SCP-rewind pattern as `*`/`/`/`<<`/`>>`.
  Folds at compile time when both operands and result are small positive (0 < v < 0x10000).
  Precedence-safe: checks right operand isn't followed by higher-precedence operator.
- **f64 builtins: `f64_sqrt`, `f64_abs`, `f64_floor`, `f64_ceil`**: Single-instruction
  transcendentals. sqrt via SSE2 `sqrtsd`, floor/ceil via SSE4.1 `roundsd`, abs via integer
  AND (clear sign bit). Unblocks abaco DSP functions (amplitude_to_db, midi_to_freq, filters).
- **Jump tables for dense switches**: When a switch has ≥4 cases with dense values
  (range ≤ 2×count), emits O(1) indirect jump via `lea rcx,[rip+table]; movsxd rax,[rcx+rax*4]; jmp rax`.
  Sparse switches still use compare-and-branch chain. Pre-scans case values in a separate pass.
- **`#derive(Serialize)`**: Preprocessor-level code generation. `#derive(Serialize)` before a
  struct auto-generates `Name_to_json(ptr, sb)` that serializes to JSON via str_builder.
  Supports nested structs (requires inner `#derive` first). Unblocks bhava/hisab serde migration.
- **Batch benchmark harness**: `bench_run_batch(b, &fn, batch_size, rounds)` in lib/bench.cyr.
  Wraps one `clock_gettime` pair around N iterations for accurate sub-100ns measurement.
  Also `bench_run_batch1`, `bench_run_batch2`, and inline `bench_batch_start`/`bench_batch_stop`.

### Improved — Compiler
- **VCNT overflow check**: Errors at 2048 with clear message instead of silent corruption.
- **Undefined function warning**: `warning: undefined function 'foo'` at compile time instead
  of silent segfault at runtime.
- **Non-ASCII byte error**: `error:N: non-ASCII byte (0xc3)` instead of silently splitting
  identifiers. UTF-8 in strings and comments still works.
- **Identifier buffer limit raised**: 65000 → 65500 bytes (struct_ftypes no longer overlaps).

### Fixed — Compiler
- **`_cfo` leak from function call arguments**: `pow2(5) + 10` folded to `15` instead of `42`
  because `_cfo=1` leaked from parsing the argument `5`. Fixed by clearing `_cfo` after
  PARSE_FNCALL, PARSE_FIELD_LOAD, and syscall builtins in PARSE_FACTOR.
- **`_cfo` leak from non-folding PARSE_TERM operations**: After `var * 8`, the `8` literal
  set `_cfo=1` which leaked to PARSE_EXPR, causing `var * 8 + 16` to fold as `8 + 16 = 24`.
  Fixed by clearing `_cfo` after all non-folding paths in PARSE_TERM (`*`, `/`, `%`, `<<`, `>>`).
- **agnosys bench_compare.cyr missing `#define LINUX`**: Not a compiler bug — platform define
  was missing, causing empty syscall bindings.

## [1.7.6] — 2026-04-06

### Fixed — Compiler
- **tok_names/struct_ftypes memory overlap (Bug #1)**: `tok_names` at 0x50000 (65536 bytes)
  overlapped with `struct_ftypes` at 0x59000 (4096 bytes). When programs with >36864 bytes
  of identifier data were compiled, identifier strings were stored in `struct_ftypes` space.
  Struct operations zeroed out those identifiers, causing `FINDVAR` to silently fail and
  produce "unexpected token" errors at random locations. Manifested as: including
  `assert.cyr` + `bench.cyr` + all 12 agnostik modules produces `unexpected '+'` at ~line 2556.
  **Fix**: relocated `struct_ftypes` from 0x59000 to 0x8A000 (free space after output_buf).
- **Fixup table overflow checks**: `ESADDR`, `ECALLFIX`, `ETAILJMP`, and `&fn` handler all
  wrote fixup entries without checking the table limit. Only `RECFIX` had the check. Added
  overflow check (4096 limit) to all four functions.
- **aarch64 ETAILJMP missing**: Tail call optimization only had x86_64 implementation.
  Added `ETAILJMP` to aarch64/emit.cyr: `mov sp, x29; ldp x29, x30, [sp], #16; B rel26`
  with fixup type 4 (B not BL).
- **aarch64 fixup stale offsets**: Three references to 0x262000 in aarch64/emit.cyr not
  updated when fixup table was relocated to 0x2A2000. All 26 CI aarch64 tests were failing.

### Changed — Compiler
- **Fixup table expanded 2048→4096**: Relocated fn_names/fn_offsets/fn_params from
  0x2AA000/0x2AC000/0x2AE000 to 0x2B2000/0x2B4000/0x2B6000. Brk increased from
  0x2B0000 to 0x2B8000. Prevents fixup overflow for large programs.

### Metrics
- Compiler: 141KB x86_64
- 267 tests (216 compiler + 51 programs), 0 failures
- Self-hosting: byte-identical
- agnostik: 58 tests, 0 failures (assert+bench+all 22 modules now compiles)

## [1.7.5] — 2026-04-06

### Fixed — Compiler
- **aarch64 ETAILJMP missing**: Tail call optimization only had x86_64 implementation.
  Added `ETAILJMP` to aarch64/emit.cyr with fixup type 4 (B not BL).
- **aarch64 fixup stale offsets**: Three references to 0x262000 in aarch64/emit.cyr not
  updated when fixup table was relocated to 0x2A2000. All 26 CI aarch64 tests were failing.
- **Allocator codegen regression**: PMM back to 1,276 cycles (was 2,044 in v1.7.4).
  Heap 32B back to 1,241 (was 2,065).

## [1.7.4] — 2026-04-06

### Fixed — Compiler
- **256 locals per function**: `fn_local_names` relocated from 0x8DC30 to 0x91000 with
  256 entries (was 64). 65th local previously overflowed into `var_types`.
- **Constant folding paren leak**: `_cfo` flag persisted from inside parenthesized
  subexpressions. `(n-6)*8` would fold `6*8=48` instead of computing `(n-6)*8`. Fixed
  by clearing `_cfo` after evaluating parenthesized expressions in `PARSE_FACTOR`.
- **aarch64 constant folding EMOVI size mismatch**: Tightened fold range from 0x80000000
  to 0x10000 to ensure same EMOVI size on both architectures (aarch64 EMOVI is variable-size).
- **Identifier buffer overflow**: Added error with count at 65000/65536 bytes in LEXID.

## [1.7.3] — 2026-04-06

### Added — Compiler
- **Constant folding for `*`, `/`, `<<`, `>>`**: Compile-time evaluation of integer
  expressions with literal operands. PARSE_TERM checks `_cfo` flag set by PARSE_FACTOR
  for small positive literals. Folds by SCP rewind + EMOVI with computed value.

### Changed — Compiler
- **Heap map reorganized**: Address-order format in compiler.cyr header for clarity.

## [1.7.2] — 2026-04-06

### Changed — Compiler
- **Input buffer expanded to 512KB**: Preprocessor output buffer at 0x222000 (524288 bytes).
  LEX reads directly from preprocess buffer, eliminating copy-back. No more source size limit
  below 512KB.
- **Tail call optimization**: `return fn(args)` emits epilogue + `jmp` instead of
  `call` + epilogue. PARSE_RETURN detects IDENT+LPAREN pattern, scans to matching RPAREN,
  verifies SEMI. x86: `mov rsp,rbp; pop rbp; jmp rel32` with type-2 fixup.
- **Fixup/fn tables relocated**: fixup_tbl to 0x2A2000, fn_names/offsets/params to
  0x2AA000/0x2AC000/0x2AE000 to accommodate larger preprocessor buffer.

## [1.7.1] — 2026-04-06

### Fixed — Compiler
- **`&&`/`||` as expression operators**: `return a > 0 && b > 0;` and `var r = a == b;`
  now work. PARSE_CMP_EXPR handles `&&`/`||` as AND/OR on 0/1 values. PARSE_VAR and
  assignment handler changed from PARSE_EXPR to PARSE_CMP_EXPR.

## [1.7.0] — 2026-04-06

### Fixed — Compiler
- **`return expr == expr`**: PARSE_RETURN now calls PARSE_CMP_EXPR. Comparisons in return statements work.
- **Input buffer 256KB**: expanded source safely overflows into codebuf (consumed before codegen)
- **Codebuf overflow check**: EB() errors at 196608 bytes with clear message
- **VCNT expanded to 2048**: var_noffs/var_sizes relocated to non-overlapping regions
  (var_sizes 0x60800→0x64000, str_data 0x62000→0x68000). Fixed overlap bug from v1.5.2.
- **Two-pass ifdef**: PP_IFDEF_PASS evaluates #ifdef/#define in included content after expansion
- **Dead code elimination**: unreachable functions get 3-byte stub (xor eax,eax; ret).
  Token scan with STREQ, skips module/mangled names. ~1.5KB saved on hello+stdlib.

### Metrics
- Compiler: 134KB x86_64
- 267 tests (216 compiler + 51 programs), 0 failures
- Self-hosting: byte-identical

## [1.6.6] — 2026-04-06

### Improved — Compiler
- **Human-readable error messages**: `error:5: unexpected token (type=17)` →
  `error:5: expected ';', got identifier 'foo'`. Token types replaced with names
  (`;`, `)`, `{`, `identifier`, `number`, `fn`, `return`, etc). Identifier values
  and numeric values shown in context. 142 parse errors upgraded to `ERR_EXPECT`
  with expected/got format. Added `TOKNAME`, `PRSTR`, `ERR_EXPECT`, `ERR_MSG` to util.cyr.

### Fixed — Compiler
- **Multi-pass preprocessor**: `include` inside `#ifdef` in included files now works.
  Preprocessor runs up to 16 passes until no more includes found. Each pass expands
  includes and evaluates `#ifdef`/`#define`. Fixes library-level platform dispatchers.

### Fixed — Tooling
- **`cyrb update` actually works**: syncs `lib/` from installed Cyrius stdlib
  (`~/.cyrius/versions/<current>/lib/`), falls back to `../cyrius/lib/`
- **`cyrb init` generates `cyrb.toml`**: includes `[deps]` section, vendors ALL stdlib
  modules (was hardcoded list of 13)
- **`cyrc vet` false positive on cyrb**: `cmd_check` contained `"include "` string literal
  that triggered dependency detection. Fixed: build needle at runtime with `store8`.

### Changed — Documentation
- **Vidya reorganization**: Cyrius reference moved from `compiler_bootstrapping/` to own
  `cyrius/` topic directory: `language.toml`, `ecosystem.toml`, `implementation.toml`, `types.toml`

## [1.6.5] — 2026-04-06

### Fixed — Compiler (aarch64)
- **cc2_aarch64 segfault on `kernel;` mode**: `EMITELF_KERNEL` was a placeholder that called
  `EMITELF` → infinite recursion → stack overflow → segfault. Implemented proper aarch64
  kernel ELF64 emission: base `0x40000000`, entry `0x40000078`, no multiboot (ARM uses
  device tree). Fixup entry point also corrected (`0x100060` → `0x40000078`).
  Bootable via: `qemu-system-aarch64 -M virt -cpu cortex-a57 -kernel build/agnos_aarch64`

### Added — Tooling
- **`cyrb build -D NAME`**: preprocessor defines from the command line. Enables conditional
  compilation without modifying source files. Key use case: AGNOS multi-arch kernel builds
  (`cyrb build -D ARCH_X86_64 kernel/agnos.cyr build/agnos`). Multiple `-D` flags supported.

### Fixed — Tooling
- **cyrb aarch64 cross-compiler search**: `cyrb build --aarch64` now searches `./build/cc2_aarch64`
  as fallback when not found in `~/.cyrius/bin/`. Fixes CI and dev environments that build
  the cross-compiler locally.

### Updated — Roadmap
- Tooling issues #1 resolved (aarch64 search path)
- Tooling issue #4 clarified: >60KB source segfault was caused by function table overflow
  (>256 functions), now mitigated by 512-entry tables in v1.6.0. Programs with >512 functions
  still need splitting.

### Added — Tests
- **Nested for-loop regression tests**: 4 new tests (nested_for_var, nested_for_match,
  triple_for, for_in_for) confirming nested for-loops with var declarations work correctly.

### Metrics
- Compiler: 136KB x86_64, 127KB aarch64
- cyrb: 60KB
- 216 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.6.0] — 2026-04-06

### Fixed — Compiler
- **Function table overflow (segfault at >256 functions)**: `fn_names`, `fn_offsets`, `fn_params`
  had 256 entries each (2048 bytes at `0x8C200`/`0x8CA00`/`0x8D200`). The 257th function name
  overwrote `fn_offsets[0]`, corrupting jump targets and causing runtime segfaults.
  Relocated all three tables to `0x26A000`/`0x26B000`/`0x26C000` with 512 entries each.
  Confirmed: old compiler segfaults (exit 139) with 260 functions, new compiler runs clean.

### Added — Tooling
- **CI setup script**: `scripts/ci.sh` — pulls release tarball, extracts to `~/.cyrius`,
  symlinks binaries. For Ubuntu, AGNOS, Alpine, agnos-slim CI images.

### Metrics
- Compiler: 136KB (unchanged)
- 212 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.5.3] — 2026-04-06

### Added — Performance (agnosys)
- **Packed Result type**: Ok/Err encoded in a single i64 using bit 63 as discriminant.
  Zero heap allocations on success path (was 2 allocs per Result via tagged_new).
  Error path still allocates 24-byte syserr struct (cold path, acceptable).
- **Caller-provided buffers**: `query_sysinfo(out)`, `agnosys_hostname(out)`,
  `agnosys_kernel_release(out)`, `agnosys_machine(out)` now write into caller's
  stack buffer instead of heap-allocating + memcpy. Eliminates alloc+copy per call.
- **Packed errno errors**: `err_from_errno` encodes kind+errno in a single i64
  (`kind<<16|errno`) — zero heap allocation on error hot path.
  `syserr_kind`/`syserr_errno` auto-dispatch between packed integers and heap pointers.
- **Dropped unnecessary memset**: `query_sysinfo` and `agnosys_uname` no longer zero
  buffers before syscall — kernel overwrites the entire struct.
- **Single uname call**: `agnosys_uname(out)` replaces separate hostname/release/machine
  functions. One syscall, zero memcpy, callers read fields via offset accessors.

### Fixed — agnosys
- **Array size unit confusion**: `var buf[N]` allocates N bytes, not N i64 elements.
  `var buf[49]` (intended for 390-byte utsname struct) only allocated 56 bytes, causing
  runtime overflow into adjacent data (corrupted string literals).
  Fixed: `var buf[392]` for utsname, `var buf[120]` for sysinfo, `var allow[160]` for
  seccomp filter, `var beneath[16]` and `var prog[16]` for landlock/seccomp structs.

### Fixed — Roadmap
- **Nested for-loop P1 bug**: confirmed fixed (by block scoping in v0.9.5). Removed from P1.

### Metrics
- Compiler: 136KB (unchanged)
- 212 compiler tests + 51 program tests, 0 failures
- Self-hosting: byte-identical

## [1.5.2] — 2026-04-06

### Fixed — Tooling
- **cyrb clean deletes itself**: `cyrb` was not in the preserve list, so `cyrb clean` removed
  its own binary from `build/` — added `cyrb` to skip list alongside cc2, stage1f, asm
- **cyrb clean output truncated**: byte count for the status message was 55, should be 57
  (UTF-8 em dash is 3 bytes not 1) — output showed "remove8 files" instead of "removed 8 files"
- **cyrb envp fix not in source**: the `load_environ()` / `_envp` passthrough from 1.5.1 was
  lost from source after a git stash — reapplied to `programs/cyrb.cyr`

### Added — Documentation
- **Module & manifest design doc**: `docs/development/module-manifest-design.md` —
  explicit dependency manifests without a resolver, `pub` enforcement, `use` imports
  with qualified access, migration path from `include` to `use`

### Fixed — Compiler
- **Variable table overflow corrupting string data**: `var_noffs` and `var_sizes` had 256 entries
  (2048 bytes each at `0x60000`/`0x60800`), overflowing into `str_data` at `0x61000` when total
  variable count exceeded 256. Since VCNT never resets between functions (arrays are globals),
  large programs silently corrupted string literals — `println` wrote backspace (0x08) instead
  of newline (0x0A)
  - Expanded both arrays to 512 entries (4096 bytes each)
  - Relocated `str_data` from `0x61000` to `0x62000`
  - Updated x86_64 and aarch64 backends (lex.cyr, fixup.cyr, arch/aarch64/fixup.cyr)
  - Triggered by agnosys port (379 variables across 14 included modules)

### Verified
- All 25+ cyrb subcommands tested and passing
- 212 compiler tests, 0 failures
- 51 program tests, 0 failures
- Self-hosting: byte-identical
- agnosys 119KB binary: all println output correct

### Metrics
- Compiler: 136KB (unchanged)
- cyrb: 59KB (was 58KB)

## [1.5.1] — 2026-04-06

### Fixed — Tooling
- **cyrb empty environment**: all `execve` calls passed empty `envp`, breaking shell script
  subcommands (`cyrb port`, `cyrb coverage`, etc.) when run outside the repo root
  - Added `load_environ()` to read `/proc/self/environ` and pass through to child processes
  - cyrb binary: 58KB → 59KB (+832 bytes)
- **install.sh missing companion scripts**: only `cyrb-init.sh` was installed; `cyrb-port.sh`,
  `cyrb-coverage.sh`, `cyrb-doctest.sh`, `cyrb-repl.sh`, `cyrb-header.sh` were never copied
  - Install and version manager now dynamically pick up all `cyrb-*.sh` scripts
- **compiler.sh wrong default**: test suite defaulted to `./build/cc` (bridge compiler, 60KB)
  instead of `./build/cc2` (full compiler, 136KB), causing 115 false failures

### Metrics
- Compiler: 136KB (unchanged)
- cyrb: 59KB (was 58KB)
- 212 tests, 0 failures
- Self-hosting: byte-identical

## [1.5.0] — 2026-04-06

### Refactored — Compiler
- **EMITELF/EMITELF_SHARED dedup**: factored 95% duplicate ELF emission into `EMITELF_USER(S, etype)`
  - ET_EXEC (2) and ET_DYN (3) now share one code path with e_type parameter
  - Compiler shrunk from 138KB to 136KB

### Refactored — Standard Library
- **process.cyr**: extracted `_exec3(cmd, arg1, arg2)` helper — eliminated 3x copy-pasted argv building
- **bounds.cyr**: extracted `_bounds_fail()` and `_bounds_neg()` — eliminated 4x copy-pasted error reporting

### Fixed — Stale Comments
- lex.cyr preprocessor comment: updated 0x90000 → 0x222000 to match actual buffer location

### Removed — Dead Code
- tagged.cyr: removed commented-out `option_map()` (lines 80-85)
- cc_bridge.cyr: removed unused `GMJP()/SMJP()` accessors
- scripts/cyrb-cffi.sh: removed (not wired into cyrb dispatcher)
- scripts/cyrb-symbols.sh: removed (not wired into cyrb dispatcher)

### Fixed — Documentation
- benchmarks.md version updated from 0.9.0-pre to 1.5.0

### Metrics
- Compiler: 136KB (was 139KB — 3KB saved from dedup)
- 263 tests, 0 failures
- Self-hosting: byte-identical

## [1.4.0] — 2026-04-06

### Added — Tooling
- **cyrb.cyr**: full Cyrius replacement for shell dispatcher (58KB binary)
  - 25+ subcommands: build, run, test, bench, check, self, clean, init, package,
    publish, install, update, port, header, fmt, lint, doc, vet, deny, audit,
    coverage, doctest, repl, version, which, help
  - Tool discovery: finds cc2 via ~/.cyrius/bin/ or ./build/ dev mode
  - VERSION file reading, --aarch64 cross-compilation flag
  - Delegates to companion tools (cyrfmt, cyrlint, cyrdoc, cyrc) and shell scripts
- **`cyrb port`**: one-command Rust→Cyrius project scaffolding
  - Moves Rust to rust-old/, creates src/lib/programs/tests dirs
  - Vendors stdlib from installed Cyrius
  - Generates main.cyr skeleton, cyrb.toml, test script
  - Tested on vidhana (228 lines) — compiles and runs

### Fixed — Compiler
- **String data buffer overflow**: expanded str_data from 2KB to 32KB (0x69000 → 0x61000)
  - Programs with >2KB of string literals would silently corrupt str_pos/data_size
- **Preprocessor output buffer**: wired PREPROCESS to use 0x222000 (256KB) instead of 0x91000
  - Old buffer overlapped tok_types at 0xA2000 after ~68KB of expanded source
  - The 256KB buffer was allocated at brk but never connected to the preprocessor
- **Fixup table overflow**: relocated from 0x8A000 to 0x262000, expanded to 2048 entries
  - Old table had only ~528 usable entries before overlapping compiler state at 0x8C100
  - Programs with >500 function calls + string literals would corrupt compiler state
  - brk extended from 0x262000 to 0x26A000

### Improved — Documentation
- Inline assembly section added to cyrius-guide.md (stack layout, param offsets)
- Known limitations updated (removed fixed items, added gotchas)

### Metrics
- Compiler: 139KB (138,400 bytes)
- cyrb binary: 58KB (58,616 bytes)
- 263 tests (212 compiler + 51 programs) + 26 aarch64, 0 failures
- First repo scaffolded: vidhana (228 lines Rust → Cyrius skeleton)

## [1.2.0] — 2026-04-06

### Added — Language
- **Address-based operator overloading**: `Vec3{10,20,12} + Vec3{32,22,30}` works
  - Multi-field structs pass addresses to operator functions (can read all fields)
  - Single-field / type-annotated vars pass values (backward compatible)
  - Dispatch based on variable allocation size: >8 bytes = address, =8 bytes = value

### Fixed — Documentation
- Updated known limitations in FAQ (removed fixed items, added gotchas section)
- Updated vidya limitations entry (marked block scoping/var-in-loop as fixed)
- Added doc comments to all 50 functions in lib/syscalls.cyr
- Documented dynamic loop bound gotcha in FAQ, vidya, and roadmap

### Added — Tests
- 10 new tests: address-based operators, enum constructors, shared compile, stress tests

### Metrics
- Compiler: 139KB
- 263 tests (212 compiler + 51 programs) + 26 aarch64, 0 failures

## [1.1.0] — 2026-04-06

### Added — Language
- **For-in over collections**: `for item in vec { body }` iterates over vec elements
  - Desugars to `vec_len` + index loop + `vec_get` per iteration
  - Works alongside range for-in (`for i in 0..10`)
  - Item variable scoped to loop body

### Changed
- Removed `lib/cyrius-ref/` — agnostik, agnosys, kybernet, nous live in own repos
- Promoted `lib/syscalls.cyr` to stdlib (was agnosys/syscalls.cyr)
- Removed reference test programs (agnostik_test, kybernet_test, nous_test)
- Synced kernel to agnos repo (source of truth)

### Added — Language
- **Enum constructors (auto-generate)**: `enum Result { Ok(val) = 0; }` auto-generates `Ok(42)`
  - Constructor registered in pass 1, body emitted in pass 2 function section
  - Uses alloc(16) to heap-allocate {tag, payload}
  - Root cause of initial bug: constructor body was emitted in main code (after JMP)
    instead of function section (before JMP). Fixed by adding `emit_code == 2` pass.

### Added — Tooling
- **Shared library output**: `shared;` directive emits ET_DYN ELF (recognized by `file` as shared object)
  - First step toward dlopen/dlsym FFI
  - Normal programs unaffected (default remains ET_EXEC)
  - Full .so with symbol tables requires PIC codegen (post-v1.1)
- `cyrb cffi` — C FFI wrapper generator (subprocess bridge)

### Metrics
- Compiler: 137KB
- 253 tests (202 compiler + 51 programs) + 26 aarch64, 0 failures

## [1.0.0] — 2026-04-06

### v1.0 — Sovereign, Self-Hosting Systems Language

**Cyrius v1.0 ships.** A sovereign, self-hosting compiler built from a 29KB seed
binary. No Rust. No LLVM. No Python. No libc. Assembly up.

### Added — Language
- **Block body closures**: `|x| { var y = x * 2; return y; }` (inside functions)
- Collection iteration via library: `vec_fold`, `vec_map`, `for_each` with closures

### Language Features (cumulative v0.1–v1.0)
- Structs, enums, switch, pattern matching (`match`), for-in range
- Functions (>6 params, recursion), closures/lambdas
- Floating point (f64, SSE2, 10 builtins, literals)
- Methods on structs (convention dispatch)
- Trait impl blocks (`impl Trait for Type { }`)
- Module system (`mod`, `use`, `pub`)
- Operator overloading (`+` `-` `*` `/` dispatch to Type_op)
- String type with 16 methods via dot syntax
- Block scoping, feature flags (`#define`/`#ifdef`/`#endif`)
- Generics Phase 1 (syntax parsed), enum constructor syntax
- Error messages with line numbers

### Toolchain
- 20+ cyrb commands (build, test, bench, fmt, lint, doc, vet, deny, audit, ...)
- cyrb repl, cyrb doctest, cyrb coverage, cyrb docs --agent
- C FFI header generation (`cyrb header`)
- Subprocess bridge (exec_vec, exec_capture, exec_env)
- Installer + version manager + release pipeline
- 45 benchmarks with CSV regression tracking

### Architecture
- x86_64: self-hosting, byte-identical
- aarch64: self-hosting, byte-identical on Raspberry Pi
- Portable syscall constants (SYS_*) for cross-architecture

### Quality
- 253 tests (202 compiler + 51 programs) + 26 aarch64, 0 failures
- `cyrb audit` → 10/10
- 5 ADRs, threat model, 37 vidya entries
- Migration strategy for 107 repos (~980K lines)

### Metrics
- Compiler: 128KB (x86), 130KB (aarch64)
- 35 stdlib modules, 200+ functions
- 57 programs, AGNOS kernel (62KB)
- 5 crate rewrites completed (wave 0)
- 29KB seed → working OS in 128KB

## [0.10.0] — 2026-04-06

### Added — Tooling
- **C FFI header generation**: `cyrb header lib/mylib.cyr > mylib.h`
  - Scans for `pub fn` declarations, emits C prototypes with `cyr_val` (int64_t)
  - Enables C/Rust code to know Cyrius function signatures

### Added — Tests
- 34 new compiler tests across 8 categories:
  - Nested structs, deep scoping, preprocessor edge cases
  - Comparison edge cases, arithmetic edge cases
  - Function edge cases (recursion, early return, chained calls)
  - String/load/store, enum edge cases
  - Combined feature tests (match in for-in, impl chains, typed operators)
- **251 total tests (200 compiler + 51 programs), target of 250 achieved**

### Added — Documentation
- **Migration strategy** (docs/development/migration-strategy.md)
  - Full survey: 107 repos, ~980K lines, 6 migration waves
  - Per-repo sizing, dependency mapping, bridge strategies
  - Rust → Cyrius translation guide
  - Porting workflow template

### Improved — Libraries
- Hashmap: added `map_values()`, `map_clear()`, formatting cleaned
- Deep code audit: all encodings verified, tombstone logic confirmed correct
- Shared library (.so) deferred to post-v1.0 — subprocess bridge covers migration needs

### Fixed — aarch64
- **BYTE-IDENTICAL SELF-HOSTING ON REAL ARM HARDWARE**
  - cc3 == cc4 = 129,760 bytes on Raspberry Pi
  - Root cause: aarch64 `openat` (syscall 56) requires `AT_FDCWD` (-100) as first arg
  - Fix: READFILE detects architecture and passes correct args
- Write loop for large ELF output (both x86 and aarch64)

### Metrics
- Compiler: 128KB (x86), 130KB (aarch64)
- 251 tests (200 compiler + 51 programs) + 26 aarch64, 0 failures
- aarch64 self-hosting: byte-identical on Raspberry Pi
- `cyrb audit` → 10/10

## [0.9.12] — 2026-04-06

### Added — Libraries
- **Enhanced subprocess bridge** in process.cyr:
  - `exec_vec(args)` — run command with variable args via vec
  - `exec_capture(args, buf, buflen)` — capture stdout with variable args
  - `exec_env(args, env)` — run with custom environment variables
  - `exec_cmd(cmdline)` — split string and execute (convenience)
  - Enables calling external tools: `nvidia-smi`, `python3`, `node`, `cargo`, etc.

### Added — Roadmap
- Shared library output (.so) — emit ET_DYN ELF for FFI bridging
- C FFI header generation — call Cyrius from C/Rust/Python
- Migration strategy: subprocess (now), protocol (v1.x), FFI (v1.x)

### Improved — Libraries
- **Hashmap cleanup**: added `map_values()`, `map_clear()`, formatting fixed
- Deep code audit: all instruction encodings verified, tombstone logic confirmed correct

### Added — Tests
- 12 new edge case tests: closures in functions, nested match, match expressions,
  nested for-in, for-in with expressions, operator chaining, typed locals/globals

### Added — Documentation
- Vidya language docs updated through v0.9.12 (traits, closures, strings, operators, subprocess)
- ai-hwaccel repo prepared for Cyrius port (Rust moved to rust-old/)

### Metrics
- Compiler: 128KB
- 217 tests (166 compiler + 51 programs) + 26 aarch64, 0 failures
- `cyrb audit` → 10/10

## [0.9.11] — 2026-04-06

### Added — Language
- **Operator overloading**: `a + b` dispatches to `Type_add(a, b)` when `a` has struct type
  - Works for `+`, `-`, `*`, `/` operators
  - Type tracked via `expr_stype` from variable load
  - Works with type-annotated locals and struct-literal globals
- Auto enum constructor syntax parsing (from v0.9.6) retained

### Added — Tests
- 3 operator overloading tests (add, sub, mul)

### Metrics
- Compiler: 128KB
- 205 tests (154 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.10] — 2026-04-06

### Added — Language
- **Closures / lambdas**: `|x| x * 2`, `|a, b| a + b` expression closures
  - Generates anonymous `__clN` functions, returns function pointer
  - Multi-param, zero-param (`|_| expr`), expression bodies
- **String type with methods**: `var s: Str = str_from("hello"); s.len(); s.contains("x")`
  - Type annotation `: Str` on local vars enables dot-call method dispatch
  - 16 Str method wrappers: len, data, print, println, eq, cat, sub, clone, contains, starts_with, ends_with, index_of, from_int, to_int, trim, split
  - Works for any struct type annotated with `: TypeName`
- **Local variable struct type tracking**: `: TypeName` annotations on locals set struct ID for method dispatch

### Metrics
- Compiler: 128KB
- 202 tests (151 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.9] — 2026-04-05

### Added — Language
- **Trait impl blocks**: `impl Trait for Type { fn method(self) { } }`
  - Methods mangled to `TypeName_method` (reuses module name mangling)
  - Multiple impl blocks for same type supported

### Added — Compiler Infrastructure
- Expression type tracking (`expr_stype`) — struct type of last expression
- Operator dispatch helpers (`BUILD_OP_NAME`, `EMIT_OP_DISPATCH`) for future use

### Added — Tests
- 3 trait impl tests (basic, mutate, multi-impl)

### Metrics
- Compiler: 124KB
- 199 tests (148 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.8] — 2026-04-05

### Added — Language
- **Pattern matching**: `match expr { val => { } _ => { } }` with scoped arms
- **For-in range loops**: `for i in 0..10 { }` with exclusive end, block-scoped iterator

### Milestone — aarch64
- cc3_aarch64 runs natively on real Raspberry Pi hardware
- ESCPOPS rewritten: pop-through-x0 fixes register mapping
- Syscall translation layer (x86→aarch64) with corrected MOVZ encodings
- SYS_* enum constants replace hardcoded syscall numbers in all shared code

## [0.9.7] — 2026-04-05

### Added — Language
- **Module system**: `mod name;`, `use mod.fn;`, `pub fn` for namespace + visibility
  - Name mangling: `mod math; fn add()` → registered as `math_add`
  - Use aliases: `use math.add;` lets you call `add()` which resolves to `math_add`

### Added — Tooling
- `cyrb coverage` — file/function-level test coverage reports
- `cyrb doctest` — run doc examples (`# >>>` / `# ===`) from .cyr files
- `cyrb repl` — interactive expression evaluator
- `cyrb docs --agent` — markdown server for bots/agents

### Added — Tests
- 6 new compiler tests: pattern matching (3), for-in range (3)
- aarch64 test suite expanded: 12 → 26 tests (arithmetic, control flow, functions, bitwise, load/store)
- `tests/aarch64-hardware.sh` — standalone test script for real ARM hardware

### Fixed
- `match` keyword collision: renamed `match` vars in grep.cyr and cyrb.cyr
- CI aarch64 test output redirect (stdout was contaminating exit code capture)

### Metrics
- Compiler: 120KB (x86), 110KB (aarch64)
- 196 tests (145 compiler + 51 programs) + 26 aarch64, 0 failures

## [0.9.6] — 2026-04-05

### Added — Language
- **Enum constructor syntax**: `enum Result { Ok(val) = 0; Err(code) = 1; }` parses payload syntax
- **Feature flags**: `#define`, `#ifdef`, `#endif` preprocessor directives
  - Hash-based flag table (32 flags), nested ifdef with skip depth tracking

### Added — Tooling
- `cyrb docs [--agent] [--port N]` — serve project docs (HTML default, markdown for agents)
- `cyrb.toml` parser: `toml_get` + `read_manifest` (replaces grep/sed)
- `scripts/version-bump.sh` — update VERSION + install.sh in one command
- cyrb version now reads from VERSION file (matches project version)

### Added — Documentation
- 5 ADRs: assembly cornerstone, everything-is-i64, fixed heap, convention dispatch, two-step bootstrap
- Threat model (docs/development/threat-model.md)
- 10 vidya planned-feature implementation strategies

### Added — Tests
- Enum constructor tests (2), feature flag tests (3)

### Fixed — Compiler
- Self-hosting test: compares compiler.cyr output (was testing bridge compiler)

### Metrics
- Compiler: 110KB
- 186 tests (135 compiler + 51 programs) + 12 aarch64, 0 failures
- `cyrb audit` → 10/10, self-hosting verified, 14/14 vidya pass

## [0.9.5] — 2026-04-05

### Added — Language
- **Block scoping**: variables in if/while/for blocks don't leak to outer scope
  - Scope depth tracking, SCOPE_PUSH/SCOPE_POP, variable shadowing
- **f64 as statements**: f64 builtins now work in statement context

### Added — Tests
- 19 new compiler tests: float (12), methods (3), block scoping (4)
- 2 new test programs: floattest.cyr (13 assertions), hmtest.cyr (14 assertions)
- Float benchmark program (bench_float.cyr — 7 benchmarks)

### Metrics
- 181 tests (130 compiler + 51 programs) + 12 aarch64, 0 failures

## [0.9.4] — 2026-04-05

### Fixed — Compiler
- **Preprocessor**: string literals containing "include" no longer trigger file inclusion
  - Only checks for include directive at beginning of line (column 0)
- **Self-hosting test**: fixed to use `compiler.cyr | cc2 = cc3` comparison

### Added — Tooling
- `scripts/version-bump.sh` — update VERSION + install.sh in one command

### Added — Documentation
- Vidya: 9 new implementation entries (float SSE2, methods, line numbers, tok_names overflow, two-step bootstrap, preprocessor fix, hashmap tombstone, P-1 hardening pattern, self-hosting test)
- Vidya: f64 usage examples in type_systems, method dispatch in design_patterns
- Roadmap: added Completed section (v0.9.0–v0.9.4), cleared done items from active lists

### Metrics
- Compiler: 104KB, 222 functions
- 160 x86_64 + 12 aarch64 tests, 0 failures
- 14/14 vidya reference files pass

## [0.9.3] — 2026-04-05

### Fixed — Libraries (P-1 Hardening)
- **hashmap**: tombstone-based deletion (was breaking probe chains on delete)
- **vec**: `vec_remove` bounds check on index
- **alloc**: brk failure detection — returns 0 on OOM
- **json**: `json_get` null key/pairs guard

## [0.9.2] — 2026-04-05

### Added — Language
- **Floating point (f64)**: SSE2 codegen for double-precision math
  - `f64_from(int)`, `f64_to(f64)` — int/float conversion
  - `f64_add`, `f64_sub`, `f64_mul`, `f64_div` — arithmetic
  - `f64_eq`, `f64_lt`, `f64_gt` — comparison (returns 0/1)
  - `f64_neg(val)` — negation
  - Float literals: `3.14` lexed and converted at runtime
- **Methods on structs**: `point.scale(2)` dispatches to `Point_scale(&point, 2)`
  - Convention: `StructName_method(self, args)` — dot-call passes `&var` as first arg
  - Works in both expression and statement context
- **Error line numbers**: `error:3: unexpected token (type=5)` replaces `error at token 42`
  - Line tracking via `tok_lines` parallel array (65536 slots)
  - Warnings and duplicate-var errors also report line numbers

### Fixed — Compiler
- **tok_names buffer overflow**: expanded 32KB → 64KB, relocated var_noffs/var_sizes downstream
  - Root cause: ~48K bytes of identifiers overflowed 32K buffer into var_noffs at 0x58000
  - Manifested as "unexpected token" errors when adding >200 functions
  - Added bounds check in LEXID (error at 65000 bytes)
- **Token arrays expanded**: 32768 → 65536 slots (tok_types, tok_values, tok_lines)
- **Preprocessor output buffer relocated**: moved past token arrays to prevent overlap
- **f64 comparison flag bug**: `xor eax,eax` clobbers ZF from `ucomisd` — use `mov eax,0` instead
- **aarch64 brk sync**: matched x86 heap layout changes (brk, tok_lines, preprocessor)
- **aarch64 var_sizes fixup**: updated 0x58800 → 0x60800 in aarch64/fixup.cyr
- **aarch64 TOKVAL offset**: was reading tok_values from old 0xE2000 instead of new 0x122000

### Metrics
- Compiler: 104KB (was 96KB) — 222 functions across 7 modules + SSE2 emitters
- 160 x86_64 tests (111 compiler + 49 programs) + 12 aarch64 tests, 0 failures
- Self-hosting: byte-identical

## [0.9.1] — 2026-04-05

### Fixed — CI
- Program test suite stalling on system-dependent tests (fork/exec, apt-cache, python3)
- Moved 8 ecosystem tests (nous, ark, cyrb, kybernet, agnostik, kernel ELF) behind `--system` flag
- Added `timeout` guards to all system test executions
- Removed python3 dependency from CI (kernel ELF tests now in `--system` only)
- Program test count: 46 (was 57) in CI, full 57 available via `--system`

### Added — Benchmarks
- 3-tier benchmark suite: 38 benchmarks across stdlib, data structures, compiler/toolchain
- 6 benchmark programs: bench_string, bench_alloc, bench_vec, bench_hashmap, bench_fmt, bench_tagged
- `scripts/bench-history.sh` — automated CSV recording + BENCHMARKS.md trend generation
- `bench-history.csv` — persistent regression tracking (matches bhava/hisab pattern)
- `cyrb bench` — run full suite, tier (`--tier1`, `--tier2`), or single file
- CI benchmark job with artifact upload (tier 1+2, 90-day retention)
- v0.9.0 baseline established: self-compile 9ms, strlen 418ns, alloc 428ns, hashmap lookup 650ns

### Improved — Installer & Release
- Rewritten `scripts/install.sh` to match python/ruby/rust installer patterns
- Single tarball download: `cyrius-$VERSION-$ARCH-linux.tar.gz` (bins + stdlib + scripts)
- SHA256 checksum verification on download
- Version-specific layout: `~/.cyrius/versions/$VERSION/bin/` + `lib/`
- Bootstrap from source fallback with self-hosting verification
- Version manager (`cyrius`): added `uninstall`, `update`, `ls` alias
- Release workflow: dual-arch tarballs (x86_64 + aarch64), parallel builds
- Clean summary output showing installed components

### Improved — Tooling
- `cyrb bench` now dispatches to `bench-history.sh` (no args = full suite)
- Roadmap updated: benchmark history tracking marked complete, bhava/hisab pillar gaps prioritized

### Improved — Documentation
- Roadmap restructured with AGNOS pillar port critical path (3 tiers, 18 features)
- Changelog consolidated: all v0.9.0 work merged into single release entry
- Article updated with v0.9.0 metrics (93KB compiler, 186 tests, 38 benchmarks, 5 crate rewrites)

### Metrics
- 38 benchmarks across 3 tiers, self-compile: 9ms
- 157 x86_64 tests (111 compiler + 46 programs) + 29 aarch64 tests, 0 failures
- 35 library modules, 199 functions
- `cyrb audit` → 10/10 green

## [0.9.0] — 2026-04-05

### Added — Language
- Comparison expressions in function arguments (`f(x == 1)` produces 0/1 via `setCC`)
- `PARSE_CMP_EXPR` + `ESETCC` codegen — comparisons as value-producing expressions
- Generics syntax: `fn foo<T>()`, `struct Bar<T>` (parsed, not enforced)
- Tagged unions: `tagged.cyr` with Option (Some/None), Result (Ok/Err), Either
- Traits: `trait.cyr` with vtable-based dispatch (Display, Eq, From, Default)
- HashMap: `hashmap.cyr` with FNV-1a hash, open addressing, auto-grow
- Callback library: `callback.cyr` with vec_map, vec_filter, vec_fold, fork_with_pre_exec
- String enhancements: contains, starts_with, split, join, trim, builder, from_int/to_int
- String formatting: `fmt_sprintf` with %d, %x, %s, %%
- Bounds checking: `bounds.cyr` with checked_load/store
- JSON parser: `json.cyr` with parse, get, build
- Process library: `process.cyr` with run, spawn, capture
- Filesystem: `fs.cyr` with path ops, dir listing, tree walk
- Network sockets: `net.cyr` with TCP/UDP via syscalls
- Pattern matching: `regex.cyr` with glob match, find/replace
- `assert.cyr` test framework: `assert(cond, name)`, `assert_eq`, `assert_neq`, `assert_gt`, `assert_summary`
- 17 new compiler tests (8 comparison-in-args + 9 Phase 10 edge cases)

### Added — Tooling
- cyrb shell dispatcher (18 commands — build, run, test, bench, check, self, clean, init, package, publish, install, update, audit, fmt, lint, doc, vet, deny)
- cyrfmt (18KB) — code formatter
- cyrlint (26KB) — linter (trailing whitespace, tabs, line length, braces)
- cyrdoc (29KB) — documentation generator + `--check` coverage mode
- cyrc (22KB) — dependency audit + policy enforcement (vet/deny)
- `cyrb audit` — 10-check full project validation
- `cyrb-init.sh` — project scaffolding with vendored stdlib
- `install.sh` — curl-pipe installer with version manager
- `cyrius` version manager (version, list, use, install, which)
- `.ark` package format (manifest.json + binary tarball)
- `cyrb.toml` project manifest
- zugot recipes: cyrius.toml, kybernet.toml, agnos-kernel.toml

### Added — Benchmarks
- 3-tier benchmark suite: stdlib (17), data structures (12), compiler/toolchain (9)
- `bench.cyr` framework with nanosecond timing (clock_gettime MONOTONIC_RAW)
- `scripts/bench-history.sh` — automated CSV recording + BENCHMARKS.md trend generation
- `bench-history.csv` — persistent regression tracking (matches bhava/hisab pattern)
- `cyrb bench` — run full suite, tier, or single file
- CI benchmark job with artifact upload

### Added — aarch64
- 29 feature tests passing (arithmetic, control flow, functions, structs, enums, strings, syscalls)
- Refactored 14 arch-specific functions from parse.cyr to emit files
- Dual-arch cyrb: `cyrb build --aarch64`, `cyrb test --aarch64`

### Added — Ecosystem
- **agnostik** — shared types: 6 modules (error, types, security, agent, audit, config), 54 tests
- **agnosys** — syscall bindings: 50 syscall numbers, 20+ wrappers
- **kybernet** — PID 1 init: 7 modules, 38 tests. Rewritten from 1649 lines Rust to 727 lines Cyrius
- **nous** — dependency resolver: marketplace + system resolution, 26 tests
- **ark** — package manager CLI (44KB): install/remove/search/list/info/status/verify/history
- AGNOS repo with dual-arch build/test scripts and CI
- All stdlib functions documented (cyrdoc --check passes)
- 14 vidya reference files (runnable, tested)

### Added — Infrastructure
- Repo restructured: stage1/ → src/, lib/, programs/, tests/
- VERSION, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE
- CI/CD: 8 parallel jobs (build, check, supply-chain, security, test, test-agnos, aarch64, doc)
- Release workflow: CI gate → version verify → bootstrap cc2 → tools → SHA256SUMS → GitHub Release
- docs: tutorial, stdlib-reference, FAQ, benchmarks, package-format, roadmap

### Fixed — Compiler
- **Enum init ordering**: enum values were 0 inside functions — swapped init order
- **Comparison in fn args**: was "error at token N (type=17)" — added PARSE_CMP_EXPR
- Fixup table expanded 512 → 1024 entries (relocated fixup_cnt/last_var)
- Generics skip in pass 1 fn-skip and pass 2 struct-skip
- Token array bounds check (error at 32768 tokens)

### Fixed — aarch64
- Initial branch (x86 JMP → aarch64 B)
- RECFIX ordering (before MOVZ, not after)
- Pop encoding (pre-indexed → post-indexed)
- Modulo (SDIV + MSUB with correct Rn register)
- Struct field access (EVADDR_X1 + EADDIMM_X1)
- Function ABI (STP/LDP frame, STUR/LDUR locals, BL calls)

### Fixed — Kernel (Phase 10 Audit — 23 issues resolved)
- pmm_bitmap bounds check, proc_table overflow guard
- ISR full register save (9 regs), syscall write clamping

### Metrics
- 35 library modules, 150+ documented functions
- 157 x86_64 tests (111 compiler + 46 programs) + 29 aarch64 tests, 0 failures
- 38 benchmarks across 3 tiers, self-compile: 9ms
- 8 tool binaries + shell dispatcher
- `cyrb audit` → 10/10 green
- Compiler: 93KB, Kernel: 62KB, Toolchain: 162KB total

## [0.8.0] — 2026-04-04

### Added — Kernel (Phase 7)
- AGNOS kernel (58KB, 606 lines, 32 functions): multiboot1 boot, 32-to-64 shim, serial I/O, GDT, IDT, PIC, PIT timer (100Hz), keyboard (ring buffer), page tables (16MB), PMM (bitmap), VMM, process table, syscalls (exit/write/getpid)

### Added — Language (Phase 8 Tier 1)
- Enums (`enum E { A = 0; B = 42; }`), switch/match, function pointers (`&fn_name`)
- Type enforcement warnings, heap allocator (brk), String type (str.cyr), argc/argv (args.cyr)
- Standard library: 8 libs, 53 functions (string, alloc, str, vec, io, fmt, args, fnptr)

### Added — Multi-Architecture (Phase 9)
- aarch64 backend (61 emit functions), cross-compiler builds
- Codegen factored: shared frontend, per-arch backend

## [0.7.0] — 2026-04-03

### Added — Language Extensions (Phase 4-6)
- cc2 modular compiler (7 modules, 182 functions, 92KB)
- Structs, pointers, >6 params, load/store 16/32/64, include, inline asm (18 mnemonics)
- elif, break/continue, for loops (token replay), &&/|| (short-circuit)
- Typed pointers, nested structs, global initializers (two-pass scanning)
- Bare metal ELF (multiboot1), ISR pattern, bitfields
- 46 programs, 157 tests, 10-233x smaller than GNU

## [0.5.0] — 2026-03-28

### Added — Self-Hosting Bootstrap (Phase 3)
- asm.cyr (1110 lines, 43 mnemonics), bootstrap closure
- 29KB committed binary root of trust, Rust seed archived
- Zero external dependencies

## [0.3.0] — 2026-03-25

### Added — Assembly Foundation (Phase 2)
- Seven-stage chain: seed → stage1a → 1b → 1c → 1d → 1e → stage1f
- stage1f: 16384 tokens, 256 functions, 63 tests

## [0.1.0] — 2026-03-20

### Added — Foundation (Phase 0-1)
- Forked rust-lang/rust, mapped cargo registry codepaths
- Ark registry sovereignty patches (ADR-001)
- cyrius-seed (Rust assembler, 69 mnemonics, 195 tests)
