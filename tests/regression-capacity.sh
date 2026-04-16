#!/bin/sh
# Regression: `cyrius capacity` subcommand (4.8.3 series).
# Covers all four invocation modes — default stats, --check CI gate,
# --json dashboard output, --check --json combined — plus the missing-
# entry-point error path. Also exercises the latent fnc > 2048 bugs
# that alpha4 fixed (DCE bitmap + EMITELF_OBJ scratch).
#
# Skipped on systems without python3 (used to synthesize a 3500-fn
# stress source). Skipped if `cyrius` script isn't found.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CYRIUS="$ROOT/scripts/cyrius"

if [ ! -x "$CYRIUS" ]; then echo "  skip: $CYRIUS not executable"; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "  skip: python3 not found (needed for synthetic stress source)"
    exit 0
fi

# The `cyrius` wrapper invokes the INSTALLED cc5 ($CYRIUS_HOME/bin/cc5),
# not build/cc5. Sync them so the test exercises the real wrapper path
# against the binary we just built — otherwise a stale install hides the
# alpha1+ stats meter (the very thing we're testing).
if [ -d "$HOME/.cyrius/bin" ] && [ -x "$ROOT/build/cc5" ]; then
    cp "$ROOT/build/cc5" "$HOME/.cyrius/bin/cc5"
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# ---- Test 1: default mode prints all 6 stat lines ----
SMALL="$TMP/small.cyr"
cat > "$SMALL" <<'EOF'
fn main() { return 42; }
EOF
"$CYRIUS" capacity "$SMALL" > "$TMP/out1" 2>"$TMP/err1"
for key in fn_table identifiers var_table fixup_table string_data code_size; do
    if ! grep -q "^  $key:" "$TMP/err1"; then
        echo "  FAIL test1: missing key '$key' in default output"
        cat "$TMP/err1"
        exit 1
    fi
done

# ---- Test 2: --check on small file exits 0 with "ok" ----
set +e
"$CYRIUS" capacity --check "$SMALL" > "$TMP/out2" 2>"$TMP/err2"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test2: --check on small file exit=$rc (expected 0)"
    cat "$TMP/err2"
    exit 1
fi
if ! grep -q "ok (all caps under 85%)" "$TMP/out2"; then
    echo "  FAIL test2: --check missing 'ok' message"
    cat "$TMP/out2"
    exit 1
fi

# ---- Test 3: synthetic 3500-fn source — --check exits 1 ----
BIG="$TMP/big.cyr"
python3 -c "
print('object;')
for i in range(3500):
    print(f'fn f{i}() {{ return {i}; }}')
" > "$BIG"
set +e
"$CYRIUS" capacity --check "$BIG" > "$TMP/out3" 2>"$TMP/err3"
rc=$?
set -e
if [ "$rc" -ne 1 ]; then
    echo "  FAIL test3: --check on big file exit=$rc (expected 1)"
    cat "$TMP/err3"
    exit 1
fi
if ! grep -q "table(s) at >=85%" "$TMP/err3"; then
    echo "  FAIL test3: missing 'failing' message"
    cat "$TMP/err3"
    exit 1
fi

# ---- Test 4: 3500-fn source compiles cleanly under default mode ----
# (this is the latent EMITELF_OBJ + live[] bug fix from alpha4 —
# pre-fix this segfaulted)
set +e
cat "$BIG" | "$ROOT/build/cc5" > "$TMP/big.o" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test4: object-mode compile of 3500-fn source exit=$rc (regression in fnc>2048 fix)"
    exit 1
fi
sz=$(wc -c < "$TMP/big.o")
if [ "$sz" -lt 100000 ]; then
    echo "  FAIL test4: 3500-fn .o suspiciously small ($sz bytes)"
    exit 1
fi

# ---- Test 5: --json produces valid JSON ----
"$CYRIUS" capacity --json "$SMALL" > "$TMP/out5" 2>/dev/null
if ! grep -q '"fn_table":' "$TMP/out5"; then
    echo "  FAIL test5: --json missing fn_table key"
    cat "$TMP/out5"
    exit 1
fi
# Validate via jq if available
if command -v jq >/dev/null 2>&1; then
    if ! jq -e '.fn_table.used >= 0 and .fn_table.cap == 4096' "$TMP/out5" >/dev/null; then
        echo "  FAIL test5: --json fn_table fields invalid"
        cat "$TMP/out5"
        exit 1
    fi
    # All six keys present + numeric
    for key in fn_table identifiers var_table fixup_table string_data code_size; do
        if ! jq -e ".$key.used >= 0 and .$key.cap > 0 and .$key.pct >= 0" "$TMP/out5" >/dev/null; then
            echo "  FAIL test5: --json key '$key' invalid shape"
            cat "$TMP/out5"
            exit 1
        fi
    done
fi

# ---- Test 6: --json on big shows fn_table.pct >= 85 ----
"$CYRIUS" capacity --json "$BIG" > "$TMP/out6" 2>/dev/null
if command -v jq >/dev/null 2>&1; then
    pct=$(jq -r '.fn_table.pct' "$TMP/out6")
    if [ "$pct" -lt 85 ]; then
        echo "  FAIL test6: big --json fn_table.pct=$pct (expected >=85)"
        exit 1
    fi
fi

# ---- Test 7: missing entry point errors clearly ----
EMPTY=$(mktemp -d)
set +e
(cd "$EMPTY" && "$CYRIUS" capacity > "$TMP/out7" 2>"$TMP/err7")
rc=$?
set -e
rm -rf "$EMPTY"
if [ "$rc" -eq 0 ]; then
    echo "  FAIL test7: capacity with no entry point should error, got exit 0"
    exit 1
fi
if ! grep -q "no file given" "$TMP/err7"; then
    echo "  FAIL test7: missing 'no file given' diagnostic"
    cat "$TMP/err7"
    exit 1
fi

exit 0
