#!/bin/sh
# Stage 1b test suite
# Usage: sh test_stage1b.sh [path-to-stage1b]
#
# Convention: program exits with the value of the last DECLARED variable.
# To control which variable is the "result", declare it last.

STAGE1B="${1:-./stage1/stage1b}"
TMPBIN="/tmp/cyr_stage1b_test_$$"
pass=0
fail=0

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1B" > "$TMPBIN" 2>/dev/null
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

echo "Stage 1b Test Suite"
echo "==================="
echo ""

echo "-- Arithmetic --"
run_test "literal"      "var x = 42;"                              42
run_test "addition"     "var x = 3 + 4;"                           7
run_test "subtraction"  "var x = 50 - 8;"                          42
run_test "multiply"     "var x = 6 * 7;"                           42
run_test "divide"       "var x = 84 / 2;"                          42
run_test "precedence"   "var x = 2 + 3 * 4;"                      14
run_test "left_assoc"   "var x = 10 - 3 - 2;"                     5
run_test "parens"       "var x = (2 + 3) * 4;"                    20
run_test "nested_p"     "var x = ((1 + 2) * (3 + 4));"            21
run_test "zero"         "var x = 0;"                               0
echo ""

echo "-- Variables --"
run_test "multi_var"    "var a = 10; var b = a + 32;"              42
run_test "chain"        "var a = 10; var b = 20; var c = a + b + 12;" 42
run_test "reuse"        "var x = 5; var y = x * x;"               25
run_test "complex"      "var a = 2; var b = 3; var c = a * b + a + b;" 11
echo ""

echo "-- Reassignment --"
run_test "reassign1"    "var x = 10; x = x + 5; var y = x;"       15
run_test "reassign2"    "var a = 100; a = a - 58;"                 42
run_test "multi_assign" "var x = 7; var y = 3; x = x * y; y = x + y;" 24
echo ""

echo "-- If Statements --"
run_test "if_taken"     "var x = 1; if (x == 1) { x = 42; }"      42
run_test "if_skip"      "var x = 1; if (x == 2) { x = 99; }"      1
run_test "if_gt"        "var x = 10; if (x > 5) { x = x + 32; }"  42
run_test "if_neq"       "var x = 10; if (x != 10) { x = 0; }"     10
run_test "if_lt"        "var x = 3; if (x < 3) { x = 99; }"       3
run_test "if_eq2"       "var b = 5; var a = 5; if (a == b) { a = 42; }" 42
run_test "if_lte"       "var x = 5; if (x <= 5) { x = 42; }"      42
run_test "if_gte"       "var x = 5; if (x >= 6) { x = 99; }"      5
echo ""

echo "-- While Loops --"
run_test "count_up"     "var x = 0; while (x < 10) { x = x + 1; }" 10
run_test "double"       "var x = 1; while (x < 100) { x = x * 2; }" 128
run_test "factorial"    "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }" 120
run_test "sum"          "var i = 0; var s = 0; while (i < 10) { i = i + 1; s = s + i; }" 55
run_test "countdown"    "var x = 100; while (x > 58) { x = x - 1; }" 58
echo ""

echo "-- Nested Control Flow --"
run_test "if_in_while"  "var i = 0; var x = 0; while (i < 20) { i = i + 1; if (i > 15) { x = x + 1; } }" 5
run_test "while_if_eq"  "var i = 0; var c = 0; while (i < 10) { i = i + 1; if (i == 5) { c = c + 100; } }" 100

echo ""
echo "==================="
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0 || exit 1
