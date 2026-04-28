#!/bin/sh
# Regression: cx codegen propagates literal arguments through the
# syscall arg path.
#
# Pinned to v5.7.23 — closes the literal-arg-propagation issue
# pinned in v5.7.12's regression-cx-roundtrip.sh "What this gate
# does NOT check" note.
#
# Root cause (single-byte typo): src/backend/cx/emit.cyr's
# TOKVAL helper read tokens from S + 0x94A000 + i*8 instead of
# S + 0xB4A000 + i*8 (the actual lex.cyr write site at line 99).
# The 0x94A000 region is a zero-initialized gap between
# tok_types (0x74A000) and tok_values (0xB4A000), so PEEKV
# always returned 0. Pre-v5.7.23 bytecode for `syscall(60, 42);`:
#
#     01 00 00 00     MOVI r0, 0   ← should be 60
#     80 00 00 00     PUSHR r0
#     01 00 00 00     MOVI r0, 0   ← should be 42
#     80 00 00 00     PUSHR r0
#     ...
#
# Plus a spurious "syscall arity mismatch" warning, because
# sc_num got read as 0 (= SYS_READ, arity 3) rather than 60.
#
# This gate locks the literal-propagation contract: bytecode
# emitted for `syscall(60, 42);` MUST contain MOVI r0, 60
# (`01 00 3c 00`) and MOVI r0, 42 (`01 00 2a 00`) in the
# expected pre-syscall sequence; cxvm executes the program
# and exits with code 42; no "arity mismatch" warning.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
CC_CX="$TMPDIR/cyrius_cc5_cx_v5723_$$"
CXVM="$TMPDIR/cyrius_cxvm_v5723_$$"
OUT="$TMPDIR/cyrius_cx_lit_$$"
ERR="$TMPDIR/cyrius_cx_lit_err_$$"
trap 'rm -f "$CC_CX" "$CXVM" "$OUT" "$ERR"' EXIT

"$CC" < "$ROOT/src/main_cx.cyr" > "$CC_CX" 2>/dev/null
chmod +x "$CC_CX"
"$CC" < "$ROOT/programs/cxvm.cyr" > "$CXVM" 2>/dev/null
chmod +x "$CXVM"

fail=0

# Test 1: literal 60 + 42 reach the bytecode.
#
# v5.7.29: `set +e` / `set -e` wrapper. cc5_cx may return any
# exit 0-127 (e.g. 1 if a future input regresses to a parse
# error); the outer `set -e` would otherwise abort the gate
# before the bytecode-content checks below could run, masking
# any real regression as a "gate aborted" exit-1.
set +e
echo 'syscall(60, 42);' | "$CC_CX" > "$OUT" 2>"$ERR"
set -e

# Look for `01 00 3c 00` (MOVI r0, 60).
if ! xxd "$OUT" | grep -q "0100 3c00"; then
    echo "  FAIL: bytecode missing MOVI r0, 60 (01 00 3c 00) — literal not propagating"
    xxd "$OUT" | head -5
    fail=$((fail + 1))
fi

# Look for `01 00 2a 00` (MOVI r0, 42).
if ! xxd "$OUT" | grep -q "0100 2a00"; then
    echo "  FAIL: bytecode missing MOVI r0, 42 (01 00 2a 00) — literal not propagating"
    xxd "$OUT" | head -5
    fail=$((fail + 1))
fi

# Test 2: no spurious arity-mismatch warning. Pre-v5.7.23 sc_num
# was read as 0 (SYS_READ, arity 3) rather than 60 (SYS_EXIT,
# arity 1) → got=1 != expected=3 → warning fired.
if grep -q "syscall arity mismatch" "$ERR"; then
    echo "  FAIL: spurious 'syscall arity mismatch' warning (sc_num was misread)"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# Test 3: cxvm executes the bytecode and exits with the literal
# value passed to syscall(60, X).
set +e
"$CXVM" < "$OUT" > /dev/null 2>"$ERR"
EXIT=$?
set -e
if [ "$EXIT" -ne 42 ]; then
    echo "  FAIL: cxvm exit was $EXIT (expected 42 — the literal user-supplied to syscall(60, X))"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# Test 4: small-literal coverage — multiple distinct values must
# round-trip independently. Catches a hypothetical regression
# where TOKVAL reads a constant (e.g. always 0).
for V in 0 7 99 200; do
    set +e
    echo "syscall(60, $V);" | "$CC_CX" > "$OUT" 2>/dev/null
    "$CXVM" < "$OUT" > /dev/null 2>/dev/null
    EXIT=$?
    set -e
    if [ "$EXIT" -ne "$V" ]; then
        echo "  FAIL: cxvm exit was $EXIT for syscall(60, $V) (expected $V)"
        fail=$((fail + 1))
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cx codegen propagates syscall literal args; cxvm exits with the user-supplied code"
    exit 0
fi
exit 1
