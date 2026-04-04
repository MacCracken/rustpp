#!/bin/sh
# Stage 1c test suite
# Usage: sh test_stage1c.sh [path-to-stage1c]
#
# Tests both exit codes and stdout output.

STAGE1C="${1:-./stage1/stage1c}"
TMPBIN="/tmp/cyr_stage1c_test_$$"
pass=0
fail=0

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1C" > "$TMPBIN" 2>/dev/null
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
    echo "$src" | "$STAGE1C" > "$TMPBIN" 2>/dev/null
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

# Pipe input to the generated program and check stdout
run_test_pipe() {
    name="$1"; src="$2"; input="$3"; expected_stdout="$4"; expected_exit="$5"
    echo "$src" | "$STAGE1C" > "$TMPBIN" 2>/dev/null
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

echo "Stage 1c Test Suite"
echo "==================="
echo ""

echo "-- Backward Compat (arithmetic) --"
run_test "literal"      "var x = 42;"                              42
run_test "addition"     "var x = 3 + 4;"                           7
run_test "multiply"     "var x = 6 * 7;"                           42
run_test "precedence"   "var x = 2 + 3 * 4;"                      14
run_test "parens"       "var x = (2 + 3) * 4;"                    20
run_test "neg_divide"   "var x = 0 - 10; var y = x / 3;"          253
echo ""

echo "-- Backward Compat (variables) --"
run_test "multi_var"    "var a = 10; var b = a + 32;"              42
run_test "reassign"     "var x = 10; x = x + 5; var y = x;"       15
echo ""

echo "-- Backward Compat (control flow) --"
run_test "if_taken"     "var x = 1; if (x == 1) { x = 42; }"      42
run_test "if_skip"      "var x = 1; if (x == 2) { x = 99; }"      1
run_test "else_taken"   "var x = 1; if (x == 2) { x = 10; } else { x = 42; }"  42
run_test "while_loop"   "var x = 0; while (x < 10) { x = x + 1; }" 10
run_test "factorial"    "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }" 120
echo ""

echo "-- syscall --"
run_test_stdout "hello_str" 'syscall(1, 1, "hi\n", 3); var x = 0;' "hi" 0
run_test_stdout "write_lit" 'syscall(1, 1, "OK\n", 3); var x = 0;' "OK" 0
# getpid returns a positive number — just verify it doesn't crash
run_test "syscall_1arg" "var x = syscall(60, 42);"                 42
echo ""

echo "-- Address-of + arrays --"
run_test "addr_store_load" "var x = 0; var p = &x; var y = x;"    0
run_test "array_decl"   "var buf[16]; var x = 42;"                 42
echo ""

echo "-- load8 / store8 --"
run_test "store8_load8" "var x = 0; store8(&x, 42); var y = load8(&x);" 42
run_test "byte_roundtrip" "var buf[8]; store8(&buf, 99); var y = load8(&buf);" 99
echo ""

echo "-- Integration --"
run_test_stdout "hello_world" 'syscall(1, 1, "hello world\n", 12); var x = 0;' "hello world" 0
echo ""

echo "==================="
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0 || exit 1
