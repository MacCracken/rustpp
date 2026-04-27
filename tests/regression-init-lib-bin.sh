#!/bin/sh
# Regression: cyrius init --lib emits library-shape scaffold (entry =
# programs/smoke.cyr + [lib] modules + header-only src/main.cyr); --bin
# emits the binary scaffold (existing behavior); bare invocation
# defaults to --bin for backward-compat. Pinned to v5.7.15.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/scripts/cyrius-init.sh"
CYRIUS="$ROOT/build/cyrius"
if [ ! -f "$INIT" ]; then echo "  skip: $INIT missing"; exit 0; fi
if [ ! -x "$CYRIUS" ]; then echo "  skip: $CYRIUS not built"; exit 0; fi

TMPDIR="${TMPDIR:-/tmp}"
SCRATCH="$TMPDIR/cyrius_init_lib_bin_$$"
trap 'rm -rf "$SCRATCH"' EXIT

fail=0

# ── Case 1: --lib emits library shape, builds smoke clean ──
SC="$SCRATCH/case1"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --lib mylib > "$SC/init.out" 2>&1 )
if [ ! -f "$SC/mylib/programs/smoke.cyr" ]; then
    echo "  FAIL: case1 — programs/smoke.cyr not emitted"
    cat "$SC/init.out"
    fail=$((fail + 1))
fi
if [ -f "$SC/mylib/src/test.cyr" ]; then
    echo "  FAIL: case1 — src/test.cyr emitted in lib shape (should be omitted)"
    fail=$((fail + 1))
fi
if ! grep -q '\[lib\]' "$SC/mylib/cyrius.cyml"; then
    echo "  FAIL: case1 — [lib] section missing from cyrius.cyml"
    fail=$((fail + 1))
fi
if grep -q '^test ' "$SC/mylib/cyrius.cyml"; then
    echo "  FAIL: case1 — stale 'test = ...' line in lib cyrius.cyml"
    fail=$((fail + 1))
fi
if ! grep -q 'entry = "programs/smoke.cyr"' "$SC/mylib/cyrius.cyml"; then
    echo "  FAIL: case1 — entry not pointed at programs/smoke.cyr"
    fail=$((fail + 1))
fi
( cd "$SC/mylib" && "$CYRIUS" build programs/smoke.cyr build/mylib-smoke > "$SC/build.out" 2>&1 )
if [ "$?" -ne 0 ] || [ ! -x "$SC/mylib/build/mylib-smoke" ]; then
    echo "  FAIL: case1 — smoke build failed"
    cat "$SC/build.out"
    fail=$((fail + 1))
fi
if [ -x "$SC/mylib/build/mylib-smoke" ]; then
    if ! "$SC/mylib/build/mylib-smoke" > "$SC/run.out" 2>&1; then
        echo "  FAIL: case1 — smoke run failed (exit non-zero)"
        cat "$SC/run.out"
        fail=$((fail + 1))
    fi
fi

# ── Case 2: --bin emits binary shape (existing behavior preserved) ──
SC="$SCRATCH/case2"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --bin foo > "$SC/init.out" 2>&1 )
if [ ! -f "$SC/foo/src/main.cyr" ] || [ ! -f "$SC/foo/src/test.cyr" ]; then
    echo "  FAIL: case2 — src/main.cyr or src/test.cyr missing"
    fail=$((fail + 1))
fi
if [ -d "$SC/foo/programs" ]; then
    echo "  FAIL: case2 — programs/ created for bin shape (should not exist)"
    fail=$((fail + 1))
fi
if ! grep -q 'entry = "src/main.cyr"' "$SC/foo/cyrius.cyml"; then
    echo "  FAIL: case2 — entry not pointed at src/main.cyr"
    fail=$((fail + 1))
fi
( cd "$SC/foo" && "$CYRIUS" build src/main.cyr build/foo > "$SC/build.out" 2>&1 )
if [ "$?" -ne 0 ] || [ ! -x "$SC/foo/build/foo" ]; then
    echo "  FAIL: case2 — bin build failed"
    cat "$SC/build.out"
    fail=$((fail + 1))
fi
if [ -x "$SC/foo/build/foo" ]; then
    if ! "$SC/foo/build/foo" > "$SC/run.out" 2>&1; then
        echo "  FAIL: case2 — bin run failed"
        cat "$SC/run.out"
        fail=$((fail + 1))
    fi
fi

# ── Case 3: bare invocation defaults to bin ──
SC="$SCRATCH/case3"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" bareproj > "$SC/init.out" 2>&1 )
if [ -d "$SC/bareproj/programs" ]; then
    echo "  FAIL: case3 — bare init created programs/ (should default to --bin)"
    fail=$((fail + 1))
fi
if ! grep -q 'entry = "src/main.cyr"' "$SC/bareproj/cyrius.cyml"; then
    echo "  FAIL: case3 — bare init not bin-shaped"
    fail=$((fail + 1))
fi

# ── Case 4: --lib CI workflow build cmd targets programs/smoke.cyr ──
SC="$SCRATCH/case4"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --lib libci > "$SC/init.out" 2>&1 )
if grep -q 'cyrius build src/main.cyr' "$SC/libci/.github/workflows/ci.yml"; then
    echo "  FAIL: case4 — ci.yml still hardcodes src/main.cyr build for lib shape"
    fail=$((fail + 1))
fi
if ! grep -q 'cyrius build programs/smoke.cyr build/.* -smoke\|cyrius build programs/smoke.cyr build/' "$SC/libci/.github/workflows/ci.yml"; then
    echo "  FAIL: case4 — ci.yml not updated for lib smoke"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrius init --lib/--bin/bare (4/4 cases)"
    exit 0
fi
exit 1
