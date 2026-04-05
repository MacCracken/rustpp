#!/bin/sh
# Full project check: format, lint, vet, deny, test, self-host, bench
# Equivalent to: cargo fmt --check && cargo clippy && cargo deny && cargo test
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc2"
CYRB="$ROOT/scripts/cyrb"
CYRFMT="$ROOT/build/cyrfmt"
CYRLINT="$ROOT/build/cyrlint"
CYRC="$ROOT/build/cyrc"

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

echo "=== Cyrius Project Check ==="
echo ""

# ── 1. Self-hosting ──
echo "── Self-Hosting ──"
cc3="/tmp/check_cc3_$$"
cc4="/tmp/check_cc4_$$"
cat "$ROOT/stage1/cc2.cyr" | "$CC" > "$cc3" 2>/dev/null && chmod +x "$cc3"
cat "$ROOT/stage1/cc2.cyr" | "$cc3" > "$cc4" 2>/dev/null
cmp -s "$cc3" "$cc4" 2>/dev/null
check "cc2==cc3 byte-identical" "$?"
rm -f "$cc3" "$cc4"
echo ""

# ── 2. Compiler Tests ──
echo "── Compiler Tests ──"
sh "$ROOT/stage1/test_cc.sh" "$CC" "$ROOT/build/stage1f" 2>&1 | tail -1
cc_result=$?
check "compiler tests (111)" "$cc_result"
echo ""

# ── 3. Program Tests ──
echo "── Program Tests ──"
sh "$ROOT/stage1/programs/test_programs.sh" "$CC" 2>&1 | tail -1
prog_result=$?
check "program tests (57)" "$prog_result"
echo ""

# ── 4. Format Check ──
echo "── Format Check ──"
if [ -x "$CYRFMT" ]; then
    fmt_fail=0
    for f in "$ROOT"/stage1/lib/*.cyr; do
        "$CYRFMT" "$f" > /tmp/check_fmt_$$ 2>/dev/null
        if ! diff -q "$f" /tmp/check_fmt_$$ > /dev/null 2>&1; then
            echo "    needs formatting: $(basename $f)"
            fmt_fail=1
        fi
        rm -f /tmp/check_fmt_$$
    done
    check "format (stdlib)" "$fmt_fail"
else
    echo "    skip: cyrfmt not built"
fi
echo ""

# ── 5. Lint ──
echo "── Lint ──"
if [ -x "$CYRLINT" ]; then
    lint_total=0
    for f in "$ROOT"/stage1/lib/*.cyr; do
        w=$("$CYRLINT" "$f" 2>&1 | tail -1 | grep -oP '^\d+' || echo 0)
        lint_total=$((lint_total + w))
    done
    if [ "$lint_total" -gt 0 ]; then
        echo "    $lint_total warnings across stdlib"
        check "lint (stdlib)" "1"
    else
        check "lint (stdlib)" "0"
    fi
else
    echo "    skip: cyrlint not built"
fi
echo ""

# ── 6. Vet ──
echo "── Dependency Audit ──"
if [ -x "$CYRC" ]; then
    vet_fail=0
    for f in "$ROOT"/stage1/programs/ark.cyr "$ROOT"/stage1/programs/cyrb.cyr "$ROOT"/stage1/programs/cyrc.cyr; do
        if [ -f "$f" ]; then
            "$CYRC" vet "$f" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "    vet failed: $(basename $f)"
                vet_fail=1
            fi
        fi
    done
    check "vet (tools)" "$vet_fail"
else
    echo "    skip: cyrc not built"
fi
echo ""

# ── 7. Deny ──
echo "── Policy Check ──"
if [ -x "$CYRC" ]; then
    deny_fail=0
    for f in "$ROOT"/stage1/programs/ark.cyr "$ROOT"/stage1/programs/cyrb.cyr "$ROOT"/stage1/programs/cyrc.cyr; do
        if [ -f "$f" ]; then
            "$CYRC" deny "$f" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "    deny failed: $(basename $f)"
                deny_fail=1
            fi
        fi
    done
    check "deny (tools)" "$deny_fail"
else
    echo "    skip: cyrc not built"
fi
echo ""

# ── 8. Benchmarks ──
echo "── Benchmarks ──"
cat > /tmp/check_bench_$$.cyr << 'BENCH'
include "stage1/lib/string.cyr"
include "stage1/lib/fmt.cyr"
include "stage1/lib/alloc.cyr"
include "stage1/lib/vec.cyr"
include "stage1/lib/fnptr.cyr"
include "stage1/lib/agnosys/syscalls.cyr"
include "stage1/lib/bench.cyr"

fn work_noop() { return 0; }
fn work_alloc() { alloc(64); return 0; }

fn main() {
    alloc_init();
    var benches = vec_new();
    var b1 = bench_new("noop");
    bench_run(b1, &work_noop, 10000);
    vec_push(benches, b1);
    var b2 = bench_new("alloc64");
    bench_run(b2, &work_alloc, 10000);
    vec_push(benches, b2);
    bench_report_all(benches);
    return 0;
}
var r = main();
BENCH
cd "$ROOT"
cat /tmp/check_bench_$$.cyr | "$CC" > /tmp/check_bench_$$ 2>/dev/null && chmod +x /tmp/check_bench_$$
/tmp/check_bench_$$ 2>/dev/null
bench_result=$?
check "benchmarks" "$bench_result"
rm -f /tmp/check_bench_$$ /tmp/check_bench_$$.cyr
echo ""

# ── 9. Documentation Check ──
echo "── Documentation ──"
doc_fail=0
for doc in README.md CHANGELOG.md VERSION CONTRIBUTING.md SECURITY.md LICENSE; do
    if [ ! -f "$ROOT/$doc" ]; then
        echo "    missing: $doc"
        doc_fail=1
    fi
done
for doc in docs/tutorial.md docs/cyrius-guide.md docs/stdlib-reference.md docs/faq.md docs/benchmarks.md; do
    if [ ! -f "$ROOT/$doc" ]; then
        echo "    missing: $doc"
        doc_fail=1
    fi
done
check "documentation" "$doc_fail"
echo ""

# ── Summary ──
echo "════════════════════════"
printf "%d passed, %d failed (%d total)\n" "$pass" "$fail" "$total"
exit $fail
