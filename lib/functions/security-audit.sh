#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Security Audit
# File: lib/functions/security-audit.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Security posture checks
# Website: https://dotfiles.io
# License: MIT
################################################################################

DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
PARANOID_MODE="${DOTFILES_PARANOID:-0}"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log_issue() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_pass() {
    echo -e "${GREEN}✓${NC} $*"
}

################################################################################
# SSH Configuration Checks
################################################################################

check_ssh_config() {
    local ssh_config="${HOME}/.ssh/config"
    
    echo "Checking SSH configuration..."
    
    if [[ ! -f "$ssh_config" ]]; then
        log_warning "SSH config not found (OK if not using SSH)"
        return 0
    fi
    
    # Check for StrictHostKeyChecking disable
    if grep -qi "^StrictHostKeyChecking.*no" "$ssh_config"; then
        log_issue "StrictHostKeyChecking is disabled - security risk"
    else
        log_pass "StrictHostKeyChecking properly configured"
    fi
    
    # Check for UserKnownHostsFile /dev/null
    if grep -qi "UserKnownHostsFile.*dev/null" "$ssh_config"; then
        log_issue "UserKnownHostsFile set to /dev/null - security risk"
    else
        log_pass "UserKnownHostsFile properly configured"
    fi
    
    # Check permissions
    local perms=$(stat -f %A "$ssh_config" 2>/dev/null || stat -c %a "$ssh_config" 2>/dev/null)
    if [[ "$perms" != "600" ]]; then
        log_issue "SSH config has permissive permissions: $perms (should be 600)"
    else
        log_pass "SSH config permissions correct"
    fi
}

################################################################################
# Git Configuration Checks
################################################################################

check_git_config() {
    echo "Checking Git configuration..."
    
    # Check for credential storage security
    local cred_helper=$(git config --global credential.helper 2>/dev/null || echo "not-set")
    case "$cred_helper" in
        "not-set"|"osxkeychain"|"pass"|"manager")
            log_pass "Git credential helper: $cred_helper"
            ;;
        *)
            log_warning "Git credential helper set to: $cred_helper (verify it's secure)"
            ;;
    esac
    
    # Check for dangerous core.safecrlf
    local safecrlf=$(git config --global core.safecrlf 2>/dev/null || echo "not-set")
    [[ "$safecrlf" == "not-set" || "$safecrlf" == "false" ]] && log_warning "core.safecrlf not set (consider setting to true)" || log_pass "core.safecrlf: $safecrlf"
    
    # Check for global .gitignore
    if [[ -n "$(git config --global core.excludesfile 2>/dev/null)" ]]; then
        log_pass "Global .gitignore configured"
    else
        log_warning "No global .gitignore - consider setting one"
    fi
}

################################################################################
# PATH Ordering Checks
################################################################################

check_path_security() {
    echo "Checking PATH security..."
    
    local IFS=":"
    local index=0
    local issues=0
    
    for dir in $PATH; do
        ((index++))
        
        # Check for empty PATH entries (current directory)
        if [[ -z "$dir" ]] || [[ "$dir" == "." ]]; then
            log_issue "PATH entry $index is current directory (.) - security risk"
            ((issues++))
            continue
        fi
        
        # Check if dir exists
        if [[ ! -d "$dir" ]]; then
            [[ "$PARANOID_MODE" == "1" ]] && log_warning "PATH entry $index does not exist: $dir"
            continue
        fi
        
        # Check for writable directories in early PATH
        if [[ $index -le 3 ]] && [[ -w "$dir" ]]; then
            log_issue "Writable directory in early PATH (#$index): $dir"
            ((issues++))
        fi
        
        # Check for world-writable directories
        local perms=$(stat -f %OLp "$dir" 2>/dev/null || stat -c %a "$dir" 2>/dev/null | tail -c 1)
        if [[ "$perms" == "2" ]] || [[ "$perms" == "7" ]]; then
            log_issue "World-writable directory in PATH: $dir"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log_pass "PATH security checks passed"
    fi
}

