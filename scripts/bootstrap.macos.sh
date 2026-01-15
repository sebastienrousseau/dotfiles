#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Bootstrap macOS
# File: scripts/bootstrap.macos.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: macOS-specific bootstrap with security hardening
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail
shopt -s failglob 2>/dev/null || true

# Script root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Source security modules
if [[ -f "$DOTFILES_DIR/lib/security.sh" ]]; then
    source "$DOTFILES_DIR/lib/security.sh"
fi

if [[ -f "$DOTFILES_DIR/lib/errors.sh" ]]; then
    source "$DOTFILES_DIR/lib/errors.sh"
fi

if [[ -f "$DOTFILES_DIR/lib/validation.sh" ]]; then
    source "$DOTFILES_DIR/lib/validation.sh"
fi

if [[ -f "$DOTFILES_DIR/lib/audit.sh" ]]; then
    source "$DOTFILES_DIR/lib/audit.sh"
    init_audit
fi

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

# Initialize error handling and security
init_error_handling
check_not_root || exit 1
verify_umask
start_audit_session 2>/dev/null || true

log "Setting up macOS environment..."
audit_event "BOOTSTRAP" "started" "version=0.2.471" 2>/dev/null || true

# 1. Install Homebrew if not present
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew..."
    
    # Download Homebrew installer with integrity check
    local installer_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    local temp_installer
    temp_installer=$(mktemp) || {
        error "Failed to create temporary file"
        exit 1
    }
    
    on_exit "rm -f '$temp_installer'" 2>/dev/null || true
    
    if curl -fsSL --connect-timeout 10 "$installer_url" -o "$temp_installer"; then
        # Verify script syntax before execution
        if verify_script_syntax "$temp_installer"; then
            bash "$temp_installer" || {
                error "Homebrew installation failed"
                audit_event "BOOTSTRAP" "failed" "reason=homebrew_install" 2>/dev/null || true
                exit 1
            }
            success "Homebrew installed"
            audit_action "INSTALL" "homebrew" "success" 2>/dev/null || true
        else
            error "Homebrew installer script has invalid syntax"
            exit 1
        fi
    else
        error "Failed to download Homebrew installer"
        exit 1
    fi
else
    log "Homebrew already installed"
fi

# 2. Update Homebrew
log "Updating Homebrew..."
if timeout_exec 120 "brew update" 2>/dev/null || warn "Could not update Homebrew"; then
    success "Homebrew updated"
fi

# 3. Install essential packages
log "Installing essential packages..."
PACKAGES=(
    "git"
    "curl"
    "wget"
    "zsh"
    "bash"
    "coreutils"
    "gnu-sed"
    "jq"
    "ripgrep"
    "mise"
)

local install_count=0
local skip_count=0
local fail_count=0

for package in "${PACKAGES[@]}"; do
    # Validate package name
    if ! validate_identifier "$package"; then
        warn "Skipping invalid package name: $package"
        continue
    fi
    
    if brew list "$package" &>/dev/null; then
        success "$package already installed"
        ((skip_count++))
    else
        log "Installing $package..."
        if retry 2 5 "brew install '$package'" 2>/dev/null; then
            success "$package installed"
            audit_action "INSTALL" "$package" "success" 2>/dev/null || true
            ((install_count++))
        else
            warn "Could not install $package"
            audit_action "INSTALL" "$package" "failed" 2>/dev/null || true
            ((fail_count++))
        fi
    fi
done

# 4. Tap additional repos if needed
log "Tapping additional Homebrew repositories..."
if timeout_exec 60 "brew tap --repair" 2>/dev/null; then
    success "Homebrew taps ready"
else
    warn "Could not repair Homebrew taps"
fi

# 5. Verify Homebrew integrity
log "Verifying Homebrew installation..."
if command -v brew &>/dev/null; then
    local brew_version
    brew_version=$(brew --version 2>/dev/null || echo "unknown")
    success "Homebrew verified: $brew_version"
    audit_event "BOOTSTRAP" "verification" "homebrew_ok" 2>/dev/null || true
else
    error "Homebrew verification failed"
    audit_event "BOOTSTRAP" "verification" "homebrew_failed" 2>/dev/null || true
    exit 1
fi

# Print summary
echo ""
log "Bootstrap Summary:"
log "  Installed: $install_count packages"
log "  Skipped: $skip_count packages"

if [[ $fail_count -gt 0 ]]; then
    warn "  Failed: $fail_count packages"
fi

audit_event "BOOTSTRAP" "completed" "installed=$install_count|skipped=$skip_count|failed=$fail_count" 2>/dev/null || true
end_audit_session 2>/dev/null || true

if [[ $fail_count -eq 0 ]]; then
    success "macOS bootstrap complete!"
    exit 0
else
    warn "macOS bootstrap completed with errors"
    exit 1
fi
