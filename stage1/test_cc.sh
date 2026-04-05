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
run_test_cc "array"     "var buf[8]; store8(&buf, 99); var y = load8(&buf);" 99
echo ""

echo "-- Hex Literals + Comments --"
run_test "hex"          "var x = 0x2A;"                            42
run_test "hex_mask"     "var x = 0xFF & 42;"                       42
run_test "comment"      '# this is a comment
var x = 42;'                                                       42
echo ""

echo "-- >6 Params (cc-only) --"
run_test_cc "7param"    'fn f(a, b, c, d, e, g, h) { return a + b + c + d + e + g + h; } var x = f(1, 2, 3, 4, 5, 6, 21);' 42
run_test_cc "8param"    'fn f(a, b, c, d, e, g, h, i) { return a + b + c + d + e + g + h + i; } var x = f(1, 2, 3, 4, 5, 6, 7, 14);' 42
run_test_cc "9param"    'fn f(a, b, c, d, e, g, h, i, j) { return a + b + c + d + e + g + h + i + j; } var x = f(1, 2, 3, 4, 5, 6, 7, 8, 6);' 42
echo ""

echo "-- Pointers (cc-only) --"
run_test_cc "deref"      'var x = 42; var p = &x; var r = *p;' 42
run_test_cc "ptr_store"  'var x = 0; var p = &x; *p = 42; var r = x;' 42
run_test_cc "ptr_arith"  'var buf[16]; store64(&buf, 10); store64(&buf + 8, 32); var r = *(&buf) + *(&buf + 8);' 42
run_test_cc "typed_ptr"  'var buf[64]; store64(&buf, 10); store64(&buf + 8, 32); var p: *i64 = &buf; var r = *p + *(p + 1);' 42
run_test_cc "ptr_i32"    'var buf[16]; store32(&buf, 42); var p: *i32 = &buf; var r = load32(p + 0);' 42
run_test_cc "ptr_walk"   'var buf[64]; store64(&buf, 1); store64(&buf + 8, 2); store64(&buf + 16, 3); var p: *i64 = &buf; var s = *p + *(p + 1) + *(p + 2); var r = s;' 6
echo ""

echo "-- Structs (cc-only) --"
run_test_cc "struct_init"  'struct Point { x; y; } var p = Point { 10, 32 }; var r = p.x + p.y;' 42
run_test_cc "struct_assign" 'struct P { a; b; } var p = P { 0, 0 }; p.a = 42;' 42
run_test_cc "struct_3field" 'struct RGB { r; g; b; } var c = RGB { 10, 20, 12 }; var x = c.r + c.g + c.b;' 42
run_test_cc "struct_fn"    'struct P { x; y; } fn sum(a, b) { return a + b; } var p = P { 20, 22 }; var r = sum(p.x, p.y);' 42
run_test_cc "nested_struct" 'struct Inner { a; b; } struct Outer { x; inner: Inner; y; } var o = Outer { 1, 20, 22, 99 }; var r = o.inner.a + o.inner.b;' 42
run_test_cc "nested_write" 'struct V { x; y; } struct R { tl: V; br: V; } var r = R { 0, 0, 0, 0 }; r.br.x = 42; var x = r.br.x;' 42
run_test_cc "nested_rect"  'struct V { x; y; } struct R { tl: V; br: V; } var r = R { 0, 0, 10, 5 }; var w = r.br.x - r.tl.x; var h = r.br.y - r.tl.y;' 5
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

echo "-- Break/Continue (cc-only) --"
run_test_cc "break"     'var x: i64 = 0; while (x < 100) { if (x == 42) { break; } x = x + 1; }' 42
run_test_cc "continue"  'var s: i64 = 0; var i: i64 = 0; while (i < 10) { i = i + 1; if (i % 2 == 0) { continue; } s = s + i; } var r = s;' 25
echo ""

echo "-- Elif (cc-only) --"
run_test_cc "elif_match" 'var x = 3; if (x == 1) { x = 10; } elif (x == 2) { x = 20; } elif (x == 3) { x = 42; } else { x = 99; }' 42
run_test_cc "elif_else"  'var x = 5; if (x == 1) { x = 10; } elif (x == 2) { x = 20; } else { x = 42; }' 42
run_test_cc "elif_first" 'var x = 1; if (x == 1) { x = 42; } elif (x == 2) { x = 20; }' 42
echo ""

