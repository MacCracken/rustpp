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

printf "\n${BOLD}Cyrius Installer${RESET}\n\n"

# ── Resolve version ──

if [ -z "$VERSION" ]; then
    VERSION=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | \
        grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "")
    if [ -z "$VERSION" ]; then
        VERSION="5.3.10"
        warn "could not fetch latest version, defaulting to ${VERSION}"
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

    # Build tools (including cyrius build tool from Cyrius source)
    for tool in cyrius cyrfmt cyrlint cyrdoc cyrc ark; do
        if [ -f "programs/${tool}.cyr" ]; then
            cat "programs/${tool}.cyr" | ./build/cc5 > "./build/${tool}" 2>/dev/null && \
                chmod +x "./build/${tool}" || true
        fi
    done

    # Cross-compiler
    if [ -f src/main_aarch64.cyr ]; then
        cat src/main_aarch64.cyr | ./build/cc5 > ./build/cc5_aarch64 2>/dev/null && \
            chmod +x ./build/cc5_aarch64 || true
    fi

    # Copy binaries
    for bin in cc5 cc5_aarch64 cyrfmt cyrlint cyrdoc cyrc ark; do
        if [ -x "./build/$bin" ]; then
            cp "./build/$bin" "$CYRIUS_HOME/versions/$VERSION/bin/"
        fi
    done
    cp bootstrap/asm "$CYRIUS_HOME/versions/$VERSION/bin/"
    # cyrius binary already built from cbt/cyrius.cyr above
    for script in scripts/cyrius-*.sh; do
        [ -f "$script" ] && cp "$script" "$CYRIUS_HOME/versions/$VERSION/bin/" && \
            chmod +x "$CYRIUS_HOME/versions/$VERSION/bin/$(basename "$script")"
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
    rm -f /tmp/cc2_verify /tmp/cc2_verify2
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

cat > "$CYRIUS_HOME/bin/cyriusly" << 'MANAGER'
#!/bin/sh
# cyriusly — Cyrius version manager ("Language Yare")
#
# Yare (adj): quick, agile, responsive — the ship answers the helm.
# Like rustup, pyenv, rbenv: manages installed Cyrius versions.
CYRIUS_HOME="${CYRIUS_HOME:-$HOME/.cyrius}"

current() { cat "$CYRIUS_HOME/current" 2>/dev/null || echo "none"; }

link_version() {
    local ver="$1"
    rm -f "$CYRIUS_HOME/bin" "$CYRIUS_HOME/lib"
    ln -sf "$CYRIUS_HOME/versions/$ver/bin" "$CYRIUS_HOME/bin"
    ln -sf "$CYRIUS_HOME/versions/$ver/lib" "$CYRIUS_HOME/lib"
}

