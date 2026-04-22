#!/bin/sh
# Regression: lib/atomic.cyr primitives + mutex race-free (v5.5.31).
#
# Covers:
#   - atomic_load / atomic_store round-trip
#   - atomic_cas success + failure paths
#   - atomic_fetch_add returns OLD; ptr advances by delta (incl.
#     negative deltas via two's-complement)
#   - atomic_fence smoke
#   - 4-thread contention (fetch_add × 10000, CAS-spin × 4000) —
#     proves x86 `lock xadd` / `lock cmpxchg` serialize correctly
#   - mutex regression — 4 × 1000 mutex-guarded increments; any
#     lost update means the v5.5.31 atomic_cas fast-path broke
#
# Direct build/cc5 compile — bypasses the cyrius-test dep-ordering
# harness issue (tracked from v5.5.26 CHANGELOG).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/atomics.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/atomics"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: atomics.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity|undefined function 'vec_get'" "$TMP/compile.err" | head -5
    exit 1
fi

out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: atomic primitives + mutex race-free ($passed assertions)"
    exit 0
else
    echo "  FAIL: atomics"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
