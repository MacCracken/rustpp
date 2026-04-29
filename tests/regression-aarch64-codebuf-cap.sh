#!/bin/sh
# Regression: aarch64 EB() codebuf cap matches the v5.7.27 codebuf
# region size (3 MB).
#
# Pre-v5.7.34, src/backend/aarch64/emit.cyr's EB still rejected
# at 524288 bytes even after v5.7.27 grew the heap region to
# 3 MB on x86 — `cyrius build --aarch64` of a phylax-shape
# program tripped `error: codebuf overflow (.../524288)` on the
# aarch64 cross-compiler while the same source built fine on x86.
#
# Source check: `if (cp >= 3145728)` must be present in
# `src/backend/aarch64/emit.cyr`'s EB body, AND `if (cp >= 524288)`
# must NOT be present (canary against accidental revert).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMIT="$ROOT/src/backend/aarch64/emit.cyr"

if [ ! -f "$EMIT" ]; then
    echo "  skip: $EMIT missing"
    exit 0
fi

fail=0

if ! grep -q "if (cp >= 3145728)" "$EMIT"; then
    echo "  FAIL: aarch64 EB codebuf cap < 3 MB — re-grow to match v5.7.27"
    fail=$((fail + 1))
fi

if grep -q "if (cp >= 524288)" "$EMIT"; then
    echo "  FAIL: aarch64 EB still has the 512 KB cap (canary tripped)"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: aarch64 EB codebuf cap matches v5.7.27 region size (3 MB; v5.7.34)"
    exit 0
fi
exit 1
