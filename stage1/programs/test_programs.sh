#!/bin/sh
# Test suite for Cyrius Linux programs
# Usage: sh test_programs.sh [path-to-cc2]

CC="${1:-./build/cc2}"
pass=0
fail=0
TMPDIR="/tmp/cyr_prog_$$"
mkdir -p "$TMPDIR"

build() {
    cat "stage1/programs/$1.cyr" | "$CC" > "$TMPDIR/$1" 2>/dev/null
    chmod +x "$TMPDIR/$1"
}

check() {
    name="$1"; expected="$2"; got="$3"
    if [ "$got" = "$expected" ]; then
        echo "  PASS: $name"
        pass=$((pass + 1))
    else
        echo "  FAIL: $name (expected '$expected', got '$got')"
        fail=$((fail + 1))
    fi
}

echo "Cyrius Programs Test Suite"
echo "=========================="
echo ""

# Build all
for p in true false echo cat head tee; do build $p; done

# true/false
"$TMPDIR/true"; check "true exits 0" "0" "$?"
"$TMPDIR/false"; check "false exits 1" "1" "$?"

# echo
out=$("$TMPDIR/echo")
check "echo output" "Hello from Cyrius!" "$out"

# cat
out=$(echo "hello world" | "$TMPDIR/cat")
check "cat pipe" "hello world" "$out"

echo "multi line" > "$TMPDIR/input"
echo "test file" >> "$TMPDIR/input"
out=$("$TMPDIR/cat" < "$TMPDIR/input")
check "cat file" "multi line
test file" "$out"

# head
out=$(printf "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\n" | "$TMPDIR/head")
lines=$(echo "$out" | wc -l)
check "head 10 lines" "10" "$lines"

# tee
echo "tee input" | "$TMPDIR/tee" > "$TMPDIR/tee_out" 2>"$TMPDIR/tee_err"
check "tee stdout" "tee input" "$(cat $TMPDIR/tee_out)"
check "tee stderr" "tee input" "$(cat $TMPDIR/tee_err)"

# rev
build rev
out=$(echo "hello" | "$TMPDIR/rev")
check "rev hello" "olleh" "$out"
out=$(printf "abc\n123\n" | "$TMPDIR/rev")
check "rev multi" "cba
321" "$out"

# Size checks
for p in true false echo cat head tee; do
    sz=$(wc -c < "$TMPDIR/$p")
    if [ "$sz" -lt 8192 ]; then
        echo "  PASS: $p size ($sz bytes < 1KB)"
        pass=$((pass + 1))
    else
        echo "  FAIL: $p size ($sz bytes >= 1KB)"
        fail=$((fail + 1))
    fi
done

rm -rf "$TMPDIR"

echo ""
echo "=========================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then exit 1; fi
