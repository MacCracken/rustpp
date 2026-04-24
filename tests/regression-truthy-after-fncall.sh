#!/bin/sh
# Regression: bare-truthy `if (r)` after fn-call must take the TRUE
# branch when r != 0. Pinned to v5.6.21 fix.
#
# Bug history: v5.6.x (5.6.10 onward through 5.6.20) silently
# miscompiled `var r = fn(); if (r) { ... }` because `_flags_reflect_rax`
# (v5.6.8 Phase O2 cat 2 optimization) was not reset by EFLLOAD,
# ECALLFIX, ECALLTO, or ESYSCALL — leaving stale flags from inside
# the callee. ECONDCMP's `_flags_reflect_rax` skip emitted the
# bare-truthy branch on the wrong flags. Fixed v5.6.21 by adding
# the resets to all four sites.
#
# Repro source originally at /tmp/cyrius_5.6_codegen_bug.cyr —
# baked into this regression script so the gate survives across
# sessions.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not present (cross-compiler not built)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cat > "$TMP/repro.cyr" <<'EOF'
# Self-contained: no includes — just builtins. Models the bug shape:
# helper has an early `if { return 0; }` that sets flags, then a
# trailing return of a value that lands in rax. caller then does
# `var r = helper(); if (r) { ... }`. v5.6.x mis-branched.

fn helper(x) {
    if (x == 0) { return 0; }   # CMP+JMP sets flags
    return 1;                    # rax = 1, but flags still from above
}

fn caller(arg) {
    var r = helper(arg);
    if (r) { return 99; }        # Expected when r == 1
    return 0 - 1;                 # Taken incorrectly on v5.6.10..v5.6.20
}

syscall(60, caller(1));
EOF

"$CC" < "$TMP/repro.cyr" > "$TMP/repro" 2>/dev/null
chmod +x "$TMP/repro"
set +e
"$TMP/repro"
rc=$?
set -e

if [ "$rc" -ne 99 ]; then
    echo "  FAIL bare-truthy-after-fncall: exit $rc (expected 99). v5.6.x _flags_reflect_rax stale-flag regression has returned."
    exit 1
fi

# Second shape: direct `if (fn_call())` (no intermediate var)
cat > "$TMP/repro2.cyr" <<'EOF'
# Direct shape: `if (fn_call())` (no intermediate var)
fn match_one(x) {
    if (x == 0) { return 0; }
    return 1;
}

fn check(arg) {
    if (match_one(arg)) { return 77; }
    return 0 - 1;
}

syscall(60, check(1));
EOF
"$CC" < "$TMP/repro2.cyr" > "$TMP/repro2" 2>/dev/null
chmod +x "$TMP/repro2"
set +e
"$TMP/repro2"
rc2=$?
set -e

if [ "$rc2" -ne 77 ]; then
    echo "  FAIL bare-truthy-direct-fncall: exit $rc2 (expected 77)."
    exit 1
fi

echo "  PASS bare-truthy after fn-call returns correct branch"
