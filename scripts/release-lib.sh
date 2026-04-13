#!/bin/sh
# Copy stdlib + dep bundles into a release staging directory.
# Usage: sh scripts/release-lib.sh <stage-lib-dir>
#
# Copies real .cyr files from lib/, follows valid symlinks,
# fetches dep bundles from GitHub when symlinks are broken (CI).

set -e
DEST="$1"
if [ -z "$DEST" ]; then echo "Usage: release-lib.sh <dest-dir>"; exit 1; fi
mkdir -p "$DEST"

# 1. Copy all real files and valid symlinks
for f in lib/*.cyr; do
    [ -f "$f" ] || continue
    if [ -L "$f" ]; then
        [ -e "$f" ] && cp -L "$f" "$DEST/" || true
    else
        cp "$f" "$DEST/"
    fi
done

# 2. Dep bundles — fetch from GitHub if not already copied
#    Format: repo tag path-in-repo
DEPS="
sakshi    0.9.0   sakshi.cyr
sakshi    0.9.0   sakshi_full.cyr
sigil     2.0.1   dist/sigil.cyr
patra     0.14.0  dist/patra.cyr
yukti     1.2.0   dist/yukti.cyr
mabda     2.1.2   dist/mabda.cyr
"

echo "$DEPS" | while read -r REPO TAG FILE; do
    [ -z "$REPO" ] && continue
    BASE=$(basename "$FILE")
    if [ ! -f "$DEST/$BASE" ]; then
        URL="https://raw.githubusercontent.com/MacCracken/$REPO/$TAG/$FILE"
        printf "  fetch: %s@%s → %s\n" "$REPO" "$TAG" "$BASE"
        curl -sfL "$URL" -o "$DEST/$BASE" || echo "  WARN: failed to fetch $BASE"
    fi
done

COUNT=$(ls "$DEST"/*.cyr 2>/dev/null | wc -l)
echo "  $COUNT stdlib files staged"
