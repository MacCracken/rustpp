#!/bin/sh
# Regression: lib/thread_local.cyr per-thread slot storage (v5.5.30).
#
# Covers TLS via %fs (x86_64) / TPIDR_EL0 (aarch64):
#   - main-thread init + round-trip across 16 slots
#   - slot independence (write to N doesn't affect M)
#   - four worker threads each isolated in slot 0 via CLONE_SETTLS
#   - main's slot 0 untouched after workers write/join
#
# Direct build/cc5 compile — bypasses the cyrius-test dep-ordering
# harness issue (tracked from v5.5.26 CHANGELOG).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/thread_local.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/thread_local"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: thread_local.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity|undefined function 'vec_get'" "$TMP/compile.err" | head -5
    exit 1
fi

out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: thread_local slot storage ($passed assertions)"
    exit 0
else
    echo "  FAIL: thread_local"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
