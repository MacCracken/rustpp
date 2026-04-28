#!/bin/sh
# Regression: aarch64 f64_exp / f64_ln polyfill correctness.
#
# Pinned to v5.7.31 — closes the phylax-blocker. Pre-v5.7.31 the
# parser hard-rejected f64_exp / f64_ln on aarch64 (x87-only path
# with `aarch64 has no native exp — needs polyfill` ERR_MSG).
# v5.7.31 dispatches both keywords to stdlib polyfills in
# `lib/math.cyr`:
#
#   _f64_exp_polyfill(x): n*ln(2) + r range reduction;
#                          11-term Taylor at |r| ≤ ln(2)/2;
#                          2^n via bit pattern.
#   _f64_ln_polyfill(x):  mantissa/exponent split; u = (m-1)/(m+1)
#                          remap to |u| ≤ ~0.171; 8-term inverse-
#                          tanh series.
#
# Both target ~few-ulp accuracy, sufficient for phylax-class
# statistical work (chi-squared p-values, entropy). Higher
# accuracy via Remez optimization is a future polish slot.
#
# This gate cross-builds a smoke test against bit-exact reference
# values, runs on the configured SSH target (default `pi`).
# Tolerances are 1024-4096 ulp (~1e-12 to ~1e-11 relative error).

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
SRC="$TMPDIR/cyrius_polyfill_aa_$$.cyr"
BIN="$TMPDIR/cyrius_polyfill_aa_$$"
trap 'rm -f "$SRC" "$BIN"' EXIT

cat > "$SRC" <<'EOF'
include "lib/math.cyr"
include "lib/syscalls.cyr"

fn main() {
    # exp(0) == 1.0 exactly (polynomial(0) = 1, 2^0 = 1).
    if (f64_exp(0) != 0x3FF0000000000000) { return 1; }

    # exp(1.0) ≈ e ≈ 2.718281828. F64_E = 0x4005BF0A8B145769.
    var e1 = f64_exp(0x3FF0000000000000);
    var d_e1 = e1 - 0x4005BF0A8B145769;
    if (d_e1 < 0) { d_e1 = 0 - d_e1; }
    if (d_e1 > 1024) { return 2; }

    # ln(1.0) == 0 (m=1 → u=0 → polynomial gives exactly 0).
    var l1 = f64_ln(0x3FF0000000000000);
    var d_l1 = l1;
    if (d_l1 < 0) { d_l1 = 0 - d_l1; }
    if (d_l1 > 1024) { return 3; }

    # ln(e) ≈ 1.0.
    var l_e = f64_ln(0x4005BF0A8B145769);
    var d_le = l_e - 0x3FF0000000000000;
    if (d_le < 0) { d_le = 0 - d_le; }
    if (d_le > 1024) { return 4; }

    # exp(ln(2)) ≈ 2.0 — round-trip through both polyfills.
    var two = 0x4000000000000000;
    var rt = f64_exp(f64_ln(two));
    var d_rt = rt - two;
    if (d_rt < 0) { d_rt = 0 - d_rt; }
    if (d_rt > 4096) { return 5; }

    # exp(-1) ≈ 1/e ≈ 0.367879441. Bits: 0x3FD78B56362CEF38.
    var e_neg1 = f64_exp(f64_neg(0x3FF0000000000000));
    var d_neg = e_neg1 - 0x3FD78B56362CEF38;
    if (d_neg < 0) { d_neg = 0 - d_neg; }
    if (d_neg > 1024) { return 6; }

    return 99;
}

var r = main();
syscall(SYS_EXIT, r);
EOF

if ! "$CC_AA" < "$SRC" > "$BIN" 2>/dev/null; then
    echo "  FAIL: aarch64 cross-build of polyfill smoke test failed"
    exit 1
fi

SSH_BIN="/tmp/cyrius_polyfill_aa_smoke_$$"
if ! scp -q "$BIN" "$SSH_TARGET:$SSH_BIN" 2>/dev/null; then
    echo "  FAIL: scp to $SSH_TARGET failed"
    exit 1
fi

set +e
EXIT=$(ssh "$SSH_TARGET" "chmod +x $SSH_BIN && $SSH_BIN; echo \$?; rm -f $SSH_BIN" 2>/dev/null | tail -1)
set -e

if [ "$EXIT" = "99" ]; then
    echo "  PASS: aarch64 f64_exp / f64_ln polyfills bit-accurate within ulp budget on $SSH_TARGET (v5.7.31)"
    exit 0
fi

case "$EXIT" in
    1) msg="f64_exp(0) != 1.0 exactly" ;;
    2) msg="f64_exp(1) deviates >1024 ulp from e" ;;
    3) msg="f64_ln(1) deviates >1024 ulp from 0" ;;
    4) msg="f64_ln(e) deviates >1024 ulp from 1.0" ;;
    5) msg="exp(ln(2)) deviates >4096 ulp from 2.0 (round-trip)" ;;
    6) msg="f64_exp(-1) deviates >1024 ulp from 1/e" ;;
    *) msg="unknown failure code $EXIT" ;;
esac
echo "  FAIL: $msg (exit=$EXIT)"
exit 1