case "${1:-help}" in
    version|--version|-v)
        echo "cyriusly $(current)"
        ;;

    list|ls)
        echo "Installed versions:"
        cur=$(current)
        for d in "$CYRIUS_HOME/versions"/*/; do
            [ -d "$d" ] || continue
            v=$(basename "$d")
            if [ "$v" = "$cur" ]; then
                echo "  * $v (active)"
            else
                echo "    $v"
            fi
        done
        ;;

    use)
        [ -z "$2" ] && echo "Usage: cyriusly use <version>" && exit 1
        [ ! -d "$CYRIUS_HOME/versions/$2" ] && echo "Version $2 not installed." && exit 1
        echo "$2" > "$CYRIUS_HOME/current"
        link_version "$2"
        echo "Now using Cyrius $2"
        ;;

    install)
        [ -z "$2" ] && echo "Usage: cyriusly install <version>" && exit 1
        echo "Installing Cyrius $2..."
        CYRIUS_VERSION="$2" curl -sSf "https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh" | sh
        ;;

    uninstall)
        [ -z "$2" ] && echo "Usage: cyriusly uninstall <version>" && exit 1
        cur=$(current)
        if [ "$2" = "$cur" ]; then
            echo "Cannot uninstall active version. Switch first: cyriusly use <other>"
            exit 1
        fi
        if [ -d "$CYRIUS_HOME/versions/$2" ]; then
            rm -rf "$CYRIUS_HOME/versions/$2"
            echo "Uninstalled Cyrius $2"
        else
            echo "Version $2 not installed."
        fi
        ;;

    which)
        echo "$CYRIUS_HOME/versions/$(current)/bin/cc5"
        ;;

    home)
        echo "$CYRIUS_HOME"
        ;;

    update)
        echo "Checking for updates..."
        LATEST=$(curl -sSf "https://api.github.com/repos/MacCracken/cyrius/releases/latest" 2>/dev/null | \
            grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "")
        CUR=$(current)
        if [ -z "$LATEST" ]; then
            echo "Could not check for updates."
        elif [ "$LATEST" = "$CUR" ]; then
            echo "Already up to date: $CUR"
        else
            echo "Update available: $CUR -> $LATEST"
            echo "Run: cyriusly install $LATEST && cyriusly use $LATEST"
        fi
        ;;

    cmdtools)
        shift
        _CT_ACTION="${1:-list}"
        _CT_TOOL="${2:-}"

        _starship_conf="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
        _p10k_conf="$HOME/.p10k.zsh"

        _CYRIUS_STARSHIP='[custom.cyrius]
command = """if [ -f bootstrap/asm ]; then cat VERSION 2>/dev/null; else cc5 --version 2>/dev/null | awk '"'"'{print $2}'"'"' || cat ~/.cyrius/current 2>/dev/null || echo '"'"'?'"'"'; fi"""
when = "test -f cyrius.cyml || test -f cyrius.toml"
symbol = "𝕮"
style = "bg:teal"
format = '"'"'[[ $symbol( $output) ](fg:base bg:teal)]($style)'"'"'
detect_files = ["cyrius.cyml", "cyrius.toml"]'

        _CYRIUS_P10K='# Cyrius prompt segment
function prompt_cyrius() {
  local ver=""
  if [[ -f cyrius.cyml ]] || [[ -f cyrius.toml ]]; then
    if [[ -f bootstrap/asm ]]; then ver=$(cat VERSION 2>/dev/null)
    else ver=$(cc5 --version 2>/dev/null | awk "{print \$2}" || cat ~/.cyrius/current 2>/dev/null || echo "?"); fi
    [[ -n "$ver" ]] && p10k segment -f teal -t "𝕮 $ver"
  fi
}'

        case "$_CT_ACTION" in
            list)
                echo "cmdtools integrations:"
                if grep -q "custom.cyrius" "$_starship_conf" 2>/dev/null; then
                    echo "  * starship  (installed)"
                elif command -v starship > /dev/null 2>&1; then
                    echo "    starship  (available, not configured)"
                fi
                if grep -q "prompt_cyrius" "$_p10k_conf" 2>/dev/null; then
                    echo "  * p10k      (installed)"
                elif [ -f "$_p10k_conf" ]; then
                    echo "    p10k      (available, not configured)"
                fi
                ;;
            install|add)
                case "$_CT_TOOL" in
                    starship)
                        if ! command -v starship > /dev/null 2>&1; then
                            echo "error: starship not installed"
                            exit 1
                        fi
                        if grep -q "custom.cyrius" "$_starship_conf" 2>/dev/null; then
                            # Update existing
                            sed -i '/\[custom\.cyrius\]/,/^$/d' "$_starship_conf"
                        fi
                        echo "" >> "$_starship_conf"
                        echo "$_CYRIUS_STARSHIP" >> "$_starship_conf"
                        echo "starship: Cyrius segment installed in $_starship_conf"
                        ;;
                    p10k|powerlevel10k)
                        if [ ! -f "$_p10k_conf" ]; then
                            echo "error: ~/.p10k.zsh not found (run p10k configure first)"
                            exit 1
                        fi
                        if grep -q "prompt_cyrius" "$_p10k_conf" 2>/dev/null; then
                            echo "p10k: Cyrius segment already installed"
                        else
                            echo "" >> "$_p10k_conf"
                            echo "$_CYRIUS_P10K" >> "$_p10k_conf"
                            echo "p10k: Cyrius segment installed in $_p10k_conf"
                            echo "  Add 'cyrius' to POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS in ~/.p10k.zsh"
                        fi
                        ;;
                    *)
                        echo "Available tools: starship, p10k"
                        ;;
                esac
                ;;
            remove)
                case "$_CT_TOOL" in
                    starship)
                        if grep -q "custom.cyrius" "$_starship_conf" 2>/dev/null; then
                            sed -i '/\[custom\.cyrius\]/,/^$/d' "$_starship_conf"
                            echo "starship: Cyrius segment removed"
                        else
                            echo "starship: no Cyrius segment found"
                        fi
                        ;;
                    p10k|powerlevel10k)
                        if grep -q "prompt_cyrius" "$_p10k_conf" 2>/dev/null; then
                            sed -i '/# Cyrius prompt segment/,/^}/d' "$_p10k_conf"
                            echo "p10k: Cyrius segment removed"
                        else
                            echo "p10k: no Cyrius segment found"
                        fi
                        ;;
                    *)
                        echo "Available tools: starship, p10k"
                        ;;
                esac
                ;;
            *)
                echo "Usage: cyriusly cmdtools [list|install|remove] [starship|p10k]"
                ;;
        esac
        ;;

    help|--help|-h)
        echo "cyriusly - Cyrius version manager"
        echo ""
        echo "USAGE:"
        echo "    cyriusly <command> [args]"
        echo ""
        echo "COMMANDS:"
        echo "    version             Show active version"
        echo "    list                List installed versions"
        echo "    use <version>       Switch to a version"
        echo "    install <version>   Download and install a version"
        echo "    uninstall <version> Remove a version"
        echo "    update              Check for new versions"
        echo "    which               Show path to active compiler"
        echo "    home                Show install directory"
        echo "    cmdtools [action]   Manage prompt integrations (starship, p10k)"
        echo "    help                Show this help"
        echo ""
        echo "EXAMPLES:"
        echo "    cyriusly install 5.1.11"
        echo "    cyriusly use 5.1.11"
        echo "    cyriusly cmdtools install starship"
        echo "    cyriusly cmdtools list"
        ;;

    *)
        echo "Unknown command: $1"
        echo "Run 'cyriusly help' for usage."
        exit 1
        ;;
esac
MANAGER
chmod +x "$CYRIUS_HOME/bin/cyriusly"

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

# Show what was installed
echo "  Toolchain:"
for bin in cc5 cyrius cyrfmt cyrlint cyrdoc cyrc ark; do
    if [ -x "$CYRIUS_HOME/bin/$bin" ]; then
        printf "    ${GREEN}+${RESET} %s\n" "$bin"
    fi
done
if [ -x "$CYRIUS_HOME/bin/cc5_aarch64" ]; then
    printf "    ${GREEN}+${RESET} %s\n" "cc5_aarch64 (cross-compiler)"
fi
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
