#!/bin/sh
# Stage 1b Benchmarks
# Measures: compilation time, generated binary size, execution time
#
# Usage: sh bench_stage1b.sh [path-to-stage1b]

STAGE1B="${1:-./stage1/stage1b}"
TMPBIN="/tmp/cyr_bench_$$"
ITERATIONS=1000

echo "================================================================"
echo "  Cyrius Stage 1b Benchmarks"
echo "================================================================"
echo ""

# ── Helper ──
bench_compile() {
    name="$1"; src="$2"
    # Measure compilation time (N iterations)
    start=$(date +%s%N)
    i=0
    while [ $i -lt $ITERATIONS ]; do
        echo "$src" | "$STAGE1B" > "$TMPBIN" 2>/dev/null
        i=$((i + 1))
    done
    end=$(date +%s%N)
    elapsed_ns=$((end - start))
    per_iter_us=$((elapsed_ns / ITERATIONS / 1000))
    size=$(wc -c < "$TMPBIN")
    chmod +x "$TMPBIN"
    echo "  $name"
    echo "    compile: ${per_iter_us}us/iter (${ITERATIONS} iterations)"
    echo "    binary:  ${size} bytes"
}

bench_execute() {
    name="$1"; src="$2"; expected="$3"
    echo "$src" | "$STAGE1B" > "$TMPBIN" 2>/dev/null
    chmod +x "$TMPBIN"
    # Measure execution time
    start=$(date +%s%N)
    i=0
    while [ $i -lt $ITERATIONS ]; do
        "$TMPBIN" > /dev/null 2>/dev/null
        i=$((i + 1))
    done
    end=$(date +%s%N)
    elapsed_ns=$((end - start))
    per_iter_us=$((elapsed_ns / ITERATIONS / 1000))
    # Verify correctness
    "$TMPBIN" > /dev/null 2>/dev/null
    got=$?
    status="OK"
    if [ "$got" -ne "$expected" ]; then
        status="WRONG (expected=$expected, got=$got)"
    fi
    echo "    execute: ${per_iter_us}us/iter  [$status]"
}

echo "-- Simple expressions --"
bench_compile "literal" "var x = 42;"
bench_execute "literal" "var x = 42;" 42
echo ""
bench_compile "arithmetic" "var x = 2 + 3 * 4;"
bench_execute "arithmetic" "var x = 2 + 3 * 4;" 14
echo ""

echo "-- Variables --"
bench_compile "multi_var" "var a = 10; var b = 20; var c = a + b + 12;"
bench_execute "multi_var" "var a = 10; var b = 20; var c = a + b + 12;" 42
echo ""

echo "-- If statement --"
bench_compile "if_taken" "var x = 10; if (x > 5) { x = x + 32; }"
bench_execute "if_taken" "var x = 10; if (x > 5) { x = x + 32; }" 42
echo ""

echo "-- While loops --"
bench_compile "count_10" "var x = 0; while (x < 10) { x = x + 1; }"
bench_execute "count_10" "var x = 0; while (x < 10) { x = x + 1; }" 10
echo ""
bench_compile "factorial" "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }"
bench_execute "factorial" "var n = 5; var f = 1; while (n > 1) { f = f * n; n = n - 1; }" 120
echo ""
bench_compile "sum_1_10" "var i = 0; var s = 0; while (i < 10) { i = i + 1; s = s + i; }"
bench_execute "sum_1_10" "var i = 0; var s = 0; while (i < 10) { i = i + 1; s = s + i; }" 55
echo ""

echo "-- Nested control flow --"
bench_compile "nested" "var i = 0; var x = 0; while (i < 20) { i = i + 1; if (i > 15) { x = x + 1; } }"
bench_execute "nested" "var i = 0; var x = 0; while (i < 20) { i = i + 1; if (i > 15) { x = x + 1; } }" 5
echo ""

echo "-- Compiler stats --"
echo "  stage1b binary size: $(wc -c < "$STAGE1B") bytes"
echo "  stage1b line count:  $(wc -l < stage1/stage1b.cyr) lines"
echo ""

rm -f "$TMPBIN"
echo "================================================================"
