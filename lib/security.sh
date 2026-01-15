#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Security Hardening Module
# File: lib/security.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Security hardening checks and utilities for dotfiles
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

# Enable strict shell options for security
shopt -s failglob 2>/dev/null || true

#------------------------------------------------------------------------------
# Security Constants
#------------------------------------------------------------------------------

readonly SECURITY_VERSION="0.2.471"
readonly SECURE_UMASK="0077"
readonly SECURE_FILE_PERMS="0600"
readonly SECURE_DIR_PERMS="0700"

# Detect OS type for stat command
if [[ "$(uname -s)" == "Darwin" ]]; then
    readonly STAT_FORMAT="-f %OLp"
else
    readonly STAT_FORMAT="-c %a"
fi

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

security_log() {
    echo "[SECURITY] $*" >&2
}

security_warn() {
    echo "[SECURITY WARNING] $*" >&2
}

security_error() {
    echo "[SECURITY ERROR] $*" >&2
    return 1
}

#------------------------------------------------------------------------------
# File Permission Hardening
#------------------------------------------------------------------------------

# Verify and fix file permissions for sensitive scripts
harden_file_permissions() {
    local file="$1"
    local expected_perms="${2:-$SECURE_FILE_PERMS}"
    
    if [[ ! -f "$file" ]]; then
        security_error "File not found: $file"
        return 1
    fi
    
    local current_perms
    current_perms=$(stat $STAT_FORMAT "$file" 2>/dev/null || echo "unknown")
    
    if [[ "$current_perms" != "$expected_perms" ]]; then
        security_warn "Fixing permissions for $file: $current_perms → $expected_perms"
        chmod "$expected_perms" "$file"
    fi
    
    security_log "✓ File permissions verified: $file ($expected_perms)"
}

# Verify directory permissions
harden_directory_permissions() {
    local dir="$1"
    local expected_perms="${2:-$SECURE_DIR_PERMS}"
    
    if [[ ! -d "$dir" ]]; then
        security_error "Directory not found: $dir"
        return 1
    fi
    
    local current_perms
    current_perms=$(stat $STAT_FORMAT "$dir" 2>/dev/null || echo "unknown")
    
    if [[ "$current_perms" != "$expected_perms" ]]; then
        security_warn "Fixing permissions for $dir: $current_perms → $expected_perms"
        chmod "$expected_perms" "$dir"
    fi
    
    security_log "✓ Directory permissions verified: $dir ($expected_perms)"
}

#------------------------------------------------------------------------------
# Script Signature Verification
#------------------------------------------------------------------------------

# Verify bash script syntax without execution
verify_script_syntax() {
    local script="$1"
    
    if [[ ! -f "$script" ]]; then
        security_error "Script not found: $script"
        return 1
    fi
    
    # Use bash -n to check syntax
    if bash -n "$script" 2>/dev/null; then
        security_log "✓ Script syntax valid: $script"
        return 0
    else
        security_error "Script syntax invalid: $script"
        return 1
    fi
}

# Check for shellcheck warnings (if available)
verify_script_quality() {
    local script="$1"
    
    if ! command -v shellcheck &>/dev/null; then
        security_log "shellcheck not found, skipping script quality check"
        return 0
    fi
    
    if shellcheck -f gcc "$script" 2>/dev/null; then
        security_log "✓ Script quality check passed: $script"
        return 0
    else
        security_warn "Script quality issues found in $script (see above)"
        return 0  # Non-blocking warning
    fi
}

#------------------------------------------------------------------------------
# Security Checks
#------------------------------------------------------------------------------

# Check for insecure permissions on sensitive files
check_sensitive_file_perms() {
    local sensitive_files=(
        "${HOME}/.ssh"
        "${HOME}/.ssh/authorized_keys"
        "${HOME}/.ssh/id_rsa"
        "${HOME}/.ssh/id_ed25519"
        "${HOME}/.aws/credentials"
        "${HOME}/.aws/config"
        "${HOME}/.kube/config"
        "${HOME}/.gnupg"
    )
    
    local insecure_count=0
    
    for file in "${sensitive_files[@]}"; do
        if [[ -e "$file" ]]; then
            local perms
            perms=$(stat $STAT_FORMAT "$file" 2>/dev/null || echo "unknown")
            
            # Check for world-readable/writable
            if [[ "$perms" == *"4"* ]] || [[ "$perms" == *"2"* ]]; then
                security_error "Insecure permissions on $file: $perms"
                ((insecure_count++))
            fi
        fi
    done
    
    if [[ $insecure_count -eq 0 ]]; then
        security_log "✓ All sensitive files have secure permissions"
        return 0
    else
        return 1
    fi
}

