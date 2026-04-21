#!/bin/sh
# Regression: lib/fdlopen.cyr primitives (v5.5.28).
#
# Covers the pieces of foreign-dlopen that land in v5.5.28:
#   - setjmp/longjmp round-trip (x86_64 Linux)
#   - helper-path resolution ($HOME via /proc/self/environ)
#   - fdlopen_helper_available probe
#   - fdlopen_init/fdlopen_status/fdlopen_slot API shape
#   - state buffer layout matches C helper's expected offsets
#
# The full ld.so-entry orchestration is scoped to land with the first
# consumer — until then, fdlopen_init returns FDL_ERR_UNINIT (-8) or
# FDL_ERR_HELPER_MISSING (-1), both of which the test treats as the
# expected v5.5.28 outcome.
#
# Direct build/cc5 compile — bypasses the cyrius-test dep-ordering
# harness issue (tracked from v5.5.26 CHANGELOG).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/fdlopen.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/fdlopen"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: fdlopen.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity|undefined function 'vec_get'" "$TMP/compile.err" | head -5
    exit 1
fi

out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: fdlopen primitives ($passed assertions)"
    exit 0
else
    echo "  FAIL: fdlopen"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
