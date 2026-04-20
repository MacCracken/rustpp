#!/bin/sh
# Regression: cc5 `object;` mode emits `_cyrius_init` with STB_GLOBAL.
#
# Background: v3.4.14 made `_cyrius_init` GLOBAL so external linkers
# (the system `ld` invoked by C-launcher builds) can resolve it.
# v4.6.0-alpha2 silently flipped it back to STB_LOCAL on the theory
# that multiple cyrius .o files would collide at standard-`ld` time.
# That broke every downstream linking a cyrius .o into a non-cyrld
# binary — mabda's GPU integration filed the regression
# (mabda/docs/issues/2026-04-19-phase0-build-broken.md, Issue 1).
# v5.4.9 reverts to STB_GLOBAL; cyrld merges per-module and never
# collides on the symbol name (programs/cyrld.cyr ~700 / ~1093),
# so multi-module cyrld builds keep working
# (tests/regression-linker.sh exercises that path).
#
# This test compiles a one-line `object;` program, reads the symbol
# table, and asserts the binding is GLOBAL. Wired into
# scripts/check.sh so the next silent flip can't ship.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if ! command -v readelf >/dev/null 2>&1; then
    echo "  skip: readelf not installed"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/m.cyr" <<'EOF'
object;
fn x() { return 0; }
EOF

cat "$TMP/m.cyr" | "$CC" > "$TMP/m.o" 2>/dev/null

# readelf -s output column layout (GNU binutils):
#    Num:  Value  Size  Type  Bind  Vis  Ndx  Name
# We grep for the symbol and read column 5 (Bind).
bind=$(readelf -s "$TMP/m.o" | awk '$NF == "_cyrius_init" { print $5; exit }')

if [ -z "$bind" ]; then
    echo "  FAIL: _cyrius_init missing from .o symbol table"
    readelf -s "$TMP/m.o" | head -20
    exit 1
fi

if [ "$bind" != "GLOBAL" ]; then
    echo "  FAIL: _cyrius_init bind=$bind (expected GLOBAL — see v5.4.9 regression)"
    exit 1
fi

exit 0
