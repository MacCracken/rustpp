#!/bin/sh
# Regression: TS 5.0 const type parameters — `<const T>`.
#
# Pinned to v5.7.45. Pre-v5.7.45 cyrius-ts rejected
# `<const T>` with `code=3 tok=102` because
# TS_PARSE_TYPE_PARAMS expected IDENT directly, no contextual
# `const` keyword handling at the type-parameter position.
# v5.7.45 adds an optional `TS_TOK_KW_CONST` consume in
# TS_PARSE_TYPE_PARAMS before the IDENT expect.
#
# Empirical premise check at v5.7.45 entry: 4 of the 5
# remaining advanced-TS pin items already parsed rc=0
# (`as const`, `satisfies` postfix, `never`/`unknown`
# primitives, conditional types in basic / nested / `infer` /
# distributive forms) — only `<const T>` had a real gap.
# Those 4 parsing-clean items move to v5.7.46 audit-pass to
# mark them ✅ in the pin list with empirical proof.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_ctp_$$.ts"
ERR="$TMPDIR/cyrius_ts_ctp_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === plain const type param =================================
cat > "$SRC" <<'EOF'
function id<const T>(x: T): T { return x; }
function pick<const K>(key: K) { return key; }
function tag<const N>(n: N) { return n; }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: plain <const T> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === const + extends constraint =============================
cat > "$SRC" <<'EOF'
function pickK<const K extends string>(key: K) { return key; }
function pickN<const N extends number>(n: N) { return n; }
function tagged<const T extends Record<string, unknown>>(x: T) { return x; }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: <const T extends C> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === const + default ========================================
cat > "$SRC" <<'EOF'
function f<const T = "x">(x: T): T { return x; }
function g<const T extends string = "default">(x: T): T { return x; }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: <const T = default> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === mixed const + non-const ================================
cat > "$SRC" <<'EOF'
function mix<T, const U, V>(a: T, b: U, c: V) {}
function mix2<const A, B, const C>(a: A, b: B, c: C) {}
function mix3<A extends string, const B, C = number>(a: A, b: B, c: C) {}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: mixed const+non-const params rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === on classes / type aliases / interfaces / methods =======
cat > "$SRC" <<'EOF'
class Box<const T> {
    constructor(public v: T) {}
    method<const U>(u: U): U { return u; }
}
interface I<const T> {
    method<const U>(u: U): U;
}
type Wrap<const T> = T;
type Pair<const A, const B> = [A, B];
const arrow = <const T>(x: T): T => x;
const generic = <const T extends string>(x: T) => x;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: const type params on class/iface/alias/method/arrow rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: plain (no const) still works ==============
cat > "$SRC" <<'EOF'
function id<T>(x: T): T { return x; }
function f<T extends U, V = W>(x: T): V { return null as V; }
class Box<T, U = string> {}
type Pair<A, B> = [A, B];
const arrow = <T>(x: T): T => x;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: plain (non-const) type params rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: const type params <const T> — 6 groups (plain, extends, default, mixed, class/iface/alias/method/arrow, plain-regression)"
    exit 0
else
    echo "  FAIL: $fail const-type-param group(s) failed"
    exit 1
fi
