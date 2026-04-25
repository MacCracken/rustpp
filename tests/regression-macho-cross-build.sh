#!/bin/sh
# regression-macho-cross-build.sh — verify cc5_aarch64_macho_cross builds cleanly.
#
# Filed at v5.6.40: main_aarch64_macho.cyr was missing `include
# "src/common/ir.cyr"` since v5.6.12 O3a shipped IR_RAW_EMIT markers in
# parse_*.cyr; the file referenced an undefined symbol and never built
# (silently — it's not a release artifact, only a buildable cross-emitter
# scaffold). v5.6.32 fixed the same shape for main_aarch64_native.cyr;
# v5.6.40 fixed it here. This gate trips if the include drifts again.

set -e
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CC="$ROOT/build/cc5"

[ -x "$CC" ] || { echo "FAIL: $CC missing"; exit 1; }

OUT=$(mktemp)
trap "rm -f $OUT" EXIT

cat "$ROOT/src/main_aarch64_macho.cyr" | "$CC" > "$OUT" 2>/dev/null
ec=$?

if [ "$ec" -ne 0 ]; then
    echo "FAIL: main_aarch64_macho.cyr did not compile (exit $ec)"
    exit 1
fi

SZ=$(wc -c < "$OUT")
if [ "$SZ" -lt 100000 ]; then
    echo "FAIL: cc5_aarch64_macho_cross output too small ($SZ B; expected >100KB)"
    exit 1
fi

# Verify it's an ELF (host x86_64 binary that emits Mach-O — host-side
# the cross-compiler is itself a Linux ELF).
HEAD=$(head -c 4 "$OUT" | od -An -txC | tr -d ' ')
if [ "$HEAD" != "7f454c46" ]; then
    echo "FAIL: output is not ELF (magic: $HEAD)"
    exit 1
fi

echo "PASS: cc5_aarch64_macho_cross built ($SZ B, ELF)"
exit 0
