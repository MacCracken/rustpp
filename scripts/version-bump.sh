#!/bin/sh
# Version bump script — single source of truth for all version references
# Usage: ./scripts/version-bump.sh 1.9.0

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

# 3b. cc3 --version string in src/main.cyr
# Permissive regex — matches any "cc3 X.Y.Z\n" so the version string can't
# drift silently if a previous bump missed this file (as happened between
# 3.4.10 and 3.4.15). Also re-computes the syscall write length since the
# string is a constant literal and the length argument is hard-coded.
if [ -f src/main.cyr ]; then
    if grep -Eq '"cc3 [0-9]+\.[0-9]+\.[0-9]+\\n"' src/main.cyr; then
        sed -i -E "s|\"cc3 [0-9]+\.[0-9]+\.[0-9]+\\\\n\"|\"cc3 $NEW\\\\n\"|" src/main.cyr
        # "cc3 X.Y.Z\n" is len(X.Y.Z) + 5 bytes (cc3 + space + \n)
        NEW_LEN=$((${#NEW} + 5))
        sed -i -E "s|(\"cc3 $NEW\\\\n\", )[0-9]+\)|\1$NEW_LEN)|" src/main.cyr
    else
        echo "  warning: no cc3 version string found in src/main.cyr" >&2
    fi
fi

# 4. CHANGELOG.md — add unreleased section if not present
if ! grep -q "## \[$NEW\]" CHANGELOG.md 2>/dev/null; then
    # Insert new version header after [Unreleased]
    sed -i "/## \[Unreleased\]/a\\
\\
## [$NEW] — $(date +%Y-%m-%d)" CHANGELOG.md 2>/dev/null || true
fi

# 5. Roadmap header
sed -i "s/> \*\*v$OLD\.\*\*/> **v$NEW.**/" docs/development/roadmap.md 2>/dev/null || true

# 6. cyrius — update version in installed copies
# When installed, cyrius can't read ../VERSION. Copy VERSION to version dir.
# The install.sh script copies this alongside the binaries.

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
