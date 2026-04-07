#!/bin/sh
# Version bump script — single source of truth for all version references
# Usage: ./scripts/version-bump.sh 1.7.7

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Current: $(cat VERSION)"
    exit 1
fi

NEW="$1"
OLD=$(cat VERSION | tr -d '[:space:]')

if [ "$NEW" = "$OLD" ]; then
    echo "Already at $OLD"
    exit 0
fi

# 1. VERSION file (source of truth)
echo "$NEW" > VERSION

# 2. install.sh fallback version
sed -i "s/VERSION=\"$OLD\"/VERSION=\"$NEW\"/" scripts/install.sh 2>/dev/null || true

# 3. CLAUDE.md
sed -i "s/- \*\*Version\*\*: $OLD/- **Version**: $NEW/" CLAUDE.md 2>/dev/null || true

# 4. CHANGELOG.md — add unreleased section if not present
if ! grep -q "## \[$NEW\]" CHANGELOG.md 2>/dev/null; then
    # Insert new version header after [Unreleased]
    sed -i "/## \[Unreleased\]/a\\
\\
## [$NEW] — $(date +%Y-%m-%d)" CHANGELOG.md 2>/dev/null || true
fi

# 5. Roadmap header
sed -i "s/> \*\*v$OLD\.\*\*/> **v$NEW.**/" docs/development/roadmap.md 2>/dev/null || true

echo "$OLD -> $NEW"
echo ""
echo "Updated:"
echo "  VERSION"
echo "  CLAUDE.md"
echo "  CHANGELOG.md"
echo "  docs/development/roadmap.md"
echo "  scripts/install.sh"
echo ""
echo "Still manual:"
echo "  - CHANGELOG.md entries (add Fixed/Changed/Added sections)"
echo "  - vidya version references (language.toml)"
echo "  - Compiler binary size in CLAUDE.md if changed"
