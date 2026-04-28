#!/bin/sh
# Regression: TypeScript 5.0 stage-3 decorators
# (`@foo class X {}`, class-member decorators, parameter
# decorators, `export @foo class`, `export default @foo class`).
#
# Pinned to v5.7.26. Pre-v5.7.26 the `@` token (TS_TOK_AT = 35)
# was unhandled at every valid decorator position — class
# statements, class members, function parameters — and parses
# rejected with `code=6 tok=35` (unexpected statement-leading
# token) or `code=3 tok=35` (unexpected token at expected
# position). The SY corpus didn't surface this gap (no SY .ts
# file uses decorators), so parse acceptance ran 100% without
# coverage.
#
# v5.7.26 adds:
#   - TS_AST_DECORATOR = 315  AST kind (allocated; not yet
#     attached to the following declaration — future polish slot).
#   - TS_PARSE_DECORATOR_LIST helper — consumes
#     `@<call-member>` repeatedly. The expression after `@` is
#     parsed via the existing TS_PARSE_CALL_MEMBER (covers `@foo`,
#     `@foo()`, `@foo.bar`, `@foo.bar.baz<T>(args)`, `@(<expr>)`).
#   - Wire-in at four sites: TS_PARSE_STMT (top), TS_PARSE_EXPORT
#     (top + default branch), TS_PARSE_CLASS_MEMBER (top),
#     TS_PARSE_ARROW_PARAMS (per-param iteration).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_dec_$$.ts"
ERR="$TMPDIR/cyrius_ts_dec_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === decorators on class declarations =========================
cat > "$SRC" <<'EOF'
@foo class A {}
@foo() class B {}
@foo @bar @baz.qux class C {}
@foo.bar class D {}
@foo.bar.baz({ a: 1, b: [1, 2] }) class E {}
@foo<T>() class F {}
@foo abstract class G {}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: class-level decorators rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === decorators on class members ==============================
cat > "$SRC" <<'EOF'
class X {
    @foo method() {}
    @foo prop: number = 1;
    @foo() public bar: string;
    @foo @bar.factory() async qux(): Promise<void> {}
    @foo get name(): string { return ''; }
    @foo set value(v: T) {}
}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: class-member decorators rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === decorators on parameters =================================
cat > "$SRC" <<'EOF'
class X {
    method(@foo x: number) {}
    ctor(@foo x: number, @bar.dec() y: string) {}
    fn(@foo public p: T, q: U) {}
    multi(@d1 @d2.factory() x: T) {}
}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: parameter decorators rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === decorators after export / export default ==================
cat > "$SRC" <<'EOF'
export @foo class A {}
export @foo() abstract class B {}
export default @foo class {}
export default @bar.factory() class {}
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: decorators after export rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === regression: plain class still works (no decorators) =====
cat > "$SRC" <<'EOF'
class X {
    method() {}
    prop: T = 1;
}
export default class Y {}
class Z { ctor(public x: number, readonly y: T) {} }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: plain class regressed"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: cc5 --parse-ts accepts TS 5.0 stage-3 decorators (v5.7.26)"
    exit 0
fi
echo "  FAIL: $fail decorator shapes rejected"
exit 1
