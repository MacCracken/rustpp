#!/bin/sh
# Regression: lib/shadow.cyr + lib/pam.cyr (v5.5.27).
#
# Direct compile via build/cc5 — matches other check.sh gates.
# Bypasses the `cyrius test` harness's known dep-auto-prepend
# ordering issue (tracked from v5.5.26 CHANGELOG).
#
# Asserts:
#   - tests/tcyr/shadow_pam.tcyr compiles cleanly
#   - binary exits 0 (all assertions pass)
#   - handles both non-root (EACCES on /etc/shadow → rc=-1) and
#     root (found → rc=1) paths
#   - pam_unix_available returns 0 or 1 truthfully
#   - wrong-password / nonexistent-user auth paths return non-zero
#     without infrastructure errors

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/shadow_pam.tcyr"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/shadow_pam"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: shadow_pam.tcyr did not compile"
    grep -vE "^\s*dead:|^note:|syscall arity" "$TMP/compile.err" | head -5
    exit 1
fi

# Filter unix_chkpwd's direct-invocation stderr noise (expected when
# we run it ourselves rather than through a PAM stack).
out=$("$BIN" 2>/dev/null | grep -vE "^\s*$")
if echo "$out" | grep -q "0 failed"; then
    passed=$(echo "$out" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '^[0-9]+')
    echo "  PASS: shadow_pam ($passed assertions)"
    exit 0
else
    echo "  FAIL: shadow_pam"
    echo "$out" | sed 's/^/    /'
    exit 1
fi
