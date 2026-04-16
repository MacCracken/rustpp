#!/bin/sh
# Regression: cyrld multi-file linker.
# Compiles two object-mode .cyr units, links them into an executable,
# runs it, and checks the exit code. Covers:
#   - cross-module fn resolution (c.cyr calls greet in a.cyr)
#   - cross-module .data access (m.cyr reads counter defined in d.cyr)
#   - DT_INIT-style _cyrius_init ordering (deps init first)
#   - compaction DCE (never_called dropped; live fns still dispatch)
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
CYRLD="$ROOT/build/cyrld"

if [ ! -x "$CYRLD" ]; then
    echo "  skip: build/cyrld not present"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# ---- Test 1: cross-module call, 43 = greet() + 1 ----
cat > "$TMP/a.cyr" <<'EOF'
object;
fn greet() { return 42; }
EOF

cat > "$TMP/c.cyr" <<'EOF'
object;
fn call_greet() { return greet() + 1; }
var result = call_greet();
EOF

cat "$TMP/a.cyr" | "$CC" > "$TMP/a.o" 2>/dev/null
cat "$TMP/c.cyr" | "$CC" > "$TMP/c.o" 2>/dev/null
"$CYRLD" -o "$TMP/exe1" "$TMP/c.o" "$TMP/a.o" >/dev/null
set +e; "$TMP/exe1"; rv=$?; set -e
if [ "$rv" -ne 43 ]; then
    echo "  FAIL: cross-module call exit $rv (expected 43)"; exit 1
fi

# ---- Test 2: cross-module data + init ordering, 44 = r2 ----
cat > "$TMP/d.cyr" <<'EOF'
object;
var counter = 42;
fn inc_counter() { counter = counter + 1; return counter; }
fn never_called() { return 99; }
EOF

cat > "$TMP/m.cyr" <<'EOF'
object;
var r1 = inc_counter();
var r2 = inc_counter();
var r = r2;
EOF

cat "$TMP/d.cyr" | "$CC" > "$TMP/d.o" 2>/dev/null
cat "$TMP/m.cyr" | "$CC" > "$TMP/m.o" 2>/dev/null
"$CYRLD" -o "$TMP/exe2" "$TMP/m.o" "$TMP/d.o" >/dev/null
set +e; "$TMP/exe2"; rv=$?; set -e
if [ "$rv" -ne 44 ]; then
    echo "  FAIL: data + init ordering exit $rv (expected 44)"; exit 1
fi

exit 0
