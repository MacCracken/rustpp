#!/bin/sh
# cyrius-coverage — test coverage report for Cyrius stdlib
# Checks which lib/*.cyr functions are exercised by .tcyr test files.
# Reports per-module and per-function coverage.
#
# Usage: cyrius coverage

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="${REPO_ROOT}/build/cc3"

total_libs=0
covered_libs=0
total_fns=0
covered_fns=0
untested_modules=""

echo "=== Coverage Report ==="
echo ""

# Collect all test content into one searchable file
TESTCORPUS="/tmp/cyrius_coverage_corpus_$$"
cat "$REPO_ROOT"/tests/tcyr/*.tcyr "$REPO_ROOT"/tests/bcyr/*.bcyr "$REPO_ROOT"/programs/*.cyr 2>/dev/null > "$TESTCORPUS"

for lib in "$REPO_ROOT"/lib/*.cyr; do
    name=$(basename "$lib" .cyr)
    total_libs=$((total_libs + 1))

    # Count public functions (lines starting with "fn ")
    lib_fns=$(grep -c "^fn " "$lib" 2>/dev/null || echo 0)
    # Skip internal functions (starting with _)
    pub_fns=$(grep "^fn " "$lib" 2>/dev/null | grep -cv "^fn _" || echo 0)
    total_fns=$((total_fns + pub_fns))

    # Check if this module is included in any test
    has_test=0
    if grep -q "\"lib/${name}.cyr\"" "$TESTCORPUS" 2>/dev/null; then
        has_test=1
    fi
    # Also check if functions from this lib are called (even without explicit include)
    if [ "$has_test" -eq 0 ]; then
        # Check if ANY public function name appears in tests
        first_fn=$(grep "^fn " "$lib" 2>/dev/null | grep -v "^fn _" | head -1 | sed 's/^fn //;s/(.*//')
        if [ -n "$first_fn" ] && grep -q "$first_fn" "$TESTCORPUS" 2>/dev/null; then
            has_test=1
        fi
    fi

    if [ "$has_test" -eq 1 ]; then
        covered_libs=$((covered_libs + 1))
        # Count unique public functions that appear in test corpus
        called=0
        while IFS= read -r fnline; do
            fname=$(echo "$fnline" | sed 's/^fn //;s/(.*//')
            # Skip private functions
            case "$fname" in _*) continue ;; esac
            if grep -q "$fname" "$TESTCORPUS" 2>/dev/null; then
                called=$((called + 1))
            fi
        done <<FNEOF
$(grep "^fn " "$lib")
FNEOF
        covered_fns=$((covered_fns + called))
        if [ "$pub_fns" -gt 0 ]; then
            pct=$((called * 100 / pub_fns))
        else
            pct=100
        fi
        printf "  %-20s %3d/%-3d fns  %3d%%\n" "$name" "$called" "$pub_fns" "$pct"
    else
        printf "  %-20s  ── NO TESTS ──\n" "$name"
        untested_modules="$untested_modules $name"
    fi
done

echo ""
echo "── Summary ──"
echo "  Libraries: $covered_libs/$total_libs covered"
if [ "$total_fns" -gt 0 ]; then
    fn_pct=$((covered_fns * 100 / total_fns))
    echo "  Functions: $covered_fns/$total_fns ($fn_pct%)"
fi
if [ -n "$untested_modules" ]; then
    echo "  Untested: $untested_modules"
fi

rm -f "$TESTCORPUS"

if [ "$covered_libs" -lt "$total_libs" ]; then
    exit 1
fi
