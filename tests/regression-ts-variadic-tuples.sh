#!/bin/sh
# Regression: TypeScript variadic tuple types — AST representation.
#
# Pinned to v5.7.44. Parse acceptance for variadic forms
# (`[...A]`, `[T, ...U]`, `[...U, T]`, `[...A, ...B]`, mixed,
# labeled `[...rest: T[]]`) was already correct pre-v5.7.44;
# the gap was AST representation: TS_PARSE_TYPE_TUPLE consumed
# `...` silently and emitted the inner element type without a
# spread-marker AST node. v5.7.44 allocates TS_AST_TYPE_REST
# (316) and wraps any tuple element preceded by `...` so
# downstream consumers (typechecker, tooling) can introspect
# the spread distinction.
#
# This gate covers parse acceptance only; AST-shape coverage is
# in tests/tcyr/ts_parse_advanced.tcyr group `ts_parse_p55`
# (8 groups, 18 assertions exercising single-rest, leading,
# trailing, multi-spread, mixed, labeled, optional+spread, and a
# plain-tuple regression that no false REST is emitted).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_vt_$$.ts"
ERR="$TMPDIR/cyrius_ts_vt_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === single rest =============================================
cat > "$SRC" <<'EOF'
type T1 = [...A];
type T2 = [...A<B>];
type T3 = [...readonly A[]];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: single-rest forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === trailing spread (the most common shape) =================
cat > "$SRC" <<'EOF'
type Push<T extends any[], U> = [...T, U];
type Cons<H, T extends any[]> = [H, ...T];
type Triple = [string, ...number[]];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: trailing-spread forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === leading spread ==========================================
cat > "$SRC" <<'EOF'
type Snoc<T extends any[], U> = [...T, U];
type WithSuffix = [...string[], number];
type FixedTail = [...readonly Foo[], Bar, Baz];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: leading-spread forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === multi-spread ============================================
cat > "$SRC" <<'EOF'
type Concat<A extends any[], B extends any[]> = [...A, ...B];
type Three<A extends any[], B extends any[], C extends any[]> = [...A, ...B, ...C];
type Mixed = [P, ...A, ...B, Q];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: multi-spread forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === labeled spread ==========================================
cat > "$SRC" <<'EOF'
type Args = [first: string, second: number, ...rest: boolean[]];
type Flexible = [...prefix: string[], suffix: number];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: labeled-spread forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === spread + optional element ==============================
cat > "$SRC" <<'EOF'
type Maybe = [T?, ...U];
type Optional = [first: string, second?: number, ...rest: boolean[]];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: optional+spread forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: plain tuples still work =====================
cat > "$SRC" <<'EOF'
type T1 = [];
type T2 = [number];
type T3 = [string, number, boolean];
type T4 = readonly [string, number];
type T5 = [first: string, second: number];
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: plain (non-variadic) tuples rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: variadic tuple parse acceptance — 7 groups (single rest, trailing, leading, multi-spread, labeled, optional+spread, plain-tuple regression)"
    exit 0
else
    echo "  FAIL: $fail variadic-tuple group(s) failed"
    exit 1
fi
