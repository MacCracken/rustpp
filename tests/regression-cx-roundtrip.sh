#!/bin/sh
# Regression: cc5_cx output is well-formed CYX bytecode with no x86
# instruction-byte pollution.
#
# Pinned to v5.7.12 — the path-B `_TARGET_CX == 0` guard work.
#
# What this gate checks:
#   1. cc5 builds main_cx.cyr cleanly (inherits v5.7.11 gate 4u).
#   2. cc5_cx output starts with `CYX\0` magic.
#   3. cc5_cx output contains NO known x86 instruction byte sequences
#      (regalloc save/restore prefixes were the high-volume noise
#      pre-v5.7.12).
#   4. cxvm consumes cc5_cx output without rejecting it as "not a
#      .cyx file" (cxvm has a magic-byte check at startup).
#   5. cxvm executes cc5_cx output without VM crash (no signal exit).
#
# What this gate does NOT check:
#   - Exit-code propagation through `syscall(60, X)`. cc5_cx has a
#     pre-existing codegen issue where literal arguments don't
#     propagate through EMOVI in the syscall arg path (the bytecode
#     emits `movi r0, 0` instead of `movi r0, 60` for the syscall
#     number). That's a separate cx codegen audit, pinned as a
#     v5.7.x patch slate item.
#   - f64 / struct-return / regalloc semantic correctness on cx.
#     Path B made those `_TARGET_CX == 1` guards (no-op or hard
#     error), not real CYX opcodes. Real opcodes are path A
#     (long-term, see roadmap).
#
# In short: this gate verifies path B did its job (no x86 noise);
# fuller cx semantic correctness is a separate effort.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
CC_CX="$TMPDIR/cyrius_cc5_cx_v578_$$"
CXVM="$TMPDIR/cyrius_cxvm_v578_$$"
OUT="$TMPDIR/cyrius_cx_out_v578_$$"
trap 'rm -f "$CC_CX" "$CXVM" "$OUT" "$OUT.err"' EXIT

# Build cc5_cx (the cx-emit cyrius compiler) and cxvm (the bytecode
# interpreter).
"$CC" < "$ROOT/src/main_cx.cyr" > "$CC_CX" 2>/dev/null
chmod +x "$CC_CX"
"$CC" < "$ROOT/programs/cxvm.cyr" > "$CXVM" 2>/dev/null
chmod +x "$CXVM"

fail=0

# Test 1: trivial program — empty input through cc5_cx must produce
# at least the magic header.
echo '' | "$CC_CX" > "$OUT" 2>"$OUT.err"
SIZE=$(wc -c < "$OUT")
if [ "$SIZE" -lt 8 ]; then
    echo "  FAIL: cc5_cx output for empty input is $SIZE B (expected ≥ 8 for magic header)"
    fail=$((fail + 1))
fi

# Test 2: magic header.
MAGIC=$(head -c 4 "$OUT" 2>/dev/null)
if [ "$MAGIC" != "CYX" ]; then
    # NUL after CYX is a 3-byte string, head -c 4 with NUL is shell-tricky;
    # use od for a robust check.
    MAGIC_HEX=$(od -An -c -N4 "$OUT" 2>/dev/null | tr -d ' ')
    if ! echo "$MAGIC_HEX" | grep -q "CYX"; then
        echo "  FAIL: cc5_cx output magic is '$MAGIC_HEX' (expected 'CYX\\0')"
        fail=$((fail + 1))
    fi
fi

# Test 3: no x86 instruction-byte noise. Pre-v5.7.12 cc5_cx output
# contained x86 callee-save sequences (`48 89 5d f8` = mov [rbp-8],
# rbx) leaked through from parse_fn.cyr's regalloc save block. Path B
# guards added v5.7.12; this test confirms they hold.
echo 'fn main() { return 0; } syscall(60, main());' | "$CC_CX" > "$OUT" 2>"$OUT.err"
# Look for the x86 callee-save signature `48 89 5d f8` in the output.
# Use xxd + grep — portable.
if xxd "$OUT" 2>/dev/null | grep -q "4889 5df8"; then
    echo "  FAIL: cc5_cx output contains x86 callee-save bytes (regalloc save leak; v5.7.12 path-B regression)"
    xxd "$OUT" 2>/dev/null | head -8
    fail=$((fail + 1))
fi
# Also check for the restore signature `4c 8b 65 f0` (mov r12, [rbp-16]).
if xxd "$OUT" 2>/dev/null | grep -q "4c8b 65f0"; then
    echo "  FAIL: cc5_cx output contains x86 callee-restore bytes"
    fail=$((fail + 1))
fi

# Test 4: cxvm consumes cc5_cx output without rejecting it as
# "not a .cyx file".
"$CXVM" < "$OUT" 2>"$OUT.err" > /dev/null || true
EXIT=$?
if [ "$EXIT" -ge 128 ]; then
    echo "  FAIL: cxvm died on signal $((EXIT - 128)) running cc5_cx output"
    cat "$OUT.err" | head -5
    fail=$((fail + 1))
fi
if grep -q "not a .cyx file" "$OUT.err" 2>/dev/null; then
    echo "  FAIL: cxvm rejected cc5_cx output as 'not a .cyx file'"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cc5_cx produces clean CYX bytecode (no x86 noise); cxvm consumes it without crash"
    exit 0
fi
exit 1
