#!/bin/sh
# Regression: stdlib thread-safety audit validation (v5.5.32).
#
# Covers the canonical "mutex-wrapped container" pattern that
# callers must use when sharing stdlib containers across threads:
#   - hashmap (map_u64_*) under 4 × 100 contention → 400 keys
#   - vec under 4 × 100 contention → 400 distinct values
#   - counter increment smoke (4 × 1000)
#
# v5.5.32 is an audit + validation patch — no lib/ changes.
# Documents findings in CHANGELOG; this test demonstrates the
# safe pattern actually works.
#
# Direct build/cc5 compile — bypasses the cyrius-test dep-ordering
# harness issue (tracked from v5.5.26 CHANGELOG).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/thread_safety.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/thread_safety"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: thread_safety.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity|undefined function 'vec_get'" "$TMP/compile.err" | head -5
    exit 1
fi

out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: mutex-wrapped hashmap + vec + counter ($passed assertions)"
    exit 0
else
    echo "  FAIL: thread_safety"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
