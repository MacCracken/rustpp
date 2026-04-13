#!/bin/sh
# cyrius init — scaffold a new Cyrius project
# Usage: cyrius-init.sh <project-name>
#
# Creates a complete Cyrius project with vendored stdlib,
# build/test scripts, and documentation templates.

set -e

DRY_RUN=0
NAME=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -*) echo "Unknown flag: $arg"; exit 1 ;;
        *) NAME="$arg" ;;
    esac
done

if [ -z "$NAME" ]; then
    echo "Usage: cyrius init [--dry-run] <project-name>"
    echo ""
    echo "Creates a new Cyrius project with:"
    echo "  cyrius.toml    project manifest + deps"
    echo "  src/main.cyr   entry point"
    echo "  src/test.cyr   test file"
    echo "  lib/           resolved stdlib (via cyrius deps)"
    echo "  scripts/       build + test"
    echo "  docs, CI, version files"
    echo ""
    echo "Options:"
    echo "  --dry-run      show what would be created without writing"
    exit 1
fi

CYRIUS="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: cyrius init $NAME"
    echo ""
    echo "Would create:"
    echo "  $NAME/"
    echo "  $NAME/src/main.cyr"
    echo "  $NAME/src/test.cyr"
    echo "  $NAME/cyrius.toml"
    echo "  $NAME/VERSION            (0.1.0)"
    echo "  $NAME/.gitignore"
    echo "  $NAME/LICENSE            (GPL-3.0-only)"
    echo "  $NAME/README.md"
    echo "  $NAME/CHANGELOG.md"
    echo "  $NAME/CONTRIBUTING.md"
    echo "  $NAME/SECURITY.md"
    echo "  $NAME/CODE_OF_CONDUCT.md"
    echo "  $NAME/CLAUDE.md"
    echo "  $NAME/tests/${NAME}.tcyr   (test suite)"
    echo "  $NAME/tests/${NAME}.bcyr   (benchmarks)"
    echo "  $NAME/tests/${NAME}.fcyr   (fuzz harness)"
    echo "  $NAME/.cyrius-toolchain  (pins Cyrius version)"
    echo "  $NAME/.github/workflows/ci.yml"
    echo "  $NAME/.github/workflows/release.yml"
    echo "  $NAME/docs/development/"
    echo ""
    echo "After init, run: cd $NAME && cyrius deps && cyrius build src/main.cyr build/$NAME"
    exit 0
fi

if [ -d "$NAME" ]; then
    echo "ERROR: directory '$NAME' already exists"
    exit 1
fi

PROJ="$(basename "$NAME")"
echo "Creating Cyrius project: $PROJ"

# Create structure
mkdir -p "$NAME/src" "$NAME/lib/agnosys" "$NAME/scripts" "$NAME/build" "$NAME/docs/development" "$NAME/.github/workflows"

# === VERSION ===
echo "0.1.0" > "$NAME/VERSION"

# === .gitignore ===
cat > "$NAME/.gitignore" << 'GITIGNORE'
/build/
*.core
.claude/
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
.env
.env.*
*.pem
*.key
GITIGNORE

# === LICENSE ===
cat > "$NAME/LICENSE" << 'LICENSE'
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License only.

See https://www.gnu.org/licenses/gpl-3.0.html for full text.
LICENSE

# === README.md ===
cat > "$NAME/README.md" << EOF
# $PROJ

