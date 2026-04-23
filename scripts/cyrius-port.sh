#!/bin/sh
# cyrius port — prepare a non-Cyrius project for Cyrius porting.
# Moves source code to <lang>-old/, scaffolds Cyrius project structure,
# generates cyrius.cyml with deps, CI/release workflows.
#
# Usage: cyrius port [--language=<lang>] [--dry-run] <path-to-project>
#
# v5.6.0: --language=<x> selects the source language. Default `rust`
# (current behavior, made explicit). Future: `go`, `python`, etc.

set -e

DRY_RUN=0
LANGUAGE="rust"
TARGET=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --language=*) LANGUAGE="${arg#--language=}" ;;
        --language) echo "error: --language requires a value (rust)"; exit 1 ;;
        -*) echo "Unknown flag: $arg"; exit 1 ;;
        *) TARGET="$arg" ;;
    esac
done

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
    echo "Usage: cyrius port [--language=<lang>] [--dry-run] <path-to-project>"
    echo ""
    echo "Options:"
    echo "  --language=<x>  source language being ported FROM (default: rust)"
    echo "                  supported: rust  (future: go, python, …)"
    echo "  --dry-run       show what would be moved/created without writing"
    echo ""
    echo "Greenfield (no source to port) → use 'cyrius init [--language=none] <name>'"
    exit 1
fi

case "$LANGUAGE" in
    rust) ;;
    none)
        echo "error: --language=none has no source to port"
        echo "  hint: use 'cyrius init --language=none $TARGET' for greenfield scaffold"
        exit 1
        ;;
    go|python|c|cpp|zig|ocaml|haskell)
        echo "error: --language=$LANGUAGE not yet supported (planned for future v5.6.x)"
        echo "  currently supported: rust"
        exit 1
        ;;
    *)
        echo "error: unsupported --language=$LANGUAGE (supported: rust)"
        exit 1
        ;;
esac

cd "$TARGET"
NAME=$(basename "$(pwd)")

if [ ! -f "Cargo.toml" ]; then
    echo "error: no Cargo.toml found in $TARGET (--language=rust expects a Rust project)"
    exit 1
fi

if [ -d "rust-old" ]; then
    echo "error: rust-old/ already exists — project may already be ported"
    exit 1
fi

