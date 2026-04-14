# stdlib math & utility recommendations (from abaco 1.1.0)

**Source**: abaco — math engine (expression eval, unit conversion, DSP).
Repo: `/home/macro/Repos/abaco`. Port target: Cyrius 4.8.3.
**Status**: all recommendations below are derived from concrete stopgaps
currently in abaco source or in its `src/ai.cyr` port. Line numbers
reference abaco at commit after `8969f24`.

Each item lists: **current abaco workaround**, **proposed stdlib surface**,
**why it belongs in stdlib**, **priority**. Priorities: P1 (unblocks a real
perf/correctness gap), P2 (removes common duplication across downstream
projects), P3 (polish).

---

## P1-1. Hardware 128-bit `mulmod` — `(a * b) % m` for u64 a, b, m

### Current abaco
`src/ntheory.cyr::mod_mul` uses the double-and-add binary method (~64 iters,
a handful of ops each). Used inside Miller–Rabin. We benched the Cyrius
4.8.0 `u128_mul + u128_mod` path and it ran **~40× slower** than the binary
method because `u128_mod` (`lib/u128.cyr:383`) is a software long-division
loop. The original Rust version used `(a as u128 * b as u128) % m as u128`
which lowers to a single `mul`/`div` instruction pair on x86-64.

### Proposed stdlib
```
# lib/u128.cyr
fn u128_mulmod_u64(a, b, m)   # returns (a*b) mod m, all u64
```
On x86-64, emit:
```
mov rax, a
mul b          ; rdx:rax = a*b
div m          ; rax = quotient, rdx = remainder
mov rax, rdx
```
On aarch64, `umulh` + `madd` + software Knuth division (or defer to a
helper) can still be faster than the current iterative path.

Alternative: a hardware-lowered `u128_div`/`u128_mod` that recognises
`divisor_hi == 0` and emits a single `div` instruction instead of the
binary loop.

### Why stdlib
Any primality, factorisation, Pollard rho, RSA, or cryptographic library
needs fast `mulmod`. It is a ~3-line asm primitive with no portable C
equivalent; every consumer either writes the same double-and-add loop or
rolls inline asm. Putting it in `lib/u128.cyr` lets ntheory in abaco
drop ~15 lines and gain 10–40× on its Miller–Rabin hot path.

### Priority
**P1**. Blocks ntheory perf parity with Rust `u128` semantics — currently
called out in `abaco/ROADMAP.md`'s "Known Gaps" section.

---

## P1-2. Inverse trig builtins — `f64_asin`, `f64_acos`, `f64_atan`, `f64_atan2`

### Current abaco
`src/eval.cyr:645–658` implements these via identity formulas:
```
asin(x) = atan(x / sqrt(1 - x*x))   # stopgap via atan
acos(x) = pi/2 - asin(x)
atan(x) = asin(x / sqrt(1 + x*x))   # not great (chicken-and-egg)
atan2(y, x) ≈ atan(y/x)              # no quadrant fix
```
Accuracy and quadrant handling are compromised; atan2 in particular is
wrong in Q2/Q3.

### Proposed stdlib
```
# lib/math.cyr
fn f64_asin(x)          # sin⁻¹(x), x ∈ [-1, 1]
fn f64_acos(x)          # cos⁻¹(x), x ∈ [-1, 1]
fn f64_atan(x)          # tan⁻¹(x), result in [-π/2, π/2]
fn f64_atan2(y, x)      # two-arg arctangent, result in [-π, π]
```
Implementation options:
1. **fsincos** isn't useful here — these need their own x87 ops or SSE
   polynomial approximation.
2. **Polynomial approximation**: a Remez-style minimax polynomial on a
   reduced range plus range-reduction via identities (`asin(x) = atan(x/√(1−x²))`,
   `atan(x) = π/2 − atan(1/x)` for `|x|>1`) is standard and ~40 lines of
   pure Cyrius. Accuracy: 1–2 ulp is achievable.
3. **x87 `fpatan`** exists but the SSE path is preferred for determinism.

### Why stdlib
Every consumer ends up with the same identity-based stopgaps. abaco,
dhvani (DSP), hisab (symbolic), future geometry/GL projects all need
accurate `atan2`. It is also very hard to get right — quadrant handling,
signed-zero semantics, edge cases at ±∞ — exactly the work a stdlib
should centralise.

### Priority
**P1**. Correctness gap (atan2 quadrants). Abaco ROADMAP flags this as
"Cyrius builtins requested".

---

## P2-1. Inverse hyperbolic — `f64_asinh`, `f64_acosh`, `f64_atanh`

