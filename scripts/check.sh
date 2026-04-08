#!/bin/sh
# Full project audit: self-host, test suite, heap audit, format, lint
# Usage: cyrb audit  (or: sh scripts/check.sh)
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc2"
CYRFMT="$ROOT/build/cyrfmt"
CYRLINT="$ROOT/build/cyrlint"

pass=0
fail=0
total=0

check() {
    total=$((total + 1))
    if [ "$2" = "0" ]; then
        printf "  \033[32mPASS\033[0m: %s\n" "$1"
        pass=$((pass + 1))
    else
        printf "  \033[31mFAIL\033[0m: %s\n" "$1"
        fail=$((fail + 1))
    fi
}

echo "=== Cyrius v2.0 Audit ==="
echo ""

# ── 1. Self-hosting (two-step) ──
echo "── Self-Hosting ──"
cc3="/tmp/audit_cc3_$$"
cc4="/tmp/audit_cc4_$$"
cat "$ROOT/src/main.cyr" | "$CC" > "$cc3" 2>/dev/null && chmod +x "$cc3"
cat "$ROOT/src/main.cyr" | "$cc3" > "$cc4" 2>/dev/null
cmp -s "$cc3" "$cc4" 2>/dev/null
check "cc2==cc3 byte-identical" "$?"
sz=$(wc -c < "$cc3")
printf "    binary: %d bytes\n" "$sz"
rm -f "$cc3" "$cc4"
echo ""

# ── 2. Heap Map Audit ──
echo "── Heap Map ──"
sh "$ROOT/tests/heapmap.sh" > /tmp/audit_heap_$$ 2>&1
hm_result=$?
check "no heap overlaps" "$hm_result"
if [ "$hm_result" -ne 0 ]; then cat /tmp/audit_heap_$$; fi
rm -f /tmp/audit_heap_$$
echo ""

# ── 3. Test Suite (.tcyr) ──
echo "── Test Suite ──"
test_fail=0
test_total=0
for tfile in "$ROOT"/tests/tcyr/*.tcyr; do
    [ -f "$tfile" ] || continue
    name=$(basename "$tfile" .tcyr)
    tmpbin="/tmp/audit_t_$$"
    printf "  %-20s " "$name"
    if cat "$tfile" | "$CC" > "$tmpbin" 2>/dev/null && chmod +x "$tmpbin"; then
        output=$("$tmpbin" 2>&1)
        ec=$?
        summary=$(echo "$output" | grep -o '[0-9]* passed, [0-9]* failed' | tail -1)
        if [ -n "$summary" ]; then
            f=$(echo "$summary" | grep -o '[0-9]* failed' | grep -o '^[0-9]*')
            if [ "$f" -gt 0 ]; then
                echo "FAIL ($summary)"
                test_fail=$((test_fail + 1))
            else
                echo "PASS ($summary)"
            fi
        elif [ "$ec" -eq 0 ]; then
            echo "PASS"
        else
            echo "FAIL (exit $ec)"
            test_fail=$((test_fail + 1))
        fi
    else
        echo "FAIL (compile)"
        test_fail=$((test_fail + 1))
    fi
    test_total=$((test_total + 1))
    rm -f "$tmpbin"
done
check "test suite ($test_total files)" "$test_fail"
echo ""

# ── 4. Format Check ──
echo "── Format ──"
if [ -x "$CYRFMT" ]; then
    fmt_fail=0
    for f in "$ROOT"/lib/*.cyr; do
        "$CYRFMT" "$f" > /tmp/audit_fmt_$$ 2>/dev/null
        if ! diff -q "$f" /tmp/audit_fmt_$$ > /dev/null 2>&1; then
            fmt_fail=1
        fi
        rm -f /tmp/audit_fmt_$$
    done
    check "format (stdlib)" "$fmt_fail"
else
    echo "  skip: cyrfmt not built"
fi
echo ""

# ── 5. Lint ──
echo "── Lint ──"
if [ -x "$CYRLINT" ]; then
    lint_total=0
    for f in "$ROOT"/lib/*.cyr; do
        w=$("$CYRLINT" "$f" 2>&1 | tail -1 | grep -o '^[0-9]*' || echo 0)
        lint_total=$((lint_total + w))
    done
    if [ "$lint_total" -gt 0 ]; then
        echo "  $lint_total warnings"
        check "lint (stdlib)" "1"
    else
        check "lint (stdlib)" "0"
    fi
else
    echo "  skip: cyrlint not built"
fi
echo ""

# ── Summary ──
echo "════════════════════════"
printf "%d passed, %d failed (%d total)\n" "$pass" "$fail" "$total"
exit $fail
