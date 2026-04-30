#!/bin/sh
# Regression: v5.7.x advanced-TS pin audit-pass — 4 stale-pin items.
#
# Pinned to v5.7.46. Premise-check at v5.7.45 entry empirically
# established that 4 of the 5 remaining advanced-TS pin items
# (§v5.7.x — patch slate) all parse `rc=0` against current cc5:
#
#   1. `as const` assertion expressions
#   2. `satisfies` postfix operator
#   3. `never` / `unknown` primitives in type position
#   4. Conditional types — exhaustive corpus (basic / nested /
#      infer T / distributive)
#
# v5.7.46 reframes the third advanced-TS slot from "feature
# implementation" to "audit-pass": this gate locks the empirical
# findings via real-world TS shapes, so any future regression
# in any of the 4 shapes fails check.sh. Zero compiler change
# at v5.7.46 ship — just gates + tcyr fixtures.
#
# Pairs with `tests/tcyr/ts_parse_advanced.tcyr` group
# `ts_parse_p57` (25 assertions in 7 sub-groups exercising the
# same 4 items at parse-pass level).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not built"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
SRC="$TMPDIR/cyrius_ts_audit_$$.ts"
ERR="$TMPDIR/cyrius_ts_audit_err_$$"
trap 'rm -f "$SRC" "$ERR"' EXIT

fail=0

# === 1. `as const` (4 shapes) ================================
cat > "$SRC" <<'EOF'
// Scalar
const c1 = "foo" as const;
const c2 = 42 as const;
const c3 = true as const;

// Object literal
const cfg = { kind: "user", id: 42, admin: true } as const;
const palette = { red: "#f00", green: "#0f0", blue: "#00f" } as const;

// Array / tuple literal
const flags = [true, false, true] as const;
const triple = [1, "two", 3] as const;

// Nested
const nested = {
    name: "root",
    children: [
        { name: "a", id: 1 },
        { name: "b", id: 2 },
    ] as const,
} as const;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: 'as const' parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 2. `satisfies` postfix (real-world shapes) ==============
cat > "$SRC" <<'EOF'
// zod-shape: validate config against a record type
const palette = { red: "#f00", blue: "#00f" } satisfies Record<string, string>;

// react-shape: typed event handler
type Handler = (e: Event) => void;
const onClick = ((e) => console.log(e)) satisfies Handler;

// redux-shape: action creator return type
type Action = { type: string; payload?: unknown };
const setUser = (id: number) => ({ type: "user/set", payload: id }) satisfies Action;

// const + satisfies combo (TS 5.0 idiom)
const routes = {
    home: "/",
    user: "/u/:id",
    post: "/p/:slug",
} as const satisfies Record<string, string>;

// Tuple satisfies
const pair = [1, "x"] satisfies [number, string];

// Object satisfies with optional fields
type Cfg = { name: string; debug?: boolean };
const c = { name: "app" } satisfies Cfg;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: 'satisfies' postfix parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 3. `never` / `unknown` primitives =======================
cat > "$SRC" <<'EOF'
// Type aliases
type T1 = never;
type T2 = unknown;
type T3 = never[];
type T4 = unknown[];

// Function return positions
function fail(): never { throw new Error("unreachable"); }
function asUnknown(x: any): unknown { return x; }

// Variable declarations
let x: never = (() => { throw 0; })();
let y: unknown = 1;

// Object members
type State = {
    last_error: never | null;
    payload: unknown;
};

// Union / intersection
type T5 = string | never;
type T6 = unknown & { tag: "x" };

// Conditional with never (the "no match" idiom)
type Filter<T, U> = T extends U ? T : never;

// Generic constraints
function assertNever(x: never): never { throw new Error("unreachable"); }
function unwrap<T>(x: T | unknown): T { return x as T; }
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: never/unknown parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 4a. Conditional types — basic ===========================
cat > "$SRC" <<'EOF'
type IsString<T> = T extends string ? true : false;
type IsArray<T> = T extends any[] ? true : false;
type IsFn<T> = T extends (...args: any[]) => any ? true : false;

// Instantiations
type R1 = IsString<"x">;
type R2 = IsString<42>;
type R3 = IsArray<number[]>;
type R4 = IsFn<() => void>;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: basic conditional types parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 4b. Conditional types — nested ==========================
cat > "$SRC" <<'EOF'
// Right-nested chain
type Triage<T> =
    T extends string ? "s" :
    T extends number ? "n" :
    T extends boolean ? "b" :
    "other";

// Mixed nesting + infer
type Awaited<T> =
    T extends null | undefined ? T :
    T extends Promise<infer U> ? Awaited<U> :
    T;

// Doubly nested
type Triage2<T> = T extends Array<infer U>
    ? U extends string ? "string-array" : "other-array"
    : T extends string ? "string"
    : "other";
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: nested conditional types parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 4c. Conditional types — `infer T` =======================
cat > "$SRC" <<'EOF'
// Standard utility shapes
type Unwrap<T> = T extends Promise<infer U> ? U : T;
type ElementOf<T> = T extends Array<infer E> ? E : never;
type ArgsOf<F> = F extends (...args: infer A) => any ? A : never;
type ReturnT<F> = F extends (...args: any[]) => infer R ? R : never;
type FirstArg<F> = F extends (first: infer F1, ...rest: any[]) => any ? F1 : never;

// Infer in object position
type Prop<T, K extends keyof T> = T extends { [P in K]: infer V } ? V : never;

// Infer in tuple position
type Head<T extends any[]> = T extends [infer H, ...any[]] ? H : never;
type Tail<T extends any[]> = T extends [any, ...infer R] ? R : never;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: infer T conditional types parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

# === 4d. Conditional types — distributive ===================
cat > "$SRC" <<'EOF'
// Distributive (T extends bare-type-param)
type ToArr<T> = T extends any ? T[] : never;
type StrOrNumArr = ToArr<string | number>;   // string[] | number[]

type Filter<T, U> = T extends U ? T : never;
type StringOnly = Filter<"a" | 1 | "b" | 2, string>;   // "a" | "b"

type Exclude2<T, U> = T extends U ? never : T;

// Non-distributive (wrapped tuple)
type IsString<T> = [T] extends [string] ? "yes" : "no";
type R1 = IsString<string>;       // "yes"
type R2 = IsString<string | number>;   // "no" (not distributed)

// Mixed
type DeepArr<T> = T extends any
    ? T extends object ? T[] : T
    : never;
EOF
if ! "$CC" --parse-ts < "$SRC" >/dev/null 2>"$ERR"; then
    echo "  FAIL: distributive conditional types parse rejected"
    cat "$ERR" | head -3
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: v5.7.x advanced-TS pin audit — 4 items × 7 sub-shapes (as const, satisfies, never/unknown, conditional basic/nested/infer/distributive)"
    exit 0
else
    echo "  FAIL: $fail audit group(s) failed"
    exit 1
fi
