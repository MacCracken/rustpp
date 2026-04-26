#!/bin/sh
# Regression: cc5 accepts source files between 512 KB and 1 MB.
#
# Pinned to v5.7.10. Pre-v5.7.10 cc5 had a 524288-byte (512 KB)
# input_buf cap; sources at the upper end of the cyrius ecosystem
# (hisab/dist/hisab.cyr at 96% of cap) were censoring upstream to
# stay under. v5.7.10 raised the cap to 1048576 (1 MB) via a
# heap-map reshuffle (95 region addresses shifted +0x100000 to
# clear room for the wider input_buf).
#
# This regression generates a synthetic source file slightly over
# 512 KB but under 1 MB, pipes it to cc5, and verifies the build
# succeeds. Pre-v5.7.10 cc5 would have errored:
#   error: input exceeds 512KB buffer (raise input_buf in src/main.cyr)
# Post-v5.7.10 cc5 accepts it and produces a working binary.
#
# The synthetic source is a stream of `var v_NNN = NNN;` declarations
# followed by a top-level `syscall(60, 0)`. We size for ~700 KB —
# comfortably above the old cap, comfortably below the new cap.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_input_1mb_$$.cyr"
BIN="$TMPDIR/cyrius_input_1mb_bin_$$"
trap 'rm -f "$SRC" "$BIN"' EXIT

# Generate ~700 KB of source. We pad with COMMENT lines (not
# identifier declarations) — pure-identifier padding hits the
# tok_names cap (128 KB) long before the input_buf cap.
# Comments are stripped at lex without consuming tok_names; they
# only consume raw input bytes, which is what we want to exercise.
# 9000 lines × ~78 chars ≈ 700 KB.
{
    awk 'BEGIN { for (i = 0; i < 9000; i++) printf "# pad-line %05d: this is a no-op comment line for input-buffer sizing\n", i }'
    echo 'var pad_done = 1;'
    echo 'syscall(60, 0);'
} > "$SRC"

SRC_SIZE=$(wc -c < "$SRC")
if [ "$SRC_SIZE" -lt 524288 ]; then
    echo "  FAIL: synthetic source $SRC_SIZE B is under the old 512 KB cap; regression doesn't exercise the cap"
    exit 1
fi
if [ "$SRC_SIZE" -gt 1048576 ]; then
    echo "  FAIL: synthetic source $SRC_SIZE B is over the new 1 MB cap; regression should fit"
    exit 1
fi

# Compile + run.
if ! "$CC" < "$SRC" > "$BIN" 2>"$TMPDIR/cyrius_input_1mb_err_$$"; then
    echo "  FAIL: cc5 exited non-zero on a $SRC_SIZE B source"
    cat "$TMPDIR/cyrius_input_1mb_err_$$"
    rm -f "$TMPDIR/cyrius_input_1mb_err_$$"
    exit 1
fi
rm -f "$TMPDIR/cyrius_input_1mb_err_$$"
chmod +x "$BIN"
"$BIN" || { echo "  FAIL: compiled binary exited non-zero"; exit 1; }

echo "  PASS: cc5 compiles + runs a $SRC_SIZE B source (pre-v5.7.10 cap was 524288 B)"
exit 0