echo "-- Enums (cc-only) --"
run_test_cc "enum_basic"  'enum C { R; G; B; } syscall(60, B);' 2
run_test_cc "enum_value"  'enum E { OK = 0; ERR = 42; } syscall(60, ERR);' 42
run_test_cc "enum_switch" 'enum Op { ADD; SUB; MUL; } fn calc(op, a, b) { switch (op) { case 0: return a + b; case 2: return a * b; default: return 0; } return 0; } syscall(60, calc(MUL, 6, 7));' 42
echo ""
echo "-- Function Pointers (cc-only) --"
run_test_cc "fnptr_addr"  'fn f() { return 42; } var fp = &f; syscall(60, 1);' 1
run_test_cc "fnptr_call"  'fn add(a,b) { return a + b; } fn call2(fp,a,b) { var r = 0; asm { 0x48; 0x8B; 0x75; 0xE8; 0x48; 0x8B; 0x7D; 0xF0; 0x48; 0x8B; 0x45; 0xF8; 0xFF; 0xD0; 0x48; 0x89; 0x45; 0xE0; } return r; } syscall(60, call2(&add, 20, 22));' 42
echo ""
echo "-- Switch (cc-only) --"
run_test_cc "switch_fn"   'fn f(n) { switch (n) { case 1: return 10; case 2: return 20; default: return 99; } return 0; } syscall(60, f(2));' 20
run_test_cc "switch_def"  'fn f(n) { switch (n) { case 1: return 10; default: return 42; } return 0; } syscall(60, f(5));' 42
run_test_cc "switch_lit"  'switch (3) { case 3: syscall(60, 42); } syscall(60, 0);' 42
echo ""
echo "-- For Loops (cc-only) --"
run_test_cc "for_sum"     'var s = 0; for (var i = 1; i <= 10; i = i + 1) { s = s + i; } var r = s;' 55
run_test_cc "for_fn"      'fn fact(n) { var r = 1; for (var i = 2; i <= n; i = i + 1) { r = r * i; } return r; } var x = fact(5);' 120
run_test_cc "for_break"   'var r = 0; for (var i = 0; i < 10; i = i + 1) { if (i == 5) { break; } r = r + 1; }' 5
run_test_cc "for_nested"  'var s = 0; for (var i = 0; i < 3; i = i + 1) { for (var j = 0; j < 3; j = j + 1) { s = s + 1; } } var r = s;' 9
run_test_cc "for_pow2"    'var s = 1; for (var i = 0; i < 5; i = i + 1) { s = s * 2; } var r = s;' 32
echo ""

echo "-- Logical && / || (cc-only) --"
run_test_cc "and_true"    'var x = 1; var y = 2; var r = 0; if (x == 1 && y == 2) { r = 42; }' 42
run_test_cc "and_false1"  'var x = 0; var y = 2; var r = 0; if (x == 1 && y == 2) { r = 99; }' 0
run_test_cc "and_false2"  'var x = 1; var y = 3; var r = 0; if (x == 1 && y == 2) { r = 99; }' 0
run_test_cc "or_true1"    'var x = 1; var y = 0; var r = 0; if (x == 1 || y == 1) { r = 42; }' 42
run_test_cc "or_true2"    'var x = 0; var y = 1; var r = 0; if (x == 1 || y == 1) { r = 42; }' 42
run_test_cc "or_false"    'var x = 0; var y = 0; var r = 0; if (x == 1 || y == 1) { r = 99; }' 0
run_test_cc "and_while"   'var x = 0; var y = 10; while (x < 5 && y > 0) { x = x + 1; y = y - 1; } var r = x;' 5
run_test_cc "and_else"    'var x = 0; var y = 0; var r = 0; if (x == 1 && y == 1) { r = 10; } else { r = 42; }' 42
echo ""

echo "-- Type Annotations (cc-only) --"
run_test_cc "typed_var"  'var x: i64 = 42;' 42
run_test_cc "typed_fn"   'fn add(a: i64, b: i64) { return a + b; } var x = add(20, 22);' 42
run_test_cc "typed_mixed" 'var x: i64 = 10; var y = 32; var r = x + y;' 42
echo ""

echo "-- Global Initializers (cc-only) --"
run_test_cc "gvar_before_fn" 'fn f() { return g; } var g = 42; syscall(60, f());' 42
run_test_cc "gvar_mixed"     'var a = 10; fn f() { return a + b; } var b = 32; syscall(60, f());' 42
echo ""

echo "-- Nested Structs Extra (cc-only) --"
run_test_cc "nested_init"   'struct V { x; y; } struct R { a: V; b: V; } var r = R { 1, 2, 3, 4 }; syscall(60, r.b.x);' 3
echo ""

echo "-- Typed Pointer Scaling (cc-only) --"
run_test_cc "ptr_scale_i64" 'var buf[64]; store64(&buf, 10); store64(&buf + 8, 20); store64(&buf + 16, 30); var p: *i64 = &buf; syscall(60, *(p + 2));' 30
echo ""

echo "-- String Null Term (cc-only) --"
run_test_cc "str_null"      'fn sl(s) { var n: i64 = 0; while (load8(s + n) != 0) { n = n + 1; } return n; } var a = sl("abc"); var b = sl("xyz"); syscall(60, a * 10 + b);' 33
echo ""

echo "-- Type Warnings (cc-only) --"
run_test_cc "type_warn_ok" 'fn f() { var buf[16]; var p: *i64 = &buf; return 42; } syscall(60, f());' 42
echo ""
echo "-- Error Messages (cc-only) --"
# Test that errors include token position
err_out=$(echo 'var x = ;' | "$CC" 2>&1 > /dev/null)
if echo "$err_out" | grep -q "error at token"; then
    echo "  PASS: error_position (reports token index)"
    pass=$((pass + 1))
else
    echo "  FAIL: error_position (expected 'error at token', got: $err_out)"
    fail=$((fail + 1))
fi
# Test that error includes token type
if echo "$err_out" | grep -q "type="; then
    echo "  PASS: error_type (reports token type)"
    pass=$((pass + 1))
else
    echo "  FAIL: error_type (expected 'type=', got: $err_out)"
    fail=$((fail + 1))
fi
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
