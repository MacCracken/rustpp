#!/bin/sh
# Regression: inline-asm SSE m128 operand alignment fix (v5.5.21).
#
# v5.4.15 filed as "include-boundary inline-asm" bug (sigil 2.9.0
# AES-NI blocker). v5.5.19 investigated: found the real trigger
# was shape-sensitive on whether the callee TU had preceding
# globals — a misleading symptom of the actual root cause. v5.5.21
# identified the root cause: cyrius placed global arrays at
# 8-byte-aligned addresses, but SSE m128 memory operands
# (PXOR xmm,m128 / MOVDQA / AESENC m128 form / etc.) require
# 16-byte alignment. When a program's code size happened to land
# `var rk[240]` on an 8-aligned-not-16-aligned address, any SSE
# m128 operand load faulted with #GP → SIGSEGV. Fixed by
# 16-aligning arrays (size > 8) in `src/backend/x86/fixup.cyr`'s
# prefix-sum pass.
#
# This test asserts BOTH shapes now work end-to-end — the original
# "with leading global" path that sigil 2.9.0 shipped on as a
# workaround, AND the "no leading global" path that previously
# crashed. If cyrius ever regresses the array-alignment fix, this
# test catches it.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not present"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Shared asm-block fn — mirrors sigil's aes256_encrypt_block_ni
# shape. 120-byte body with movdqu+pxor+13 AESENCs+AESENCLAST.
# PXOR xmm,m128 and the AESENC m128 form are the alignment-
# sensitive ops; `var rk[240]` feeds them through rdi.
_write_common () {
    local path="$1"
    local leading_global="$2"
    cat > "$path" <<EOF
$leading_global
fn _big_asm_fn(a, b, c) {
    asm {
        0x48; 0x8B; 0x7D; 0xF8;
        0x48; 0x8B; 0x75; 0xF0;
        0x48; 0x8B; 0x55; 0xE8;
        0xF3; 0x0F; 0x6F; 0x06;
        0x66; 0x0F; 0xEF; 0x07;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x10;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x20;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x30;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x40;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x50;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x60;
        0x66; 0x0F; 0x38; 0xDC; 0x47; 0x70;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0x80; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0x90; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0xA0; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0xB0; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0xC0; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDC; 0x87; 0xD0; 0x00; 0x00; 0x00;
        0x66; 0x0F; 0x38; 0xDD; 0x87; 0xE0; 0x00; 0x00; 0x00;
        0xF3; 0x0F; 0x7F; 0x02;
    }
    return 0;
}
EOF
}

_write_main () {
    local path="$1"
    local common="$2"
    cat > "$path" <<EOF
include "lib/syscalls.cyr"
include "$common"

fn main() {
    var rk[240];
    var pt[16];
    var ct[16];
    var i = 0;
    while (i < 240) { store8(&rk + i, i & 0xFF); i = i + 1; }
    i = 0;
    while (i < 16) { store8(&pt + i, 0xAA); store8(&ct + i, 65 + i); i = i + 1; }
    _big_asm_fn(&rk, &pt, &ct);
    var n = sys_write(1, &ct, 16);
    return n;
}

var r = main();
syscall(SYS_EXIT, r);
EOF
}

fail=0

# Test A: "with leading global" — sigil's 2.9.0 workaround shape.
# Post-v5.5.21 still works.
_write_common "$TMP/common_a.cyr" "var _regression_marker = 0;"
_write_main "$TMP/ta.cyr" "$TMP/common_a.cyr"
cat "$TMP/ta.cyr" | "$CC" > "$TMP/ta" 2>/dev/null
chmod +x "$TMP/ta"
ta_bytes=$("$TMP/ta" | wc -c)
if [ "$ta_bytes" -ne 16 ]; then
    echo "  FAIL: shape A (with leading global) wrote $ta_bytes bytes (expected 16)"
    fail=$((fail+1))
fi

# Test B: "no leading global" — the shape that CRASHED pre-v5.5.21
# with SIGSEGV from PXOR xmm,m128 on a misaligned &rk. Post-v5.5.21
# the 16-alignment fix in fixup.cyr makes this shape work too.
_write_common "$TMP/common_b.cyr" "# no leading global"
_write_main "$TMP/tb.cyr" "$TMP/common_b.cyr"
cat "$TMP/tb.cyr" | "$CC" > "$TMP/tb" 2>/dev/null
chmod +x "$TMP/tb"
tb_bytes=$("$TMP/tb" | wc -c)
if [ "$tb_bytes" -ne 16 ]; then
    echo "  FAIL: shape B (no leading global, previously SIGSEGV) wrote $tb_bytes bytes (expected 16)"
    echo "        v5.5.21 array-alignment fix regressed?"
    fail=$((fail+1))
fi

exit $fail
