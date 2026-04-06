#!/bin/sh
# Version bump script — update VERSION + install.sh fallback
# Usage: ./scripts/version-bump.sh 0.9.4

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Current: $(cat VERSION)"
    exit 1
fi

NEW="$1"
OLD=$(cat VERSION | tr -d '[:space:]')

echo "$NEW" > VERSION
sed -i "s/VERSION=\"$OLD\"/VERSION=\"$NEW\"/" scripts/install.sh 2>/dev/null || true

echo "$OLD -> $NEW"
echo "Updated: VERSION"
echo ""
echo "Remember to:"
echo "  1. Update CHANGELOG.md"
echo "  2. Commit"
echo "  3. git tag $NEW && git push origin $NEW"
