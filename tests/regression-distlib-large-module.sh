#!/bin/sh
# Regression: cyrius distlib per-module read buffer cap.
#
# Pinned to v5.7.36. Mabda surfaced a wall when its dist generation
# truncated mid-module — `cmd_distlib` in `cbt/commands.cyr` was
# reading each module into a 64KB buffer (`alloc(65536)` +
# `file_read_all(..., 65535)`); modules that grew past 64KB lost the
# tail bytes silently. v5.7.36 raises the cap to 256KB.
#
# This gate fences regressions by:
#   1. Synthesising a >64KB module with a SENTINEL line at byte ~70KB
#      (clear of the 64KB cap, well under the new 256KB cap).
#   2. Running `cyrius distlib` against a minimal manifest that
#      points at the synthesised module.
#   3. Asserting the resulting bundle file contains the SENTINEL —
#      proves the read didn't truncate, the bundle includes the
#      tail of every module.
#
# Skips cleanly if `build/cyrius` (the dispatcher) hasn't been
# rebuilt yet — pre-bootstrap CI invocations shouldn't fail this.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRIUS="$ROOT/build/cyrius"

if [ ! -x "$CYRIUS" ]; then
    # Fall back to the PATH-resolved binary so the gate runs against
    # an installed toolchain on a fresh checkout.
    CYRIUS="$(command -v cyrius 2>/dev/null)"
fi
if [ ! -x "$CYRIUS" ]; then
    echo "  skip: cyrius dispatcher not built and not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
mkdir -p src

# Synthesise an ~80KB module. Each `var f_NNNNN = NNNNN;` line is
# ~21 bytes; 4000 lines ≈ 84 KB. SENTINEL is the very last line so
# any truncation at 64KB drops it; clearance under the new 256KB
# cap is comfortable (~3×).
{
    i=0
    while [ "$i" -lt 4000 ]; do
        printf 'var f_%05d = %d;\n' "$i" "$i"
        i=$((i + 1))
    done
    echo 'var DISTLIB_LARGE_MODULE_SENTINEL = 1;'
} > src/big.cyr

# Minimal manifest. [lib].modules drives distlib in the no-profile
# path (cmd_distlib's [build] / [lib] fallback).
cat > cyrius.cyml <<'EOF'
[package]
name = "distlib_capgate"
version = "0.0.1"

[lib]
modules = ["src/big.cyr"]
EOF

# Confirm input is genuinely past the 64KB cap.
input_bytes=$(wc -c < src/big.cyr)
if [ "$input_bytes" -le 65536 ]; then
    echo "  FAIL: fixture only $input_bytes bytes — must exceed 64KB to exercise the cap"
    exit 1
fi

if ! "$CYRIUS" distlib > distlib.out 2>&1; then
    echo "  FAIL: cyrius distlib exited non-zero"
    cat distlib.out | head -20
    exit 1
fi

if [ ! -f dist/distlib_capgate.cyr ]; then
    echo "  FAIL: dist/distlib_capgate.cyr not produced"
    cat distlib.out | head -20
    exit 1
fi

if ! grep -q "DISTLIB_LARGE_MODULE_SENTINEL" dist/distlib_capgate.cyr; then
    echo "  FAIL: bundle truncated — sentinel missing from dist/distlib_capgate.cyr"
    echo "  input bytes: $input_bytes"
    echo "  bundle bytes: $(wc -c < dist/distlib_capgate.cyr)"
    exit 1
fi

echo "  PASS: cyrius distlib bundles a >64KB module without truncation ($input_bytes-byte input; v5.7.36)"
exit 0
