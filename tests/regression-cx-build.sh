#!/bin/sh
# Regression: main_cx.cyr (cyrius-x bytecode entry) builds cleanly
# AND cc5_cx does not SIGSEGV at startup on empty/trivial input.
#
# Pinned to v5.7.11 — the smaller-slot bar.
#
# History: pre-v5.7.11 main_cx.cyr accumulated 4 silent drift
# breakages over the v5.6.x optimization arc + v5.7.x reshuffle:
#   1. `include "src/common/ir.cyr"` was added to main.cyr at
#      v5.6.12 (O3a IR instrumentation) but never to main_cx.cyr;
#      parse_expr.cyr references IR_RAW_EMIT.
#   2. `var _AARCH64_BACKEND = 0` defined in x86 + aarch64 emit
#      but never in cx emit; parse.cyr references it.
#   3. `var _TARGET_MACHO = 0` + `var _TARGET_PE = 0` same shape.
#   4. `var _flags_reflect_rax = 0` + 4 peephole-tracker globals.
#   Plus: brk extension at +0x54A000 (5.5 MB) was undersized
#   long before v5.7.10 — never reached the tok_types region at
#   S+0x74A000. The v5.7.10 heap reshuffle made the boundary
#   bite immediately on any non-empty input.
#
# Each surfaced one at a time as we plowed through; each fix
# revealed the next missing piece. Drift accumulated because no
# CI gate ever built main_cx.cyr — this is that gate.
#
# **What this gate does NOT verify** (cascaded to v5.7.12):
# bytecode SEMANTIC correctness. cc5_cx today produces a CYX
# header + valid CYX opcodes interleaved with raw x86 instruction
# bytes (parser-to-emit interface assumes x86 emits in shared
# codepaths). Fixing that is the v5.7.12 slot — a real
# parser-to-emit re-architecture.
#
# This gate closes the SMALLEST drift surface: builds clean,
# starts clean. If cc5_cx ever regresses past either bar, this
# gate fails LOUDLY rather than letting the drift sit for another
# 6 minors.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
CC_CX="$TMPDIR/cyrius_cc5_cx_$$"
trap 'rm -f "$CC_CX" "$CC_CX.err"' EXIT

# Step 1: build main_cx.cyr through cc5. Must exit 0; size must
# be non-zero (a 0-byte output means cc5 errored mid-emit and
# wrote nothing).
if ! "$CC" < "$ROOT/src/main_cx.cyr" > "$CC_CX" 2>"$CC_CX.err"; then
    echo "  FAIL: cc5 < src/main_cx.cyr exited non-zero"
    head -10 "$CC_CX.err"
    exit 1
fi
SIZE=$(wc -c < "$CC_CX")
if [ "$SIZE" -lt 100000 ]; then
    echo "  FAIL: cc5_cx output is $SIZE B (suspiciously small; expected > 100 KB)"
    exit 1
fi
chmod +x "$CC_CX"

# Step 2: cc5_cx must not SIGSEGV on empty input. Pre-v5.7.11
# crashed at S+0x74A000 the moment LEX was called because brk
# was 5.5 MB and tok_types lives at 7.5 MB into the heap.
echo '' | "$CC_CX" > /dev/null 2>"$CC_CX.err"
EXIT=$?
# SIGSEGV under sh shows up as 139 (128 + 11). Anything ≥ 128
# means the child died on a signal — a regression from where
# v5.7.11 closed.
if [ "$EXIT" -ge 128 ]; then
    echo "  FAIL: cc5_cx died on signal $((EXIT - 128)) on empty input (regression past v5.7.11 startup-clean bar)"
    head -10 "$CC_CX.err"
    exit 1
fi

# Step 3: trivial non-empty input — same bar, extra coverage.
echo 'syscall(60, 0);' | "$CC_CX" > /dev/null 2>"$CC_CX.err"
EXIT=$?
if [ "$EXIT" -ge 128 ]; then
    echo "  FAIL: cc5_cx died on signal $((EXIT - 128)) on trivial input"
    head -10 "$CC_CX.err"
    exit 1
fi

echo "  PASS: cc5 builds main_cx.cyr ($SIZE B); cc5_cx starts clean on empty + trivial input"
exit 0
