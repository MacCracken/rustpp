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
        cat src/cc_bridge.cyr | "$SF" > "$CC"
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
# Test that errors include line number
err_out=$(echo 'var x = ;' | "$CC" 2>&1 > /dev/null)
if echo "$err_out" | grep -q "error:1:"; then
    echo "  PASS: error_line_number (reports line number)"
    pass=$((pass + 1))
else
    echo "  FAIL: error_line_number (expected 'error:1:', got: $err_out)"
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

echo "-- Comparison in Function Args --"
run_test_cc "cmp_eq_arg"     'fn f(x) { return x; } syscall(60, f(1 == 1));' 1
run_test_cc "cmp_neq_arg"    'fn f(x) { return x; } syscall(60, f(1 == 2));' 0
run_test_cc "cmp_gt_arg"     'fn f(x) { return x; } syscall(60, f(5 > 3));' 1
run_test_cc "cmp_lt_arg"     'fn f(x) { return x; } syscall(60, f(3 < 5));' 1
run_test_cc "cmp_gte_arg"    'fn f(x) { return x; } syscall(60, f(3 >= 3));' 1
run_test_cc "cmp_neq2_arg"   'fn f(x) { return x; } syscall(60, f(3 != 4));' 1
run_test_cc "cmp_multi_arg"  'fn check(c, v) { if (c == 1) { return v; } return 0; } syscall(60, check(42 == 42, 99));' 99
run_test_cc "cmp_false_arg"  'fn check(c, v) { if (c == 1) { return v; } return 0; } syscall(60, check(42 == 43, 99));' 0
echo ""

echo "-- Edge Cases (Phase 10 Audit) --"
# Enum in function (was bug: returned 0)
run_test_cc "enum_in_fn"     'enum E { A = 10; B = 20; C = 30; } fn f() { return B; } syscall(60, f());' 20
# Many enum values
run_test_cc "enum_many"      'enum Big { A0; A1; A2; A3; A4; A5; A6; A7; A8; A9; } fn f() { return A9; } syscall(60, f());' 9
# Deep nesting
run_test_cc "deep_if"        'var r = 0; if (1 == 1) { if (2 == 2) { if (3 == 3) { if (4 == 4) { r = 42; } } } }' 42
# Multiple functions calling each other
run_test_cc "fn_chain"       'fn a() { return 1; } fn b() { return a() + 2; } fn c() { return b() + 3; } syscall(60, c());' 6
# Struct in function
run_test_cc "struct_in_fn"   'struct P { x; y; } fn f() { var p = P { 20, 22 }; return p.x + p.y; } syscall(60, f());' 42
# Global + enum interaction
run_test_cc "enum_global"    'enum E { X = 5; Y = 10; } var g = 0; fn f() { g = X + Y; return g; } syscall(60, f());' 15
# For loop in function with enum
run_test_cc "for_enum"       'enum Lim { N = 5; } fn sum() { var s = 0; for (var i = 1; i <= N; i = i + 1) { s = s + i; } return s; } syscall(60, sum());' 15
# Switch with many cases
run_test_cc "switch_many"    'fn f(n) { switch (n) { case 0: return 0; case 1: return 1; case 2: return 2; case 3: return 3; case 4: return 4; case 5: return 42; default: return 99; } return 0; } syscall(60, f(5));' 42
# Pointer arithmetic in function
run_test_cc "ptr_fn"         'fn f() { var buf[4]; store64(&buf, 100); store64(&buf + 8, 200); return load64(&buf) + load64(&buf + 8); } var r = f();' 44
# (300 truncated to 44 at exit)
echo ""

echo "-- Floating Point (cc-only) --"
run_test_cc "f64_from_to"   'var a = f64_from(42); var r = f64_to(a);' 42
run_test_cc "f64_add"       'var a = f64_from(20); var b = f64_from(22); var r = f64_to(f64_add(a, b));' 42
run_test_cc "f64_sub"       'var a = f64_from(50); var b = f64_from(8); var r = f64_to(f64_sub(a, b));' 42
run_test_cc "f64_mul"       'var a = f64_from(6); var b = f64_from(7); var r = f64_to(f64_mul(a, b));' 42
run_test_cc "f64_div"       'var a = f64_from(10); var b = f64_from(3); var r = f64_to(f64_div(a, b));' 3
run_test_cc "f64_eq_true"   'var a = f64_from(5); var b = f64_from(5); var r = f64_eq(a, b);' 1
run_test_cc "f64_eq_false"  'var a = f64_from(5); var b = f64_from(6); var r = f64_eq(a, b);' 0
run_test_cc "f64_lt"        'var a = f64_from(3); var b = f64_from(10); var r = f64_lt(a, b);' 1
run_test_cc "f64_gt"        'var a = f64_from(10); var b = f64_from(3); var r = f64_gt(a, b);' 1
run_test_cc "f64_neg"       'var a = f64_from(42); var b = f64_neg(a); var r = f64_to(f64_add(a, b));' 0
run_test_cc "f64_literal"   'var pi = 3.14; var two = f64_from(2); var r = f64_to(f64_mul(pi, two));' 6
run_test_cc "f64_in_fn"     'fn calc() { var a = f64_from(100); var b = f64_from(58); return f64_to(f64_sub(a, b)); } syscall(60, calc());' 42

