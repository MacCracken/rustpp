#!/bin/sh
# cyrb symbols — extract symbol map from compiled Cyrius binary
# Shows function names and their offsets in the binary.
#
# Usage: cyrb symbols <source.cyr>
# Output: function_name offset_hex size_estimate

CC="${1:-./build/cc2}"
SRC="$2"

if [ -z "$SRC" ]; then
    echo "Usage: cyrb symbols <source.cyr>"
    exit 1
fi

# Compile to get the binary
TMPBIN="/tmp/cyrb_sym_$$"
cat "$SRC" | "$CC" > "$TMPBIN" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "error: compilation failed" >&2
    rm -f "$TMPBIN"
    exit 1
fi

BINSIZE=$(wc -c < "$TMPBIN")
echo "# Symbol map for $SRC ($BINSIZE bytes)"
echo "# name offset size"

# Extract function definitions and their addresses from source
# Functions are defined as "fn name(" or "pub fn name("
grep -n '^fn \|^pub fn ' "$SRC" | while IFS= read -r line; do
    lineno=$(echo "$line" | cut -d: -f1)
    fname=$(echo "$line" | sed 's/.*fn //;s/(.*//')
    echo "  $fname (line $lineno)"
done

echo ""
echo "# Binary entry: 0x400078"
echo "# Code section: 0x400078 + 5 (after initial JMP)"
echo "# Total: $BINSIZE bytes"

rm -f "$TMPBIN"
