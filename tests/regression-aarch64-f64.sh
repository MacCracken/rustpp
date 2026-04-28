#!/bin/sh
# Regression: aarch64 f64 basic-op correctness.
#
# Pinned to v5.7.30. Pre-v5.7.30 every f64 op on aarch64 was a stub
# (`return 0;` in src/backend/aarch64/emit.cyr) — `f64_add(1.0, 2.0)`
# returned 2.0 (the second arg, because the parser left it in x0
# and EMIT_F64_BINOP emitted nothing), with a stack leak from the
# unpopped first arg. Silent miscompile on every f64 op since
# (probably) v5.4.x when aarch64 cross-build first shipped.
#
# Surfaced via phylax's f64_exp aarch64 cross-build failure (user-
# pin v5.7.29 ship). Premise verification at v5.7.30 start (per
# `feedback_verify_slot_premise_first.md`) found that f64_exp's
# hard-reject was masking a much bigger bug: f64_add/sub/mul/div/
# sqrt/floor/ceil/round/neg + int↔f64 conversions were ALL
# silently broken on aarch64.
#
# v5.7.30 implements single-instruction emits for all basic f64
# ops. Polyfills for f64_exp / f64_ln land at v5.7.31.
#
# This gate cross-builds a comprehensive f64 op smoke test for
# aarch64 and runs it on the configured SSH target (default `pi`).
# Asserts bit-exact expected results for each op against IEEE 754
# constants. Each assertion exits with a unique code (1-11) on
# failure; success exits 99.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_AA="$ROOT/build/cc5_aarch64"
SSH_TARGET="${SSH_TARGET:-pi}"

if [ ! -x "$CC_AA" ]; then
    echo "  skip: $CC_AA not built (cross-compiler required)"
    exit 0
fi

if ! ssh -o ConnectTimeout=2 -o BatchMode=yes "$SSH_TARGET" true 2>/dev/null; then
    echo "  skip: $SSH_TARGET unreachable via ssh"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_f64_aa_$$.cyr"
BIN="$TMPDIR/cyrius_f64_aa_$$"
trap 'rm -f "$SRC" "$BIN"' EXIT

cat > "$SRC" <<'EOF'
include "lib/syscalls.cyr"

fn main() {
    var a = 0x4000000000000000;  # 2.0
    var b = 0x4008000000000000;  # 3.0
    if (f64_add(a, b) != 0x4014000000000000) { return 1; }
    if (f64_sub(b, a) != 0x3FF0000000000000) { return 2; }
    if (f64_mul(a, b) != 0x4018000000000000) { return 3; }
    if (f64_div(b, a) != 0x3FF8000000000000) { return 4; }
    if (f64_neg(a) != 0xC000000000000000) { return 5; }
    if (f64_sqrt(0x4010000000000000) != 0x4000000000000000) { return 6; }
    if (f64_floor(0x4004000000000000) != 0x4000000000000000) { return 7; }
    if (f64_ceil(0x4004000000000000) != 0x4008000000000000) { return 8; }
    if (f64_round(0x4004000000000000) != 0x4000000000000000) { return 9; }
    if (f64_to(f64_from(42)) != 42) { return 10; }
    if (f64_to(f64_from(0 - 7)) != (0 - 7)) { return 11; }
    return 99;
}

var r = main();
syscall(SYS_EXIT, r);
EOF

# Cross-build for aarch64.
if ! "$CC_AA" < "$SRC" > "$BIN" 2>/dev/null; then
    echo "  FAIL: aarch64 cross-build of f64 smoke test failed"
    exit 1
fi

# scp to target + run.
SSH_BIN="/tmp/cyrius_f64_aa_smoke_$$"
if ! scp -q "$BIN" "$SSH_TARGET:$SSH_BIN" 2>/dev/null; then
    echo "  FAIL: scp to $SSH_TARGET failed"
    exit 1
fi

set +e
EXIT=$(ssh "$SSH_TARGET" "chmod +x $SSH_BIN && $SSH_BIN; echo \$?; rm -f $SSH_BIN" 2>/dev/null | tail -1)
set -e

if [ "$EXIT" = "99" ]; then
    echo "  PASS: aarch64 f64 basic ops (add/sub/mul/div/neg/sqrt/floor/ceil/round + int↔f64) bit-exact on $SSH_TARGET (v5.7.30)"
    exit 0
fi

case "$EXIT" in
    1)  msg="f64_add(2.0, 3.0) != 5.0" ;;
    2)  msg="f64_sub(3.0, 2.0) != 1.0" ;;
    3)  msg="f64_mul(2.0, 3.0) != 6.0" ;;
    4)  msg="f64_div(3.0, 2.0) != 1.5" ;;
    5)  msg="f64_neg(2.0) != -2.0" ;;
    6)  msg="f64_sqrt(4.0) != 2.0" ;;
    7)  msg="f64_floor(2.5) != 2.0" ;;
    8)  msg="f64_ceil(2.5) != 3.0" ;;
    9)  msg="f64_round(2.5) != 2.0 (ties-to-even)" ;;
    10) msg="f64_to(f64_from(42)) != 42" ;;
    11) msg="f64_to(f64_from(-7)) != -7" ;;
    *)  msg="unknown failure code $EXIT" ;;
esac
echo "  FAIL: $msg (exit=$EXIT)"
exit 1
