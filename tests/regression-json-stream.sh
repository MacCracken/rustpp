#!/bin/sh
# Regression: lib/json.cyr streaming parser (v5.7.41).
#
# Pinned to v5.7.41. Pairs with tests/tcyr/json_stream.tcyr (65
# unit-level assertions). This gate is the end-to-end check: compile
# a fixture that streams a representative nested payload and emits a
# single-character tag per event, then exact-byte cmp against the
# canonical event sequence. Catches regressions in the dispatch
# table, callback firing order, or any silent slot-offset drift.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: build/cc5 not built"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fixture: prints one tag per event and the final return code.
cat > "$WORK/fixture.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/string.cyr"
include "lib/str.cyr"
include "lib/vec.cyr"
include "lib/fmt.cyr"
include "lib/io.cyr"
include "lib/math.cyr"
include "lib/fnptr.cyr"
include "lib/json.cyr"

alloc_init();

fn cb_obj_start(ctx) { print("{", 1); return 0; }
fn cb_obj_end(ctx)   { print("}", 1); return 0; }
fn cb_arr_start(ctx) { print("[", 1); return 0; }
fn cb_arr_end(ctx)   { print("]", 1); return 0; }
fn cb_key(ctx, k)    { print("k", 1); return 0; }
fn cb_str(ctx, s)    { print("s", 1); return 0; }
fn cb_int(ctx, n)    { print("i", 1); return 0; }
fn cb_bool(ctx, b)   { print("b", 1); return 0; }
fn cb_null(ctx)      { print("n", 1); return 0; }

var h = json_stream_handler_new(0);
json_stream_on(h, JS_EV_OBJECT_START, &cb_obj_start);
json_stream_on(h, JS_EV_OBJECT_END,   &cb_obj_end);
json_stream_on(h, JS_EV_ARRAY_START,  &cb_arr_start);
json_stream_on(h, JS_EV_ARRAY_END,    &cb_arr_end);
json_stream_on(h, JS_EV_KEY,          &cb_key);
json_stream_on(h, JS_EV_STRING,       &cb_str);
json_stream_on(h, JS_EV_INT,          &cb_int);
json_stream_on(h, JS_EV_BOOL,         &cb_bool);
json_stream_on(h, JS_EV_NULL,         &cb_null);

var src = "{\"name\":\"alice\",\"id\":42,\"flags\":[true,null],\"meta\":{\"k\":\"v\"}}";
var rc = json_stream_parse(str_data(str_from(src)), strlen(src), h);
print("\n", 1);
if (rc == 0) { print("OK\n", 3); } else { print("ERR\n", 4); }
return 0;
EOF

cat "$WORK/fixture.cyr" | "$CC" > "$WORK/fixture.bin" 2>"$WORK/cc.err"
if [ ! -s "$WORK/fixture.bin" ]; then
    echo "  FAIL: fixture compile error"
    cat "$WORK/cc.err"
    exit 1
fi
chmod +x "$WORK/fixture.bin"

"$WORK/fixture.bin" > "$WORK/out.txt" 2>&1 || true

# Expected event trace for the fixture above:
#   {  obj_start  outer
#   k  "name"
#   s  "alice"
#   k  "id"
#   i  42
#   k  "flags"
#   [  arr_start
#   b  true
#   n  null
#   ]  arr_end
#   k  "meta"
#   {  obj_start  inner
#   k  "k"
#   s  "v"
#   }  obj_end inner
#   }  obj_end outer
cat > "$WORK/expected.txt" <<'EOF'
{kskik[bn]k{ks}}
OK
EOF

if cmp -s "$WORK/out.txt" "$WORK/expected.txt"; then
    echo "  PASS: streaming parser fires events in canonical order (16 events, 0 errors)"
    # event count breakdown:
    # 2× obj_start, 2× obj_end, 1× arr_start, 1× arr_end,
    # 4× key, 2× string, 1× int, 1× bool, 1× null = 16 events
    exit 0
else
    echo "  FAIL: streaming event sequence drifted"
    echo "  ── expected ──"
    sed 's/^/    /' "$WORK/expected.txt"
    echo "  ── got ──"
    sed 's/^/    /' "$WORK/out.txt"
    echo "  ── diff ──"
    diff "$WORK/expected.txt" "$WORK/out.txt" || true
    exit 1
fi
