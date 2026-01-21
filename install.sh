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
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN_DIR"
    export PATH="$BIN_DIR:$PATH"
fi

# 4. Initialize & Apply
step "Applying Configuration..."
# If we are running from the repo itself, just apply
if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "   Applying from local source..."
    chezmoi apply
else
    echo "   Initializing from GitHub..."
    chezmoi init --apply sebastienrousseau
fi

success
echo -e "${GREEN}Configuration loaded. Please restart your shell.${NC}"
