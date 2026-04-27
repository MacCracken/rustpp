#!/bin/sh
# Regression: lex must reject malformed `\x##` / `\u####` / `\u{...}`
# escape sequences and surrogate codepoints. Pinned to v5.7.13.
#
# Positive coverage lives in tests/tcyr/string_escapes.tcyr; this gate
# covers reject paths only (lex errors abort cc5; .tcyr can only test
# successful compiles).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
TMPSTEM="$TMPDIR/cyrius_string_escapes_$$"
trap 'rm -f "$TMPSTEM".*' EXIT

fail=0
total=0

# expect_lex_error <case_name> <source> <expected_substring>
expect_lex_error() {
    name="$1"
    src="$2"
    expect="$3"
    total=$((total + 1))
    printf "%s" "$src" > "$TMPSTEM.in"
    if "$CC" < "$TMPSTEM.in" > "$TMPSTEM.out" 2> "$TMPSTEM.err"; then
        echo "  FAIL: $name — compile unexpectedly succeeded"
        fail=$((fail + 1))
        return
    fi
    if grep -q "$expect" "$TMPSTEM.err"; then
        :
    else
        echo "  FAIL: $name — expected substring not found: $expect"
        cat "$TMPSTEM.err"
        fail=$((fail + 1))
    fi
}

# ── \x## reject cases ──
expect_lex_error "x: bad-hex-1st-nibble" \
    'var s = "\xZ0"; syscall(60, 0);' \
    "\\\\x escape: bad hex digit"

expect_lex_error "x: bad-hex-2nd-nibble" \
    'var s = "\x1Z"; syscall(60, 0);' \
    "\\\\x escape: bad hex digit"

# ── \u#### reject cases ──
expect_lex_error "u: bad-hex" \
    'var s = "\u00Z0"; syscall(60, 0);' \
    "\\\\u escape: bad hex digit"

expect_lex_error "u: surrogate-low" \
    'var s = "\uD800"; syscall(60, 0);' \
    "surrogate codepoint not allowed"

expect_lex_error "u: surrogate-high" \
    'var s = "\uDFFF"; syscall(60, 0);' \
    "surrogate codepoint not allowed"

# ── \u{...} reject cases ──
expect_lex_error "u{}: empty" \
    'var s = "\u{}"; syscall(60, 0);' \
    "\\\\u{...} escape: no hex digits"

expect_lex_error "u{}: bad-hex" \
    'var s = "\u{1G}"; syscall(60, 0);' \
    "\\\\u{...} escape: bad hex digit"

expect_lex_error "u{}: too-many-digits" \
    'var s = "\u{1234567}"; syscall(60, 0);' \
    "\\\\u{...} escape: > 6 hex digits"

expect_lex_error "u{}: above-max-codepoint" \
    'var s = "\u{110000}"; syscall(60, 0);' \
    "codepoint > U+10FFFF"

expect_lex_error "u{}: surrogate-low" \
    'var s = "\u{D800}"; syscall(60, 0);' \
    "surrogate codepoint not allowed"

expect_lex_error "u{}: surrogate-high" \
    'var s = "\u{DFFF}"; syscall(60, 0);' \
    "surrogate codepoint not allowed"

if [ "$fail" -eq 0 ]; then
    echo "  PASS: string-escape reject cases ($total/$total)"
    exit 0
fi
exit 1
