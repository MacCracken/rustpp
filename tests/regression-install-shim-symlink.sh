#!/bin/sh
# Regression: install.sh --refresh-only must re-link ~/.cyrius/bin →
# versions/$VERSION/bin so the PATH-resolved cyrius/cc5/cyrfmt match
# the version recorded in ~/.cyrius/current. Pinned to v5.7.22.
#
# Pre-v5.7.22, --refresh-only refreshed versions/$VERSION/ but never
# touched ~/.cyrius/bin's symlink. version-bump.sh's standard usage
# (bump → refresh-only) left local devs with a stale ~/.cyrius/bin →
# old-version/bin symlink, so `cyrius --version` reported the wrong
# version even though the snapshot under versions/$VERSION/ was
# correct. CI didn't see this because each CI job does a fresh full
# install (not refresh-only). Local-dev footgun only.
#
# This gate uses an isolated CYRIUS_HOME (under TMPDIR) so it never
# touches the developer's real ~/.cyrius. Builds two fake "version"
# snapshots, runs install.sh --refresh-only against the second, and
# asserts ~/.cyrius/bin re-points at it.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/scripts/install.sh"
if [ ! -x "$INSTALL" ]; then
    echo "  skip: $INSTALL not executable"
    exit 0
fi
if [ ! -f "$ROOT/VERSION" ]; then
    echo "  skip: $ROOT/VERSION missing (refresh-only needs a repo context)"
    exit 0
fi

TMPDIR="${TMPDIR:-/tmp}"
FAKE="$TMPDIR/cyrius_install_shim_$$"
mkdir -p "$FAKE/versions"
trap 'rm -rf "$FAKE"' EXIT

fail=0

# Build a fake "old" version snapshot.
OLD_VERSION="0.0.1-test"
mkdir -p "$FAKE/versions/$OLD_VERSION/bin" "$FAKE/versions/$OLD_VERSION/lib"
echo "#!/bin/sh\necho stale-cyrius" > "$FAKE/versions/$OLD_VERSION/bin/cyrius"
chmod +x "$FAKE/versions/$OLD_VERSION/bin/cyrius"
echo "$OLD_VERSION" > "$FAKE/current"
echo "$OLD_VERSION" > "$FAKE/versions/$OLD_VERSION/VERSION"

# Point ~/.cyrius/bin at the OLD version (simulates the stale state).
ln -sf "$FAKE/versions/$OLD_VERSION/bin" "$FAKE/bin"
ln -sf "$FAKE/versions/$OLD_VERSION/lib" "$FAKE/lib"

# Sanity: the stale shim resolves to the old version's cyrius.
if [ "$(readlink "$FAKE/bin")" != "$FAKE/versions/$OLD_VERSION/bin" ]; then
    echo "  FAIL: setup — stale symlink not in expected pre-state"
    fail=$((fail + 1))
fi

# Now run install.sh --refresh-only (uses the current repo's VERSION).
CURRENT_VERSION=$(cat "$ROOT/VERSION")
( cd "$ROOT" && CYRIUS_HOME="$FAKE" sh "$INSTALL" --refresh-only > "$FAKE/refresh.out" 2>&1 )
ec=$?
if [ "$ec" -ne 0 ]; then
    echo "  FAIL: --refresh-only exit $ec"
    cat "$FAKE/refresh.out"
    fail=$((fail + 1))
fi

# Post-refresh: ~/.cyrius/bin must point at versions/$CURRENT_VERSION/bin.
expected="$FAKE/versions/$CURRENT_VERSION/bin"
actual=$(readlink "$FAKE/bin" 2>/dev/null)
if [ "$actual" != "$expected" ]; then
    echo "  FAIL: ~/.cyrius/bin not re-linked"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    fail=$((fail + 1))
fi

# And ~/.cyrius/lib too.
expected_lib="$FAKE/versions/$CURRENT_VERSION/lib"
actual_lib=$(readlink "$FAKE/lib" 2>/dev/null)
if [ "$actual_lib" != "$expected_lib" ]; then
    echo "  FAIL: ~/.cyrius/lib not re-linked"
    echo "    expected: $expected_lib"
    echo "    actual:   $actual_lib"
    fail=$((fail + 1))
fi

if [ "$fail" -eq 0 ]; then
    echo "  PASS: install.sh --refresh-only re-links ~/.cyrius/bin + lib"
    exit 0
fi
exit 1
