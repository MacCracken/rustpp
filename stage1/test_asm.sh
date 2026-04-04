#!/bin/sh
# asm.cyr test suite
# Usage: sh test_asm.sh [path-to-asm]
#
# Tests the self-hosting assembler by assembling stage1 files
# and comparing output byte-for-byte with the seed assembler.
# Also tests example programs.

ASM="${1:-./build/asm}"
SEED_ASM="./bootstrap/asm"
pass=0
fail=0

if [ ! -x "$ASM" ]; then
    echo "ERROR: assembler not found at $ASM"
    echo "Run: sh bootstrap/bootstrap.sh"
    exit 1
fi

run_byte_exact() {
    name="$1"; src="$2"
    cat "$src" | "$SEED_ASM" > /tmp/cyr_seed_$$ 2>/dev/null
    cat "$src" | "$ASM" > /tmp/cyr_asm_$$ 2>/dev/null
    if cmp -s /tmp/cyr_seed_$$ /tmp/cyr_asm_$$; then
        echo "  PASS: $name ($(wc -c < /tmp/cyr_asm_$$) bytes, byte-exact)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (bytes differ from seed)"
        fail=$((fail + 1))
    fi
    rm -f /tmp/cyr_seed_$$ /tmp/cyr_asm_$$
}

run_example() {
    name="$1"; src="$2"; expected="$3"
    cat "$src" | "$ASM" > /tmp/cyr_ex_$$ 2>/dev/null
    chmod +x /tmp/cyr_ex_$$ 2>/dev/null
    /tmp/cyr_ex_$$ 2>/dev/null
    got=$?
    rm -f /tmp/cyr_ex_$$
    if [ "$got" -eq "$expected" ]; then
        echo "  PASS: $name (exit=$got)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected=$expected, got=$got)"
        fail=$((fail + 1))
    fi
}

echo "asm.cyr Test Suite"
echo "=================="
echo ""

echo "-- Example Programs --"
run_example "exit42"    "stage1/examples/exit42.cyr"    42
run_example "mem"       "stage1/examples/mem.cyr"       42
run_example "mem_rsp"   "stage1/examples/mem_rsp.cyr"   42
run_example "mem_disp"  "stage1/examples/mem_disp.cyr"  42
echo ""

echo "-- Byte-Exact: Stage Compilers --"
run_byte_exact "stage1a" "stage1/stage1a.cyr"
run_byte_exact "stage1b" "stage1/stage1b.cyr"
run_byte_exact "stage1c" "stage1/stage1c.cyr"
run_byte_exact "stage1d" "stage1/stage1d.cyr"
run_byte_exact "stage1e" "stage1/stage1e.cyr"
run_byte_exact "stage1f" "stage1/stage1f.cyr"
echo ""

echo "-- Bootstrap Closure --"
echo -n "  "
cat stage1/stage1f.cyr | "$ASM" > /tmp/cyr_sf_$$ 2>/dev/null
cat stage1/stage1f.cyr | "$SEED_ASM" > /tmp/cyr_seed_sf_$$ 2>/dev/null
if cmp -s /tmp/cyr_sf_$$ /tmp/cyr_seed_sf_$$; then
    echo "PASS: asm assembles stage1f byte-identical to seed"
    pass=$((pass + 1))
else
    echo "FAIL: bootstrap closure broken"
    fail=$((fail + 1))
fi
rm -f /tmp/cyr_sf_$$ /tmp/cyr_seed_sf_$$

echo ""
echo "=================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
