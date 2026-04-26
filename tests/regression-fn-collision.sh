#!/bin/sh
# Regression: cc5 emits `warning: ... duplicate fn '<name>' (last
# definition wins)` when a fn-name registration finds a slot whose
# body offset is already non-(-1).
#
# Pinned to v5.7.9. Pre-v5.7.9 silent overwrite case: lib/json.cyr
# `fn json_build/1` vs lib/patra.cyr `fn json_build/6`. Last-include
# wins; calls to the losing arity silently miscompile; build reports
# OK.
#
# This regression covers the WARNING (option (b) per
# docs/audit/2026-04-26-stdlib-fn-collisions.md) — not arity-aware
# overload resolution (separate language addition, no slot pinned).
#
# Cases:
#   1. same-arity duplicate          → warn fires
#   2. different-arity duplicate     → warn fires
#   3. forward-decl + later body     → warn does NOT fire
#                                      (the registered slot has
#                                      offset=-1 until body lands;
#                                      the warn condition is
#                                      offset>=0)
#
# A failure here means either:
#   a. the warn was not emitted (collision regressed to silent), or
#   b. the warn was emitted on a forward-decl pattern (false
#      positive that would break legitimate cyrius idioms).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
TMPSTEM="$TMPDIR/cyrius_fn_collision_$$"
trap 'rm -f "$TMPSTEM".*' EXIT

fail=0

# --- Case 1: same-arity duplicate ---
cat > "$TMPSTEM.case1.cyr" <<'EOF'
fn dup_a(x) { return x + 1; }
fn dup_a(x) { return x + 2; }
syscall(60, 0);
EOF
"$CC" < "$TMPSTEM.case1.cyr" > "$TMPSTEM.case1.out" 2> "$TMPSTEM.case1.err"
if grep -q "duplicate fn 'dup_a'" "$TMPSTEM.case1.err"; then
    :
else
    echo "  FAIL: case1 (same-arity duplicate) — expected warn missing"
    cat "$TMPSTEM.case1.err"
    fail=$((fail + 1))
fi

# --- Case 2: different-arity duplicate ---
cat > "$TMPSTEM.case2.cyr" <<'EOF'
fn dup_b(a) { return a; }
fn dup_b(a, b) { return a + b; }
syscall(60, 0);
EOF
"$CC" < "$TMPSTEM.case2.cyr" > "$TMPSTEM.case2.out" 2> "$TMPSTEM.case2.err"
if grep -q "duplicate fn 'dup_b'" "$TMPSTEM.case2.err"; then
    :
else
    echo "  FAIL: case2 (different-arity duplicate) — expected warn missing"
    cat "$TMPSTEM.case2.err"
    fail=$((fail + 1))
fi

# --- Case 3: forward-decl call + later body — warn must NOT fire ---
# Mutual recursion: caller declares the callee at compile time via
# the call site (which registers a slot with offset=-1); the body
# arrives later. Must not warn.
cat > "$TMPSTEM.case3.cyr" <<'EOF'
fn caller_one(n) { if (n <= 0) { return 0; } return callee_two(n - 1); }
fn callee_two(n) { if (n <= 0) { return 0; } return caller_one(n - 1); }
syscall(60, caller_one(3));
EOF
"$CC" < "$TMPSTEM.case3.cyr" > "$TMPSTEM.case3.out" 2> "$TMPSTEM.case3.err"
if grep -q "duplicate fn" "$TMPSTEM.case3.err"; then
    echo "  FAIL: case3 (forward-decl) — false-positive warn fired"
    cat "$TMPSTEM.case3.err"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: fn-name collision warning (3/3 cases)"
    exit 0
fi
exit 1
