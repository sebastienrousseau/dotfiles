#!/usr/bin/env bash
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
# (or ./install.sh locally)
#
# This installer uses modular libraries from install/lib/:
#   - os_detection.sh    : OS and architecture detection
#   - package_managers.sh: Package manager bootstrapping
#   - backup.sh          : Dotfile backup functionality
#   - chezmoi.sh         : Chezmoi installation and configuration

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

VERSION="${1:-v0.2.480}"
REPO_URL="https://github.com/sebastienrousseau/dotfiles.git"
SOURCE_DIR="$HOME/.dotfiles"
LEGACY_SOURCE_DIR="$HOME/.local/share/chezmoi"

# =============================================================================
# Colors and Output
# =============================================================================

if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' BLUE='' CYAN='' BOLD='' NC=''
fi

step() { printf "%s==>%s %s%s%s\n" "${BLUE}" "${NC}" "${BOLD}" "$1" "${NC}"; }
success() { printf "%s==> Done!%s\n" "${GREEN}" "${NC}"; }
error() {
  printf "%s==> Error: %s%s\n" "${RED}" "$1" "${NC}" >&2
  exit 1
}

# =============================================================================
# Banner
# =============================================================================

printf "%s%s\n" "${CYAN}" "${BOLD}"
printf "   ___      _    _  _  _ \n"
printf "  / _ \\___ | |_ (_)| |(_) ___  ___\n"
printf " / /_)/ _ \\| __|| || || |/ _ \\/ __|\n"
printf "/ ___/ (_) | |_ | || || |  __/\\__ \\\n"
printf "\\/    \\___/ \\__|_||_||_|\___||___/\n"
printf "           Universal Installer\n"
printf "%s\n" "${NC}"

# =============================================================================
# Library Loading
# =============================================================================

# Determine script directory for library loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
LIB_DIR="${SCRIPT_DIR}/install/lib"

# Source libraries if available (for local installs)
if [ -d "$LIB_DIR" ]; then
  # shellcheck source=install/lib/os_detection.sh
  source "$LIB_DIR/os_detection.sh"
  # shellcheck source=install/lib/package_managers.sh
  source "$LIB_DIR/package_managers.sh"
  # shellcheck source=install/lib/backup.sh
  source "$LIB_DIR/backup.sh"
  # shellcheck source=install/lib/chezmoi.sh
  source "$LIB_DIR/chezmoi.sh"
  LIBS_LOADED=1
else
  LIBS_LOADED=0
fi

# =============================================================================
# Inline Functions (for remote install without libraries)
# =============================================================================

