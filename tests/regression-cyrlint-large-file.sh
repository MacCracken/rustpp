#!/bin/sh
# Regression: cyrlint large-file false-positive.
#
# Filed 2026-04-28 by mabda v3 Step 3d/3e at
# `mabda/docs/development/issues/2026-04-28-cyrlint-multi-line-
# assert.md`. Originally diagnosed as a multi-line assert_eq()
# parser bug (Step 3d); re-bisected during Step 3e and the real
# trigger is FILE-SIZE THRESHOLD. Once `tests/tcyr/mabda.tcyr`
# grew past ~3270 lines, cyrlint started emitting false-positive
# warnings:
#
#   warn line N: trailing whitespace
#   warn line N+1: unclosed braces at end of file
#
# Brace counts audit balanced; whitespace inspection clean;
# `cyrius test` passes every assertion. The "unclosed braces"
# text is misleading — the actual heuristic was file-length-
# related.
#
# v5.8.41 verification slot
# =========================
#
# Premise check at slot entry (2026-05-03 across 4 synthetic
# repros) found the bug NOT REPRODUCING at v5.8.40:
#
#   - 3500-line synthetic (`var x_N = N;` x 3500) -> 0 warnings
#   - mabda's actual mabda.tcyr (2743 lines) -> 0 warnings
#   - Doubled mabda content (5486 lines) -> 0 warnings
#   - Aggressive 9007-line synthetic (600 fns + multi-line
#     assert_eq() + comments) -> 0 warnings
#
# Likely already fixed by intermediate cyrlint refactor /
# brace-tracker / string-literal-awareness work between v5.7.23
# (filing) and v5.8.40 (premise check). Mabda's issue file was
# never updated post-resolution.
#
# v5.8.41 ships as a verification slot:
#   - This regression-floor gate locks the FIXED state into CI.
#   - mabda issue file annotated as RESOLVED in v5.8.41.
#   - If mabda still hits a new variant, file a NEW issue with
#     full repro + repo location (per user direction at slot
#     entry).
#
# This gate
# =========
#
# Generates a 3500-line synthetic file matching mabda's repro
# shape (multi-line assert_eq calls, var declarations, fn
# bodies, brace blocks, comments) and runs cyrlint. Asserts
# zero "unclosed braces at end of file" warnings - the specific
# false-positive class. Other warnings (line-too-long etc.)
# are tolerated since the synthetic doesn't promise to be
# style-clean - only brace-balance-clean.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$ROOT/build/cyrlint"

if [ ! -x "$LINT" ]; then
    echo "  skip: $LINT not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_cyrlint_large_$$.cyr"
trap 'rm -f "$SRC"' EXIT

# Generate ~3500 lines: 700 fns each with a 5-line body
# (test_group + multi-line assert_eq + close brace). Mirrors
# mabda's mabda.tcyr shape past the 3270 trip threshold.
{
    echo '# v5.8.41 regression floor - cyrlint large-file false-positive.'
    echo '# Filed at mabda/docs/development/issues/2026-04-28-cyrlint-multi-line-assert.md'
    echo ''
    echo 'include "lib/syscalls.cyr"'
    echo 'include "lib/alloc.cyr"'
    echo 'include "lib/assert.cyr"'
    echo ''
    echo 'alloc_init();'
    echo ''
    i=0
    while [ "$i" -lt 700 ]; do
        cat <<EOF
fn _check_$i() {
    test_group("group $i");
    assert_eq(
        $i,
        $i,
        "self equality"
    );
    return 0;
}

EOF
        i=$((i + 1))
    done
    echo 'syscall(60, 0);'
} > "$SRC"

linecount=$(wc -l < "$SRC")
if [ "$linecount" -lt 3270 ]; then
    echo "  FAIL: synthetic file only $linecount lines, need >= 3270 to trigger the (alleged) historic bug"
    exit 1
fi

set +e
out=$("$LINT" "$SRC" 2>&1)
unclosed_braces=$(echo "$out" | grep -c "unclosed braces at end of file")
trailing_ws=$(echo "$out" | grep -c "trailing whitespace")
set -e

fail=0
if [ "$unclosed_braces" -ne 0 ]; then
    echo "  FAIL: $linecount-line file produced $unclosed_braces 'unclosed braces' warning(s) - historic bug regression"
    echo "$out" | grep "unclosed braces" | head -3
    fail=$((fail + 1))
fi
# Trailing-whitespace count: the synthetic shouldn't have any
# (heredoc content is stripped at line ends). Any non-zero is
# either a heredoc artifact OR the historic bug's other
# false-positive class.
if [ "$trailing_ws" -ne 0 ]; then
    echo "  FAIL: $linecount-line file produced $trailing_ws 'trailing whitespace' warning(s) - likely a v5.8.41-regression of the file-size false-positive"
    echo "$out" | grep "trailing whitespace" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrlint clean on $linecount-line synthetic (mabda 2026-04-28 repro shape; floor for v5.8.41)"
    exit 0
fi
exit 1
