#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Universal Dotfiles Installer (Zero-Dependency)
# Usage: sh -c "$(curl -fsSL https://dotfiles.io/install.sh)"
# (or ./install.sh locally)

set -euo pipefail

# ANSI Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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
  
  echo "   Bootstrapping UI components (gum)..."
  if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null; then
    brew install gum >/dev/null 2>&1
  elif [[ "$target_os" == "debian" || "$target_os" == "wsl2" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt-get update && sudo apt-get install gum -y >/dev/null 2>&1
  fi
}
bootstrap_gum || true

if command -v gum >/dev/null 2>&1; then
  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "   ___      _    _  _  _          " \
    "  / _ \___ | |_ (_)| |(_) ___  ___ " \
    " / /_)/ _ \| __|| || || |/ _ \/ __|" \
    "/ ___/ (_) | |_ | || || |  __/\__ \ " \
    "\/    \___/ \__||_||_||_|\___||___/" \
    "           Universal Installer"
else
  printf '%b\n' "${CYAN}${BOLD}"
  cat <<"EOF"
   ___      _    _  _  _          
  / _ \___ | |_ (_)| |(_) ___  ___ 
 / /_)/ _ \| __|| || || |/ _ \/ __|
/ ___/ (_) | |_ | || || |  __/\__ \
\/    \___/ \__||_||_||_|\___||___/
           Universal Installer
EOF
  printf '%b\n' "${NC}"
fi

# On macOS, ensure Homebrew is available before checking curl/git
if [[ "$target_os" = "macos" ]] && ! command -v brew >/dev/null; then
  echo "   Homebrew not found."
  printf '%b\n' "${CYAN}   SECURITY NOTE: This will download and execute code from brew.sh${NC}"
  echo "   Verify at: https://github.com/Homebrew/install"

  # In non-interactive mode, proceed with warning
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    read -r -p "   Continue with Homebrew installation? [y/N] " response
    case "$response" in
      [yY][eE][sS] | [yY]) ;;
      *) error "Homebrew installation cancelled. Install manually: https://brew.sh" ;;
    esac
  fi

  echo "   Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
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
elif command -v brew >/dev/null; then
  echo "   Installing chezmoi via Homebrew..."
  brew install chezmoi
else
  bin_dir="$HOME/.local/bin"
  BIN_DIR="$bin_dir"
  mkdir -p "$BIN_DIR"

  echo "   Installing chezmoi via binary download..."
  printf '%b\n' "${CYAN}   SECURITY NOTE: Downloading from get.chezmoi.io with integrity check${NC}"

  # Download installer script first for inspection
  CHEZMOI_INSTALLER=$(umask 077 && mktemp)
  if ! curl -fsSL -o "$CHEZMOI_INSTALLER" https://get.chezmoi.io; then
    rm -f "$CHEZMOI_INSTALLER"
    error "Failed to download chezmoi installer."
  fi

  # Basic validation: check it's a shell script and not suspiciously large
  if [[ "$(wc -c <"$CHEZMOI_INSTALLER")" -gt 102400 ]]; then
    rm -f "$CHEZMOI_INSTALLER"
    error "Chezmoi installer suspiciously large. Aborting for security."
  fi

  if ! head -1 "$CHEZMOI_INSTALLER" | grep -q '^#!/'; then
    rm -f "$CHEZMOI_INSTALLER"
    error "Chezmoi installer doesn't look like a shell script. Aborting."
  fi

  # Execute the verified installer
  sh "$CHEZMOI_INSTALLER" -- -b "$BIN_DIR" 2>/dev/null ||
    {
      rm -f "$CHEZMOI_INSTALLER"
      error "Failed to install chezmoi."
    }

  rm -f "$CHEZMOI_INSTALLER"

  # Critical: Add to PATH for the rest of the script to see it
  export PATH="$bin_dir:$PATH"
fi

# 4. Prepare source directory
step "Preparing source directory..."

# VERSION pinning for supply-chain security
VERSION="${1:-v0.2.492}"

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
  if [[ -f "$CHEZMOI_CONFIG_FILE" ]] && grep -q '^sourceDir' "$CHEZMOI_CONFIG_FILE"; then
    sed -i.bak "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$CHEZMOI_CONFIG_FILE"
    rm -f "$CHEZMOI_CONFIG_FILE.bak"
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

success
printf '%b\n' "${GREEN}Configuration loaded. Please restart your shell.${NC}"