################################################################################
# File Ownership Checks
################################################################################

check_file_ownership() {
    echo "Checking file ownership..."
    
    local current_user=$(whoami)
    local current_uid=$(id -u)
    local issues=0
    
    # Check home directory
    local home_uid=$(stat -f %u ~/ 2>/dev/null || stat -c %u ~/ 2>/dev/null)
    if [[ "$home_uid" != "$current_uid" ]]; then
        log_issue "Home directory owned by different user"
        ((issues++))
    else
        log_pass "Home directory ownership correct"
    fi
    
    # Check dotfiles directory
    if [[ -d "$DOTFILES_ROOT" ]]; then
        local dotfiles_uid=$(stat -f %u "$DOTFILES_ROOT" 2>/dev/null || stat -c %u "$DOTFILES_ROOT" 2>/dev/null)
        if [[ "$dotfiles_uid" != "$current_uid" ]]; then
            log_issue "Dotfiles directory owned by different user"
            ((issues++))
        else
            log_pass "Dotfiles directory ownership correct"
        fi
    fi
    
    # Check .ssh directory if it exists
    if [[ -d "${HOME}/.ssh" ]]; then
        local ssh_perms=$(stat -f %A "${HOME}/.ssh" 2>/dev/null || stat -c %a "${HOME}/.ssh" 2>/dev/null)
        if [[ "$ssh_perms" != "700" ]]; then
            log_issue ".ssh directory has permissive permissions: $ssh_perms (should be 700)"
            ((issues++))
        else
            log_pass ".ssh directory permissions correct"
        fi
    fi
}

################################################################################
# GPG Configuration Checks
################################################################################

check_gpg_agent() {
    echo "Checking GPG configuration..."
    
    if ! command -v gpg &>/dev/null; then
        log_warning "GPG not installed (optional)"
        return 0
    fi
    
    # Check if GPG agent is running
    if pgrep -x gpg-agent &>/dev/null; then
        log_pass "GPG agent is running"
    else
        log_warning "GPG agent not running (consider starting: gpgconf --launch gpg-agent)"
    fi
    
    # Check gpg-agent config
    local gpg_agent_conf="${HOME}/.gnupg/gpg-agent.conf"
    if [[ -f "$gpg_agent_conf" ]]; then
        if grep -q "^max-cache-ttl" "$gpg_agent_conf"; then
            log_pass "GPG agent timeout configured"
        else
            log_warning "GPG agent timeout not configured (consider setting max-cache-ttl)"
        fi
    else
        log_warning "GPG agent config not found (using defaults is OK)"
    fi
}

################################################################################
# Permissions Checks
################################################################################

check_permissions() {
    echo "Checking file permissions..."
    
    local issues=0
    
    # Check dotfiles scripts are executable
    if [[ -d "${DOTFILES_ROOT}/scripts" ]]; then
        for script in "${DOTFILES_ROOT}/scripts"/*.sh; do
            if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
                log_warning "Script not executable: $script"
                ((issues++))
            fi
        done
    fi
    
    # Check bin/dotfiles is executable
    if [[ -f "${DOTFILES_ROOT}/bin/dotfiles" ]] && [[ ! -x "${DOTFILES_ROOT}/bin/dotfiles" ]]; then
        log_issue "bin/dotfiles not executable"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_pass "Permissions checks passed"
    fi
}

################################################################################
# Main Security Audit
################################################################################

security_audit() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔒 SECURITY POSTURE AUDIT"
    [[ "$PARANOID_MODE" == "1" ]] && echo "🔒 (PARANOID MODE ENABLED)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_ssh_config
    echo ""
    check_git_config
    echo ""
    check_path_security
    echo ""
    check_file_ownership
    echo ""
    check_gpg_agent
    echo ""
    check_permissions
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Audit complete. Fix issues marked with ✗"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Run if executed directly (Bash-only guard)
# Referencing BASH_SOURCE in Zsh can trigger "parameter not set" errors.
if [[ -n "${BASH_VERSION:-}" ]]; then
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        security_audit "$@"
    fi
fi