Written in [Cyrius](https://github.com/MacCracken/cyrius).

## Build

\`\`\`sh
cyrius build src/main.cyr build/$PROJ
cyrius test src/test.cyr
\`\`\`

## License

GPL-3.0-only
EOF

# === CHANGELOG.md ===
cat > "$NAME/CHANGELOG.md" << 'CHANGELOG'
# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0]

### Added
- Initial project scaffold
CHANGELOG

# === cyrius.toml ===
cat > "$NAME/cyrius.toml" << EOF
[package]
name = "$PROJ"
version = "0.1.0"
description = ""
license = "GPL-3.0-only"
language = "cyrius"

[build]
entry = "src/main.cyr"
test = "src/test.cyr"
output = "$PROJ"

[deps]
stdlib = ["string", "fmt", "alloc", "io", "vec", "str", "syscalls", "assert"]
EOF

# === src/main.cyr ===
cat > "$NAME/src/main.cyr" << EOF
# $PROJ — main entry point
# Stdlib auto-included via cyrius.toml

fn main() {
    alloc_init();
    println("hello from $PROJ");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
EOF

# === tests/test.tcyr ===
mkdir -p "$NAME/tests"
cat > "$NAME/tests/${PROJ}.tcyr" << EOF
# $PROJ test suite
# Stdlib auto-included via cyrius.toml

fn main() {
    alloc_init();
    test_group("smoke");
    assert(1, "true is true");
    assert_eq(1 + 1, 2, "math works");
    return assert_summary();
}

var exit_code = main();
syscall(60, exit_code);
EOF

# === tests/bench.bcyr ===
cat > "$NAME/tests/${PROJ}.bcyr" << EOF
# $PROJ benchmarks
# Stdlib auto-included via cyrius.toml

fn bench_noop() { return 0; }

fn main() {
    alloc_init();
    bench("noop", &bench_noop, 1000000);
    return 0;
}

var r = main();
syscall(60, r);
EOF

# === tests/fuzz.fcyr ===
cat > "$NAME/tests/${PROJ}.fcyr" << EOF
# $PROJ fuzz harness

fn fuzz_main(data, len) {
    if (len == 0) { return 0; }
    return 0;
}

fn main() {
    alloc_init();
    fuzz_main("test", 4);
    println("fuzz: ok");
    return 0;
}

var r = main();
syscall(60, r);
EOF

# === .cyrius-toolchain ===
CYRIUS_VER="${CYRIUS_VER:-4.2.1}"
echo "$CYRIUS_VER" > "$NAME/.cyrius-toolchain"

# === CI ===
cat > "$NAME/.github/workflows/ci.yml" << 'CI'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-test:
    name: Build & Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Cyrius toolchain
        run: |
          CYRIUS_VERSION="${CYRIUS_VERSION:-$(cat .cyrius-toolchain | tr -d '[:space:]')}"
          echo "Installing Cyrius $CYRIUS_VERSION"
          curl -sLO "https://github.com/MacCracken/cyrius/releases/download/$CYRIUS_VERSION/cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
          tar xzf "cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
          CYRIUS_DIR="cyrius-$CYRIUS_VERSION-x86_64-linux"
          mkdir -p "$HOME/.cyrius/bin" "$HOME/.cyrius/lib"
          cp "$CYRIUS_DIR/bin/"* "$HOME/.cyrius/bin/" 2>/dev/null || true
          cp -r "$CYRIUS_DIR/lib/"* "$HOME/.cyrius/lib/" 2>/dev/null || true
          chmod +x "$HOME/.cyrius/bin/"* 2>/dev/null || true
          echo "$HOME/.cyrius/bin" >> $GITHUB_PATH
          echo "CYRIUS_HOME=$HOME/.cyrius" >> $GITHUB_ENV

      - name: Resolve dependencies
        run: cyrius deps

      - name: Build
        run: |
          mkdir -p build
          cyrius build src/main.cyr build/${{ github.event.repository.name }}

      - name: Test
        run: cyrius test src/test.cyr
CI

# === Release workflow ===
cat > "$NAME/.github/workflows/release.yml" << 'RELEASE'
name: Release

on:
  push:
    tags: ['[0-9]*']

permissions:
  contents: write

jobs:
  ci:
    name: CI Gate
    uses: ./.github/workflows/ci.yml

  release:
    name: Build & Release
    needs: [ci]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Verify version
        run: |
          FILE_VERSION=$(cat VERSION | tr -d '[:space:]')
          TAG_VERSION="${GITHUB_REF_NAME}"
          test "$FILE_VERSION" = "$TAG_VERSION" || { echo "VERSION ($FILE_VERSION) != tag ($TAG_VERSION)"; exit 1; }

      - name: Install Cyrius toolchain
        run: |
          CYRIUS_VERSION="${CYRIUS_VERSION:-$(cat .cyrius-toolchain | tr -d '[:space:]')}"
          echo "Installing Cyrius $CYRIUS_VERSION"
          curl -sLO "https://github.com/MacCracken/cyrius/releases/download/$CYRIUS_VERSION/cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
          tar xzf "cyrius-$CYRIUS_VERSION-x86_64-linux.tar.gz"
          CYRIUS_DIR="cyrius-$CYRIUS_VERSION-x86_64-linux"
          mkdir -p "$HOME/.cyrius/bin" "$HOME/.cyrius/lib"
          cp "$CYRIUS_DIR/bin/"* "$HOME/.cyrius/bin/" 2>/dev/null || true
          cp -r "$CYRIUS_DIR/lib/"* "$HOME/.cyrius/lib/" 2>/dev/null || true
          chmod +x "$HOME/.cyrius/bin/"* 2>/dev/null || true
          echo "$HOME/.cyrius/bin" >> $GITHUB_PATH
          echo "CYRIUS_HOME=$HOME/.cyrius" >> $GITHUB_ENV

      - name: Build
        run: |
          cyrius deps
          mkdir -p build
          cyrius build src/main.cyr build/${{ github.event.repository.name }}

      - name: Create release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          files: build/*
RELEASE

# === Vendor stdlib ===
echo "Vendoring Cyrius stdlib..."
CYRIUS_HOME="${CYRIUS_HOME:-$HOME/.cyrius}"
CYRIUS_VER=$(cat "$CYRIUS_HOME/current" 2>/dev/null)
CYRIUS_LIB=""
if [ -n "$CYRIUS_VER" ] && [ -d "$CYRIUS_HOME/versions/$CYRIUS_VER/lib" ]; then
    CYRIUS_LIB="$CYRIUS_HOME/versions/$CYRIUS_VER/lib"
elif [ -d "$CYRIUS/lib" ]; then
    CYRIUS_LIB="$CYRIUS/lib"
fi
if [ -n "$CYRIUS_LIB" ]; then
    for f in "$CYRIUS_LIB"/*.cyr; do
        [ -f "$f" ] && cp "$f" "$NAME/lib/"
    done
else
    echo "  warn: Cyrius stdlib not found, lib/ will be empty"
fi

# === Done ===
LIB_COUNT=$(find "$NAME/lib" -name '*.cyr' | wc -l)
echo ""
echo "Created $NAME/"
echo "  $LIB_COUNT stdlib modules vendored"
echo "  src/main.cyr — entry point"
echo "  src/test.cyr — test file"
echo ""
echo "Next steps:"
echo "  cd $NAME"
echo "  sh scripts/build.sh"
echo "  sh scripts/test.sh"