if [ "$LIBS_LOADED" = "0" ]; then
  # Minimal inline implementations when libraries aren't available
  detect_os() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    target_os="unknown"
    case "$OS" in
    Darwin) target_os="macos" ;;
    Linux)
      if [ -f /proc/version ] && grep -qi 'microsoft\|WSL' /proc/version; then
        target_os="wsl2"
      elif [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-}" in
        ubuntu | debian | pop | linuxmint | elementary) target_os="debian" ;;
        fedora | rhel | centos | rocky | alma) target_os="fedora" ;;
        arch | manjaro | endeavouros) target_os="arch" ;;
        *) target_os="linux" ;;
        esac
      else
        target_os="linux"
      fi
      ;;
    esac
    export OS ARCH target_os
  }

  print_os_info() {
    printf "   OS: %s\n" "$OS"
    printf "   Arch: %s\n" "$ARCH"
    printf "   Target: %s\n" "$target_os"
  }

  bootstrap_package_manager() {
    if [ "$target_os" = "macos" ] && ! command -v brew >/dev/null; then
      printf "   Homebrew not found.\n"
      printf "%s   SECURITY NOTE: This will download and execute code from brew.sh%s\n" "${CYAN}" "${NC}"
      if [ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]; then
        read -r -p "   Continue with Homebrew installation? [y/N] " response
        case "$response" in
        [yY][eE][sS] | [yY]) ;;
        *) error "Homebrew installation cancelled." ;;
        esac
      fi
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      [ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)"
    fi
    case "$target_os" in
    debian | wsl2) command -v apt-get >/dev/null || error "apt-get required" ;;
    fedora) command -v dnf >/dev/null || error "dnf required" ;;
    arch) command -v pacman >/dev/null || error "pacman required" ;;
    esac
  }

  check_prerequisites() {
    command -v curl >/dev/null || error "curl is required"
    command -v git >/dev/null || error "git is required"
  }

  install_chezmoi() {
    if command -v chezmoi >/dev/null; then
      printf "   chezmoi already installed: %s\n" "$(chezmoi --version)"
    elif command -v brew >/dev/null; then
      brew install chezmoi
    else
      local bin_dir="$HOME/.local/bin"
      mkdir -p "$bin_dir"
      local installer
      installer=$(mktemp)
      curl -fsSL -o "$installer" https://get.chezmoi.io || error "Failed to download chezmoi"
      [ "$(wc -c <"$installer")" -gt 102400 ] && {
        rm -f "$installer"
        error "Installer too large"
      }
      sh "$installer" -- -b "$bin_dir" 2>/dev/null || {
        rm -f "$installer"
        error "Failed to install chezmoi"
      }
      rm -f "$installer"
      export PATH="$bin_dir:$PATH"
    fi
  }

  ensure_chezmoi_source() {
    local dir="$1"
    local config_dir="$HOME/.config/chezmoi"
    mkdir -p "$config_dir"
    printf 'sourceDir = "%s"\n' "$dir" >"$config_dir/chezmoi.toml"
  }

  perform_backup() {
    local backup_dir
    backup_dir="$HOME/.dotfiles.bak.$(date +"%Y%m%d_%H%M%S")"
    local count=0

    if ! command -v chezmoi >/dev/null || ! [ -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
      printf "   chezmoi not found or not configured. Skipping backup.\n"
      return
    fi

    local managed_files
    if ! managed_files=$(chezmoi managed --path-style=absolute 2>/dev/null); then
      error "Backup failed: 'chezmoi managed' command failed."
      return 1
    fi

    if [ -z "$managed_files" ]; then
      printf "   No existing dotfiles to back up.\n"
      return
    fi

    mkdir -p "$backup_dir"

    while IFS= read -r file; do
      [ -z "$file" ] && continue
      if [ -e "$file" ]; then
        local rel="${file#"$HOME"/}"
        mkdir -p "$backup_dir/$(dirname "$rel")"
        if ! cp -a "$file" "$backup_dir/$rel"; then
          error "Backup failed: Could not copy $file"
          return 1
        fi
        count=$((count + 1))
      fi
    done <<<"$managed_files"

    if [ "$count" -gt 0 ]; then
      printf "   Backed up %s files to %s\n" "$count" "$backup_dir"
    else
      printf "   No existing dotfiles to back up.\n"
      rm -rf "$backup_dir" 2>/dev/null || true
    fi
  }
fi

# =============================================================================
# Main Installation Flow
# =============================================================================

# Step 1: Detect Environment
step "Detecting Environment..."
detect_os
print_os_info

# Step 2: Bootstrap Package Managers
step "Checking Prerequisites..."
bootstrap_package_manager
check_prerequisites

# Step 3: Install Chezmoi
step "Installing Chezmoi..."
install_chezmoi

# Step 4: Backup Existing Dotfiles
step "Backing up existing dotfiles..."
if [ -d "$SOURCE_DIR/.git" ]; then
  ensure_chezmoi_source "$SOURCE_DIR"
elif [ -d "$LEGACY_SOURCE_DIR/.git" ]; then
  ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
fi
perform_backup

# Step 5: Apply Configuration
step "Applying Configuration..."

APPLY_FLAGS=()
[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ] && APPLY_FLAGS=(--force --no-tty)

if [ -d "$SOURCE_DIR/.git" ]; then
  printf "   Applying from local source: %s\n" "$SOURCE_DIR"
  ensure_chezmoi_source "$SOURCE_DIR"
  chezmoi apply "${APPLY_FLAGS[@]}"
elif [ -d "$LEGACY_SOURCE_DIR/.git" ]; then
  printf "   Migrating from legacy source: %s\n" "$LEGACY_SOURCE_DIR"
  mv "$LEGACY_SOURCE_DIR" "$SOURCE_DIR"
  ensure_chezmoi_source "$SOURCE_DIR"
  chezmoi apply "${APPLY_FLAGS[@]}"
else
  printf "   Initializing from GitHub (Version: %s)...\n" "$VERSION"
  printf "%s   SECURITY NOTE: Cloning pinned version %s%s\n" "${CYAN}" "$VERSION" "${NC}"

  git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$SOURCE_DIR" 2>/dev/null ||
    { git clone "$REPO_URL" "$SOURCE_DIR" && (cd "$SOURCE_DIR" && git checkout "$VERSION"); }

  ensure_chezmoi_source "$SOURCE_DIR"
  chezmoi apply "${APPLY_FLAGS[@]}"
fi

# =============================================================================
# Complete
# =============================================================================

success
printf "%sConfiguration loaded. Please restart your shell.%s\n" "${GREEN}" "${NC}"
