#!/bin/sh
# Regression: `cyrius fuzz` runs the manifest-deps auto-prepend codepath
# (the same `_auto_deps` gate that `cyrius test` / `cyrius bench` /
# `cyrius build` already used). Pinned to v5.7.21 — pre-v5.7.21 the
# gate skipped fuzz, so fuzz harnesses that referenced any stdlib
# symbol (strlen, alloc, etc.) failed at compile with
# `undefined function 'X'` even when `cyrius.cyml [deps] stdlib = [...]`
# declared the fn. cmd_test / cmd_bench had this from day one — gate
# now has parity.
#
# Cases:
#   1. cyrius.cyml declares stdlib + fuzz/X.fcyr uses strlen → PASS
#      (auto-prepend resolves the include).
#   2. No cyrius.cyml at all + fuzz/X.fcyr uses syscalls only → still
#      runs (no manifest, no auto-prepend, no breakage).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRIUS="$ROOT/build/cyrius"
if [ ! -x "$CYRIUS" ]; then
    echo "  skip: $CYRIUS not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SCRATCH="$TMPDIR/cyrius_fuzz_deps_$$"
trap 'rm -rf "$SCRATCH"' EXIT

fail=0

# ── Case 1: manifest declares stdlib; fcyr uses strlen ──
SC="$SCRATCH/case1"
mkdir -p "$SC/fuzz"
cat > "$SC/cyrius.cyml" <<MEOF
[package]
name = "fz1"
version = "0.1.0"
license = "GPL-3.0-only"
language = "cyrius"

[deps]
stdlib = ["string", "syscalls"]
MEOF
cat > "$SC/fuzz/uses_stdlib.fcyr" <<MEOF
# Uses strlen from lib/string.cyr — auto-prepended via manifest.
fn fuzz_main(data, n) {
    if (n == 0) { return 0; }
    if (strlen("hello") != 5) { return 1; }
    return 0;
}
fn main() {
    if (fuzz_main("dummy", 5) != 0) { syscall(60, 1); }
    syscall(60, 0);
    return 0;
}
var r = main();
syscall(60, r);
MEOF

(cd "$SC" && "$CYRIUS" fuzz > "$SC/case1.out" 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
    echo "  FAIL: case1 — cyrius fuzz exit $ec (auto-prepend not working)"
    cat "$SC/case1.out"
    fail=$((fail + 1))
else
    if ! grep -q '^=== 1 passed, 0 failed ===' "$SC/case1.out"; then
        echo "  FAIL: case1 — fuzz ran but did not summarize 1 passed"
        cat "$SC/case1.out"
        fail=$((fail + 1))
    fi
fi

# ── Case 2: no manifest, fcyr self-contained → still runs cleanly ──
SC="$SCRATCH/case2"
mkdir -p "$SC/fuzz"
cat > "$SC/fuzz/standalone.fcyr" <<MEOF
# No include needed — uses only syscall (compiler builtin).
fn fuzz_main(data, n) {
    if (n == 0) { return 0; }
    return 0;
}
fn main() {
    if (fuzz_main("x", 1) != 0) { syscall(60, 1); }
    syscall(60, 0);
    return 0;
}
var r = main();
syscall(60, r);
MEOF

(cd "$SC" && "$CYRIUS" fuzz > "$SC/case2.out" 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
    echo "  FAIL: case2 — cyrius fuzz exit $ec (no-manifest path broken)"
    cat "$SC/case2.out"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrius fuzz auto-prepend parity (2/2 cases)"
    exit 0
fi
exit 1
