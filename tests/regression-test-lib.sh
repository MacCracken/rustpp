#!/bin/sh
# Regression: lib/test.cyr v1 (test_each helper) — v5.7.43.
#
# Pinned to v5.7.43. Pairs with tests/tcyr/test_lib.tcyr (12
# unit-level assertions). This gate is the end-to-end check:
# compile a fixture using test_each over a known-shape vec of
# cases, print a per-case marker, exact-byte cmp the trace.
# Catches regressions in fncall1 dispatch, vec iteration order,
# and the transitive-include chain (test.cyr → assert.cyr +
# fnptr.cyr).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: build/cc5 not built"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fixture: build a 5-element vec of int-payload cases, run them
# through test_each, print "<n>." per case so the output trace
# encodes both ordering and count.
cat > "$WORK/fixture.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/string.cyr"
include "lib/str.cyr"
include "lib/vec.cyr"
include "lib/fmt.cyr"
include "lib/io.cyr"
include "lib/math.cyr"
include "lib/test.cyr"

alloc_init();

fn _emit(c) {
    var n = load64(c);
    var b[2];
    store8(&b, 48 + n);
    store8(&b + 1, 0);
    print(&b, 1);
    print(".", 1);
    return 0;
}

var cases = vec_new();
var i = 0;
while (i < 5) {
    var c = alloc(8);
    store64(c, i);
    vec_push(cases, c);
    i = i + 1;
}
test_each(cases, &_emit);
print("\n", 1);

# Empty vec is a no-op; trace stays empty.
var empty = vec_new();
test_each(empty, &_emit);
print("end\n", 4);

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

cat > "$WORK/expected.txt" <<'EOF'
0.1.2.3.4.
end
EOF

if cmp -s "$WORK/out.txt" "$WORK/expected.txt"; then
    echo "  PASS: test_each iterates in vec order, no-ops on empty (5 cases + 0-case run)"
    exit 0
else
    echo "  FAIL: test_each trace drifted"
    echo "  ── expected ──"
    sed 's/^/    /' "$WORK/expected.txt"
    echo "  ── got ──"
    sed 's/^/    /' "$WORK/out.txt"
    echo "  ── diff ──"
    diff "$WORK/expected.txt" "$WORK/out.txt" || true
    exit 1
fi
