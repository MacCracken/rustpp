#!/bin/sh
# Heap map audit — detects overlapping regions and tight gaps.
# Parses the authoritative heap map from src/main.cyr comments.
# Run: sh tests/heapmap.sh
# Exit 0 = clean, exit 1 = overlaps found.

set -e

MAIN="src/main.cyr"
if [ ! -f "$MAIN" ]; then
    echo "error: $MAIN not found (run from repo root)" >&2
    exit 1
fi

# Extract heap map entries from main.cyr.
# Format:  #   0xOFFSET  name  [BYTES]  description
# Some names have array syntax: name[N] — the [N] is element count, not byte size.
# The byte size is the LAST [NUMBER] on the line.

awk '
BEGIN { n = 0; errors = 0; warnings = 0 }

# Match heap map comment lines.
# v5.5.40: relaxed the space requirement from `  +` (2+) to ` +` (1+)
# — previously, entries where the hex offset was 7+ chars wide (e.g.
# 0x11A000, 0x150B000) had only ONE space before the name due to
# column alignment, which silently dropped them from the audit.
# Every region past 0xFC000 was invisible until this fix.
/^#   0x[0-9A-Fa-f]+ +[a-zA-Z_]/ {
    # Extract offset
    match($0, /0x[0-9A-Fa-f]+/)
    offset_str = substr($0, RSTART, RLENGTH)

    # Extract name (word after offset)
    split($0, parts)
    name = ""
    for (i = 1; i <= length(parts); i++) {
        if (parts[i] ~ /^0x/) {
            name = parts[i+1]
            break
        }
    }
    # Strip trailing array index from name for display
    gsub(/\[.*/, "", name)

    # Find byte size: last [NUMBER] on line (skip name[N] patterns)
    size = 0
    line = $0
    while (match(line, /\[([0-9]+)\]/, arr)) {
        size = arr[1] + 0
        line = substr(line, RSTART + RLENGTH)
    }

    if (name != "" && size > 0) {
        # Skip entries marked (nested — intentionally inside a larger region
        if ($0 ~ /\(nested/) { next }
        offsets[n] = strtonum(offset_str)
        sizes[n] = size
        names[n] = name
        n++
    }
}

END {
    # Sort by offset (insertion sort)
    for (i = 1; i < n; i++) {
        j = i
        while (j > 0 && offsets[j] < offsets[j-1]) {
            t = offsets[j]; offsets[j] = offsets[j-1]; offsets[j-1] = t
            t = sizes[j]; sizes[j] = sizes[j-1]; sizes[j-1] = t
            t = names[j]; names[j] = names[j-1]; names[j-1] = t
            j--
        }
    }

    printf "Heap map: %d regions parsed from %s\n\n", n, "src/main.cyr"

    for (i = 0; i < n; i++) {
        end_addr = offsets[i] + sizes[i]
        printf "  0x%05X  +%-6d  -> 0x%05X  %s\n", offsets[i], sizes[i], end_addr, names[i]

        if (i < n - 1) {
            gap = offsets[i+1] - end_addr
            if (gap < 0) {
                printf "  ** OVERLAP: %s (ends 0x%05X) overlaps %s (starts 0x%05X) by %d bytes **\n", \
                    names[i], end_addr, names[i+1], offsets[i+1], -gap
                errors++
            } else if (gap >= 0 && gap < 16 && gap > 0) {
                printf "  ~~ WARNING: %d-byte gap before %s ~~\n", gap, names[i+1]
                warnings++
            }
        }
    }

    printf "\n"
    if (errors > 0) {
        printf "FAIL: %d overlap(s), %d warning(s)\n", errors, warnings
        exit 1
    } else {
        printf "PASS: no overlaps (%d regions, %d warnings)\n", n, warnings
    }
}
' "$MAIN"
