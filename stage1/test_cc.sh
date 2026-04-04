#!/bin/sh
# cc.cyr test suite
# Usage: sh test_cc.sh [path-to-cc] [path-to-stage1f]
#
# Tests cc.cyr for byte-exact match with stage1f on all features,
# plus self-hosting verification.

CC="${1:-./build/cc}"
SF="${2:-./build/stage1f}"
pass=0
fail=0

# Build cc if not present
if [ ! -x "$CC" ]; then
    if [ -x "$SF" ]; then
        cat stage1/cc.cyr | "$SF" > "$CC"
        chmod +x "$CC"
    else
        echo "ERROR: need stage1f to build cc"
        exit 1
    fi
fi

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$SF" > /tmp/cyr_sf_$$ 2>/dev/null
    echo "$src" | "$CC" > /tmp/cyr_cc_$$ 2>/dev/null
    if cmp -s /tmp/cyr_sf_$$ /tmp/cyr_cc_$$; then
        chmod +x /tmp/cyr_cc_$$
        /tmp/cyr_cc_$$ > /dev/null 2>/dev/null
        got=$?
        if [ "$got" -eq "$expected" ]; then
            echo "  PASS: $name (exit=$got, byte-exact)"
            pass=$((pass + 1))
        else
            echo "  FAIL: $name (expected=$expected, got=$got, bytes match)"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $name (bytes differ from stage1f)"
        fail=$((fail + 1))
    fi
    rm -f /tmp/cyr_sf_$$ /tmp/cyr_cc_$$
}

# cc-only test: no stage1f comparison, just run and check exit code
run_test_cc() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$CC" > /tmp/cyr_cc_$$ 2>/dev/null
    chmod +x /tmp/cyr_cc_$$ 2>/dev/null
    /tmp/cyr_cc_$$ > /dev/null 2>/dev/null
    got=$?
    rm -f /tmp/cyr_cc_$$
    if [ "$got" -eq "$expected" ]; then
        echo "  PASS: $name (exit=$got)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected=$expected, got=$got)"
        fail=$((fail + 1))
    fi
}

run_test_stdout() {
    name="$1"; src="$2"; expected_out="$3"; expected_exit="$4"
    echo "$src" | "$SF" > /tmp/cyr_sf_$$ 2>/dev/null
    echo "$src" | "$CC" > /tmp/cyr_cc_$$ 2>/dev/null
    if cmp -s /tmp/cyr_sf_$$ /tmp/cyr_cc_$$; then
        chmod +x /tmp/cyr_cc_$$
        got_out=$(/tmp/cyr_cc_$$ 2>/dev/null)
        got_exit=$?
        if [ "$got_out" = "$expected_out" ] && [ "$got_exit" -eq "$expected_exit" ]; then
            echo "  PASS: $name (byte-exact)"
            pass=$((pass + 1))
        else
            echo "  FAIL: $name (expected '$expected_out' exit=$expected_exit, got '$got_out' exit=$got_exit)"
            fail=$((fail + 1))
        fi
    else
        echo "  FAIL: $name (bytes differ from stage1f)"
        fail=$((fail + 1))
    fi
    rm -f /tmp/cyr_sf_$$ /tmp/cyr_cc_$$
}

echo "cc.cyr Test Suite"
echo "================="
echo ""

echo "-- Literals + Variables --"
run_test "literal"      "var x = 42;"                              42
run_test "multi_var"    "var a = 10; var b = a + 32;"              42
run_test "reassign"     "var x = 1; x = 42;"                      42
run_test "chain"        "var a = 10; var b = a; var c = b + 32;"   42
echo ""

echo "-- Arithmetic + Precedence --"
run_test "add_sub"      "var x = 50 - 8;"                         42
run_test "mul"          "var x = 6 * 7;"                          42
run_test "div"          "var x = 126 / 3;"                        42
run_test "precedence"   "var x = 2 + 3 * 4;"                     14
run_test "parens"       "var x = (5 + 3) * 2;"                   16
run_test "neg_divide"   "var x = 0 - 10; var y = x / 3;"         253
echo ""

echo "-- Modulo + Bitwise + Shifts --"
run_test "modulo"       "var x = 17 % 5;"                         2
run_test "band"         "var x = 255 & 15;"                       15
run_test "bor"          "var x = 32 | 10;"                        42
run_test "bxor"         "var x = 255 ^ 213;"                      42
run_test "bnot"         "var x = ~0 & 255;"                       255
run_test "shl"          "var x = 1 << 5;"                         32
run_test "shr"          "var x = 84 >> 1;"                        42
echo ""

