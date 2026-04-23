#!/bin/sh
# cyrius init — scaffold a new Cyrius project
# Usage: cyrius-init.sh [flags] <project-name | .>
#
# Creates a complete Cyrius project with vendored stdlib,
# build/test scripts, and documentation templates.
#
# v5.6.0: --language=<source-language-posture> selects target shape:
#   none (default) — greenfield scaffold; if target is `.` or already
#                    exists, runs in-place and skips-don't-overwrite
#                    any pre-existing file (safe for git-inited, docs-
#                    only repos).
#   rust           — declines and points at `cyrius port <path>`,
#                    which owns the rust→cyrius migration path.

set -e

DRY_RUN=0
AGENT=""
CMTOOLS=""
LANGUAGE="none"
NAME=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --agent) AGENT="generic" ;;
        --agent=*) AGENT="${arg#--agent=}" ;;
        --cmtools) CMTOOLS="starship" ;;
        --cmtools=*) CMTOOLS="${arg#--cmtools=}" ;;
        --language=*) LANGUAGE="${arg#--language=}" ;;
        --language) echo "error: --language requires a value (none|rust)"; exit 1 ;;
        -*) echo "Unknown flag: $arg"; exit 1 ;;
        *) NAME="$arg" ;;
    esac
done

# --language=rust → rust→cyrius migration is owned by `cyrius port`.
# Don't fork the migration logic into init; route the user to the right
# tool with a clear pointer.
if [ "$LANGUAGE" = "rust" ]; then
    echo "error: --language=rust is for rust→cyrius migration; use:"
    echo "  cyrius port ${NAME:-<path-to-rust-project>}"
    exit 1
fi

if [ "$LANGUAGE" != "none" ]; then
    echo "error: unsupported --language=$LANGUAGE (supported: none, rust)"
    echo "  none — greenfield scaffold (default; in-place safe)"
    echo "  rust — see 'cyrius port <path>'"
    exit 1
fi

if [ -z "$NAME" ]; then
    echo "Usage: cyrius init [flags] <project-name | .>"
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
    echo "  --language=<x>     source-language posture (none|rust); default none"
    echo "                     none — greenfield (in-place safe; skips existing files)"
    echo "                     rust — declines; use 'cyrius port <path>'"
    echo "  --dry-run          show what would be created without writing"
    echo "  --agent            create a CLAUDE.md for generic Cyrius projects"
    echo "  --agent=<preset>   create a CLAUDE.md from a preset (agnos, claude)"
    echo "  --cmtools          install CLI tool integrations (default: starship)"
    echo "  --cmtools=<name>   install specific tool (starship)"
    echo ""
    echo "Targets:"
    echo "  cyrius init my-proj                 → create ./my-proj/ (errors if exists)"
    echo "  cyrius init --language=none .       → scaffold INTO current dir (skip-existing)"
    echo "  cyrius init --language=none my-proj → if my-proj/ exists, scaffold in-place"
    exit 1
fi

CYRIUS="$(cd "$(dirname "$0")/.." && pwd)"

# In-place vs greenfield. v5.6.0: in-place mode is OPT-IN via NAME=`.`
# (always) — never auto-triggered by an existing dir match, since
# `cyrius init my-proj` against an unintentional preexisting `my-proj/`
# should still hard-error rather than silently scaffold over it. The
# in-place path makes every writer below skip-if-exists, so docs-only /
# git-inited repos at the cwd don't get clobbered.
INPLACE=0
if [ "$NAME" = "." ]; then
    INPLACE=1
    NAME="$(pwd)"
fi

