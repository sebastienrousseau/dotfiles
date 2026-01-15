#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Bootstrap Ubuntu
# File: scripts/bootstrap.ubuntu.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Ubuntu-specific bootstrap (apt setup)
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}→${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log "Setting up Ubuntu environment..."

# 1. Update package lists
log "Updating package lists..."
sudo apt-get update || warn "Could not update package lists"
success "Package lists updated"

# 2. Install essential packages
log "Installing essential packages..."
PACKAGES=(
    "git"
    "curl"
    "wget"
    "zsh"
    "bash"
    "coreutils"
    "sed"
    "jq"
    "ripgrep"
    "build-essential"
    "ca-certificates"
)

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package"; then
        success "$package already installed"
    else
        log "Installing $package..."
        sudo apt-get install -y "$package" 2>/dev/null || warn "Could not install $package"
    fi
done

# 3. Install mise (version manager)
if ! command -v mise &>/dev/null; then
    log "Installing mise..."
    curl https://mise.jq.sh | sh 2>/dev/null || warn "Could not install mise"
    success "mise installed"
else
    log "mise already installed"
fi

success "Ubuntu bootstrap complete!"
