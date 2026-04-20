#!/bin/sh
# Cyrius installer
# Usage: curl -sSf https://install.cyrius.dev | sh
#    or: curl -sSf https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh | sh
#
# Installs the Cyrius toolchain to ~/.cyrius/
# Structure:
#   ~/.cyrius/
#     bin/              symlinks to active version (on PATH)
#     versions/0.9.0/   version-specific binaries
#     current           active version file
#
# Environment:
#   CYRIUS_VERSION   install specific version (default: latest)
#   CYRIUS_HOME      install directory (default: ~/.cyrius)

set -e

CYRIUS_HOME="${CYRIUS_HOME:-$HOME/.cyrius}"
REPO="MacCracken/cyrius"
VERSION="${CYRIUS_VERSION:-}"
ARCH=$(uname -m)

# v5.4.18: --refresh-only mode. Skips tarball fetch / source bootstrap
# and only re-copies lib/ + bin/ from the CURRENT REPO state into
# ~/.cyrius/versions/$VERSION/. Called by version-bump.sh post-bump so
# the install snapshot never lags the repo after a dep or tool bump.
# Only makes sense when run from within a cyrius repo checkout.
REFRESH_ONLY=0
if [ "${1:-}" = "--refresh-only" ]; then
    REFRESH_ONLY=1
    VERSION="$(tr -d '[:space:]' < VERSION 2>/dev/null)"
    if [ -z "$VERSION" ]; then
        echo "error: --refresh-only must run from a cyrius repo (VERSION file not found)" >&2
        exit 1
    fi
fi

