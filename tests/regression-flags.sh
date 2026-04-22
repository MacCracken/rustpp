#!/bin/sh
# Regression: lib/flags.cyr getopt-long CLI flag parser (v5.5.33).
#
# Covers:
#   - bool flags (long + short)
#   - int flags (`--name=value` and `--name value`)
#   - str flags (`-x value`)
#   - defaults when flag absent
#   - positional capture (argv order preserved)
#   - `--` terminator routes remaining args to positional
#   - error paths: unknown flag, missing value, bad int, bundled short
#   - realistic mixed cyrfmt-shaped invocation
#
# Direct build/cc5 compile — bypasses the cyrius-test dep-ordering
# harness issue (tracked from v5.5.26 CHANGELOG).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/flags.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/flags"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: flags.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity|undefined function 'vec_get'" "$TMP/compile.err" | head -5
    exit 1
fi

out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: flags getopt-long parser ($passed assertions)"
    exit 0
else
    echo "  FAIL: flags"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