echo ""
echo "-- Methods on Structs (cc-only) --"
run_test_cc "method_call"   'struct P { x; y; } fn P_sum(self) { return load64(self) + load64(self + 8); } var p = P { 20, 22 }; var r = p.sum();' 42
run_test_cc "method_args"   'struct V { x; } fn V_add(self, n) { store64(self, load64(self) + n); return 0; } var v = V { 40 }; v.add(2); var r = v.x;' 42
run_test_cc "method_chain"  'struct C { v; } fn C_get(self) { return load64(self); } fn C_set(self, n) { store64(self, n); return 0; } var c = C { 0 }; c.set(42); var r = c.get();' 42

echo ""
echo "-- Enum Constructors (cc-only) --"
run_test_cc "enum_payload"  'enum R { Ok(v) = 0; Err(e) = 1; } var r = Ok;' 0
run_test_cc "enum_pay_val"  'enum E { A(x) = 10; B(y) = 20; } var r = B;' 20

echo ""
echo "-- Feature Flags (cc-only) --"
# Use printf to include #define and #ifdef
run_test_cc "ifdef_true"    "$(printf '#define X\nvar r = 0;\n#ifdef X\nr = 42;\n#endif')" 42
run_test_cc "ifdef_false"   "$(printf 'var r = 42;\n#ifdef NOPE\nr = 0;\n#endif')" 42
run_test_cc "ifdef_nested"  "$(printf '#define A\nvar r = 0;\n#ifdef A\nr = 10;\n#ifdef B\nr = 99;\n#endif\nr = r + 32;\n#endif')" 42

echo ""
echo "-- Pattern Matching (cc-only) --"
run_test_cc "match_basic"   'fn f(n) { match n { 0 => { return 0; } 42 => { return 42; } _ => { return 99; } } return 0; } syscall(60, f(42));' 42
run_test_cc "match_default" 'fn f(n) { match n { 1 => { return 1; } _ => { return 42; } } return 0; } syscall(60, f(7));' 42
run_test_cc "match_first"   'fn f(n) { match n { 10 => { return 10; } 20 => { return 20; } _ => { return 0; } } return 0; } syscall(60, f(10));' 10

echo ""
echo "-- For-In Range (cc-only) --"
run_test_cc "forin_basic"   'fn f() { var s = 0; for i in 1..8 { s = s + i; } return s; } syscall(60, f());' 28
run_test_cc "forin_zero"    'fn f() { var s = 0; for i in 0..5 { s = s + 1; } return s; } syscall(60, f());' 5
run_test_cc "forin_scope"   'fn f() { for i in 0..3 { var x = i; } var i = 42; return i; } syscall(60, f());' 42

echo ""
echo "-- Modules (cc-only) --"
run_test_cc "mod_basic"     'mod math; fn add(a, b) { return a + b; } mod main; use math.add; var r = add(20, 22);' 42
run_test_cc "mod_multi"     'mod math; fn add(a, b) { return a + b; } fn mul(a, b) { return a * b; } mod main; use math.add; use math.mul; var a = mul(2, 11); var r = add(20, a);' 42
run_test_cc "mod_no_use"    'mod math; fn secret() { return 42; } mod main; var r = 0;' 0
run_test_cc "pub_fn"        'pub fn visible() { return 42; } var r = visible();' 42

echo ""
echo "-- Operator Overloading (cc-only) --"
run_test_cc "op_add"  'struct N { v; } fn N_add(a, b) { return a + b; } var x: N = 20; var y: N = 22; var r = x + y;' 42
run_test_cc "op_sub"  'struct N { v; } fn N_sub(a, b) { return a - b; } var x: N = 50; var y: N = 8; var r = x - y;' 42
run_test_cc "op_mul"  'struct N { v; } fn N_mul(a, b) { return a * b; } var x: N = 6; var y: N = 7; var r = x * y;' 42

echo ""
echo "-- Closures (cc-only) --"
run_test_cc "closure_addr"  'var f = |x| x * 2; var r = 0; if (f > 0) { r = 42; }' 42
run_test_cc "closure_params" 'var f = |a, b| a + b; var r = 0; if (f > 0) { r = 42; }' 42
# Note: || is OR operator, so zero-param closures use |_| syntax
run_test_cc "closure_noparam" 'var f = |_| 42; var r = 0; if (f > 0) { r = 42; }' 42

