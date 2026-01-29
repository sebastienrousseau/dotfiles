#!/usr/bin/env bash
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
# (or ./install.sh locally)

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
cat <<"EOF"
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
error() {
  echo -e "${RED}==> Error: $1${NC}"
  exit 1
}

# 1. Detect Environment
step "Detecting Environment..."
OS="$(uname -s)"
ARCH="$(uname -m)"

# Robust OS detection: set target_os for downstream use
target_os="unknown"
case "$OS" in
  Darwin)
    target_os="macos"
    ;;
  Linux)
    # shellcheck disable=SC2250
    if [ -f /proc/version ] && grep -qi 'microsoft\|WSL' /proc/version; then
      target_os="wsl2"
    elif [ -f /etc/os-release ]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      case "${ID:-}" in
        ubuntu | debian | pop | linuxmint | elementary)
          target_os="debian"
          ;;
        fedora | rhel | centos | rocky | alma)
          target_os="fedora"
          ;;
        arch | manjaro | endeavouros)
          target_os="arch"
          ;;
        *)
          target_os="linux"
          ;;
      esac
    else
      target_os="linux"
    fi
    ;;
esac
echo "   OS: $OS"
echo "   Arch: $ARCH"
echo "   Target: $target_os"

# 2. Check Prerequisites & Bootstrap Package Managers
step "Checking Prerequisites..."

# On macOS, ensure Homebrew is available before checking curl/git
if [ "$target_os" = "macos" ] && ! command -v brew >/dev/null; then
  echo "   Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# On Linux, verify a package manager is available
case "$target_os" in
  debian | wsl2)
    if ! command -v apt-get >/dev/null; then
      error "apt-get is required on Debian/Ubuntu/WSL2."
    fi
    ;;
  fedora)
    if ! command -v dnf >/dev/null; then
      error "dnf is required on Fedora/RHEL."
    fi
    ;;
  arch)
    if ! command -v pacman >/dev/null; then
      error "pacman is required on Arch Linux."
    fi
    ;;
  *) ;;
esac

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
    x86_64 | amd64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    armv7l | armv7) arch="armv7" ;;
    *) error "Unsupported architecture for verified chezmoi install: $arch" ;;
  esac

  case "$os" in
    linux | darwin) ;;
    *) error "Unsupported OS for verified chezmoi install: $os" ;;
  esac

  tarball="chezmoi_${CHEZMOI_VERSION}_${os}_${arch}.tar.gz"
  checksums="chezmoi_${CHEZMOI_VERSION}_checksums.txt"
  base_url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL --connect-timeout 10 --max-time 120 -o "$tmp_dir/$tarball" "$base_url/$tarball"
  curl -fsSL --connect-timeout 10 --max-time 30 -o "$tmp_dir/$checksums" "$base_url/$checksums"

  # GPG Signature Verification (graceful degradation)
  checksums_sig="chezmoi_${CHEZMOI_VERSION}_checksums.txt.sig"
  if command -v gpg >/dev/null; then
    if curl -fsSL --connect-timeout 10 --max-time 30 -o "$tmp_dir/$checksums_sig" "$base_url/$checksums_sig" 2>/dev/null; then
      # Attempt to import the chezmoi signing key
      CHEZMOI_GPG_KEY="FD93980B3D3173B6894CBB0A3C270B7E4E6B46F4" # gitleaks:allow (public GPG fingerprint, not a secret)
      if ! gpg --list-keys "$CHEZMOI_GPG_KEY" >/dev/null 2>&1; then
        gpg --keyserver hkps://keys.openpgp.org --recv-keys "$CHEZMOI_GPG_KEY" 2>/dev/null ||
          gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$CHEZMOI_GPG_KEY" 2>/dev/null || true
      fi
      if gpg --list-keys "$CHEZMOI_GPG_KEY" >/dev/null 2>&1; then
        if gpg --verify "$tmp_dir/$checksums_sig" "$tmp_dir/$checksums" 2>/dev/null; then
          echo "   GPG signature verified for checksums file."
        else
          error "GPG signature verification FAILED for chezmoi checksums. Aborting."
        fi
      else
        echo "   WARNING: Could not import GPG signing key. Falling back to checksum-only verification."
      fi
    else
      echo "   WARNING: GPG signature file not available. Falling back to checksum-only verification."
    fi
  else
    echo "   NOTE: gpg not installed. Skipping signature verification (checksum-only)."
  fi

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

# 4. Backup existing dotfiles
step "Backing up existing dotfiles..."
if [ -d "$HOME/.dotfiles" ]; then
  timestamp=$(date +"%Y%m%d_%H%M%S")
  mv "$HOME/.dotfiles" "$HOME/.dotfiles.bak.$timestamp"
  echo "   Backed up existing .dotfiles to .dotfiles.bak.$timestamp"
fi

# 5. Initialize & Apply
step "Applying Configuration..."

# VERSION pinning for supply-chain security
VERSION="${1:-v0.2.478}"

SOURCE_DIR="$HOME/.dotfiles"
LEGACY_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.toml"

ensure_chezmoi_source() {
  local dir="$1"
  mkdir -p "$CHEZMOI_CONFIG_DIR"
  # Escape sed metacharacters in replacement string
  local escaped_dir
  escaped_dir=$(printf '%s\n' "$dir" | sed -e 's/[\/&]/\\&/g')
  if [ -f "$CHEZMOI_CONFIG_FILE" ] && grep -q '^sourceDir' "$CHEZMOI_CONFIG_FILE"; then
    sed -i.bak "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$CHEZMOI_CONFIG_FILE"
    rm -f "$CHEZMOI_CONFIG_FILE.bak"
  else
    printf 'sourceDir = \"%s\"\\n' "$dir" >"$CHEZMOI_CONFIG_FILE"
  fi
}

# If we are running from a local source, just apply
if [ -d "$SOURCE_DIR/.git" ]; then
  echo "   Applying from local source: $SOURCE_DIR"
  ensure_chezmoi_source "$SOURCE_DIR"
  APPLY_FLAGS=()
  if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
    APPLY_FLAGS=(--force --no-tty)
  fi
  chezmoi apply "${APPLY_FLAGS[@]}"
elif [ -d "$LEGACY_SOURCE_DIR/.git" ]; then
  echo "   Applying from legacy source: $LEGACY_SOURCE_DIR"
  ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
  APPLY_FLAGS=()
  if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
    APPLY_FLAGS=(--force --no-tty)
  fi
  chezmoi apply "${APPLY_FLAGS[@]}"
else
  echo "   Initializing from GitHub (Branch/Tag: $VERSION)..."
  # STRICT MODE: We pin to the specific tag to avoid 'main' branch drift
  git clone https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR"
  (cd "$SOURCE_DIR" && git checkout "$VERSION")
  ensure_chezmoi_source "$SOURCE_DIR"
  APPLY_FLAGS=()
  if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
    APPLY_FLAGS=(--force --no-tty)
  fi
  chezmoi apply "${APPLY_FLAGS[@]}"
fi

success
echo -e "${GREEN}Configuration loaded. Please restart your shell.${NC}"