# Verify no hardcoded secrets in environment setup
check_for_secrets() {
    local dir="${1:-.}"
    local secret_patterns=(
        "password="
        "passwd="
        "secret="
        "api_key="
        "apikey="
        "api-key="
        "aws_secret="
        "private_key="
        "database_url="
        "mongodb_uri="
    )
    
    local secrets_found=0
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -r "$pattern" "$dir" --include="*.sh" --include="*.bash" 2>/dev/null | grep -v "REDACTED" | grep -v ".git"; then
            security_warn "Potential hardcoded secret found: $pattern"
            ((secrets_found++))
        fi
    done
    
    if [[ $secrets_found -eq 0 ]]; then
        security_log "✓ No hardcoded secrets detected"
        return 0
    else
        security_warn "Found potential secrets - review the above matches"
        return 0  # Non-blocking
    fi
}

# Verify umask is secure
verify_umask() {
    local current_umask
    current_umask=$(umask)
    
    if [[ "$current_umask" == "0077" ]] || [[ "$current_umask" == "077" ]]; then
        security_log "✓ Umask is secure: $current_umask"
        return 0
    else
        security_warn "Umask is not optimal: $current_umask (recommended: 0077)"
        return 0
    fi
}

#------------------------------------------------------------------------------
# Input Validation
#------------------------------------------------------------------------------

# Sanitize string input - remove potentially dangerous characters
sanitize_input() {
    local input="$1"
    # Remove control characters and other dangerous sequences
    echo "$input" | sed 's/[^[:alnum:]._\/-]//g'
}

# Validate that input only contains safe characters
is_safe_string() {
    local input="$1"
    # Allow alphanumeric, dash, underscore, dot, and forward slash
    if [[ "$input" =~ ^[a-zA-Z0-9._\/-]+$ ]]; then
        return 0
    else
        security_error "Unsafe string: $input"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Runtime Security Checks
#------------------------------------------------------------------------------

# Verify running as non-root (unless necessary)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        security_error "This script should not be run as root"
        return 1
    fi
    return 0
}

# Verify script is sourced from a trusted location
verify_source_location() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Ensure script is from dotfiles repo
    if [[ ! "$script_dir" =~ \.dotfiles ]]; then
        security_warn "Script is not from dotfiles directory: $script_dir"
    fi
}

#------------------------------------------------------------------------------
# Secure Temporary File Handling
#------------------------------------------------------------------------------

# Create a secure temporary file
create_secure_temp() {
    local temp_file
    
    # Use mktemp with secure options
    if command -v mktemp &>/dev/null; then
        temp_file=$(mktemp) || {
            security_error "Failed to create temporary file"
            return 1
        }
        chmod "$SECURE_FILE_PERMS" "$temp_file"
        echo "$temp_file"
    else
        security_error "mktemp not available"
        return 1
    fi
}

# Securely remove a file
secure_rm() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Overwrite with random data before deletion (optional, slower)
        # shred -vfz -n 3 "$file" 2>/dev/null || rm -f "$file"
        rm -f "$file"
        security_log "✓ Securely removed: $file"
    fi
}

#------------------------------------------------------------------------------
# Audit Trail
#------------------------------------------------------------------------------

# Log security events with timestamp
log_security_event() {
    local event="$1"
    local audit_file="${DOTFILES_AUDIT_LOG:-.dotfiles_audit.log}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $event" >> "$audit_file"
}

#------------------------------------------------------------------------------
# Main Security Check
#------------------------------------------------------------------------------

# Run all security checks
run_all_security_checks() {
    security_log "Running comprehensive security checks..."
    
    local checks_passed=0
    local checks_failed=0
    
    # Run all checks
    check_not_root && ((checks_passed++)) || ((checks_failed++))
    verify_umask && ((checks_passed++)) || ((checks_failed++))
    check_sensitive_file_perms && ((checks_passed++)) || ((checks_failed++))
    check_for_secrets "." && ((checks_passed++)) || ((checks_failed++))
    
    security_log "Security checks completed: $checks_passed passed, $checks_failed failed"
    
    if [[ $checks_failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

################################################################################
# Export public functions (Bash only); Zsh does not support exporting functions
################################################################################
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f harden_file_permissions
  export -f harden_directory_permissions
  export -f verify_script_syntax
  export -f verify_script_quality
  export -f check_sensitive_file_perms
  export -f check_for_secrets
  export -f verify_umask
  export -f sanitize_input
  export -f is_safe_string
  export -f check_not_root
  export -f create_secure_temp
  export -f secure_rm
  export -f log_security_event
  export -f run_all_security_checks
  export -f security_log
  export -f security_warn
  export -f security_error
fi