# Count Rust LOC
RUST_LOC=$(find src -name "*.rs" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: cyrius port $NAME"
    echo ""
    echo "Would move to rust-old/:"
    echo "  src/, Cargo.toml, Cargo.lock, tests/, benches/ etc."
    echo "  Rust source: ${RUST_LOC:-0} lines"
    echo ""
    echo "Would create:"
    echo "  src/main.cyr              (entry point skeleton)"
    echo "  cyrius.cyml               ([package] + [build] + [deps])"
    echo "  cyrius.cyml [package].cyrius = \"$CYRIUS_VER\"  (pins toolchain version)"
    echo "  .github/workflows/ci.yml"
    echo "  .github/workflows/release.yml"
    echo ""
    echo "After port: cyrius build src/main.cyr build/$NAME"
    exit 0
fi

echo "=== Porting $NAME to Cyrius ==="
echo "  Rust source: ${RUST_LOC:-0} lines"

# Move Rust code
mkdir -p rust-old
for item in src benches examples fuzz tests supply-chain include py \
    Cargo.toml Cargo.lock rust-toolchain.toml deny.toml codecov.yml \
    Makefile bench-history.csv benchmarks.md target rust_out; do
    if [ -e "$item" ]; then
        mv "$item" rust-old/
    fi
done
echo "  Moved Rust to rust-old/"
echo "${RUST_LOC:-0}" > rust-old/LINES_OF_RUST.txt

# Create structure
mkdir -p src tests build docs/development .github/workflows

# Detect current toolchain version (cascade: env → cc5 binary → install snapshot)
# NEVER hardcode a fallback here — stale fallbacks silently seed ancient versions
# into freshly-ported projects (the v5.4.12 release-lib.sh drift class).
CYRIUS_VER="${CYRIUS_VER:-}"
if [ -z "$CYRIUS_VER" ] && command -v cc5 >/dev/null 2>&1; then
    CYRIUS_VER=$(cc5 --version 2>&1 | head -1 | awk '{print $2}')
fi
if [ -z "$CYRIUS_VER" ] && [ -f "$HOME/.cyrius/current" ]; then
    CYRIUS_VER=$(tr -d '[:space:]' < "$HOME/.cyrius/current")
fi
if [ -z "$CYRIUS_VER" ]; then
    echo "  error: no cyrius toolchain detected — install first or set CYRIUS_VER" >&2
    exit 1
fi
# Toolchain version is pinned in cyrius.cyml as `cyrius = "X.Y.Z"` —
# the manifest is the single source of truth. Legacy `.cyrius-toolchain`
# is no longer written or read; CI/release workflows below grep the
# manifest directly.

# Generate source skeleton (no manual includes — auto-included via cyrius.cyml)
cat > src/main.cyr << CYRSRC
# $NAME — Cyrius port
# Ported from ${RUST_LOC:-0} lines of Rust

# Stdlib auto-included via cyrius.cyml

fn main() {
    alloc_init();
    println("$NAME ready");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
CYRSRC
echo "  Created src/main.cyr"

# Generate cyrius.cyml
cat > cyrius.cyml << TOML
[package]
name = "$NAME"
version = "0.1.0"
description = "$NAME — Cyrius port (from ${RUST_LOC:-0} lines of Rust)"
license = "GPL-3.0-only"
language = "cyrius"
cyrius = "$CYRIUS_VER"

[build]
entry = "src/main.cyr"
output = "$NAME"

[deps]
stdlib = ["string", "fmt", "alloc", "vec", "str", "syscalls", "io", "args", "assert"]
TOML
echo "  Created cyrius.cyml"

# Generate .gitignore — mirrors cyrius-init.sh plus /rust-old/target/ so a
# local `cargo build` in rust-old/ (for parity checks against the port) does
# not drop hundreds of MB of build artifacts into git.
if [ ! -f .gitignore ]; then
    cat > .gitignore << 'GITIGNORE'
# Build output
/build/
/rust-old/target/

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Claude Code
.claude/

# Core dumps
*.core

# Environment / secrets
.env
.env.*
*.pem
*.key

# Coverage
/coverage/
*.profraw
*.profdata
GITIGNORE
    echo "  Created .gitignore"
else
    # .gitignore exists (carried over from Rust project) — ensure rust-old/target/ is covered
    if ! grep -qE '^/?rust-old/target/?' .gitignore; then
        printf "\n# Cyrius port\n/rust-old/target/\n/build/\n" >> .gitignore
        echo "  Appended /rust-old/target/ and /build/ to existing .gitignore"
    fi
fi

# Generate CI workflow
cat > .github/workflows/ci.yml << 'CI'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_call:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Cyrius toolchain
        run: |
          CYRIUS_VERSION="${CYRIUS_VERSION:-$(grep 'cyrius *= *"' cyrius.cyml 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/')}"
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

  docs:
    name: Documentation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check required docs
        run: |
          for doc in README.md CHANGELOG.md VERSION LICENSE cyrius.cyml; do
            test -f "$doc" && echo "OK: $doc" || { echo "MISSING: $doc"; exit 1; }
          done
CI
echo "  Created .github/workflows/ci.yml"

# Generate release workflow
cat > .github/workflows/release.yml << 'RELEASE'
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
          CYRIUS_VERSION="${CYRIUS_VERSION:-$(grep 'cyrius *= *"' cyrius.cyml 2>/dev/null | head -1 | sed 's/.*"\(.*\)"/\1/')}"
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
echo "  Created .github/workflows/release.yml"

# Generate test file
cat > tests/${NAME}.tcyr << TCYR
# ${NAME} test suite

fn main() {
    alloc_init();
    test_group("smoke");
    assert(1, "true is true");
    assert_eq(1 + 1, 2, "math works");
    return assert_summary();
}

var exit_code = main();
syscall(60, exit_code);
TCYR
echo "  Created tests/${NAME}.tcyr"

# Generate bench file
cat > tests/${NAME}.bcyr << BCYR
# ${NAME} benchmarks

fn bench_noop() { return 0; }

fn main() {
    alloc_init();
    bench("noop", &bench_noop, 1000000);
    return 0;
}

var r = main();
syscall(60, r);
BCYR
echo "  Created tests/${NAME}.bcyr"

# Generate fuzz harness
cat > tests/${NAME}.fcyr << FCYR
# ${NAME} fuzz harness

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
FCYR
echo "  Created tests/${NAME}.fcyr"

echo ""
echo "=== $NAME ready for porting ==="
echo "  Rust (rust-old/): ${RUST_LOC:-0} lines"
echo "  Cyrius (src/):    skeleton + test + bench + fuzz"
echo "  Toolchain:        $CYRIUS_VER (cyrius.cyml)"
echo ""
echo "Next steps:"
echo "  1. Read rust-old/src/ to understand the API"
echo "  2. Port module by module into src/main.cyr"
echo "  3. Add deps to cyrius.cyml as needed"
echo "  4. Build: cyrius build src/main.cyr build/$NAME"
echo "  5. Test:  cyrius test tests/${NAME}.tcyr"
echo "  6. Bench: cyrius bench tests/${NAME}.bcyr"