if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$INPLACE" -eq 1 ]; then
        echo "Dry run: cyrius init --language=none $NAME (in-place, skip-existing)"
    else
        echo "Dry run: cyrius init $NAME"
    fi
    echo ""
    echo "Would create (skip if exists in in-place mode):"
    echo "  $NAME/"
    echo "  $NAME/src/main.cyr"
    echo "  $NAME/src/test.cyr"
    echo "  $NAME/cyrius.cyml"
    echo "  $NAME/VERSION            (0.1.0)"
    echo "  $NAME/.gitignore"
    echo "  $NAME/LICENSE            (GPL-3.0-only)"
    echo "  $NAME/README.md"
    echo "  $NAME/CHANGELOG.md"
    echo "  $NAME/CONTRIBUTING.md"
    echo "  $NAME/SECURITY.md"
    echo "  $NAME/CODE_OF_CONDUCT.md"
    if [ -n "$AGENT" ]; then
        echo "  $NAME/CLAUDE.md          (agent preset: $AGENT)"
    fi
    echo "  $NAME/tests/${NAME}.tcyr   (test suite)"
    echo "  $NAME/tests/${NAME}.bcyr   (benchmarks)"
    echo "  $NAME/tests/${NAME}.fcyr   (fuzz harness)"
    echo "  $NAME/cyrius.cyml [package].cyrius  (pins Cyrius version)"
    echo "  $NAME/.github/workflows/ci.yml"
    echo "  $NAME/.github/workflows/release.yml"
    echo "  $NAME/docs/development/"
    echo ""
    echo "After init, run: cd $NAME && cyrius deps && cyrius build src/main.cyr build/$NAME"
    exit 0
fi

if [ "$INPLACE" -eq 0 ] && [ -d "$NAME" ]; then
    echo "ERROR: directory '$NAME' already exists"
    echo "  hint: use 'cyrius init --language=none $NAME' to scaffold in-place"
    exit 1
fi

PROJ="$(basename "$NAME")"
if [ "$INPLACE" -eq 1 ]; then
    echo "Initializing Cyrius project in-place: $PROJ ($NAME)"
else
    echo "Creating Cyrius project: $PROJ"
fi

# write_if_absent <path> <heredoc-marker>: stdin → file unless file
# already exists. In greenfield mode the file never exists, so this
# is a plain write; in-place mode it preserves any existing file the
# user already authored (README, CHANGELOG, .gitignore, LICENSE, etc).
write_if_absent() {
    if [ -e "$1" ]; then
        echo "  skip: $1 (already exists)"
        cat > /dev/null
        return 0
    fi
    cat > "$1"
}

# Toolchain version detection — must happen BEFORE cyrius.cyml is
# written so the manifest's `cyrius = "X.Y.Z"` pin is correct.
# Cascade: env → install VERSION → live cc5 → install snapshot. NEVER
# hardcode a fallback (stale fallbacks silently seed ancient versions
# into new projects — the v5.4.12 release-lib.sh drift class). The CI
# and release templates below grep this same field out of cyrius.cyml,
# so it is the single source of truth for downstream consumers.
CYRIUS_VER="${CYRIUS_VER:-}"
if [ -z "$CYRIUS_VER" ] && [ -f "$CYRIUS/VERSION" ]; then
    CYRIUS_VER=$(tr -d '[:space:]' < "$CYRIUS/VERSION")
fi
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

# Create structure (mkdir -p is idempotent — safe in both modes)
mkdir -p "$NAME/src" "$NAME/lib/agnosys" "$NAME/scripts" "$NAME/build" "$NAME/docs/development" "$NAME/.github/workflows"

# === VERSION ===
if [ -e "$NAME/VERSION" ]; then
    echo "  skip: $NAME/VERSION (already exists)"
else
    echo "0.1.0" > "$NAME/VERSION"
fi

# === .gitignore ===
write_if_absent "$NAME/.gitignore" << 'GITIGNORE'
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
write_if_absent "$NAME/LICENSE" << 'LICENSE'
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License only.

See https://www.gnu.org/licenses/gpl-3.0.html for full text.
LICENSE

# === README.md ===
write_if_absent "$NAME/README.md" << EOF
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
write_if_absent "$NAME/CHANGELOG.md" << 'CHANGELOG'
# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0]

### Added
- Initial project scaffold
CHANGELOG

# === cyrius.cyml ===
write_if_absent "$NAME/cyrius.cyml" << EOF
[package]
name = "$PROJ"
version = "0.1.0"
description = ""
license = "GPL-3.0-only"
language = "cyrius"
cyrius = "$CYRIUS_VER"

