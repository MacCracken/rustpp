#!/bin/sh
# Stage 1a test suite
# Usage: sh test_stage1a.sh [path-to-stage1a]
#
# Tests the stage 1a compiler by feeding it source programs,
# running the generated ELF binaries, and checking exit codes.

STAGE1A="${1:-./stage1/stage1a}"
TMPBIN="/tmp/cyr_stage1a_test_$$"
pass=0
fail=0

run_test() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1A" > "$TMPBIN" 2>/dev/null
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

echo "Stage 1a Test Suite"
echo "==================="

run_test "literal"     "var x = 42;"                              42
run_test "addition"    "var x = 3 + 4;"                           7
run_test "subtraction" "var x = 50 - 8;"                          42
run_test "multiply"    "var x = 6 * 7;"                           42
run_test "divide"      "var x = 84 / 2;"                          42
run_test "precedence"  "var x = 2 + 3 * 4;"                      14
run_test "left_assoc"  "var x = 10 - 3 - 2;"                     5
run_test "parens"      "var x = (2 + 3) * 4;"                    20
run_test "nested"      "var x = ((1 + 2) * (3 + 4));"            21
run_test "multi_var"   "var a = 10; var b = a + 32;"              42
run_test "chain"       "var a = 10; var b = 20; var c = a + b + 12;" 42
run_test "reuse"       "var x = 5; var y = x * x;"               25
run_test "zero"        "var x = 0;"                               0
run_test "complex"     "var a = 2; var b = 3; var c = a * b + a + b;" 11
run_test "neg_divide"  "var x = 0 - 10; var y = x / 3;"           253
run_test "div_chain"   "var x = 100 / 5 / 2;"                     10

echo "==================="
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] && exit 0 || exit 1
