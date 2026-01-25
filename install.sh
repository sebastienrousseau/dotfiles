#!/usr/bin/env bash
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
# (or ./install.sh locally)

set -e

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
   ___      _    _  _  _          
  / _ \___ | |_ (_)| |(_) ___  ___ 
 / /_)/ _ \| __|| || || |/ _ \/ __|
/ ___/ (_) | |_ | || || |  __/\__ \
\/    \___/ \__||_||_||_|\___||___/
           Universal Installer
EOF
echo -e "${NC}"

step() { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}==> Done!${NC}"; }
error() { echo -e "${RED}==> Error: $1${NC}"; exit 1; }

# 1. Detect Environment
step "Detecting Environment..."
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "   OS: $OS"
echo "   Arch: $ARCH"

# 2. Check Prerequisites
step "Checking Prerequisites..."
if ! command -v curl >/dev/null; then error "curl is required."; fi
if ! command -v git >/dev/null; then error "git is required."; fi

# 3. Install Chezmoi
step "Installing Chezmoi..."
if command -v chezmoi >/dev/null; then
    echo "   chezmoi already installed: $(chezmoi --version)"
else
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    
    # Binary Locking: Explicitly pinned version with SHA256 verification
    CHEZMOI_VERSION="2.47.1"
    echo "   Installing chezmoi v${CHEZMOI_VERSION} (Verified)..."

    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    case "$arch" in
      x86_64|amd64) arch="amd64" ;;
      aarch64|arm64) arch="arm64" ;;
      armv7l|armv7) arch="armv7" ;;
      *) error "Unsupported architecture for verified chezmoi install: $arch" ;;
    esac

    case "$os" in
      linux|darwin) ;;
      *) error "Unsupported OS for verified chezmoi install: $os" ;;
    esac

    tarball="chezmoi_${CHEZMOI_VERSION}_${os}_${arch}.tar.gz"
    checksums="chezmoi_${CHEZMOI_VERSION}_checksums.txt"
    base_url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    curl -fsSL -o "$tmp_dir/$tarball" "$base_url/$tarball"
    curl -fsSL -o "$tmp_dir/$checksums" "$base_url/$checksums"

    if command -v sha256sum >/dev/null; then
      expected="$(awk -v f="$tarball" '$2==f {print $1}' "$tmp_dir/$checksums")"
      actual="$(sha256sum "$tmp_dir/$tarball" | awk '{print $1}')"
    elif command -v shasum >/dev/null; then
      expected="$(awk -v f="$tarball" '$2==f {print $1}' "$tmp_dir/$checksums")"
      actual="$(shasum -a 256 "$tmp_dir/$tarball" | awk '{print $1}')"
    else
      error "sha256sum or shasum is required to verify chezmoi."
    fi

    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
      error "Checksum verification failed for chezmoi."
    fi

    tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir"
    install -m 0755 "$tmp_dir/chezmoi" "$BIN_DIR/chezmoi"
    
    # Critical: Add to PATH for the rest of the script to see it
    export PATH="$BIN_DIR:$PATH"
fi

# 4. Initialize & Apply
step "Applying Configuration..."

# VERSION pinning for supply-chain security
if [ -n "$1" ]; then
  VERSION="$1"
else
  VERSION="v0.2.472"
fi

SOURCE_DIR="$HOME/.dotfiles"
LEGACY_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.toml"

ensure_chezmoi_source() {
    local dir="$1"
    mkdir -p "$CHEZMOI_CONFIG_DIR"
    if [ -f "$CHEZMOI_CONFIG_FILE" ]; then
        if ! grep -q '^sourceDir' "$CHEZMOI_CONFIG_FILE"; then
            printf '\nsourceDir = \"%s\"\\n' "$dir" >> "$CHEZMOI_CONFIG_FILE"
        fi
    else
        printf 'sourceDir = \"%s\"\\n' "$dir" > "$CHEZMOI_CONFIG_FILE"
    fi
}

# If we are running from a local source, just apply
if [ -d "$SOURCE_DIR/.git" ]; then
    echo "   Applying from local source: $SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    APPLY_FLAGS=""
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
      APPLY_FLAGS="--force --no-tty"
    fi
    chezmoi apply $APPLY_FLAGS
elif [ -d "$LEGACY_SOURCE_DIR/.git" ]; then
    echo "   Applying from legacy source: $LEGACY_SOURCE_DIR"
    ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
    APPLY_FLAGS=""
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
      APPLY_FLAGS="--force --no-tty"
    fi
    chezmoi apply $APPLY_FLAGS
else
    echo "   Initializing from GitHub (Branch/Tag: $VERSION)..."
    # STRICT MODE: We pin to the specific tag to avoid 'main' branch drift
    git clone --branch "$VERSION" https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    APPLY_FLAGS=""
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
      APPLY_FLAGS="--force --no-tty"
    fi
    chezmoi apply $APPLY_FLAGS
fi

success
echo -e "${GREEN}Configuration loaded. Please restart your shell.${NC}"
