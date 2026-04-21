#!/bin/sh
# Regression: reserved-keyword diagnostic (v5.5.26).
#
# v5.5.26 improved the error a user sees when they write e.g.
#   var match = 1;
#   var in    = 42;
#   var default = x;
#   var shared  = y;
#
# Before:
#   "expected identifier, got match"      (semi-clear but ambiguous)
#   "expected identifier, got unknown"    (misleading — for `in` /
#                                          `shared` / `default` that
#                                          weren't in TOKNAME)
#
# After:
#   "expected identifier, got reserved keyword 'match' (cannot be
#    used as an identifier; rename the variable/field/fn)"
#
# This gate compiles a minimal reproducer for each of the four
# common reserved-keyword footguns and checks stderr contains the
# new message.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

fail=0

check_keyword() {
    kw="$1"
    cat > "$TMP/src.cyr" <<EOF
include "lib/syscalls.cyr"
fn foo() {
    var $kw = 1;
    return $kw;
}
foo();
syscall(60, 0);
EOF
    err=$("$CC5" < "$TMP/src.cyr" > /dev/null 2>&1 || true)
    err=$("$CC5" < "$TMP/src.cyr" > /dev/null 2>"$TMP/err.txt" || true)
    if ! grep -q "reserved keyword '$kw'" "$TMP/err.txt"; then
        echo "  FAIL: 'var $kw = 1;' did not trigger reserved-keyword diagnostic"
        echo "        stderr was:"
        sed 's/^/          /' "$TMP/err.txt" | head -5
        fail=1
    fi
    if ! grep -q "cannot be used as an identifier" "$TMP/err.txt"; then
        echo "  FAIL: 'var $kw = 1;' missing 'cannot be used as an identifier' hint"
        fail=1
    fi
}

check_keyword match
check_keyword in
check_keyword default
check_keyword shared

# Negative control: a legitimate identifier must NOT trigger the
# reserved-keyword path. Any parse should succeed (no stderr).
cat > "$TMP/ok.cyr" <<EOF
include "lib/syscalls.cyr"
fn foo() {
    var my_var = 1;
    return my_var;
}
foo();
syscall(60, 0);
EOF
"$CC5" < "$TMP/ok.cyr" > /dev/null 2>"$TMP/err.txt" || true
if grep -q "reserved keyword" "$TMP/err.txt"; then
    echo "  FAIL: legitimate identifier 'my_var' falsely flagged as reserved"
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: reserved keyword diagnostic (4 kw + negative control)"
    exit 0
else
    echo "  FAIL: reserved keyword diagnostic"
    exit 1
fi
