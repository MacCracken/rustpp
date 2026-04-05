#!/bin/sh
# Cyrius installer
# Usage: curl -sSf https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh | sh
#
# Installs the Cyrius toolchain to ~/.cyrius/
# Adds ~/.cyrius/bin to PATH via shell profile.

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
    RESET="\033[0m"
else
    BOLD="" GREEN="" YELLOW="" RED="" RESET=""
fi

info() { printf "${GREEN}info${RESET}: %s\n" "$1"; }
warn() { printf "${YELLOW}warn${RESET}: %s\n" "$1"; }
err()  { printf "${RED}error${RESET}: %s\n" "$1" >&2; exit 1; }

# Detect architecture
case "$ARCH" in
    x86_64|amd64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) err "unsupported architecture: $ARCH" ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux) ;;
    *) err "unsupported OS: $OS (Cyrius requires Linux)" ;;
esac

printf "\n${BOLD}Cyrius Installer${RESET}\n\n"
info "architecture: ${ARCH}"
info "install dir: ${CYRIUS_HOME}"

# Get latest version if not specified
if [ -z "$VERSION" ]; then
    info "fetching latest version..."
    VERSION=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | \
        grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "")
    if [ -z "$VERSION" ]; then
        # Fallback: clone and read VERSION file
        VERSION="0.9.0"
        warn "could not fetch latest version, using ${VERSION}"
    fi
fi
info "version: ${VERSION}"

# Create directory structure
mkdir -p "$CYRIUS_HOME/bin"
mkdir -p "$CYRIUS_HOME/versions/$VERSION"

# Try to download prebuilt binaries from GitHub release
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}"
BINARIES="cc2 cc2_aarch64 cyrb ark asm"
downloaded=0

info "downloading binaries..."
for bin in $BINARIES; do
    url="${DOWNLOAD_URL}/${bin}"
    dest="$CYRIUS_HOME/versions/$VERSION/$bin"
    if curl -sSfL "$url" -o "$dest" 2>/dev/null; then
        chmod +x "$dest"
        downloaded=$((downloaded + 1))
    fi
done

if [ "$downloaded" -eq 0 ]; then
    # No release binaries — bootstrap from source
    info "no prebuilt binaries found, bootstrapping from source..."
    TMPDIR=$(mktemp -d)
    cd "$TMPDIR"
    git clone --depth 1 --branch "$VERSION" "https://github.com/${REPO}.git" cyrius 2>/dev/null || \
        git clone --depth 1 "https://github.com/${REPO}.git" cyrius
    cd cyrius
    # Bootstrap chain: asm → stage1f → cc.cyr → cc2 → tools
    sh bootstrap/bootstrap.sh
    # cc.cyr is the bridge compiler (stage1f feature set)
    if [ -f stage1/cc.cyr ]; then
        cat stage1/cc.cyr | ./build/stage1f > ./build/cc && chmod +x ./build/cc
        cat stage1/cc2.cyr | ./build/cc > ./build/cc2 && chmod +x ./build/cc2
    else
        # If cc.cyr is committed as build/cc2, use it directly
        cat stage1/cc2.cyr | ./build/stage1f > ./build/cc2 && chmod +x ./build/cc2
    fi
    # Cross-compiler + tools
    cat stage1/cc2_aarch64.cyr | ./build/cc2 > ./build/cc2_aarch64 2>/dev/null && chmod +x ./build/cc2_aarch64 || true
    cat stage1/programs/cyrb.cyr | ./build/cc2 > ./build/cyrb 2>/dev/null && chmod +x ./build/cyrb || true
    cat stage1/programs/ark.cyr | ./build/cc2 > ./build/ark 2>/dev/null && chmod +x ./build/ark || true
    cat stage1/programs/cyrc.cyr | ./build/cc2 > ./build/cyrc 2>/dev/null && chmod +x ./build/cyrc || true

    # Copy to version dir
    for bin in cc2 cc2_aarch64 cyrb ark cyrc; do
        if [ -x "./build/$bin" ]; then
            cp "./build/$bin" "$CYRIUS_HOME/versions/$VERSION/"
        fi
    done
    cp bootstrap/asm "$CYRIUS_HOME/versions/$VERSION/"

    # Copy init script
    if [ -f scripts/cyrb-init.sh ]; then
        cp scripts/cyrb-init.sh "$CYRIUS_HOME/bin/cyrb-init"
        chmod +x "$CYRIUS_HOME/bin/cyrb-init"
    fi

    # Cleanup
    cd /
    rm -rf "$TMPDIR"
    info "bootstrapped from source"
fi

