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

# 3b. cc5 --version string in src/main.cyr
# Permissive regex — matches any "cc5 X.Y.Z\n" so the version string can't
# drift silently if a previous bump missed this file (as happened between
# 3.4.10 and 3.4.15). Also re-computes the syscall write length since the
# string is a constant literal and the length argument is hard-coded.
if [ -f src/main.cyr ]; then
    if grep -Eq '"cc5 [0-9]+\.[0-9]+\.[0-9]+\\n"' src/main.cyr; then
        sed -i -E "s|\"cc5 [0-9]+\.[0-9]+\.[0-9]+\\\\n\"|\"cc5 $NEW\\\\n\"|" src/main.cyr
        # "cc5 X.Y.Z\n" is len(X.Y.Z) + 5 bytes (cc5 + space + \n)
        NEW_LEN=$((${#NEW} + 5))
        sed -i -E "s|(\"cc5 $NEW\\\\n\", )[0-9]+\)|\1$NEW_LEN)|" src/main.cyr
    else
        echo "  warning: no cc5 version string found in src/main.cyr" >&2
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

# 6. Install-snapshot refresh (v5.4.18): reconcile
# ~/.cyrius/versions/$NEW/ with the current repo so a dep bump or
# new tool appears immediately — no waiting for the next full install.
# install.sh --refresh-only skips tarball fetch / bootstrap and just
# re-copies build/ + scripts/ named in cyrius.cyml [release] + lib/.
# Skipped silently if install.sh is missing (shouldn't happen in a
# normal cyrius checkout).
if [ -x scripts/install.sh ]; then
    sh scripts/install.sh --refresh-only 2>/dev/null || \
        echo "  warning: install-snapshot refresh failed (non-fatal)" >&2
fi

echo "$OLD -> $NEW"
echo ""
echo "Updated:"
echo "  VERSION"
echo "  CLAUDE.md"
echo "  CHANGELOG.md"
echo "  docs/development/roadmap.md"
echo "  scripts/install.sh"
echo "  ~/.cyrius/versions/$NEW/ (install snapshot refreshed)"
echo ""
echo "Still manual:"
echo "  - CHANGELOG.md entries (add Fixed/Changed/Added sections)"
echo "  - vidya version references (language.toml)"
echo "  - Compiler binary size in CLAUDE.md if changed"
