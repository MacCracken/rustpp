# Issue: Arithmetic expressions inside function-call arguments fail to parse

**Discovered:** 2026-05-03 (vidya audio_dsp 11-lang port)
**Component:** `cyrius` compiler — parser (call argument expression handling)
**Severity:** Low (mechanical workaround exists; affects ergonomics
not correctness)
**Toolchain:** `cyrius 5.8.34`

## Summary

Companion gap to the existing `no_comparisons_in_fn_args` parser
restriction (see vidya field-notes
`content/cyrius/field_notes/language/parser_syntax.cyml`).
Subtraction expressions inside function-call argument lists fail
to parse with the same generic `expected identifier, got unknown`
diagnostic. The error fires at a downstream construct, not at the
call site itself. Likely applies to other binary arithmetic
operators (haven't bisected each).

Single identifiers, integer literals, and pre-declared variables
all work as call arguments — only computed expressions trip it.

## Reproduction

```cyrius
var ONE = 32768;

fn biquad_set(b0, b1, b2, a1, a2) { return 0; }

fn biquad_lowpass_1pole(a_q15) {
    biquad_set(a_q15, 0, 0, a_q15 - ONE, 0);   # <-- a_q15 - ONE in arg
}
```

Compile output:
```
error:<source>:7: expected identifier, got unknown
```

## Workaround

Hoist the expression to a local variable first:

```cyrius
fn biquad_lowpass_1pole(a_q15) {
    var a1 = a_q15 - ONE;
    biquad_set(a_q15, 0, 0, a1, 0);
}
```

## Suggested fix

Allow general expressions in function argument positions, matching
the rule for assignment RHS, return values, and array-index
expressions. The current restriction is inconsistent: arithmetic
works everywhere except inside `(...)` of a call.

If parser ambiguity prevents this, at least emit a specific
diagnostic at the offending arg: `error: arithmetic expressions
not allowed in function arguments — assign to a local first`.

## Scope confirmed

- `f(x - 1, ...)` → fails
- `f(x, y, ...)` → works
- `f(123, ...)` → works
- `f(precomputed_var, ...)` → works

Not yet bisected:
- `f(x + 1, ...)` (addition)
- `f(x * 2, ...)` (multiplication)
- `f(x | y, ...)` (bitwise)
- `f(x << 2, ...)` (shift)

When in doubt: hoist.
