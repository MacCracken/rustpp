# Preprocessor scans `include "` pattern inside string literals — RESOLVED

**Status:** ✅ **RESOLVED in cyrius v5.8.40** (preprocessor string-
literal awareness shipped). PP_PASS + PP_IFDEF_PASS in
`src/frontend/lex_pp.cyr` track `"`-bounded string-literal state
via `in_string` + `escape_next` flags; the `if (bol == 1)`
directive-detection block is gated on `&& in_string == 0`.
Mirrors the v5.7.36 cyrlint string-literal awareness fix shape.
cc5 +640 B (320 B per pass). Regression gate at
`tests/tcyr/preprocessor_string_literal.tcyr` — 12 assertions
across 5 groups (string with include pattern preserved byte-by-
byte; back-compat byte-store workaround; real include directives
at col 0; escape-sequence handling; '#define' inside string).
Vidya entry at `content/cyrius/ecosystem.cyml:685-720` flipped
from "pinned for v5.8.x" → "✅ FIXED in v5.8.40"; workaround
text kept for pre-v5.8.40 toolchain users. Archived 2026-05-03
during the v5.8.41 cyrlint cleanup pass.

**Discovered**: surfaced in vidya `content/cyrius/ecosystem.cyml:685-713`;
filed as local issue 2026-05-01 during v5.7.49 vidya audit.
**Toolchain at filing**: cyrius 5.7.49.
**Component**: compiler / lex.cyr / PREPROCESS
**Severity**: Low (consumer-mitigable workaround exists; no silent
miscompile in normal source; affects tools that scan their own source
for include directives — `cyrc vet`/`deny`-class programs).

## Symptom

The preprocessor (`PREPROCESS` in `src/frontend/lex.cyr`) scans raw
source bytes for the literal pattern `include "` (i-n-c-l-u-d-e-space-
quote). It does NOT distinguish between code and string-literal
context.

If a string literal contains this pattern, the preprocessor tries to
process it as a file inclusion, corrupting the source.

## Reproduction

```cyrius
fn check_include_token(buf) {
    if (memeq(buf, "include \"", 9) == 1) { ... }
    # Preprocessor sees 'include "' inside the string literal and
    # tries to open file '", 9) == 1) {...}'
}
```

Affects any program that scans source files for include directives
(`cyrc vet` / `deny`, `cyrius-lsp` indexer, build-system audit
scripts). Also affects comments containing the word `include` followed
by a quote — be careful in documentation.

## Workaround

Build the pattern at runtime using byte stores:

```cyrius
var _pat[2];
fn _init_pat() {
    store8(&_pat, 105);     # i
    store8(&_pat + 1, 110); # n
    store8(&_pat + 2, 99);  # c
    store8(&_pat + 3, 108); # l
    store8(&_pat + 4, 117); # u
    store8(&_pat + 5, 100); # d
    store8(&_pat + 6, 101); # e
    store8(&_pat + 7, 32);  # space
    store8(&_pat + 8, 34);  # "
    return 0;
}
# Then use: memeq(buf, &_pat, 9)
```

## Proper fix

Modify `PREPROCESS` in `src/frontend/lex.cyr` to track whether the
scanner is inside a string literal (between unescaped quotes). Only
trigger include-directive processing when NOT inside a string.

Pattern: state-machine flag `_pp_in_string` flipped on unescaped
`"`, suppress the include-pattern check while flag is set. Mirror
the logic used by `cyrlint`'s string-literal awareness shipped in
v5.7.36 — that pass already does string-literal tracking for
identifier scanning; the same primitive applies to PREPROCESS.

## Slot

**Pinned for v5.8.x** — bug-fix theme of the v5.8.x cycle. Mirrors
the v5.7.36 cyrlint string-literal fix shape.

## Vidya pointer

The workaround section was lifted from vidya
`content/cyrius/ecosystem.cyml:685-713`. The vidya entry should be
annotated with a link back to this issue file (per the v5.7.49 vidya
audit policy: open issues stay in vidya so consumers know the
workaround is still active, but get cross-referenced to the
canonical issue file in `docs/development/issues/`).
