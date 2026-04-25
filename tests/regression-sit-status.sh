#!/bin/sh
# Regression: sit status / sit fsck on a 100-commit fixture.
#
# PINNED: cyrius v5.6.35 (shipped; sankoch 2.0.3 fixes the
# deflate non-roundtrip bug that surfaced as sit symptom 2).
#
# Background: sit S-33 triage 2026-04-24 surfaced TWO symptoms in
# sit's `sit status` SIGSEGV on a 100-commit / 100-file fixture.
# Symptom 1 was a cyrius `lib/alloc.cyr` grow-undersize bug
# (silent SIGSEGV on `alloc(>1 MB)` near the grow boundary) —
# fixed in cyrius v5.6.34. Symptom 2 was that AFTER the alloc fix
# `sit fsck` reports ~20% of objects unreadable, with `read_object`
# returning -7 on the zlib retry. v5.6.35 triage pinned the layer
# to sankoch's `zlib_compress` producing non-decompressible DEFLATE
# for sit-tree-shaped inputs. sankoch 2.0.2 fixed 51/53 cases;
# sankoch 2.0.3 fixed the remaining 2; cyrius v5.6.35 bumps the
# `cyrius.cyml` sankoch pin to 2.0.3 and ships this gate active.
# Repro artifacts at `docs/development/issues/repros/sankoch-2.0.1-deflate-non-roundtrip.{bin,cyr}`
# (kept committed; original 751-byte case still verifies under 2.0.3).
#
# Skip cleanly if:
#   - sit isn't checked out at ../sit,
#   - sit's build/sit isn't fresh against the current cyrius.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIT_DIR="${SIT_DIR:-$ROOT/../sit}"

if [ ! -d "$SIT_DIR" ]; then
    echo "  skip: sit not present at $SIT_DIR (export SIT_DIR=... to override)"
    exit 0
fi

if [ ! -x "$SIT_DIR/build/sit" ]; then
    echo "  skip: $SIT_DIR/build/sit not built"
    exit 0
fi

D=$(mktemp -d)
trap "rm -rf $D" EXIT

cd "$D"
"$SIT_DIR/build/sit" init >/dev/null

i=0
while [ $i -lt 100 ]; do
    echo "file $i content" > "f$i.txt"
    "$SIT_DIR/build/sit" add "f$i.txt" >/dev/null 2>&1 || { echo "  FAIL: add f$i failed"; exit 1; }
    "$SIT_DIR/build/sit" commit -m "c$i" >/dev/null 2>&1 || { echo "  FAIL: commit c$i failed"; exit 1; }
    i=$((i+1))
done

# fsck must report 0 bad objects.
fsck_out=$("$SIT_DIR/build/sit" fsck 2>&1) || true
bad=$(echo "$fsck_out" | grep -oE 'checked [0-9]+ objects, [0-9]+ bad' | grep -oE '[0-9]+ bad' | grep -oE '^[0-9]+')
if [ -z "$bad" ]; then
    echo "  FAIL: fsck output not parseable: $fsck_out"
    exit 1
fi
if [ "$bad" -ne 0 ]; then
    echo "  FAIL: fsck reports $bad bad objects (expected 0)"
    exit 1
fi

# status must exit 0.
"$SIT_DIR/build/sit" status >/dev/null 2>&1 || { echo "  FAIL: status non-zero exit"; exit 1; }

echo "  PASS sit 100-commit fixture (status + fsck clean)"
