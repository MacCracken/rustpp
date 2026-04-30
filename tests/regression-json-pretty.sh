#!/bin/sh
# Regression: lib/json.cyr pretty-printer (v5.7.40).
#
# Pinned to v5.7.40. Pairs with tests/tcyr/json_pretty.tcyr (unit-level
# assertions). This gate is the end-to-end check: compile a fixture
# that pretty-prints a representative tree at indent=2, run it, and
# assert exact-byte stdout match. Catches regressions in the walker,
# helper layout, and indent-fallback path in one execution.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if [ ! -x "$CC" ]; then
    echo "  skip: build/cc5 not built"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fixture: nested object with array + scalars + empty container.
# Expected pretty-print at indent=2 has one well-known canonical shape
# the walker must produce; any drift is a regression.
cat > "$WORK/fixture.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/string.cyr"
include "lib/str.cyr"
include "lib/vec.cyr"
include "lib/fmt.cyr"
include "lib/io.cyr"
include "lib/math.cyr"
include "lib/json.cyr"

alloc_init();

var src = "{\"name\":\"alice\",\"tags\":[1,2],\"empty\":[]}";
var v = json_v_parse_str(src, strlen(src));
var pretty = json_v_build_pretty(v, 2);
print(str_data(pretty), str_len(pretty));
print("\n", 1);
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

# Expected output (LF-separated, single trailing newline).
cat > "$WORK/expected.txt" <<'EOF'
{
  "name": "alice",
  "tags": [
    1,
    2
  ],
  "empty": []
}
EOF

if cmp -s "$WORK/out.txt" "$WORK/expected.txt"; then
    echo "  PASS: pretty-print indent=2 matches expected canonical shape (8 lines)"
    exit 0
else
    echo "  FAIL: pretty-print output drifted"
    echo "  ── expected ──"
    sed 's/^/    /' "$WORK/expected.txt"
    echo "  ── got ──"
    sed 's/^/    /' "$WORK/out.txt"
    echo "  ── diff ──"
    diff "$WORK/expected.txt" "$WORK/out.txt" || true
    exit 1
fi
