#!/bin/sh
# Regression: cyrius deps walks transitive [deps.X] sections, dedupes
# diamonds, and breaks cycles. Pinned to v5.7.14.
#
# Pre-v5.7.14: only the consumer's direct deps were resolved.
# Downstreams had to re-list every transitive in their own manifest.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRIUS="$ROOT/build/cyrius"
if [ ! -x "$CYRIUS" ]; then
    echo "  skip: $CYRIUS not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SCRATCH="$TMPDIR/cyrius_deps_transitive_$$"
trap 'rm -rf "$SCRATCH"' EXIT

fail=0

# ── Case 1: 3-level chain A→B→C ──
SC="$SCRATCH/case1"
mkdir -p "$SC/A" "$SC/B/dist" "$SC/C/dist"
echo '# C' > "$SC/C/dist/C.cyr"
cat > "$SC/C/cyrius.cyml" <<MEOF
[package]
name = "C"
[lib]
modules = ["dist/C.cyr"]
MEOF
echo '# B' > "$SC/B/dist/B.cyr"
cat > "$SC/B/cyrius.cyml" <<MEOF
[package]
name = "B"
[deps.C]
path = "$SC/C"
modules = ["dist/C.cyr"]
MEOF
cat > "$SC/A/cyrius.cyml" <<MEOF
[package]
name = "A"
[deps.B]
path = "$SC/B"
modules = ["dist/B.cyr"]
MEOF
( cd "$SC/A" && "$CYRIUS" deps > "$SC/case1.out" 2>&1 )
if [ -L "$SC/A/lib/B.cyr" ] && [ -L "$SC/A/lib/C.cyr" ]; then
    :
else
    echo "  FAIL: case1 (3-level chain) — B.cyr and/or C.cyr missing in A/lib"
    cat "$SC/case1.out"
    fail=$((fail + 1))
fi

# ── Case 2: diamond A→B→D, A→C→D ──
SC="$SCRATCH/case2"
mkdir -p "$SC/A" "$SC/B/dist" "$SC/C/dist" "$SC/D/dist"
echo '# D' > "$SC/D/dist/D.cyr"
cat > "$SC/D/cyrius.cyml" <<MEOF
[package]
name = "D"
[lib]
modules = ["dist/D.cyr"]
MEOF
echo '# B' > "$SC/B/dist/B.cyr"
cat > "$SC/B/cyrius.cyml" <<MEOF
[package]
name = "B"
[deps.D]
path = "$SC/D"
modules = ["dist/D.cyr"]
MEOF
echo '# C' > "$SC/C/dist/C.cyr"
cat > "$SC/C/cyrius.cyml" <<MEOF
[package]
name = "C"
[deps.D]
path = "$SC/D"
modules = ["dist/D.cyr"]
MEOF
cat > "$SC/A/cyrius.cyml" <<MEOF
[package]
name = "A"
[deps.B]
path = "$SC/B"
modules = ["dist/B.cyr"]
[deps.C]
path = "$SC/C"
modules = ["dist/C.cyr"]
MEOF
( cd "$SC/A" && "$CYRIUS" deps > "$SC/case2.out" 2>&1 )
n=$(grep -c '^' "$SC/case2.out" || true)
# Expect "3 deps resolved" — D appears once despite double declaration.
if grep -q '^3 deps resolved' "$SC/case2.out" && [ -L "$SC/A/lib/D.cyr" ]; then
    :
else
    echo "  FAIL: case2 (diamond) — expected 3 distinct deps, D dedup'd"
    cat "$SC/case2.out"
    fail=$((fail + 1))
fi

# ── Case 3: cycle A→B→A — must terminate, exit 0 ──
SC="$SCRATCH/case3"
mkdir -p "$SC/A/dist" "$SC/B/dist"
echo '# A' > "$SC/A/dist/A.cyr"
echo '# B' > "$SC/B/dist/B.cyr"
cat > "$SC/A/cyrius.cyml" <<MEOF
[package]
name = "A"
[deps.B]
path = "$SC/B"
modules = ["dist/B.cyr"]
MEOF
cat > "$SC/B/cyrius.cyml" <<MEOF
[package]
name = "B"
[deps.A]
path = "$SC/A"
modules = ["dist/A.cyr"]
MEOF
( cd "$SC/A" && timeout 10 "$CYRIUS" deps > "$SC/case3.out" 2>&1 )
ec=$?
if [ "$ec" -ne 0 ]; then
    echo "  FAIL: case3 (cycle) — expected exit 0, got $ec (likely infinite-loop timeout)"
    cat "$SC/case3.out"
    fail=$((fail + 1))
fi

# ── Case 4: transitive `path = "..."` resolved against transitive
#            manifest's own dir, not consumer's cwd. A→B; B has
#            [deps.C] path = "../C" (relative to B's dir). ──
SC="$SCRATCH/case4"
mkdir -p "$SC/A" "$SC/B/dist" "$SC/C/dist"
echo '# C' > "$SC/C/dist/C.cyr"
cat > "$SC/C/cyrius.cyml" <<MEOF
[package]
name = "C"
[lib]
modules = ["dist/C.cyr"]
MEOF
echo '# B' > "$SC/B/dist/B.cyr"
cat > "$SC/B/cyrius.cyml" <<MEOF
[package]
name = "B"
[deps.C]
path = "../C"
modules = ["dist/C.cyr"]
MEOF
cat > "$SC/A/cyrius.cyml" <<MEOF
[package]
name = "A"
[deps.B]
path = "$SC/B"
modules = ["dist/B.cyr"]
MEOF
( cd "$SC/A" && "$CYRIUS" deps > "$SC/case4.out" 2>&1 )
if [ -L "$SC/A/lib/C.cyr" ]; then
    :
else
    echo "  FAIL: case4 (relative-path resolution) — C.cyr missing"
    cat "$SC/case4.out"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrius deps transitive (4/4 cases)"
    exit 0
fi
exit 1
