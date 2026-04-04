#!/bin/sh
# Stage 1d test suite
# Usage: sh test_stage1d.sh [path-to-stage1d]

STAGE1D="${1:-./stage1/stage1d}"
TMPBIN="/tmp/cyr_stage1d_test_$$"
pass=0
fail=0

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1D" > "$TMPBIN" 2>/dev/null
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
    echo "$src" | "$STAGE1D" > "$TMPBIN" 2>/dev/null
    chmod +x "$TMPBIN" 2>/dev/null
    got_stdout=$("$TMPBIN" 2>/dev/null)
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

run_test_pipe() {
    name="$1"; src="$2"; input="$3"; expected_stdout="$4"; expected_exit="$5"
    echo "$src" | "$STAGE1D" > "$TMPBIN" 2>/dev/null
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

echo "Stage 1d Test Suite"
echo "==================="
echo ""

echo "-- Backward Compat (stage1c features) --"
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
echo ""

echo "-- Basic functions --"
run_test "fn_noargs"    "fn f() { return 42; } var r = f();"      42
run_test "fn_1param"    "fn add1(x) { return x + 1; } var r = add1(41);" 42
run_test "fn_2param"    "fn add(a, b) { return a + b; } var r = add(30, 12);" 42
run_test "fn_3param"    "fn sum3(a, b, c) { return a + b + c; } var r = sum3(10, 20, 12);" 42
echo ""

echo "-- Function locals --"
run_test "fn_local"     "fn double(x) { var y = x + x; return y; } var r = double(21);" 42
run_test "fn_multi_local" "fn f(x) { var a = x + 1; var b = a * 2; return b; } var r = f(20);" 42
echo ""

echo "-- Multiple functions --"
run_test "fn_multi"     "fn inc(x) { return x + 1; } fn dec(x) { return x - 1; } var r = inc(dec(42));" 42
run_test "fn_chain"     "fn add1(x) { return x + 1; } fn add2(x) { return add1(add1(x)); } var r = add2(40);" 42
echo ""

echo "-- Forward calls --"
run_test "fn_forward"   "fn f(x) { return g(x + 1); } fn g(x) { return x * 2; } var r = f(20);" 42
echo ""

echo "-- Function with control flow --"
run_test "fn_if"        "fn abs(x) { if (x < 0) { return 0 - x; } return x; } var r = abs(0 - 42);" 42
run_test "fn_while"     "fn fact(n) { var f = 1; while (n > 1) { f = f * n; n = n - 1; } return f; } var r = fact(5);" 120
run_test "fn_if_else"   "fn max(a, b) { if (a > b) { return a; } else { return b; } } var r = max(10, 42);" 42
echo ""

echo "-- Function as statement --"
run_test_stdout "fn_stmt" 'fn greet() { syscall(1, 1, "hi\n", 3); return 0; } greet(); var x = 0;' "hi" 0
echo ""

echo "-- Function with memory --"
run_test "fn_store8"    "fn putbyte(buf, val) { store8(buf, val); return 0; } var b[8]; putbyte(&b, 42); var r = load8(&b);" 42
echo ""

echo "-- Nested calls as arguments --"
run_test "fn_nested"    "fn id(x) { return x; } var r = id(id(id(42)));" 42
echo ""

echo "-- Function result in expression --"
run_test "fn_in_expr"   "fn sq(x) { return x * x; } var r = sq(6) + sq(1) + 5;" 42
echo ""

echo "-- Six parameters (max System V) --"
run_test "fn_6param"    "fn sum6(a, b, c, d, e, f) { return a + b + c + d + e + f; } var r = sum6(1, 2, 3, 4, 5, 27);" 42
echo ""

echo "==================="
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0 || exit 1
