#!/bin/sh
# Regression: `cyrius smoke` discovers and runs *.smcyr harnesses.
#
# Pinned at v5.7.38 along with the .scyr (soak) + .smcyr (smoke)
# discovery shapes added to `cmd_soak` / `cmd_smoke` in
# `cbt/commands.cyr`. Mirrors the *.tcyr / *.bcyr / *.fcyr discovery
# pattern. This gate covers:
#   1. `cyrius smoke` finds tests/smcyr/*.smcyr files
#   2. PASSing smoke harnesses report PASS and the verb exits 0
#   3. FAILing harnesses cause the verb to exit non-zero AND bail
#      after the first failure (smoke = fail-fast by design)
#   4. Empty directory or missing dir → exit 0 with a friendly message
#      ("did this start at all?" → no harness == no answer == not an
#      error)
#
# The .scyr walker in cmd_soak shares the discovery-loop shape; we
# don't gate it directly because the surrounding built-in self-host
# loop is too slow for check.sh. Manual verification at slot ship
# plus tests/scyr/alloc_pressure.scyr as a working example covers it.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRIUS="$ROOT/build/cyrius"

if [ ! -x "$CYRIUS" ]; then
    CYRIUS="$(command -v cyrius 2>/dev/null)"
fi
if [ ! -x "$CYRIUS" ]; then
    echo "  skip: cyrius dispatcher not built and not on PATH"
    exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ── Test 1: smoke discovery on the cyrius repo's own tests/smcyr/ ──
# tests/smcyr/compile_minimal.smcyr is the example harness shipped at
# v5.7.38. We invoke from a sub-dir then walk back to repo root for
# the actual run, so the output reflects discovery against the live
# checkout.
cd "$ROOT"
out=$("$CYRIUS" smoke 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
    echo "  FAIL test1: 'cyrius smoke' on the live repo exited $ec (expected 0)"
    echo "$out" | tail -10
    exit 1
fi
if ! echo "$out" | grep -q "compile_minimal.smcyr"; then
    echo "  FAIL test1: 'cyrius smoke' did not list compile_minimal.smcyr"
    echo "$out" | tail -10
    exit 1
fi

# ── Test 2: empty directory → friendly skip + exit 0 ──
EMPTY=$(mktemp -d)
cd "$EMPTY"
set +e
out=$("$CYRIUS" smoke 2>&1)
ec=$?
set -e
rm -rf "$EMPTY"
cd "$ROOT"
if [ "$ec" -ne 0 ]; then
    echo "  FAIL test2: empty-dir smoke run exited $ec (expected 0)"
    echo "$out"
    exit 1
fi
if ! echo "$out" | grep -q "No smoke harnesses found"; then
    echo "  FAIL test2: empty-dir run missing 'No smoke harnesses found' message"
    echo "$out"
    exit 1
fi

# ── Test 3: failing harness → exit non-zero + "smoke aborted" ──
# Build a synthetic project with one harness that exits 1. Verify the
# verb propagates non-zero AND prints the fail-fast bail message.
# (Dir-traversal order isn't guaranteed alphabetical — `dir_list`
# walks getdents which returns inode order on most filesystems — so
# we can't reliably assert "second harness was skipped" in a unit
# test. Manual end-to-end verification with two harnesses confirmed
# the bail-on-first-fail behaviour at slot ship.)
mkdir -p "$WORK/tests/smcyr"
cat > "$WORK/cyrius.cyml" <<'EOF'
[package]
name = "smoke_failfast_gate"
version = "0.0.1"

[build]
src = "src/main.cyr"
output = "build/main"
EOF
cat > "$WORK/tests/smcyr/fails.smcyr" <<'EOF'
include "lib/syscalls.cyr"
syscall(60, 1);
EOF

cd "$WORK"
set +e
out=$("$CYRIUS" smoke 2>&1)
ec=$?
set -e
cd "$ROOT"

if [ "$ec" -eq 0 ]; then
    echo "  FAIL test3: failing harness should exit non-zero, got $ec"
    echo "$out"
    exit 1
fi
if ! echo "$out" | grep -q "fails.smcyr"; then
    echo "  FAIL test3: output didn't mention fails.smcyr"
    echo "$out"
    exit 1
fi
if ! echo "$out" | grep -q "smoke aborted"; then
    echo "  FAIL test3: missing 'smoke aborted' message"
    echo "$out"
    exit 1
fi

echo "  PASS: cyrius smoke discovers .smcyr, exits 0 on pass, bails on first fail (v5.7.38)"
exit 0