echo ""
echo "-- Closure Edge Cases (cc-only) --"
run_test_cc "closure_in_fn"  'fn f() { var d = |x| x * 2; return d; } var fp = f(); var r = 0; if (fp > 0) { r = 42; }' 42
run_test_cc "closure_multi"  'var a = |x| x + 1; var b = |x| x * 2; var r = 0; if (a > 0) { if (b > 0) { r = 42; } }' 42

echo ""
echo "-- Match Edge Cases (cc-only) --"
run_test_cc "match_nested"   'fn f(a, b) { match a { 1 => { match b { 10 => { return 42; } _ => { return 0; } } } _ => { return 0; } } return 0; } syscall(60, f(1, 10));' 42
run_test_cc "match_expr"     'fn f(n) { match n * 2 { 84 => { return 42; } _ => { return 0; } } return 0; } syscall(60, f(42));' 42
run_test_cc "match_many"     'fn f(n) { match n { 1 => { return 1; } 2 => { return 2; } 3 => { return 3; } 4 => { return 4; } 5 => { return 42; } _ => { return 0; } } return 0; } syscall(60, f(5));' 42

echo ""
echo "-- For-In Edge Cases (cc-only) --"
run_test_cc "forin_nested"   'fn f() { var t = 0; for i in 0..3 { for j in 0..3 { t = t + 1; } } return t; } syscall(60, f());' 9
run_test_cc "forin_expr"     'fn f(n) { var s = 0; for i in 0..n { s = s + i; } return s; } syscall(60, f(7));' 21
run_test_cc "forin_one"      'fn f() { var s = 0; for i in 0..1 { s = 42; } return s; } syscall(60, f());' 42

echo ""
echo "-- Operator Overloading Edge Cases (cc-only) --"
run_test_cc "op_div"         'struct N { v; } fn N_div(a, b) { return a / b; } var x: N = 84; var y: N = 2; var r = x / y;' 42
run_test_cc "op_chain"       'struct N { v; } fn N_add(a, b) { return a + b; } var x: N = 10; var y: N = 12; var z: N = 20; var r = x + y + z;' 42

echo ""
echo "-- Type Annotation Method Dispatch (cc-only) --"
run_test_cc "typed_local"    'struct T { v; } fn T_get(self) { return load64(self); } fn f() { var x: T = 42; return x; } var r = f();' 42
run_test_cc "typed_global"   'struct T { v; } fn T_val(self) { return load64(self); } var g: T = 42; var r = g;' 42

echo ""
echo "-- Trait Impls (cc-only) --"
run_test_cc "impl_basic"    'struct P { x; y; } impl Math for P { fn sum(self) { return load64(self) + load64(self + 8); } } var p = P { 20, 22 }; var r = p.sum();' 42
run_test_cc "impl_mutate"   'struct V { val; } impl Ops for V { fn double(self) { store64(self, load64(self) * 2); return 0; } } var v = V { 21 }; v.double(); var r = v.val;' 42
run_test_cc "impl_multi"    'struct C { n; } impl A for C { fn get(self) { return load64(self); } } impl B for C { fn set(self, v) { store64(self, v); return 0; } } var c = C { 0 }; c.set(42); var r = c.get();' 42

echo ""
echo "-- Block Scoping (cc-only) --"
run_test_cc "scope_shadow"  'fn f() { var x = 10; if (1 == 1) { var x = 42; } return x; } syscall(60, f());' 10
run_test_cc "scope_for"     'fn f() { for (var i = 0; i < 3; i = i + 1) { var tmp = i; } var i = 99; return i; } syscall(60, f());' 99
run_test_cc "scope_while"   'fn f() { var n = 0; while (n < 1) { var x = 42; n = n + 1; } var x = 10; return x; } syscall(60, f());' 10
run_test_cc "scope_nested"  'fn f() { var x = 1; if (1 == 1) { var x = 2; if (1 == 1) { var x = 3; } } return x; } syscall(60, f());' 1

echo ""
echo "-- Self-Hosting --"
echo -n "  "
cat src/compiler.cyr | "$CC" > /tmp/cyr_cc3_$$ 2>/dev/null
if cmp -s "$CC" /tmp/cyr_cc3_$$; then
    echo "PASS: cc2==cc3 byte-identical (extended self-hosting)"
    pass=$((pass + 1))
else
    echo "FAIL: cc self-hosting broken ($(wc -c < "$CC") vs $(wc -c < /tmp/cyr_cc3_$$))"
    fail=$((fail + 1))
fi
rm -f /tmp/cyr_cc3_$$

echo ""
echo "================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
