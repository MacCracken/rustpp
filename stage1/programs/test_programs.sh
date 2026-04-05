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

# New programs
for p in seq tr sum uniq grep; do build $p; done

out=$("$TMPDIR/seq" | wc -l | tr -d ' ')
check "seq count" "10" "$out"

out=$("$TMPDIR/seq" | tail -1)
check "seq last" "10" "$out"

out=$(echo "hello world" | "$TMPDIR/tr")
check "tr upper" "HELLO WORLD" "$out"

out=$(printf "a\na\nb\nb\nc\n" | "$TMPDIR/uniq")
check "uniq dedup" "a
b
c" "$out"

out=$(printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n" | "$TMPDIR/sum")
check "sum 1-10" "55" "$out"

out=$(printf "hello world\ngoodbye\nhello there\n" | "$TMPDIR/grep")
check "grep hello" "hello world
hello there" "$out"

# New programs (for-loop era)
for p in hexdump basename cols tail; do build $p; done

out=$(echo "AB" | "$TMPDIR/hexdump")
check "hexdump AB" "00000000  41 42 0a " "$out"

out=$(echo "/usr/bin/test" | "$TMPDIR/basename")
check "basename" "test" "$out"

out=$(echo "nopath" | "$TMPDIR/basename")
check "basename nodir" "nopath" "$out"

out=$(printf "short\nthis is a longer line\nhi\n" | "$TMPDIR/cols")
check "cols max" "21" "$out"

out=$(printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n" | "$TMPDIR/tail" | head -1)
check "tail first" "6" "$out"

out=$(printf "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n" | "$TMPDIR/tail" | tail -1)
check "tail last" "15" "$out"

# Programs using string stdlib
for p in toupper count rot13; do build $p; done

out=$(echo "hello world" | "$TMPDIR/toupper")
check "toupper" "HELLO WORLD" "$out"

out=$(printf "a\nb\nc\n" | "$TMPDIR/count")
check "count lines" "3" "$out"

out=$(echo "Hello" | "$TMPDIR/rot13")
check "rot13" "Uryyb" "$out"

out=$(echo "Uryyb" | "$TMPDIR/rot13")
check "rot13 inverse" "Hello" "$out"

# String stdlib test
build strtest
"$TMPDIR/strtest" > /dev/null 2>/dev/null
check "strtest 10 funcs" "10" "$?"

# Feature-exercise programs
for p in asmtest bitfield life fib sieve points memset; do build $p; done

out=$("$TMPDIR/fib" | wc -l | tr -d ' ')
check "fib 20 lines" "20" "$out"

out=$("$TMPDIR/fib" | head -7 | tail -1)
check "fib 7th" "8" "$out"

"$TMPDIR/asmtest" > /dev/null 2>/dev/null
check "asmtest 18" "18" "$?"
"$TMPDIR/bitfield" > /dev/null 2>/dev/null
check "bitfield 11" "11" "$?"

"$TMPDIR/life" > /dev/null 2>/dev/null
check "life glider" "5" "$?"
"$TMPDIR/sieve"
check "sieve 54 primes" "54" "$?"

"$TMPDIR/points"
check "points dist²" "25" "$?"

"$TMPDIR/memset"
check "memset 100" "100" "$?"

rm -rf "$TMPDIR"

echo ""
echo "=========================="
echo "$pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then exit 1; fi
