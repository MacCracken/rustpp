#!/bin/sh
# aarch64 hardware test suite
# Run on actual ARM hardware (not qemu).
#
# Usage:
#   1. From x86 host: scp tests/aarch64-hardware.sh /tmp/cc2_aarch64 runner@agnosarm.local:/tmp/cyrius_test/
#   2. On ARM machine: cd /tmp/cyrius_test && sh aarch64-hardware.sh
#   3. Cleanup: rm -rf /tmp/cyrius_test

# No set -e: test binaries exit with non-zero codes intentionally

CC="${1:-./cc2_aarch64}"
TMPDIR="/tmp/cyr_a64_$$"
mkdir -p "$TMPDIR"

if [ ! -x "$CC" ]; then
    echo "error: $CC not found or not executable"
    exit 1
fi

echo "=== Cyrius aarch64 Hardware Test Suite ==="
echo "  compiler: $CC ($(wc -c < "$CC") bytes)"
echo "  arch: $(uname -m)"
echo "  host: $(hostname)"
echo ""

pass=0
fail=0

check() {
    local name="$1" expected="$2" got="$3"
    if [ "$got" = "$expected" ]; then
        echo "  PASS: $name"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected $expected, got $got)"
        fail=$((fail + 1))
    fi
}

run_test() {
    local name="$1" code="$2" expected="$3"
    echo "$code" | "$CC" > "$TMPDIR/test" 2>/dev/null && chmod +x "$TMPDIR/test"
    result=$("$TMPDIR/test" 2>/dev/null; echo $?)
    check "$name" "$expected" "$result"
}

echo "-- Literals + Arithmetic --"
run_test "literal"    "var x = 42;" 42
run_test "add"        "var x = 20 + 22;" 42
run_test "sub"        "var x = 50 - 8;" 42
run_test "mul"        "var x = 6 * 7;" 42
run_test "div"        "var x = 84 / 2;" 42
run_test "mod"        "var r = 10 % 3;" 1
run_test "neg"        "var x = 0 - 42; var r = 0 - x;" 42
run_test "precedence" "var x = 2 + 5 * 8;" 42

echo ""
echo "-- Control Flow --"
run_test "if_true"    "var x = 0; if (1 == 1) { x = 42; }" 42
run_test "if_false"   "var x = 42; if (1 == 0) { x = 0; }" 42
run_test "if_else"    "var x = 0; if (0 == 1) { x = 0; } else { x = 42; }" 42
run_test "while"      "var x = 0; while (x < 10) { x = x + 1; }" 10
run_test "for"        "var s = 0; for (var i = 1; i <= 10; i = i + 1) { s = s + i; } var r = s;" 55
run_test "break"      "var i = 0; while (i < 100) { if (i == 42) { break; } i = i + 1; }" 42

echo ""
echo "-- Functions --"
run_test "fn_basic"   "fn f(a, b) { return a + b; } var x = f(20, 22);" 42
run_test "fn_recurse" "fn fib(n) { if (n <= 1) { return n; } return fib(n-1) + fib(n-2); } var r = fib(7);" 13
run_test "fn_multi"   "fn add(a,b) { return a+b; } fn mul(a,b) { return a*b; } var r = add(mul(6,7),0);" 42
run_test "fn_6args"   "fn f(a,b,c,d,e,g) { return a+b+c+d+e+g; } var r = f(1,2,3,4,5,27);" 42

echo ""
echo "-- Enums + Structs --"
run_test "enum"       "enum E { A = 10; B = 42; } fn f() { return B; } var r = f();" 42
run_test "struct"     "struct P { x; y; } var p = P { 20, 22 }; var r = p.x + p.y;" 42
run_test "struct_fn"  "struct P { x; y; } fn sum(p) { return load64(p) + load64(p + 8); } var p = P { 20, 22 }; var r = sum(&p);" 42

echo ""
echo "-- Syscall + I/O --"
run_test "syscall"    'syscall(1, 1, "ok", 2); var r = 42;' 42
run_test "exit"       "syscall(93, 42);" 42

echo ""
echo "-- Bitwise --"
run_test "and"        "var r = 0xFF & 0x2A;" 42
run_test "or"         "var r = 0x20 | 0x0A;" 42
run_test "xor"        "var r = 0xFF ^ 0xD5;" 42
run_test "shl"        "var r = 21 << 1;" 42
run_test "shr"        "var r = 84 >> 1;" 42

echo ""
echo "-- Load/Store --"
run_test "store_load" "var buf[2]; store64(&buf, 42); var r = load64(&buf);" 42
run_test "store8"     "var buf[2]; store8(&buf, 42); var r = load8(&buf);" 42

echo ""
echo "-- Self-Hosting Prep --"
# Test compiling a multi-function program
run_test "complex" "fn max(a,b) { if (a > b) { return a; } return b; } fn min(a,b) { if (a < b) { return a; } return b; } var r = max(min(50, 42), 10);" 42

echo ""
echo "=============================="
echo "$pass passed, $fail failed"
echo ""

rm -rf "$TMPDIR"

if [ "$fail" -gt 0 ]; then exit 1; fi