[build]
entry = "src/main.cyr"
test = "src/test.cyr"
output = "$PROJ"

[deps]
stdlib = ["string", "fmt", "alloc", "io", "vec", "str", "syscalls", "assert"]
---
EOF

# === src/main.cyr ===
write_if_absent "$NAME/src/main.cyr" << EOF
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
write_if_absent "$NAME/tests/${PROJ}.tcyr" << EOF
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
write_if_absent "$NAME/tests/${PROJ}.bcyr" << EOF
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
write_if_absent "$NAME/tests/${PROJ}.fcyr" << EOF
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

# === CI ===
write_if_absent "$NAME/.github/workflows/ci.yml" << 'CI'
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

      - name: Test
        run: cyrius test src/test.cyr
CI

# === Release workflow ===
write_if_absent "$NAME/.github/workflows/release.yml" << 'RELEASE'
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

# === CLAUDE.md (agent file, opt-in) ===
if [ -n "$AGENT" ]; then
    case "$AGENT" in
        generic)
            write_if_absent "$NAME/CLAUDE.md" << AGENT_EOF
# $PROJ

Written in [Cyrius](https://github.com/MacCracken/cyrius). Built with \`cyrius build\`.

## Build

\`\`\`sh
cyrius deps                          # resolve dependencies
cyrius build src/main.cyr build/$PROJ  # compile
cyrius test                          # run test suite
\`\`\`

## Conventions

- Source lives in \`src/\`, tests in \`tests/\`
- Dependencies declared in \`cyrius.toml\`, resolved via \`cyrius deps\`
- Toolchain version pinned in \`cyrius.cyml [package].cyrius\`
- \`var buf[N]\` is N **bytes**, not elements
- No closures — use named functions + globals
- \`&&\`/\`||\` short-circuit; mixed requires explicit parens

## Do Not

- Do not commit or push without user approval
- Do not modify \`lib/\` files (vendored stdlib)
- Do not skip \`cyrius deps\` before builds
AGENT_EOF
            ;;
        agnos)
            write_if_absent "$NAME/CLAUDE.md" << AGENT_EOF
# $PROJ — AGNOS Ecosystem

Part of the [AGNOS](https://github.com/MacCracken) ecosystem.
Written in [Cyrius](https://github.com/MacCracken/cyrius).

## Build

\`\`\`sh
cyrius deps                          # resolve dependencies
cyrius build src/main.cyr build/$PROJ  # compile
cyrius test                          # run test suite
\`\`\`

## AGNOS Conventions

- All AGNOS projects use GPL-3.0-only
- Pin toolchain version in \`cyrius.cyml [package].cyrius\` to latest stable
- Use \`assert_summary()\` exit pattern in tests
- Stdlib modules are vendored in \`lib/\`; do not modify
- Prefix public functions with project name to avoid collisions
- \`var buf[N]\` is N **bytes**, not elements
- No closures — use named functions + globals

## Testing

- \`.tcyr\` files are test suites (run via \`cyrius test\`)
- \`.bcyr\` files are benchmarks (run via \`cyrius bench\`)
- \`.fcyr\` files are fuzz harnesses (run via \`cyrius fuzz\`)
- Always exit with \`syscall(60, assert_summary())\`

## Do Not

- Do not commit or push without user approval
- Do not modify \`lib/\` files (vendored stdlib)
- Do not skip \`cyrius deps\` before builds
- Do not add features without tests
AGENT_EOF
            ;;
        claude)
            write_if_absent "$NAME/CLAUDE.md" << AGENT_EOF
# $PROJ

Written in [Cyrius](https://github.com/MacCracken/cyrius).

## Build

\`\`\`sh
cyrius deps && cyrius build src/main.cyr build/$PROJ
cyrius test
\`\`\`

## Key Facts

- Source in \`src/\`, tests in \`tests/\`, stdlib in \`lib/\` (vendored, do not edit)
- Dependencies declared in \`cyrius.toml\`
- Toolchain pinned in \`cyrius.cyml [package].cyrius\`

## Language Notes

- \`var buf[N]\` is N bytes, not elements
- \`&&\`/\`||\` short-circuit; mixed requires parens: \`a && (b || c)\`
- No closures — use named functions
- Test exit pattern: \`syscall(60, assert_summary())\`

## Do Not

- Do not commit or push without user approval
- Do not modify files in \`lib/\`
AGENT_EOF
            ;;
        *)
            echo "  note: unknown preset '$AGENT', using generic"
            write_if_absent "$NAME/CLAUDE.md" << AGENT_FALLBACK_EOF
# $PROJ

Written in [Cyrius](https://github.com/MacCracken/cyrius). Built with \`cyrius build\`.

## Build

\`\`\`sh
cyrius deps                          # resolve dependencies
cyrius build src/main.cyr build/$PROJ  # compile
cyrius test                          # run test suite
\`\`\`

## Conventions

- Source lives in \`src/\`, tests in \`tests/\`
- Dependencies declared in \`cyrius.toml\`, resolved via \`cyrius deps\`
- Toolchain version pinned in \`cyrius.cyml [package].cyrius\`
- \`var buf[N]\` is N **bytes**, not elements
- No closures — use named functions + globals
- \`&&\`/\`||\` short-circuit; mixed requires explicit parens

## Do Not

- Do not commit or push without user approval
- Do not modify \`lib/\` files (vendored stdlib)
- Do not skip \`cyrius deps\` before builds
AGENT_FALLBACK_EOF
            ;;
    esac
fi

# === CLI tool integrations ===
if [ -n "$CMTOOLS" ]; then
    case "$CMTOOLS" in
        starship|all)
            STARSHIP_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
            if [ -f "$STARSHIP_CONF" ]; then
                if ! grep -q 'custom.cyrius' "$STARSHIP_CONF" 2>/dev/null; then
                    cat >> "$STARSHIP_CONF" << 'STARSHIP'

[custom.cyrius]
command = "cyrius version 2>/dev/null | awk '{print $2}'"
when = "test -f cyrius.cyml -o -f cyrius.toml"
symbol = "𝕮"
style = "bg:teal"
format = '[[ $symbol( $output) ](fg:base bg:teal)]($style)'
detect_files = ["cyrius.cyml", "cyrius.toml"]
STARSHIP
                    echo "  starship: added Cyrius segment to $STARSHIP_CONF"
                else
                    echo "  starship: Cyrius segment already configured"
                fi
            else
                echo "  starship: no config found at $STARSHIP_CONF (skipped)"
            fi
            ;;
        *)
            echo "  note: unknown cmtools preset '$CMTOOLS', available: starship"
            ;;
    esac
fi

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
    # In-place: don't overwrite anything the user authored under lib/.
    # Greenfield: clobber-OK (lib/ is empty by definition).
    if [ "$INPLACE" -eq 1 ]; then
        CP_FLAGS="-n"
    else
        CP_FLAGS=""
    fi
    for f in "$CYRIUS_LIB"/*.cyr; do
        [ -f "$f" ] && cp $CP_FLAGS "$f" "$NAME/lib/" 2>/dev/null || true
    done
else
    echo "  warn: Cyrius stdlib not found, lib/ will be empty"
fi

# === Done ===
LIB_COUNT=$(find "$NAME/lib" -name '*.cyr' 2>/dev/null | wc -l)
echo ""
if [ "$INPLACE" -eq 1 ]; then
    echo "Initialized $NAME (in-place, --language=none)"
else
    echo "Created $NAME/"
fi
echo "  $LIB_COUNT stdlib modules vendored"
echo "  src/main.cyr — entry point"
echo "  src/test.cyr — test file"
echo ""
echo "Next steps:"
if [ "$INPLACE" -eq 1 ]; then
    echo "  cyrius deps"
    echo "  cyrius build src/main.cyr build/$PROJ"
else
    echo "  cd $NAME"
    echo "  sh scripts/build.sh"
    echo "  sh scripts/test.sh"
fi
