# Issue: Global-init order — silent zero for forward references

**Discovered:** 2026-04-28 (mabda v3 Step 4f.ii — BO page perms tightening)
**Component:** `cyrius` compiler / runtime — global initializer evaluation
**Severity:** Medium (silent miscompile; surfaces as runtime zeros that
look like working code)
**Toolchain:** `cyrius 5.7.23`
**Filed:** mabda team, mirrored from
[`mabda/docs/development/issues/2026-04-28-cyrius-global-init-order.md`](https://github.com/MacCracken/mabda/blob/main/docs/development/issues/2026-04-28-cyrius-global-init-order.md).

## Summary

Cyrius initializes top-level `var X = expr;` declarations in source
declaration order. If `expr` references a constant declared **later**
in the same file, the reference resolves to `0` (the default
zero-initialized value) at the time `X` is evaluated. No warning,
no error — `X` ends up holding the wrong value, and downstream
consumers silently see the wrong value too.

## Reproduction

```cyrius
# In src/foo.cyr (or any single Cyrius file):

var COMPUTED = FLAG_A | FLAG_B | FLAG_C;   # → 0, not 7

# ... 200 lines later ...

var FLAG_A = 0x1;
var FLAG_B = 0x2;
var FLAG_C = 0x4;

# COMPUTED reads as 0 throughout the program.
```

A trivial smoke test surfaces it:

```cyrius
fn test() {
    assert_eq(COMPUTED, FLAG_A | FLAG_B | FLAG_C, "computed = OR of flags");
    # → fails with "got 0, expected 7"
}
```

## Why it bit hard during mabda Step 4f.ii

Mabda team added named perm-bitmask constants near the top of
`src/backend_native.cyr`:

```cyrius
var _NATIVE_PERM_FULL = AMDGPU_VM_PAGE_READABLE
                      | AMDGPU_VM_PAGE_WRITEABLE
                      | AMDGPU_VM_PAGE_EXECUTABLE;
```

…at line 117. The `AMDGPU_VM_PAGE_*` constants live at line 391+ in
the same file. Result: `_NATIVE_PERM_FULL` evaluated to `0` at load
time. Every BO got mapped with `perms = 0` — no read, no write, no
execute. Every dispatch TDR'd at the 10-second AMDGPU timeout.

Mabda burned ~30 minutes investigating a "wedged GPU" hypothesis
before a CPU regression test (`assert_eq(_NATIVE_PERM_FULL, R|W|X)`)
returned `got 0, expected 14` and pinned the actual cause. **Hardware
iteration cost matters** — every TDR puts the AMDGPU firmware closer
to a permanent wedge.

## Class of bug

Beyond the specific bit-flag pattern, this affects:

- Any computed-from-other-constants global (size calculations,
  page perms, bit-packed enum compositions)
- Refactors that reorder top-level declarations
- The pattern of "define module constants near the top of the file
  for grep-ability" — the natural readability convention is
  exactly what trips this.

## Suggested upstream fixes (in priority order, mabda)

1. **`cyrius lint` warning for forward references in top-level
   initialisers.** Walk the file; if any `var X = expr` references
   a symbol that appears later in the source, emit a warning. Text
   should be specific: "global '_NATIVE_PERM_FULL' at line 117
   references 'AMDGPU_VM_PAGE_READABLE' defined at line 391 — this
   evaluates to 0 at load time. Move the dependency above, or move
   the reference below."
2. **Compile-time error** if the language requires declaration
   order. Current behaviour (silent zero) is the worst of both
   worlds — neither permissive (let me forward-reference) nor
   strict (tell me I can't). Pick one.
3. **Runtime check** that warns when zero-initialized memory is
   read by a `var` initializer that the compiler can statically
   identify as a forward reference.

## Cyrius-side disposition

**Pinned 2026-04-28** at v5.7.29 ship as a v5.7.x patch slate item.
Slot promoted when claimed; v5.7.37 backstop now accommodates
the additional surfacing per the user-authorized 2026-04-28
slot-bound extension.

**Recommendation:** option (1) — `cyrius lint` warning. Reasons:

- Cheapest implementation (parse-time AST walk over top-level
  decls; build a name → line map of `var` / `fn` / `enum` /
  `struct` defs first pass, then check each `var = expr` against
  it — the symbol resolver already does this work for
  diagnostics, just with a different lookup direction).
- No compiler-correctness risk (warn-only, no codegen change).
- Self-host byte-identity preserved trivially.
- Matches "compiler grows to fit language, never the other way
  around" memory pin (`feedback_grow_compiler_to_fit_language.md`).
- Option (2) would break ~50+ stdlib globals that intentionally
  use forward refs to constants defined elsewhere in the file —
  too disruptive without an audit pass first. Option (3) is
  invasive (runtime cost + needs a way to distinguish "real 0"
  from "forward-ref 0").

**Acceptance gate** (when claimed): `cyrius lint` walks the file,
emits a warning for every forward-ref `var X = expr`, with file:
line + offending symbol + line where it's defined. The mabda
repro should produce exactly the warning shown in option (1)
above. CI gate runs `cyrius lint` on stdlib + mabda fixture and
counts warnings.

**Filing trail**

- Mabda v3 Step 4f.ii, 2026-04-28: encountered + diagnosed +
  fixed in a single session. Memory note (mabda):
  `feedback_cyrius_global_init_order.md`.
- Mabda workaround: place computed-constant blocks AFTER their
  dependencies; CPU regression tests now assert the *value* of
  every computed perm constant.
- Cyrius mirror filed 2026-04-28 at v5.7.29 ship.
