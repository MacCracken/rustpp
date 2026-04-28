#!/bin/sh
# Regression: TypeScript mapped types — `as`-clause + `+/-readonly` /
# `+/-?` modifier prefixes (TS 2.1 / 2.8 / 4.5 features).
#
# Pinned to v5.7.25. Pre-v5.7.25 the parser handled `[k: K]: V`
# index signatures inside object types but treated mapped types
# (`[K in T]: V`) as a syntax error — KW_IN was unexpected after
# the bracket-key IDENT consume. The SY corpus didn't surface
# this gap (no SY .ts file uses mapped types in real code), so
# parse-acceptance ran 100% without coverage.
#
# v5.7.25 adds the mapped-type fork inside TS_PARSE_TYPE_OBJECT:
# detection by peek_ahead(2) == KW_IN; modifier prefix consume
# extended for `+/-readonly`; post-`]` `+/-?` modifier; optional
# `as <Type>` key remapping. New AST kind TS_AST_TYPE_MAPPED = 314.
#
# Cases below cover the seven primary shapes plus regressions for
# pre-v5.7.25 forms (index signatures, readonly properties).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_mapped_$$.ts"
ERR="$TMPDIR/cyrius_ts_mapped_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === bare mapped type [K in T]: V ============================
cat > "$SRC" <<'EOF'
type Pick<T, K extends keyof T> = { [P in K]: T[P] };
type R<T> = { [K in keyof T]: T[K] };
type U = { [K in "a" | "b"]: number };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: bare mapped type rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === as-clause key remapping (TS 4.5+) =======================
cat > "$SRC" <<'EOF'
type CapKeys<T> = { [K in keyof T as Capitalize<string & K>]: T[K] };
type Filter<T, U> = { [K in keyof T as T[K] extends U ? K : never]: T[K] };
type Prefix<T> = { [K in keyof T as `_${string & K}`]: T[K] };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: as-clause key remapping rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === readonly modifiers (incl. +/-readonly TS 2.8+) ==========
cat > "$SRC" <<'EOF'
type R<T> = { readonly [K in keyof T]: T[K] };
type AddR<T> = { +readonly [K in keyof T]: T[K] };
type Mut<T> = { -readonly [K in keyof T]: T[K] };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: readonly mapped-type modifiers rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === optional ? modifiers (incl. +/-?) =======================
cat > "$SRC" <<'EOF'
type P<T> = { [K in keyof T]?: T[K] };
type Opt<T> = { [K in keyof T]+?: T[K] };
type Req<T> = { [K in keyof T]-?: T[K] };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: optional mapped-type modifiers rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === combined: -readonly + as + -? ===========================
cat > "$SRC" <<'EOF'
type X<T> = { -readonly [K in keyof T as `_${string & K}`]-?: T[K] };
type Y<T> = { +readonly [K in keyof T as Lowercase<K & string>]+?: T[K] };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: combined mapped-type forms rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: index signatures (pre-v5.7.25) =============
cat > "$SRC" <<'EOF'
type R = { [k: string]: number };
type S = { readonly [k: number]: string };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: index signature regressed"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: readonly property =========================
cat > "$SRC" <<'EOF'
interface I { readonly name: string; }
type P = { readonly x: number; readonly y: number };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: readonly property regressed"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cc5 --parse-ts accepts mapped types + as-clause + +/- modifiers (v5.7.25)"
    exit 0
fi
echo "  FAIL: $fail mapped-type shapes rejected"
exit 1
