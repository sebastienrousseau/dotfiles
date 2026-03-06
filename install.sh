#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh)"
# (or ./install.sh locally)

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Paths
SOURCE_DIR="${SOURCE_DIR:-$HOME/.dotfiles}"
LEGACY_SOURCE_DIR="$HOME/.local/share/chezmoi"
CHEZMOI_CONFIG_DIR="$HOME/.config/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.toml"

# Utility Functions
step() {
  if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
    printf '%b\n' "${BOLD}${BLUE}==>${NC} ${BOLD}$1${NC}"
  fi
}

error() {
  printf '%b\n' "${RED}Error:${NC} $1" >&2
  exit 1
}

success() {
  if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
    printf '%b\n' "${GREEN}Success!${NC} $1"
  fi
}

# Cross-platform sed in-place (BSD vs GNU)
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" # GNU
  else
    sed -i '' "$@" # BSD (macOS)
  fi
}

show_help() {
  cat <<EOF
Usage: install.sh [version] [options]

Arguments:
  version       The version (tag or branch) to install (default: v0.2.494)

Options:
  --help        Show this help message
  --force       Non-interactive mode (sets DOTFILES_NONINTERACTIVE=1)
  --silent      Quiet mode (sets DOTFILES_SILENT=1)

EOF
}

main() {
  local version="${1:-v0.2.494}"
  local _cleanup_files=()
  trap 'rm -f "${_cleanup_files[@]}" 2>/dev/null' EXIT

  case "$version" in
    --help)
      show_help
      exit 0
      ;;
    --silent)
      export DOTFILES_SILENT=1
      version="v0.2.494"
      ;;
  esac

  # Shift arguments to handle mixed flags/version
  for arg in "$@"; do
    case "$arg" in
      --silent) export DOTFILES_SILENT=1 ;;
      --force) export DOTFILES_NONINTERACTIVE=1 ;;
    esac
  done

  # 2. Check Prerequisites & Bootstrap Package Managers
  step "Checking Prerequisites..."

  # Detect Operating System
  OS="$(uname -s)"
  case "$OS" in
    Darwin) target_os="macos" ;;
    Linux)
      if grep -q Microsoft /proc/version 2>/dev/null; then
        target_os="wsl2"
      elif [ -f /etc/debian_version ]; then
        target_os="debian"
      elif [ -f /etc/fedora-release ]; then
        target_os="fedora"
      elif [ -f /etc/arch-release ]; then
        target_os="arch"
      else
        target_os="linux"
      fi
      ;;
    *) target_os="unknown" ;;
  esac

  # Bootstrap gum for a better UI if available or install it
  bootstrap_gum() {
    if command -v gum >/dev/null 2>&1; then return 0; fi
    if [[ "${DOTFILES_SILENT:-0}" == "1" ]]; then return 0; fi

    echo "   Bootstrapping UI components (gum)..."
    if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null; then
      brew install gum >/dev/null 2>&1
    elif [[ "$target_os" == "debian" || "$target_os" == "wsl2" ]]; then
      sudo mkdir -p /etc/apt/keyrings
      local gpg_tmp
      gpg_tmp=$(mktemp)
      _cleanup_files+=("$gpg_tmp")
      curl -fsSL -o "$gpg_tmp" https://repo.charm.sh/apt/gpg.key && sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg <"$gpg_tmp"
      rm -f "$gpg_tmp"
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt-get update && sudo apt-get install gum -y >/dev/null 2>&1
    fi
  }

  # 3. Install Chezmoi (in parallel with other checks where possible)
  install_chezmoi() {
    if command -v chezmoi >/dev/null; then
      echo "   chezmoi already installed: $(chezmoi --version)"
      return 0
    fi

    if command -v brew >/dev/null; then
      echo "   Installing chezmoi via Homebrew..."
      brew install chezmoi >/dev/null 2>&1
    else
      bin_dir="$HOME/.local/bin"
      mkdir -p "$bin_dir"
      echo "   Installing chezmoi via binary download..."

      # Secure download to temporary file
      local tmp_installer
      tmp_installer=$(umask 077 && mktemp)
      if curl -fsSL -o "$tmp_installer" https://get.chezmoi.io; then
        sh "$tmp_installer" -- -b "$bin_dir" >/dev/null 2>&1
        rm -f "$tmp_installer"
      else
        rm -f "$tmp_installer"
        return 1
      fi
    fi
  }

  # Parallel execution of bootstrapping components
  local pid_gum pid_cm
  (bootstrap_gum) &
  pid_gum=$!
  (install_chezmoi) &
  pid_cm=$!

  # Wait and check exit codes
  wait "$pid_gum" || true # gum is optional
  wait "$pid_cm" || error "chezmoi installation failed"

  # Critical: Add to PATH for the rest of the script to see it
  bin_dir="$HOME/.local/bin"
  export PATH="$bin_dir:$PATH"

  # 4. Prepare source directory
  step "Preparing source directory..."

  # VERSION pinning for supply-chain security
  VERSION="$version"

  ensure_chezmoi_source() {
    local dir="$1"
    mkdir -p "$CHEZMOI_CONFIG_DIR"
    # Escape sed metacharacters in replacement string
    local escaped_dir
    escaped_dir=$(printf '%s\n' "$dir" | sed -e 's/[\/&]/\\&/g')
    if [[ -f "$CHEZMOI_CONFIG_FILE" ]] && grep -q '^sourceDir' "$CHEZMOI_CONFIG_FILE"; then
      sed_in_place "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$CHEZMOI_CONFIG_FILE"
    else
      printf 'sourceDir = "%s"\n' "$dir" >"$CHEZMOI_CONFIG_FILE"
    fi
  }

  # 5. Backup existing dotfiles that chezmoi will overwrite
  step "Backing up existing dotfiles..."
  BACKUP_DIR="$HOME/.dotfiles.bak.$(date +"%Y%m%d_%H%M%S")"
  backup_count=0

  # Determine the source directory for chezmoi to diff against
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$SOURCE_DIR"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    ensure_chezmoi_source "$LEGACY_SOURCE_DIR"
  fi

  # Back up any existing files that chezmoi would overwrite
  if command -v chezmoi >/dev/null && [[ -f "$CHEZMOI_CONFIG_FILE" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      if [[ -e "$file" ]]; then
        rel="${file#"$HOME"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        cp -a "$file" "$BACKUP_DIR/$rel"
        backup_count=$((backup_count + 1))
      fi
    done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)
  fi

  if [[ "$backup_count" -gt 0 ]]; then
    echo "   Backed up $backup_count files to $BACKUP_DIR"
  else
    echo "   No existing dotfiles to back up."
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
  fi

  # 6. Initialize & Apply
  step "Applying Configuration..."

  # If we are running from a local source, just apply
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    echo "   Applying from local source: $SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  elif [[ -d "$LEGACY_SOURCE_DIR/.git" ]]; then
    echo "   Migrating from legacy source: $LEGACY_SOURCE_DIR"
    mv "$LEGACY_SOURCE_DIR" "$SOURCE_DIR"
    ensure_chezmoi_source "$SOURCE_DIR"
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  else
    echo "   Initializing from GitHub (Branch/Tag: $VERSION)..."
    printf '%b\n' "${CYAN}   SECURITY NOTE: Cloning pinned version $VERSION for supply-chain safety${NC}"

    # STRICT MODE: We pin to the specific tag to avoid 'main' branch drift
    git clone --depth 1 --branch "$VERSION" https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR" 2>/dev/null ||
      { git clone https://github.com/sebastienrousseau/dotfiles.git "$SOURCE_DIR" && (cd "$SOURCE_DIR" && git checkout "$VERSION"); }

    # Verify the checkout succeeded and we're on the expected version
    ACTUAL_REF=$(
      cd "$SOURCE_DIR" || exit 1
      if ! git describe --tags --exact-match 2>/dev/null; then
        git rev-parse --short HEAD
      fi
    )
    if [[ "$ACTUAL_REF" != "$VERSION" ]] && [[ "${ACTUAL_REF#v}" != "${VERSION#v}" ]]; then
      printf '%b\n' "${CYAN}   INFO: Checked out ref $ACTUAL_REF (requested: $VERSION)${NC}"
    fi

    ensure_chezmoi_source "$SOURCE_DIR"
    APPLY_FLAGS=()
    if [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
      APPLY_FLAGS=(--force --no-tty)
    fi
    chezmoi apply "${APPLY_FLAGS[@]}"
  fi

  success "Configuration loaded. Please restart your shell."
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
