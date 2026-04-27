#!/bin/sh
# Regression: struct cap raised 64 → 256 (v5.7.17). Pre-v5.7.17, three
# auto-prepended dep dist bundles (libro 29 + agnostik 9 + agnosys 10 +
# consumer ≈ 75+ structs) overflowed the 64-struct ceiling — kybernet
# hit it 2026-04-27 and got a misleading error blaming the first
# user-code struct line. Cap is now 256 and the overflow diagnostic
# dumps every registered struct name to stderr so the user sees
# WHICH deps filled the table.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
if [ ! -x "$CC" ]; then echo "  skip: $CC not built"; exit 0; fi

TMPDIR="${TMPDIR:-/tmp}"
SCRATCH="$TMPDIR/cyrius_struct_cap_$$"
trap 'rm -rf "$SCRATCH"' EXIT
mkdir -p "$SCRATCH"

fail=0

# ── Case 1: 80 structs (pre-v5.7.17 would fail at #65; now passes) ──
{
    n=0
    while [ $n -lt 80 ]; do
        echo "struct S$n { x; }"
        n=$((n + 1))
    done
    echo "syscall(60, 0);"
} > "$SCRATCH/case1.cyr"
if "$CC" < "$SCRATCH/case1.cyr" > "$SCRATCH/case1.out" 2> "$SCRATCH/case1.err"; then
    chmod +x "$SCRATCH/case1.out"
    if ! "$SCRATCH/case1.out"; then
        echo "  FAIL: case1 — 80-struct binary did not exit 0"
        fail=$((fail + 1))
    fi
else
    echo "  FAIL: case1 — 80-struct compile failed (cap regressed below 80)"
    cat "$SCRATCH/case1.err"
    fail=$((fail + 1))
fi

# ── Case 2: 200 structs (kybernet-class multi-dep workload; passes) ──
{
    n=0
    while [ $n -lt 200 ]; do
        echo "struct S$n { x; }"
        n=$((n + 1))
    done
    echo "syscall(60, 0);"
} > "$SCRATCH/case2.cyr"
if ! "$CC" < "$SCRATCH/case2.cyr" > "$SCRATCH/case2.out" 2> "$SCRATCH/case2.err"; then
    echo "  FAIL: case2 — 200-struct compile failed (cap regressed below 200)"
    cat "$SCRATCH/case2.err"
    fail=$((fail + 1))
fi

# ── Case 3: 257 structs (overflow — must abort with the v5.7.17 diagnostic) ──
{
    n=0
    while [ $n -lt 257 ]; do
        echo "struct S$n { x; }"
        n=$((n + 1))
    done
    echo "syscall(60, 0);"
} > "$SCRATCH/case3.cyr"
if "$CC" < "$SCRATCH/case3.cyr" > "$SCRATCH/case3.out" 2> "$SCRATCH/case3.err"; then
    echo "  FAIL: case3 — 257-struct compile unexpectedly succeeded (cap > 256?)"
    fail=$((fail + 1))
else
    # The diagnostic must (a) include the new "structs registered" note,
    # (b) list at least the first and last registered names with their
    # indices, and (c) include the cap-overflow error line.
    if ! grep -q '^note: 256 structs registered' "$SCRATCH/case3.err"; then
        echo "  FAIL: case3 — overflow note missing 'note: 256 structs registered' header"
        cat "$SCRATCH/case3.err"
        fail=$((fail + 1))
    fi
    if ! grep -q '^  #0 S0$' "$SCRATCH/case3.err"; then
        echo "  FAIL: case3 — name-dump missing '#0 S0' (first registered struct)"
        fail=$((fail + 1))
    fi
    if ! grep -q '^  #255 S255$' "$SCRATCH/case3.err"; then
        echo "  FAIL: case3 — name-dump missing '#255 S255' (last registered struct)"
        fail=$((fail + 1))
    fi
    if ! grep -q 'too many struct definitions (max 256)' "$SCRATCH/case3.err"; then
        echo "  FAIL: case3 — final error line not updated to 'max 256'"
        fail=$((fail + 1))
    fi
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: struct cap 64→256 + diagnostic dump (3/3 cases)"
    exit 0
fi
exit 1