# Write current version
echo "$VERSION" > "$CYRIUS_HOME/current"

# Create symlinks in bin/
info "creating symlinks..."
for bin in cc2 cc2_aarch64 cyrb ark cyrc; do
    src="$CYRIUS_HOME/versions/$VERSION/$bin"
    dst="$CYRIUS_HOME/bin/$bin"
    if [ -x "$src" ]; then
        ln -sf "$src" "$dst"
    fi
done

# Install version manager
cat > "$CYRIUS_HOME/bin/cyrius" << 'MANAGER'
#!/bin/sh
# cyrius — Cyrius version manager
CYRIUS_HOME="${CYRIUS_HOME:-$HOME/.cyrius}"

case "$1" in
    version|--version|-v)
        cat "$CYRIUS_HOME/current" 2>/dev/null || echo "unknown"
        ;;
    list)
        echo "Installed versions:"
        for d in "$CYRIUS_HOME/versions"/*/; do
            v=$(basename "$d")
            cur=$(cat "$CYRIUS_HOME/current" 2>/dev/null)
            if [ "$v" = "$cur" ]; then
                echo "  * $v (active)"
            else
                echo "    $v"
            fi
        done
        ;;
    use)
        if [ -z "$2" ]; then echo "Usage: cyrius use <version>"; exit 1; fi
        if [ ! -d "$CYRIUS_HOME/versions/$2" ]; then
            echo "Version $2 not installed. Run: cyrius install $2"
            exit 1
        fi
        echo "$2" > "$CYRIUS_HOME/current"
        for bin in cc2 cc2_aarch64 cyrb ark cyrc; do
            src="$CYRIUS_HOME/versions/$2/$bin"
            dst="$CYRIUS_HOME/bin/$bin"
            if [ -x "$src" ]; then ln -sf "$src" "$dst"; fi
        done
        echo "Now using Cyrius $2"
        ;;
    install)
        if [ -z "$2" ]; then echo "Usage: cyrius install <version>"; exit 1; fi
        echo "Installing Cyrius $2..."
        CYRIUS_VERSION="$2" sh "$CYRIUS_HOME/bin/cyrius-install" 2>/dev/null || \
            echo "Use the install script: curl -sSf https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh | CYRIUS_VERSION=$2 sh"
        ;;
    which)
        echo "$CYRIUS_HOME/versions/$(cat "$CYRIUS_HOME/current" 2>/dev/null)/cc2"
        ;;
    home)
        echo "$CYRIUS_HOME"
        ;;
    help|--help|-h|"")
        echo "cyrius — Cyrius version manager"
        echo ""
        echo "Commands:"
        echo "  cyrius version       show active version"
        echo "  cyrius list          list installed versions"
        echo "  cyrius use <ver>     switch active version"
        echo "  cyrius install <ver> install a version"
        echo "  cyrius which         show path to active cc2"
        echo "  cyrius home          show install directory"
        ;;
    *)
        echo "Unknown command: $1. Run 'cyrius help'."
        exit 1
        ;;
esac
MANAGER
chmod +x "$CYRIUS_HOME/bin/cyrius"

# Setup PATH in shell profile
add_to_path() {
    local profile="$1"
    if [ -f "$profile" ]; then
        if ! grep -q "\.cyrius/bin" "$profile" 2>/dev/null; then
            echo '' >> "$profile"
            echo '# Cyrius' >> "$profile"
            echo 'export PATH="$HOME/.cyrius/bin:$PATH"' >> "$profile"
            info "added to $profile"
            return 0
        fi
    fi
    return 1
}

path_added=0
if [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
    add_to_path "$HOME/.bashrc" && path_added=1
fi
if [ -f "$HOME/.zshrc" ]; then
    add_to_path "$HOME/.zshrc" && path_added=1
fi
if [ "$path_added" -eq 0 ]; then
    add_to_path "$HOME/.profile" || true
fi

# Summary
printf "\n${BOLD}Cyrius ${VERSION} installed!${RESET}\n\n"
echo "  Location:  $CYRIUS_HOME"
echo "  Compiler:  $CYRIUS_HOME/bin/cc2"
echo "  Builder:   $CYRIUS_HOME/bin/cyrb"
echo ""
echo "To get started:"
echo "  1. Restart your shell (or run: export PATH=\"\$HOME/.cyrius/bin:\$PATH\")"
echo "  2. cyrb-init myproject"
echo "  3. cd myproject && sh scripts/build.sh"
echo ""
echo "Manage versions:"
echo "  cyrius version     # show current"
echo "  cyrius list        # list installed"
echo "  cyrius use 0.9.0   # switch version"