### Current abaco
`src/eval.cyr:678–687`:
```
asinh(x) = ln(x + sqrt(x² + 1))
acosh(x) = ln(x + sqrt(x² - 1))        # x ≥ 1
atanh(x) = 0.5 * ln((1+x)/(1-x))       # |x| < 1
```
The formulas are correct but lose precision for small `x` (in `asinh`)
and near `x = 1` (in `atanh` / `acosh`). Standard stdlibs use
range-reduced series for small arguments.

### Proposed stdlib
```
# lib/math.cyr
fn f64_asinh(x)
fn f64_acosh(x)
fn f64_atanh(x)
```
Trivial to add now that `f64_sinh/cosh/tanh` already live there; the
symmetry reads well. Implementation ~6 lines each with a precision
guard at small-argument branches.

### Why stdlib
Paired with the sinh/cosh/tanh already shipped in `lib/math.cyr` — the
missing half of the hyperbolic family. Several downstream projects
(abaco, dhvani, jalwa) duplicate the naive formulas.

### Priority
**P2**.

---

## P2-2. `parse_f64(cstring)` with Ok/Err result

### Current abaco
`src/ai.cyr::_nl_parse_f64` (50 lines) parses a whole null-terminated
cstring as an `f64`, returning `Ok(bits)` / `Err(0)`. Handles sign, decimal,
and whole-string validation. Does *not* handle scientific notation.
`src/eval.cyr::parse_number` is a similar parser but:
- takes `input, start, len, out_end`
- consumes as much as is a number, writes back the end index
- handles `e±NN` scientific notation

Neither is reusable from the other because the signatures differ.

### Proposed stdlib
```
# lib/fmt.cyr or lib/str.cyr
fn f64_parse(cstr)          # returns Ok(f64_bits) / Err(0), must consume all
fn f64_parse_prefix(cstr, out_end)  # consumes longest prefix, writes end offset
```
Both share a core that handles optional sign, integer part, `.` + fraction,
`e[+-]?digits`, and `NaN` / `Inf` (per IEEE 754 input grammar, roughly).

### Why stdlib
Every config loader, NL parser, benchmark harness, or simple calculator
writes this. It is tedious to get right (scientific notation, rounding to
nearest, handling of `Inf` / `NaN` text). Pairing with the existing
`fmt_float` output side closes a symmetric gap.

### Priority
**P2**.

---

## P2-3. Cstring case helpers — `str_lower_cstr` / `str_upper_cstr`

### Current abaco
Abaco's `src/core.cyr` defines:
```
fn str_lower(s)  # lowercase ASCII copy of a cstring
fn str_upper(s)
```
Because `lib/str.cyr` operates on `Str` structs (`{data, len}`), not
null-terminated byte pointers, there's no stdlib equivalent. Both vidya
and abaco re-invented this.

### Proposed stdlib
```
# lib/string.cyr (sibling of strlen, streq)
fn str_lower_cstr(s)        # allocates; lowercase copy
fn str_upper_cstr(s)        # allocates; uppercase copy
# or in-place variants:
fn str_lower_cstr_inplace(s)
fn str_upper_cstr_inplace(s)
```
ASCII-only is fine (matches existing `lib/string.cyr` conventions).

### Why stdlib
Two downstream projects (abaco, vidya) duplicate the exact loop. Any
consumer doing case-insensitive lookup by cstring key (HashMap, option
flags, HTTP headers) hits this. `lib/str.cyr` has `str_lower` only for
the `Str` struct variant.

### Priority
**P2**.

---

## P2-4. f64 constants — `F64_HALF`, `F64_PI`, `F64_TAU`, etc.

### Current abaco
`lib/math.cyr` exposes only `F64_ONE` and `F64_TWO`. Abaco's `src/dsp.cyr`
defines its own (see `DSP_ONE`, `DSP_HALF`, `DSP_TWO`, `DSP_TWO_HALF`,
`DSP_ONE_HALF`, `DSP_PI`, `DSP_PI_2`, `DSP_PI_4`, `DSP_TAU`,
`DSP_FRAC_1_SQRT2`, `DSP_SEMITONES`, `DSP_A4_FREQ`, `DSP_A4_MIDI`,
`DSP_C0_FREQ`).

The ones with mathematical significance (π, τ, √2⁻¹, e, ln 2, ln 10,
½, 1.5, 2.5) are universal; the audio-specific ones (A4, C0) are not.

