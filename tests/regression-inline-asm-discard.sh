#!/bin/sh
# Regression: narrowed repro for v5.4.15's "include-boundary inline-asm"
# bug (pinned to v5.5.19 investigation).
#
# The v5.5.19 investigation narrowed the bug: it is NOT an include-
# boundary issue per se. The actual trigger is a shape-sensitive
# codegen defect that combines:
#   - a large (~120-byte) asm block in a callee fn
#   - the caller passes stack-array pointers (`var ct[16]` etc.)
#   - the caller follows the callee call with a standalone fn call
#     whose return is discarded (`sys_write(1, &ct, 16);` with no
#     `var _ = ...` wrapper)
#   - and specifically, the presence/absence of preceding globals
#     in the translation unit shifts whether the bug fires
#
# The bug manifests as the following `sys_write` writing 0 bytes
# (or some other value less than `count`), not the correct count.
# Capturing the return into a var (`var n = sys_write(...)`) doesn't
# dodge the bug by itself — presence of globals in the included file
# does. This is the shape sigil's AES-NI 2.9.0 path originally
# tripped on; sigil's workaround is to use the "with globals" shape.
#
# Tests below assert the KNOWN-WORKING shape (global var present in
# the included file). Pin a stronger assertion here once v5.5.20+
# fixes the root cause.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not present"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Shared asm-block fn. Mirrors sigil's aes256_encrypt_block_ni shape:
# 3 pointer params, 120-byte asm body with movdqu+pxor+13 AESENCs+AESENCLAST.
# The asm runs whether or not AES-NI is available — invalid memory
# won't be dereferenced because the caller supplies valid in-bounds
# pointers (`var rk[240]` global-backed array).
cat > "$TMP/common.cyr" <<'EOF'
# v5.5.19 regression: global var before the fn is LOAD-BEARING for
# the codegen path today. Removing it flips the following sys_write
# to write 0 bytes instead of 16. Do NOT delete this var without
# verifying v5.5.20+ fixes the underlying bug.
var _v5519_regression_global = 0;

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

# Test A: known-working shape. Global var in included file present,
# standalone sys_write after the asm call. Writes 16 bytes today.
cat > "$TMP/ta.cyr" <<EOF
include "lib/syscalls.cyr"
include "$TMP/common.cyr"

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

cat "$TMP/ta.cyr" | "$CC" > "$TMP/ta" 2>/dev/null
chmod +x "$TMP/ta"
ta_bytes=$("$TMP/ta" | wc -c)

fail=0
if [ "$ta_bytes" -ne 16 ]; then
    echo "  FAIL: workaround shape (global var + assigned sys_write) wrote $ta_bytes bytes (expected 16)"
    echo "        sigil's AES-NI 2.9.1 depends on this shape working."
    fail=$((fail+1))
fi

exit $fail