echo "-- Control Flow --"
run_test "if_else"      "var x = 1; if (x == 2) { x = 10; } else { x = 42; }" 42
run_test "while"        "var x = 0; while (x < 10) { x = x + 1; }" 10
run_test "factorial"    "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }" 120
run_test "nested_if"    "var x = 5; if (x > 3) { if (x < 10) { x = 42; } }" 42
echo ""

echo "-- Functions --"
run_test "fn_noargs"    "fn f() { return 42; } var x = f();"       42
run_test "fn_1param"    "fn f(x) { return x + 1; } var x = f(41);" 42
run_test "fn_2param"    "fn add(a, b) { return a + b; } var x = add(20, 22);" 42
run_test "fn_6param"    "fn f(a, b, c, d, e, g) { return a + b + c + d + e + g; } var x = f(1, 2, 3, 4, 5, 27);" 42
run_test "fn_forward"   "fn f(x) { return g(x + 1); } fn g(x) { return x * 2; } var r = f(20);" 42
run_test "fn_local"     "fn f() { var a = 20; var b = 22; return a + b; } var x = f();" 42
run_test "fn_while"     "fn fact(n) { var f = 1; while (n > 1) { f = f * n; n = n - 1; } return f; } var x = fact(5);" 120
run_test "fn_stmt"      "fn greet() { syscall(1, 1, \"hi\", 2); return 0; } greet(); var x = 42;" 42
echo ""

echo "-- Syscall + I/O --"
run_test_stdout "hello" 'syscall(1, 1, "hello\n", 6); var x = 0;' "hello" 0
run_test "store_load"   "var x = 0; store8(&x, 42); var y = load8(&x);" 42
run_test "array"        "var buf[8]; store8(&buf, 99); var y = load8(&buf);" 99
echo ""

echo "-- Hex Literals + Comments --"
run_test "hex"          "var x = 0x2A;"                            42
run_test "hex_mask"     "var x = 0xFF & 42;"                       42
run_test "comment"      '# this is a comment
var x = 42;'                                                       42
echo ""

echo "-- Structs (cc-only) --"
run_test_cc "struct_init"  'struct Point { x; y; } var p = Point { 10, 32 }; var r = p.x + p.y;' 42
run_test_cc "struct_assign" 'struct P { a; b; } var p = P { 0, 0 }; p.a = 42;' 42
run_test_cc "struct_3field" 'struct RGB { r; g; b; } var c = RGB { 10, 20, 12 }; var x = c.r + c.g + c.b;' 42
run_test_cc "struct_fn"    'struct P { x; y; } fn sum(a, b) { return a + b; } var p = P { 20, 22 }; var r = sum(p.x, p.y);' 42
echo ""

echo "-- Multi-Width Load/Store (cc-only) --"
run_test_cc "load64"       'var buf[16]; store64(&buf, 42); var r = load64(&buf);' 42
run_test_cc "load32"       'var buf[16]; store32(&buf, 42); var r = load32(&buf);' 42
run_test_cc "load16"       'var buf[16]; store16(&buf, 42); var r = load16(&buf);' 42
run_test_cc "mix_width"    'var buf[16]; store64(&buf, 0x2A); var r = load8(&buf);' 42
echo ""

echo "-- Include (cc-only) --"
echo "var y = 32;" > /tmp/cyr_inc_$$
run_test_cc "include_basic" "include \"/tmp/cyr_inc_$$\"
var x = 10 + y;" 42
rm -f /tmp/cyr_inc_$$
echo ""

echo "-- Self-Hosting --"
echo -n "  "
cat stage1/cc.cyr | "$CC" > /tmp/cyr_cc2_$$ 2>/dev/null
if cmp -s "$CC" /tmp/cyr_cc2_$$; then
    echo "PASS: cc compiles itself byte-identical"
    pass=$((pass + 1))
else
    # Check cc2==cc3 instead (true self-hosting for extended compiler)
    chmod +x /tmp/cyr_cc2_$$
    cat stage1/cc.cyr | /tmp/cyr_cc2_$$ > /tmp/cyr_cc3_$$ 2>/dev/null
    if cmp -s /tmp/cyr_cc2_$$ /tmp/cyr_cc3_$$; then
        echo "PASS: cc2==cc3 byte-identical (extended self-hosting)"
        pass=$((pass + 1))
    else
        echo "FAIL: cc self-hosting broken"
        fail=$((fail + 1))
    fi
    rm -f /tmp/cyr_cc3_$$
fi
rm -f /tmp/cyr_cc2_$$

echo ""
echo "================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
