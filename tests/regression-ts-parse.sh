#!/bin/sh
# v5.7.2 P2.7 regression — TS parser acceptance against SY corpus.
#
# Runs cc5 --parse-ts against all .ts files in the SecureYeoman repo
# (excluding node_modules, dist, build, .next, coverage). Tracks PASS
# count + asserts a minimum acceptance threshold.
#
# v5.7.3 P3.1 baseline: 2019/2053 (98%) of SY .ts files parse cleanly.
# Remaining failures are mostly TS-position edge cases (mapped types,
# `asserts`, complex destructure defaults, etc.) — slated for v5.7.3.
#
# Threshold: 2000 — guards against regression while leaving headroom
# for the remaining iterative fixes.
#
# Skipped automatically if SY corpus isn't present locally.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
SY="/home/macro/Repos/secureyeoman"
THRESHOLD=2030

if [ ! -x "$CC" ]; then
    echo "skip: $CC not present"
    exit 0
fi

if [ ! -d "$SY" ]; then
    echo "skip: $SY not present (SY parse-acceptance corpus)"
    exit 0
fi

PASS=0
FAIL=0

files=$(find "$SY" -name "*.ts" -not -name "*.tsx" \
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
echo "TS parser acceptance: $PASS/$TOTAL ($(( PASS*100 / TOTAL ))%)"
if [ "$PASS" -lt "$THRESHOLD" ]; then
    echo "FAIL: pass count $PASS below threshold $THRESHOLD (regression)"
    exit 1
fi
echo "PASS: above threshold $THRESHOLD"
exit 0
