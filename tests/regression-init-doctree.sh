#!/bin/sh
# Regression: cyrius init / cyrius port emit the first-party-
# documentation.md doc-tree (adr / architecture / guides / examples /
# development) + a default CLAUDE.md (no inlined state). Pinned
# v5.7.16. Closes the v5.7.14-as-bundle 3-patch split.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$ROOT/scripts/cyrius-init.sh"
PORT="$ROOT/scripts/cyrius-port.sh"
if [ ! -f "$INIT" ]; then echo "  skip: $INIT missing"; exit 0; fi
if [ ! -f "$PORT" ]; then echo "  skip: $PORT missing"; exit 0; fi

TMPDIR="${TMPDIR:-/tmp}"
SCRATCH="$TMPDIR/cyrius_init_doctree_$$"
trap 'rm -rf "$SCRATCH"' EXIT

fail=0

# expect_doctree <case_label> <project_dir>
# Verifies the standard doc-tree files exist with the expected shape.
expect_doctree() {
    label="$1"
    pdir="$2"
    for f in \
        docs/adr/README.md \
        docs/adr/template.md \
        docs/architecture/README.md \
        docs/guides/getting-started.md \
        docs/examples/.gitkeep \
        docs/development/state.md \
        docs/development/roadmap.md \
        CLAUDE.md ; do
        if [ ! -f "$pdir/$f" ]; then
            echo "  FAIL: $label — missing $f"
            fail=$((fail + 1))
        fi
    done
}

# ── Case 1: cyrius init --lib emits full doc-tree ──
SC="$SCRATCH/case1"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --lib mylib > "$SC/init.out" 2>&1 )
expect_doctree "case1 (--lib)" "$SC/mylib"
# ADR template stays generic — must NOT mention a specific project.
if ! grep -q "^# NNNN " "$SC/mylib/docs/adr/template.md"; then
    echo "  FAIL: case1 — ADR template missing the canonical \"# NNNN — Title\" header"
    fail=$((fail + 1))
fi
# CLAUDE.md must NOT inline a version number or test count (volatile state).
if grep -E '^\*\*Version\*\*: \[?[0-9]' "$SC/mylib/CLAUDE.md" > /dev/null 2>&1; then
    echo "  FAIL: case1 — CLAUDE.md inlines a version number (volatile state)"
    fail=$((fail + 1))
fi
# CLAUDE.md must point at docs/development/state.md.
if ! grep -q 'docs/development/state.md' "$SC/mylib/CLAUDE.md"; then
    echo "  FAIL: case1 — CLAUDE.md does not link to docs/development/state.md"
    fail=$((fail + 1))
fi
# CLAUDE.md must reflect lib shape: build hint references programs/smoke.cyr.
if ! grep -q 'cyrius build programs/smoke.cyr' "$SC/mylib/CLAUDE.md"; then
    echo "  FAIL: case1 — lib CLAUDE.md missing programs/smoke.cyr build hint"
    fail=$((fail + 1))
fi

# ── Case 2: cyrius init --bin also gets full doc-tree ──
SC="$SCRATCH/case2"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --bin foo > "$SC/init.out" 2>&1 )
expect_doctree "case2 (--bin)" "$SC/foo"
# CLAUDE.md must reflect bin shape: build hint references src/main.cyr.
if ! grep -q 'cyrius build src/main.cyr' "$SC/foo/CLAUDE.md"; then
    echo "  FAIL: case2 — bin CLAUDE.md missing src/main.cyr build hint"
    fail=$((fail + 1))
fi

# ── Case 3: bare cyrius init defaults to bin + still gets doc-tree ──
SC="$SCRATCH/case3"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" bareproj > "$SC/init.out" 2>&1 )
expect_doctree "case3 (bare)" "$SC/bareproj"

# ── Case 4: cyrius port mirrors the same doc-tree ──
SC="$SCRATCH/case4"
mkdir -p "$SC/portproj/src"
echo 'fn main() {}' > "$SC/portproj/src/main.rs"
cat > "$SC/portproj/Cargo.toml" <<MEOF
[package]
name = "portproj"
version = "0.1.0"
edition = "2021"
MEOF
sh "$PORT" "$SC/portproj" > "$SC/port.out" 2>&1
expect_doctree "case4 (cyrius port)" "$SC/portproj"
# Port CLAUDE.md should mention rust-old/ as the parity oracle.
if ! grep -q 'rust-old' "$SC/portproj/CLAUDE.md"; then
    echo "  FAIL: case4 — port CLAUDE.md missing rust-old/ reference"
    fail=$((fail + 1))
fi

# ── Case 5: state.md scaffolded from cyrius init carries the toolchain pin ──
# Ensures the toolchain version is captured in state.md, not inlined into
# CLAUDE.md — durable-vs-volatile separation.
SC="$SCRATCH/case5"
mkdir -p "$SC"
( cd "$SC" && sh "$INIT" --lib pinproj > "$SC/init.out" 2>&1 )
if ! grep -q 'Cyrius pin' "$SC/pinproj/docs/development/state.md"; then
    echo "  FAIL: case5 — state.md missing 'Cyrius pin' line"
    fail=$((fail + 1))
fi
if grep -q '^- \*\*Cyrius pin\*\*' "$SC/pinproj/CLAUDE.md"; then
    echo "  FAIL: case5 — toolchain pin leaked into CLAUDE.md (should be state.md only)"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cyrius init/port doc-tree (5/5 cases)"
    exit 0
fi
exit 1