### Proposed stdlib
```
# lib/math.cyr — add to the existing F64_ONE / F64_TWO
var F64_HALF         = 0x3FE0_0000_0000_0000;   # 0.5
var F64_ONE_HALF     = 0x3FF8_0000_0000_0000;   # 1.5
var F64_TWO_HALF     = 0x4004_0000_0000_0000;   # 2.5
var F64_PI           = 0x4009_21FB_5444_2D18;
var F64_PI_2         = 0x3FF9_21FB_5444_2D18;
var F64_PI_4         = 0x3FE9_21FB_5444_2D18;
var F64_TAU          = 0x4019_21FB_5444_2D18;
var F64_E            = 0x4005_BF0A_8B14_5769;
var F64_LN2          = 0x3FE6_2E42_FEFA_39EF;
var F64_LN10         = 0x4002_6BB1_BBB5_5516;
var F64_FRAC_1_SQRT2 = 0x3FE6_A09E_667F_3BCD;
var F64_SQRT2        = 0x3FF6_A09E_667F_3BCD;
```

### Why stdlib
These are universal mathematical constants with hot-path users (graphics,
DSP, numerics). Defining them once in bit-pattern form avoids f64
parse-at-init cost, f64-literal precision discussion, and duplication.
We already have `F64_ONE` / `F64_TWO` — the same pattern applied more
completely.

### Priority
**P2**.

---

## P3-1. DSP window functions — `f64_window_hann`, `f64_window_hamming`, …

### Current abaco
`src/dsp.cyr:319–395` ships `window_hann(n, size)`, `window_hamming`,
`window_blackman`, `window_kaiser(n, size, beta)` plus a
`window_kaiser_fill(dst, size, beta)` that precomputes I0(β). All four
are classical signal-processing windows; ported from dhvani's inline
code.

### Proposed stdlib
Optional: lift these into `lib/math.cyr` or a new `lib/dsp.cyr`. Kaiser
needs the modified Bessel I0 series (`_bessel_i0` in abaco's dsp.cyr).

```
fn f64_window_hann(n, size)
fn f64_window_hamming(n, size)
fn f64_window_blackman(n, size)
fn f64_window_kaiser(n, size, beta_bits)
fn f64_window_kaiser_fill(dst, size, beta_bits)
fn f64_bessel_i0(x_bits)
```

### Why stdlib
Every audio/radio/seismic project hand-rolls these. The formulas are
standard and the tests easy. If Cyrius grows a broader DSP community
these become a productivity multiplier; until then leaving them in
abaco is defensible.

### Priority
**P3** — nice-to-have, not blocking.

---

## P3-2. Modular exponentiation — `u64_pow_mod(base, exp, modulus)`

### Current abaco
`src/ntheory.cyr::mod_pow` — 12 lines, uses `mod_mul`. Same pattern as
RSA libraries, HMAC key stretchers, `random::shuffle`, etc.

### Proposed stdlib
```
# lib/u128.cyr or a new lib/modarith.cyr
fn u64_mulmod(a, b, m)          # = P1-1 above when hardware path exists
fn u64_powmod(base, exp, mod)
```

### Why stdlib
Paired with P1-1 — if you add `u64_mulmod` you almost certainly also
want `u64_powmod` since the two are always used together in primality,
cryptography, and hashing.

### Priority
**P3**.

---

## Out of scope / skipped

- **Async HTTP client** — we don't need it. Sync `http_get` from
  `lib/http.cyr` works fine for abaco's currency fetch.
- **Nested JSON** — `lib/json.cyr` is flat, we wrote a ~50-line
  field-extractor in `src/ai.cyr::_jf_get_object` for our one nested
  shape. Would be nice to have stdlib nesting support, but the flat
  parser plus a slice helper is adequate and the grammar is under-
  specified without a full value tree.
- **Trig builtins `f64_sin/cos/tan/exp/ln/log2/sqrt`** — already shipped.

---

## Summary table

| ID    | Priority | Area           | One-liner                                  |
|-------|----------|----------------|--------------------------------------------|
| P1-1  | P1       | `lib/u128.cyr` | Hardware 128-bit `mulmod` or fast u128 div |
| P1-2  | P1       | `lib/math.cyr` | Inverse trig: asin, acos, atan, atan2      |
| P2-1  | P2       | `lib/math.cyr` | Inverse hyperbolic: asinh, acosh, atanh    |
| P2-2  | P2       | `lib/fmt.cyr`  | `f64_parse(cstr)` → `Ok/Err`               |
| P2-3  | P2       | `lib/string.cyr` | `str_lower_cstr` / `str_upper_cstr`      |
| P2-4  | P2       | `lib/math.cyr` | π/τ/e/ln2/ln10/½/√2 f64 constants          |
| P3-1  | P3       | new `lib/dsp.cyr` | Hann/Hamming/Blackman/Kaiser windows    |
| P3-2  | P3       | `lib/u128.cyr` | `u64_powmod` (companion to P1-1)           |

All items are concrete stopgaps in abaco today — not speculative
requests. Happy to write patches for any item once an approach is
confirmed.
