#!/bin/sh
# Stage 1e test suite
# Usage: sh test_stage1e.sh [path-to-stage1e]
#
# Tests all stage1e features: backward compat + bitwise ops,
# shifts, modulo, hex literals, comments, uppercase idents.

STAGE1E="${1:-./stage1/stage1e}"
TMPBIN="/tmp/cyr_stage1e_test_$$"
pass=0
fail=0

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1E" > "$TMPBIN" 2>/dev/null
    chmod +x "$TMPBIN" 2>/dev/null
    "$TMPBIN" 2>/dev/null
    got=$?
    rm -f "$TMPBIN"
    if [ "$got" -eq "$expected" ]; then
        echo "  PASS: $name (exit=$got)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected=$expected, got=$got)"
        fail=$((fail + 1))
    fi
}

run_test_stdout() {
    name="$1"; src="$2"; expected_stdout="$3"; expected_exit="$4"
    echo "$src" | "$STAGE1E" > "$TMPBIN" 2>/dev/null
    chmod +x "$TMPBIN" 2>/dev/null
    got_stdout=$("$TMPBIN" 2>/dev/null)
    got_exit=$?
    rm -f "$TMPBIN"
    if [ "$got_stdout" = "$expected_stdout" ] && [ "$got_exit" -eq "$expected_exit" ]; then
        echo "  PASS: $name (stdout='$got_stdout', exit=$got_exit)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected stdout='$expected_stdout' exit=$expected_exit, got stdout='$got_stdout' exit=$got_exit)"
        fail=$((fail + 1))
    fi
}

run_test_pipe() {
    name="$1"; src="$2"; input="$3"; expected_stdout="$4"; expected_exit="$5"
    echo "$src" | "$STAGE1E" > "$TMPBIN" 2>/dev/null
    chmod +x "$TMPBIN" 2>/dev/null
    got_stdout=$(echo -n "$input" | "$TMPBIN" 2>/dev/null)
    got_exit=$?
    rm -f "$TMPBIN"
    if [ "$got_stdout" = "$expected_stdout" ] && [ "$got_exit" -eq "$expected_exit" ]; then
        echo "  PASS: $name"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected stdout='$expected_stdout' exit=$expected_exit, got stdout='$got_stdout' exit=$got_exit)"
        fail=$((fail + 1))
    fi
}

echo "Stage 1e Test Suite"
echo "==================="
echo ""

echo "-- Backward Compat (stage1d features) --"
run_test "literal"      "var x = 42;"                              42
run_test "arithmetic"   "var x = 2 + 3 * 4;"                      14
run_test "neg_divide"   "var x = 0 - 10; var y = x / 3;"          253
run_test "multi_var"    "var a = 10; var b = a + 32;"              42
run_test "if_else"      "var x = 1; if (x == 2) { x = 10; } else { x = 42; }" 42
run_test "while_loop"   "var x = 0; while (x < 10) { x = x + 1; }" 10
run_test "factorial_g"  "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }" 120
run_test_stdout "hello" 'syscall(1, 1, "hello\n", 6); var x = 0;' "hello" 0
run_test "store_load"   "var x = 0; store8(&x, 42); var y = load8(&x);" 42
run_test "array"        "var buf[8]; store8(&buf, 99); var y = load8(&buf);" 99
run_test_pipe "echo"    'var buf[256]; var n = syscall(0, 0, &buf, 256); syscall(1, 1, &buf, n); var x = 0;' "test" "test" 0
run_test "fn_noargs"    "fn f() { return 42; } var x = f();"       42
run_test "fn_2param"    "fn add(a, b) { return a + b; } var x = add(20, 22);" 42
run_test "fn_forward"   "fn f(x) { return g(x + 1); } fn g(x) { return x * 2; } var r = f(20);" 42
run_test "fn_while"     "fn fact(n) { var f = 1; while (n > 1) { f = f * n; n = n - 1; } return f; } var x = fact(5);" 120
run_test "fn_6param"    "fn f(a, b, c, d, e, g) { return a + b + c + d + e + g; } var x = f(1, 2, 3, 4, 5, 27);" 42
echo ""

