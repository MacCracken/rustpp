#!/bin/sh
# v5.7.3 P3.3 regression gate — TS parser .tsx (JSX) acceptance.
#
# Runs cc5 --parse-ts against all .tsx files in the SecureYeoman repo
# (excluding node_modules, dist, build, .next, coverage). Tracks PASS
# count + asserts a minimum acceptance threshold.
#
# v5.7.3 baseline: 427/435 (98%) of SY .tsx files parse cleanly via
# the JSX-aware lex skip introduced in P3.3 — JSX expressions are
# recognized at lex time and emitted as opaque INT placeholders so
# the parser doesn't need to know about JSX shape. A real JSX AST
# is deferred to a later cycle (the SY consumer needs only that the
# files parse without error).
#
# Threshold: 420 — guards against regression while leaving headroom.
# Skipped automatically if SY corpus isn't present locally.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
SY="/home/macro/Repos/secureyeoman"
THRESHOLD=420

if [ ! -x "$CC" ]; then
    echo "skip: $CC not present"
    exit 0
fi
if [ ! -d "$SY" ]; then
    echo "skip: $SY not present (SY .tsx parse-acceptance corpus)"
    exit 0
fi

PASS=0
FAIL=0

files=$(find "$SY" -name "*.tsx" \
    -not -path "*/node_modules/*" -not -path "*/dist/*" \
    -not -path "*/build/*" -not -path "*/.next/*" \
    -not -path "*/coverage/*" 2>/dev/null)

for f in $files; do
    if "$CC" --parse-ts < "$f" >/dev/null 2>&1; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
    fi
done

TOTAL=$((PASS+FAIL))
echo "TS .tsx parser acceptance: $PASS/$TOTAL ($(( PASS*100 / TOTAL ))%)"
if [ "$PASS" -lt "$THRESHOLD" ]; then
    echo "FAIL: pass count $PASS below threshold $THRESHOLD (regression)"
    exit 1
fi
echo "PASS: above threshold $THRESHOLD"
exit 0
