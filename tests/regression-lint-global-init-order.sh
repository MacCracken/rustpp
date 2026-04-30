#!/bin/sh
# Regression: cyrlint global-init-order forward-ref warning.
#
# Pinned to v5.7.32. Mabda team filed at
# `mabda/docs/development/issues/2026-04-28-cyrius-global-init-
# order.md` after losing 30+ minutes on a hardware-iter
# misdiagnosis caused by a top-level `var COMPUTED = FLAG_A |
# FLAG_B | FLAG_C;` reference where FLAG_A/B/C were declared
# LATER in the same file. Cyrius initializes top-level
# `var X = expr;` in source declaration order; forward refs
# silently evaluate to 0.
#
# v5.7.32 adds a `cyrlint` rule (`lint_globals_init_order`)
# that walks the file twice. Pass 1 collects every top-level
# `var IDENT = ...;` and records (name, line). Pass 2 walks
# every `var X = expr;` initializer, scans the expr for
# identifier tokens, and emits a warning if any IDENT was
# declared at a line LATER than X. Mirrors mabda's option (1)
# in the filing.
#
# Scope deliberately narrow: only `var → var` references.
# fns / enums / structs are forward-ref-safe (fn addresses
# fixed at emit time; enum values compile-time constants;
# structs are types, not values).
#
# This gate runs cyrlint on:
#   1. A known-bad fixture (mabda repro shape) — expects ≥3
#      warnings (3 forward refs).
#   2. lib/math.cyr — expects 0 warnings (stdlib should be
#      forward-ref clean).
#   3. lib/string.cyr — expects 0 warnings (regression
#      against false positives).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$ROOT/build/cyrlint"

if [ ! -x "$LINT" ]; then
    echo "  skip: $LINT not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_init_order_$$.cyr"
trap 'rm -f "$SRC"' EXIT

# Test 1: known-bad fixture from mabda's filing.
cat > "$SRC" <<'EOF'
var COMPUTED = FLAG_A | FLAG_B | FLAG_C;

fn dummy() { return 0; }

var FLAG_A = 0x1;
var FLAG_B = 0x2;
var FLAG_C = 0x4;

var SAFE_REF = FLAG_A;

fn main() { return 0; }
var r = main();
syscall(60, r);
EOF
fail=0

# cyrlint returns the warning count as exit code; wrap with set +e
# so non-zero (= warnings present) doesn't abort the gate.
set +e
out=$("$LINT" "$SRC" 2>&1)
warn_count=$(echo "$out" | grep -c "global var init refs")
set -e
if [ "$warn_count" -lt 3 ]; then
    echo "  FAIL: forward-ref fixture produced $warn_count warnings, expected ≥3"
    echo "$out" | head -10
    fail=$((fail + 1))
fi

# Test 2: lib/math.cyr should be 0 forward-ref warnings.
set +e
out=$("$LINT" "$ROOT/lib/math.cyr" 2>&1)
math_warns=$(echo "$out" | grep -c "global var init refs")
set -e
if [ "$math_warns" -ne 0 ]; then
    echo "  FAIL: lib/math.cyr produced $math_warns false-positive forward-ref warnings"
    echo "$out" | grep "global var init refs"
    fail=$((fail + 1))
fi

# Test 3: lib/string.cyr should be 0 forward-ref warnings.
set +e
out=$("$LINT" "$ROOT/lib/string.cyr" 2>&1)
str_warns=$(echo "$out" | grep -c "global var init refs")
set -e
if [ "$str_warns" -ne 0 ]; then
    echo "  FAIL: lib/string.cyr produced $str_warns false-positive forward-ref warnings"
    echo "$out" | grep "global var init refs"
    fail=$((fail + 1))
fi

# Test 4 (v5.7.36): string-literal awareness. A var init expression
# whose RHS contains an IDENT-shaped substring inside a "..."
# string literal must NOT trigger a forward-ref warning, even if
# that bareword is also a forward-declared var. Pre-v5.7.36 the
# scanner walked every byte and matched IDENTs by name regardless
# of quote-context.
SRC2="$TMPDIR/cyrius_init_order_strlit_$$.cyr"
trap 'rm -f "$SRC" "$SRC2"' EXIT
cat > "$SRC2" <<'EOF'
var MSG = "FLAG_LATER not yet defined here";
var CHR = 'X';

fn dummy() { return 0; }

var FLAG_LATER = 0x1;

fn main() { return 0; }
var r = main();
syscall(60, r);
EOF
set +e
out=$("$LINT" "$SRC2" 2>&1)
strlit_warns=$(echo "$out" | grep -c "global var init refs")
set -e
if [ "$strlit_warns" -ne 0 ]; then
    echo "  FAIL: string-literal fixture produced $strlit_warns false-positive forward-ref warnings (v5.7.36 string-lit awareness)"
    echo "$out" | grep "global var init refs"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrlint flags forward-ref var inits ($warn_count on fixture; 0 false-positives on stdlib + string-literal scope; v5.7.32 + v5.7.36)"
    exit 0
fi
exit 1
