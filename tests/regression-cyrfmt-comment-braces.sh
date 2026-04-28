#!/bin/sh
# Regression: cyrfmt must not track `{` / `}` inside `#` comments or
# `"..."` string literals. Pinned to v5.7.22; closes
# agnos/docs/development/issue/2026-04-27-cyrius-fmt-tracks-braces-in-comments.md.
#
# Pre-v5.7.22 the brace-counter incremented on every `{` and `}`
# regardless of whether they were code, comment, or string. A doc
# comment quoting `asm { mov cr3, rax; }` made the next comment line
# get re-indented one level relative to the rest of the block —
# `cyrius fmt --check` then reported NEEDS FORMAT on perfectly fine
# source. agnos kernel hit it during 1.26.0 CI; same shape applies to
# any consumer with inline-asm syntax in docstrings.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRFMT="$ROOT/build/cyrfmt"
if [ ! -x "$CYRFMT" ]; then
    echo "  skip: $CYRFMT not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SC="$TMPDIR/cyrius_cyrfmt_brace_$$"
mkdir -p "$SC"
trap 'rm -rf "$SC"' EXIT

fail=0

# Case 1: agnos repro — comment quotes inline asm with literal braces.
cat > "$SC/case1.cyr" <<MEOF
# Load cr3_val. Replaces the \`var x = y; asm { mov cr3,
# rax; }\` pattern — that pattern relied on cc3-era codegen leaving
# the assigned value in RAX, which cc5's regalloc breaks.
fn cr3_load(cr3_val) {
    asm {
        0x48; 0x8B; 0x45; 0xF8;
        0x0F; 0x22; 0xD8;
    }
    return 0;
}
MEOF

"$CYRFMT" "$SC/case1.cyr" > "$SC/case1.out"
if ! diff -q "$SC/case1.cyr" "$SC/case1.out" > /dev/null 2>&1; then
    echo "  FAIL: case1 — cyrfmt re-indented around comment-quoted braces"
    diff "$SC/case1.cyr" "$SC/case1.out" | head -10
    fail=$((fail + 1))
fi

# Case 2: string literal containing braces.
cat > "$SC/case2.cyr" <<MEOF
fn pattern() {
    var s = "asm { mov cr3, rax; }";
    return s;
}
MEOF

"$CYRFMT" "$SC/case2.cyr" > "$SC/case2.out"
if ! diff -q "$SC/case2.cyr" "$SC/case2.out" > /dev/null 2>&1; then
    echo "  FAIL: case2 — cyrfmt counted braces inside a string literal"
    diff "$SC/case2.cyr" "$SC/case2.out" | head -10
    fail=$((fail + 1))
fi

# Case 3: existing well-formed code stays well-formed (regression
# coverage so the brace fix doesn't break ordinary indentation).
cat > "$SC/case3.cyr" <<MEOF
fn outer() {
    if (1 == 1) {
        var x = 42;
        return x;
    }
    return 0;
}
MEOF

"$CYRFMT" "$SC/case3.cyr" > "$SC/case3.out"
if ! diff -q "$SC/case3.cyr" "$SC/case3.out" > /dev/null 2>&1; then
    echo "  FAIL: case3 — normal indentation regressed"
    diff "$SC/case3.cyr" "$SC/case3.out" | head -10
    fail=$((fail + 1))
fi

# Case 4: comment + string + code mixed.
cat > "$SC/case4.cyr" <<MEOF
# Wraps the asm { ... } pattern.
fn wrapper() {
    var msg = "block { with } braces";
    if (msg != 0) {
        return 1;
    }
    return 0;
}
MEOF

"$CYRFMT" "$SC/case4.cyr" > "$SC/case4.out"
if ! diff -q "$SC/case4.cyr" "$SC/case4.out" > /dev/null 2>&1; then
    echo "  FAIL: case4 — mixed comment+string+code mis-indented"
    diff "$SC/case4.cyr" "$SC/case4.out" | head -10
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrfmt skips braces in comments/strings (4/4 cases)"
    exit 0
fi
exit 1
