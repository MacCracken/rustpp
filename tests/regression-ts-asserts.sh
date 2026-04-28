#!/bin/sh
# Regression: TypeScript `asserts` predicate signatures (TS 3.7+).
#
# Pinned to v5.7.24. Pre-v5.7.24 the parser had a comment-only
# stub at TS_PARSE_TYPE that *intended* to tolerate
# `asserts <ident> [is <T>]` in return-type position but the
# implementation only handled the `<lhs> is <T>` suffix and
# misparsed any input starting with `asserts`:
#
#   function f(x): asserts x is string {}
#                  ^^^^^^^                 → consumed as type-ref
#                          ^                → consumed as predicate subj
#                            ^^             → consumed as predicate type
#                               ^^^^^^      → unconsumed; body parse fails
#
# v5.7.24 adds:
#   1. KW_ASSERTS contextual keyword (token 219, ident-eligible
#      where `satisfies` is — consumers like `var asserts = 1;`
#      stay green).
#   2. Real prefix consumer in TS_PARSE_TYPE — when the next
#      token is name-like (IDENT / KW / `this`), consume
#      `asserts` and let the existing predicate-suffix logic
#      handle the rest.
#   3. KW_THIS branch in TS_PARSE_TYPE_PRIMARY — the polymorphic
#      `this`-type, needed for `asserts this is C` method
#      predicates and class-builder return-type `this` patterns.
#
# Cases below cover the primary shapes plus regressions for
# pre-v5.7.24 forms (`<id> is <T>`, `var asserts = 1`,
# regular return types).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_asserts_$$.ts"
ERR="$TMPDIR/cyrius_ts_asserts_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === asserts <ident> is <Type> — typed predicate ============
cat > "$SRC" <<'EOF'
function isString(x: any): asserts x is string {}
function chk(x: unknown): asserts x is number | bigint {}
function notNull<T>(x: T | null): asserts x is T {}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: asserts <id> is <T> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === asserts <ident> — bare predicate =======================
cat > "$SRC" <<'EOF'
function ok(cond: boolean): asserts cond {}
function defined<T>(x: T | undefined): asserts x {}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: bare asserts <id> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === asserts this is <Type> — class method predicate ========
cat > "$SRC" <<'EOF'
class C {
    check(): asserts this is C { return; }
}
class Loaded<T> {
    ensure(): asserts this is Loaded<T> { return; }
}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: asserts this is <T> rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === polymorphic this-type in return position ===============
cat > "$SRC" <<'EOF'
interface Builder { build(): this; }
class B { chain(): this { return this; } }
class P { is(): this is P { return; } }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: polymorphic this-type rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === asserts as ident name (KW_ASSERTS ident-eligible) ======
cat > "$SRC" <<'EOF'
var asserts = 1;
let x: asserts;
type T = asserts;
const y = { asserts: 42 };
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: 'asserts' ident-eligibility broken"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: <id> is <T> predicate (pre-v5.7.24) ========
cat > "$SRC" <<'EOF'
function isStr(x: any): x is string {}
function f(x: number): number { return x; }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: <id> is <T> predicate regressed"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cc5 --parse-ts accepts asserts predicate signatures (v5.7.24)"
    exit 0
fi
echo "  FAIL: $fail asserts shapes rejected"
exit 1