echo "-- Modulo --"
run_test "mod_basic"    "var x = 17 % 5;"                          2
run_test "mod_exact"    "var x = 15 % 5;"                          0
run_test "mod_ident"    "var x = 42 % 100;"                        42
run_test "mod_chain"    "var x = 100 % 7;"                         2
run_test "mod_expr"     "var x = (25 + 17) % 10;"                  2
echo ""

echo "-- Bitwise AND --"
run_test "band_basic"   "var x = 255 & 15;"                        15
run_test "band_mask"    "var x = 0 - 1 & 255;"                     255
run_test "band_zero"    "var x = 42 & 0;"                          0
run_test "band_ident"   "var x = 42 & 255;"                        42
echo ""

echo "-- Bitwise OR --"
run_test "bor_basic"    "var x = 32 | 10;"                         42
run_test "bor_flags"    "var x = 1 | 2 | 4 | 8;"                  15
run_test "bor_zero"     "var x = 42 | 0;"                          42
echo ""

echo "-- Bitwise XOR --"
run_test "bxor_basic"   "var x = 255 ^ 213;"                       42
run_test "bxor_self"    "var x = 42 ^ 42;"                         0
run_test "bxor_zero"    "var x = 42 ^ 0;"                          42
echo ""

echo "-- Bitwise NOT --"
run_test "bnot_zero"    "var x = ~0 & 255;"                        255
run_test "bnot_ff"      "var x = ~255 & 255;"                      0
run_test "bnot_expr"    "var x = ~213 & 255;"                      42
echo ""

echo "-- Left Shift --"
run_test "shl_basic"    "var x = 1 << 5;"                          32
run_test "shl_mul"      "var x = 21 << 1;"                         42
run_test "shl_zero"     "var x = 42 << 0;"                         42
run_test "shl_chain"    "var x = 1 << 3 << 1;"                     16
echo ""

echo "-- Right Shift --"
run_test "shr_basic"    "var x = 128 >> 2;"                        32
run_test "shr_half"     "var x = 84 >> 1;"                         42
run_test "shr_zero"     "var x = 42 >> 0;"                         42
run_test "shr_byte"     "var x = 0 - 256 & 65535; var y = x >> 8;" 255
echo ""

echo "-- Hex Literals --"
run_test "hex_basic"    "var x = 0x2A;"                             42
run_test "hex_ff"       "var x = 0xFF;"                             255
run_test "hex_upper"    "var x = 0x2a;"                             42
run_test "hex_zero"     "var x = 0x00;"                             0
run_test "hex_mask"     "var x = 0xDEAD & 0xFF;"                   173
run_test "hex_in_expr"  "var x = 0x20 | 0x0A;"                     42
echo ""

echo "-- Comments --"
run_test "comment_eol"  'var x = 42; # this is a comment'          42
run_test "comment_mid"  'var a = 10; # first
var b = a + 32;'                                                    42
run_test "comment_only" '# just a comment
var x = 42;'                                                        42
echo ""

echo "-- Uppercase Identifiers --"
run_test "upper_var"    "var REX = 72; var x = REX;"                72
run_test "mixed_fn"     "fn ModRM(a, b) { return a << 6 | b; } var x = ModRM(0, 42);" 42
run_test "underscore"   "var my_var = 42;"                          42
echo ""

echo "-- Operator Precedence --"
run_test "shift_add"    "var x = 3 << 2 + 1;"                      13
run_test "and_or"       "var x = 15 & 6 | 40;"                     46
run_test "mod_add"      "var x = 10 % 3 + 41;"                     42
run_test "parens_bw"    "var x = (0xFF & 42) | (1 << 6);"          106
echo ""

echo "-- Combined (self-hosting patterns) --"
run_test "rex_byte"     "fn rex(w, r, b) { return 0x40 | w << 3 | r << 2 | b; } var x = rex(1, 0, 0);" 72
run_test "modrm"        "fn modrm(m, reg, rm) { return m << 6 | reg << 3 | rm; } var x = modrm(3, 0, 0);" 192
run_test "extract_byte" "var val = 0x1234; var lo = val & 0xFF; var hi = val >> 8 & 0xFF;" 18
run_test "bit_test"     "var flags = 0xFF; var x = flags & (1 << 3);" 8
run_test "align8"       "var x = 13 + 7 & (0 - 8);"               16
echo ""

echo "==================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