# Parse a single array from cyrius.cyml's [release] table. Outputs
# space-separated entries. Returns empty if key/section missing.
_parse_release_array() {
    local cyml="${CYRIUS_CYML:-cyrius.cyml}"
    [ -f "$cyml" ] || return 0
    awk -v k="$1" '
        /^\[release\]/ { in_r = 1; next }
        in_r && /^\[/ { exit }
        in_r && $1 == k {
            sub(/^[^=]+= \[/, ""); sub(/\].*$/, "")
            gsub(/[",]/, " "); gsub(/ +/, " ")
            sub(/^ +/, ""); sub(/ +$/, ""); print; exit
        }' "$cyml"
}

# Colors (if terminal)
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" YELLOW="" RED="" DIM="" RESET=""
fi

info() { printf "  ${GREEN}>${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
err()  { printf "  ${RED}x${RESET} %s\n" "$1" >&2; exit 1; }

# ── Detect platform ──

case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) err "unsupported architecture: $ARCH" ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux) ;;
    *) err "unsupported OS: $OS (Cyrius targets Linux only)" ;;
esac

# ── --refresh-only fast path (v5.4.18) ──
# Skips the Installer banner, version resolve, tarball fetch, and source
# bootstrap. Just re-copies the current repo's build/ + lib/ + scripts
# named in cyrius.cyml [release] into ~/.cyrius/versions/$VERSION/.
# Purpose: version-bump.sh calls this after bumping so the install
# snapshot never rots behind dep/tool bumps.
if [ "$REFRESH_ONLY" -eq 1 ]; then
    printf "\n${BOLD}Refreshing install snapshot for %s${RESET}\n" "$VERSION"
    mkdir -p "$CYRIUS_HOME/versions/$VERSION/bin"
    mkdir -p "$CYRIUS_HOME/versions/$VERSION/lib"

    _R_BINS=$(_parse_release_array bins)
    _R_CROSS=$(_parse_release_array cross_bins)
    _R_SCRIPTS=$(_parse_release_array scripts)

    _refreshed=0
    for bin in $_R_BINS $_R_CROSS; do
        if [ -x "build/$bin" ]; then
            cp "build/$bin" "$CYRIUS_HOME/versions/$VERSION/bin/"
            _refreshed=$((_refreshed + 1))
        fi
    done
    [ -f bootstrap/asm ] && cp bootstrap/asm "$CYRIUS_HOME/versions/$VERSION/bin/"

    for script in $_R_SCRIPTS; do
        if [ -f "scripts/$script" ]; then
            cp "scripts/$script" "$CYRIUS_HOME/versions/$VERSION/bin/"
            chmod +x "$CYRIUS_HOME/versions/$VERSION/bin/$script"
            _refreshed=$((_refreshed + 1))
        fi
    done

    # Stdlib refresh (follow symlinks so dep content gets dereferenced)
    _lib_count=0
    for f in lib/*.cyr; do
        [ -e "$f" ] || continue
        if [ -L "$f" ]; then
            cp -L "$f" "$CYRIUS_HOME/versions/$VERSION/lib/"
        else
            cp "$f" "$CYRIUS_HOME/versions/$VERSION/lib/"
        fi
        _lib_count=$((_lib_count + 1))
    done

    echo "$VERSION" > "$CYRIUS_HOME/current"
    echo "$VERSION" > "$CYRIUS_HOME/versions/$VERSION/VERSION"

    info "refreshed $_refreshed bins/scripts + $_lib_count stdlib files"
    exit 0
fi

printf "\n${BOLD}Cyrius Installer${RESET}\n\n"

# ── Resolve version ──

if [ -z "$VERSION" ]; then
    VERSION=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | \
        grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "")
    if [ -z "$VERSION" ]; then
        # API rate-limited or offline — fall back to the VERSION file on main
        VERSION=$(curl -sSf "https://raw.githubusercontent.com/${REPO}/main/VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    if [ -z "$VERSION" ]; then
        err "could not resolve latest version (GitHub API + raw VERSION both unreachable). Set CYRIUS_VERSION=<tag> and retry."
    fi
fi

info "version:  ${VERSION}"
info "arch:     ${ARCH}"
info "home:     ${CYRIUS_HOME}"
echo ""

# ── Create directory structure ──

mkdir -p "$CYRIUS_HOME"
mkdir -p "$CYRIUS_HOME/versions/$VERSION/bin"

# ── Download tarball or bootstrap from source ──

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}"
TARBALL="cyrius-${VERSION}-${ARCH}-linux.tar.gz"
TMPDIR=$(mktemp -d)
installed=0

info "downloading Cyrius ${VERSION}..."
if curl -sSfL "${DOWNLOAD_URL}/${TARBALL}" -o "$TMPDIR/$TARBALL" 2>/dev/null; then
    # Verify checksum if available
    if curl -sSfL "${DOWNLOAD_URL}/${TARBALL}.sha256" -o "$TMPDIR/checksum" 2>/dev/null; then
        cd "$TMPDIR"
        if sha256sum -c checksum > /dev/null 2>&1; then
            info "checksum verified"
        else
            warn "checksum mismatch — continuing anyway"
        fi
        cd - > /dev/null
    fi

    # Untar into version directory
    tar xzf "$TMPDIR/$TARBALL" -C "$TMPDIR"
    EXTRACTED="$TMPDIR/cyrius-${VERSION}-${ARCH}-linux"

    if [ -d "$EXTRACTED/bin" ]; then
        cp -r "$EXTRACTED/bin"/* "$CYRIUS_HOME/versions/$VERSION/bin/"
        chmod +x "$CYRIUS_HOME/versions/$VERSION/bin"/*
        info "binaries installed"
    fi

    if [ -d "$EXTRACTED/lib" ]; then
        cp -r "$EXTRACTED/lib" "$CYRIUS_HOME/versions/$VERSION/"
        info "standard library installed"
    fi

    installed=1
fi

if [ "$installed" -eq 0 ]; then
    # No tarball — bootstrap from source
    warn "no prebuilt release found, bootstrapping from source..."
    cd "$TMPDIR"
    git clone --depth 1 --branch "$VERSION" "https://github.com/${REPO}.git" cyrius 2>/dev/null || \
        git clone --depth 1 "https://github.com/${REPO}.git" cyrius
    cd cyrius

    sh bootstrap/bootstrap.sh
    chmod +x build/cc5

    # Verify self-hosting
    cat src/main.cyr | ./build/cc5 > /tmp/cc5_verify
    chmod +x /tmp/cc5_verify
    cat src/main.cyr | /tmp/cc5_verify > /tmp/cc5_verify2
    if cmp -s /tmp/cc5_verify /tmp/cc5_verify2; then
        info "self-hosting verified"
    else
        warn "self-hosting check failed, using committed cc5"
    fi

    # Build tools from cyrius.cyml [release].bins + cross_bins
    # (single source of truth introduced at v5.4.18). cyrius itself is
    # special-cased below because its source lives in cbt/, not programs/.
    _BINS=$(_parse_release_array bins)
    _CROSS_BINS=$(_parse_release_array cross_bins)
    for tool in $_BINS; do
        if [ "$tool" = "cc5" ] || [ "$tool" = "cyrius" ]; then continue; fi
        if [ -f "programs/${tool}.cyr" ]; then
            cat "programs/${tool}.cyr" | ./build/cc5 > "./build/${tool}" 2>/dev/null && \
                chmod +x "./build/${tool}" || true
        fi
    done
    # cyrius build tool (lives in cbt/cyrius.cyr, not programs/)
    if [ -f cbt/cyrius.cyr ]; then
        cat cbt/cyrius.cyr | ./build/cc5 > ./build/cyrius 2>/dev/null && \
            chmod +x ./build/cyrius || true
    fi

    # Cross-compiler(s)
    if [ -f src/main_aarch64.cyr ]; then
        cat src/main_aarch64.cyr | ./build/cc5 > ./build/cc5_aarch64 2>/dev/null && \
            chmod +x ./build/cc5_aarch64 || true
    fi

    # Copy binaries
    for bin in $_BINS $_CROSS_BINS; do
        if [ -x "./build/$bin" ]; then
            cp "./build/$bin" "$CYRIUS_HOME/versions/$VERSION/bin/"
        fi
    done
    cp bootstrap/asm "$CYRIUS_HOME/versions/$VERSION/bin/"

    # Scripts from [release].scripts (includes cyriusly + cyrius-*.sh)
    _SCRIPTS=$(_parse_release_array scripts)
    for script in $_SCRIPTS; do
        if [ -f "scripts/$script" ]; then
            cp "scripts/$script" "$CYRIUS_HOME/versions/$VERSION/bin/"
            chmod +x "$CYRIUS_HOME/versions/$VERSION/bin/$script"
        fi
    done

    # Shared audit helpers (sourced by the cyrius dispatcher)
    if [ -d scripts/lib ]; then
        mkdir -p "$CYRIUS_HOME/versions/$VERSION/bin/lib"
        cp scripts/lib/*.sh "$CYRIUS_HOME/versions/$VERSION/bin/lib/" 2>/dev/null || true
    fi

    # Copy stdlib
    if [ -d lib ]; then
        cp -r lib "$CYRIUS_HOME/versions/$VERSION/"
    fi

    cd /
    rm -f /tmp/cc5_verify /tmp/cc5_verify2
    info "bootstrapped from source"
fi

rm -rf "$TMPDIR"

# ── Set active version ──

echo "$VERSION" > "$CYRIUS_HOME/current"
# Copy VERSION file so cyrius can read it from install directory
echo "$VERSION" > "$CYRIUS_HOME/versions/$VERSION/VERSION"

# ── Create symlinks (directory-level, version-agnostic) ──

info "linking directories..."
rm -rf "$CYRIUS_HOME/bin" "$CYRIUS_HOME/lib"
ln -sf "$CYRIUS_HOME/versions/$VERSION/bin" "$CYRIUS_HOME/bin"
ln -sf "$CYRIUS_HOME/versions/$VERSION/lib" "$CYRIUS_HOME/lib"

# ── Install version manager ──
# cyriusly lives in scripts/cyriusly (committed source of truth). The
# release tarball ships it under bin/, so the tarball path already has
# it. The source-bootstrap path also copies it from scripts/. This
# block is a safety net for stale tarballs (pre-5.4.12) that didn't
# include cyriusly — fetch it from the matching tag.
if [ ! -x "$CYRIUS_HOME/bin/cyriusly" ]; then
    if curl -sSfL "https://raw.githubusercontent.com/${REPO}/${VERSION}/scripts/cyriusly" \
        -o "$CYRIUS_HOME/bin/cyriusly" 2>/dev/null; then
        chmod +x "$CYRIUS_HOME/bin/cyriusly"
        info "version manager installed"
    else
        warn "cyriusly not found in tarball and fetch failed — run 'cyrius pulsar' from a repo to install it"
    fi
fi

# ── Setup PATH ──

add_to_path() {
    local profile="$1"
    if [ -f "$profile" ]; then
        if ! grep -q "\.cyrius/bin" "$profile" 2>/dev/null; then
            printf '\n# Cyrius\nexport PATH="$HOME/.cyrius/bin:$PATH"\n' >> "$profile"
            return 0
        fi
    fi
    return 1
}

path_added=0
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
        add_to_path "$rc" && path_added=1 && info "PATH added to $(basename $rc)"
    fi
done
if [ "$path_added" -eq 0 ]; then
    add_to_path "$HOME/.profile" && info "PATH added to .profile" || true
fi

# ── Starship prompt integration ──

STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
if [ -f "$STARSHIP_CONFIG" ] && command -v starship > /dev/null 2>&1; then
    if ! grep -q "custom.cyrius" "$STARSHIP_CONFIG" 2>/dev/null; then
        cat >> "$STARSHIP_CONFIG" << 'STARSHIP'

[custom.cyrius]
command = """if [ -f bootstrap/asm ]; then cat VERSION 2>/dev/null; else cc5 --version 2>/dev/null | awk '{print $2}' || cat ~/.cyrius/current 2>/dev/null || echo '?'; fi"""
when = "test -f cyrius.cyml || test -f cyrius.toml"
symbol = "𝕮"
style = "bg:teal"
format = '[[ $symbol( $output) ](fg:base bg:teal)]($style)'
detect_files = ["cyrius.cyml", "cyrius.toml"]
STARSHIP
        info "Starship prompt configured (shows toolchain version in Cyrius projects)"
    fi
elif command -v starship > /dev/null 2>&1; then
    # Starship installed but no config — create minimal config with cyrius section
    mkdir -p "$(dirname "$STARSHIP_CONFIG")"
    cat > "$STARSHIP_CONFIG" << 'STARSHIP'
[custom.cyrius]
command = """if [ -f bootstrap/asm ]; then cat VERSION 2>/dev/null; else cc5 --version 2>/dev/null | awk '{print $2}' || cat ~/.cyrius/current 2>/dev/null || echo '?'; fi"""
when = "test -f cyrius.cyml || test -f cyrius.toml"
symbol = "𝕮"
style = "bg:teal"
format = '[[ $symbol( $output) ](fg:base bg:teal)]($style)'
detect_files = ["cyrius.cyml", "cyrius.toml"]
STARSHIP
    info "Starship config created with Cyrius prompt"
fi

# ── Summary ──

printf "\n${BOLD}Cyrius ${VERSION} installed successfully!${RESET}\n\n"

# Show what was installed — bin list from [release] (single source of truth).
echo "  Toolchain:"
_SUMMARY_BINS=$(_parse_release_array bins)
for bin in $_SUMMARY_BINS; do
    if [ -x "$CYRIUS_HOME/bin/$bin" ]; then
        printf "    ${GREEN}+${RESET} %s\n" "$bin"
    fi
done
_SUMMARY_CROSS=$(_parse_release_array cross_bins)
for bin in $_SUMMARY_CROSS; do
    if [ -x "$CYRIUS_HOME/bin/$bin" ]; then
        printf "    ${GREEN}+${RESET} %s (cross-compiler)\n" "$bin"
    fi
done
echo ""
echo "  To get started:"
echo "    ${DIM}# restart your shell, or:${RESET}"
echo "    export PATH=\"\$HOME/.cyrius/bin:\$PATH\""
echo ""
echo "    ${DIM}# create a new project:${RESET}"
echo "    cyrius init myproject"
echo "    cd myproject"
echo "    cyrius build src/main.cyr -o build/main"
echo ""
echo "    ${DIM}# manage versions:${RESET}"
echo "    cyriusly list"
echo "    cyriusly update"
echo ""
