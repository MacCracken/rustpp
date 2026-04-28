#!/bin/sh
# Regression: cross-backend token-offset parity.
#
# Pinned to v5.7.28. v5.7.27's heap reshuffle (codebuf 1 MB → 3 MB
# + 19-region shift +0x200000) shifted the SHARED frontend lex's
# write offsets:
#
#   tok_types  0x74A000 → 0x94A000
#   tok_values 0xB4A000 → 0xD4A000
#   tok_lines  0xD4A000 → 0xF4A000
#
# x86 + aarch64 backends were shifted in lockstep, but `src/backend/
# cx/emit.cyr` was deliberately skipped (it has its own codebuf at
# 0x54A000 and per-fn region at 0x150B000, both unchanged by the
# reshuffle). The skip OVER-applied — cx/emit.cyr also defines
# `TOKTYP` / `TOKVAL` that read the SHARED frontend tokens at the
# same offsets the main backends use. Skipping them left cx/emit.cyr
# reading from the OLD (now-vacated) offsets, which made cc5_cx
# silently broken on every input (lex emits "unexpected unknown" on
# what looks like garbage tokens because cx is reading from the new
# codebuf region instead of from the new tok_types region).
#
# The bug stayed invisible because the cx regression gates have a
# separate `set -e + pipeline` issue (queued v5.7.29) that masked
# any cc5_cx failure: `set -e` aborts the gate before the gate's
# explicit failure reporting can fire. Pipe-masking in the
# `check.sh 2>&1 | tail -3` verification idiom then made check.sh
# look like it was passing 47/47 when it was actually aborting at
# the cx-build gate.
#
# This gate guards the lex-write / backend-read parity at the
# **source level** so the next heap reshuffle can't slip past
# without a synchronized backend update. It greps each backend's
# `TOKTYP` / `TOKVAL` definitions and the shared lex's write sites,
# extracts the hex offsets, and asserts they all agree.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Extract a single hex offset from a known-shape line. Args:
#   $1 = file path (relative to repo root)
#   $2 = anchor pattern that uniquely identifies the line
# Returns the offset on stdout (e.g. `0x94A000`); empty string if
# not found.
extract_hex() {
    local f="$1" pat="$2"
    grep -E "$pat" "$ROOT/$f" 2>/dev/null \
        | grep -oE '0x[0-9A-Fa-f]+' \
        | head -1
}

fail=0

# === lex writes (canonical source of truth) ===================
LEX_TYP=$(extract_hex "src/frontend/lex.cyr" 'S64\(S \+ 0x[0-9A-Fa-f]+ \+ tc \* 8, typ\)')
LEX_VAL=$(extract_hex "src/frontend/lex.cyr" 'S64\(S \+ 0x[0-9A-Fa-f]+ \+ tc \* 8, val\)')
LEX_LINE=$(extract_hex "src/common/util.cyr" 'fn STLINE\(S, ti, v\) \{ S64')

if [ -z "$LEX_TYP" ] || [ -z "$LEX_VAL" ] || [ -z "$LEX_LINE" ]; then
    echo "  FAIL: could not extract lex/util write offsets — script needs update"
    echo "    LEX_TYP='$LEX_TYP' LEX_VAL='$LEX_VAL' LEX_LINE='$LEX_LINE'"
    exit 1
fi

# === per-backend reads — must match ===========================
check_backend() {
    local name="$1" file="$2"
    local typ val
    typ=$(extract_hex "$file" 'fn TOKTYP\(S, i\) \{')
    val=$(extract_hex "$file" 'fn TOKVAL\(S, i\) \{')

    if [ -z "$typ" ] || [ -z "$val" ]; then
        echo "  FAIL: $name backend ($file) — missing TOKTYP / TOKVAL definitions"
        fail=$((fail + 1))
        return
    fi
    if [ "$typ" != "$LEX_TYP" ]; then
        echo "  FAIL: $name TOKTYP reads $typ, lex writes typ at $LEX_TYP — drift!"
        fail=$((fail + 1))
    fi
    if [ "$val" != "$LEX_VAL" ]; then
        echo "  FAIL: $name TOKVAL reads $val, lex writes val at $LEX_VAL — drift!"
        fail=$((fail + 1))
    fi
}

check_backend "x86"     "src/backend/x86/emit.cyr"
check_backend "aarch64" "src/backend/aarch64/emit.cyr"
check_backend "cx"      "src/backend/cx/emit.cyr"

# === GTLINE in util.cyr — also a token-region read ============
GTLINE=$(extract_hex "src/common/util.cyr" 'fn GTLINE\(S, ti\) \{ return L64')
if [ "$GTLINE" != "$LEX_LINE" ]; then
    echo "  FAIL: util.cyr GTLINE reads $GTLINE, STLINE writes at $LEX_LINE — drift!"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: lex tokens (typ=$LEX_TYP, val=$LEX_VAL, line=$LEX_LINE) — all backends in sync (v5.7.28)"
    exit 0
fi
echo "  FAIL: $fail token-offset parity issue(s)"
exit 1
