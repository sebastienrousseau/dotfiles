#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Integrity Verification
# File: scripts/verify-integrity.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Verify integrity of dotfiles installation
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Script Variables
#------------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
readonly CHECKSUMS_FILE="${DOTFILES_DIR}/.checksums"
readonly INTEGRITY_LOG="${DOTFILES_DIR}/.integrity_log"

COLORS_ENABLED=true
VERBOSE=false
GENERATE_MODE=false
STRICT_MODE=false

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

log() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${BLUE}→${NC} $*"
    else
        echo "→ $*"
    fi
}

success() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${GREEN}✓${NC} $*"
    else
        echo "✓ $*"
    fi
}

error() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${RED}✗${NC} $*" >&2
    else
        echo "✗ $*" >&2
    fi
}

warn() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${YELLOW}⚠${NC} $*" >&2
    else
        echo "⚠ $*" >&2
    fi
}

debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "[DEBUG] $*"
    fi
}

#------------------------------------------------------------------------------
# Checksum Generation
#------------------------------------------------------------------------------

# Generate SHA256 checksum for a file
get_file_checksum() {
    local filepath="$1"
    
    if [[ ! -f "$filepath" ]]; then
        debug "File not found: $filepath"
        return 1
    fi
    
    # Use appropriate hash command based on system
    if command -v sha256sum &>/dev/null; then
        sha256sum "$filepath" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$filepath" | awk '{print $1}'
    else
        warn "No SHA256 utility available"
        return 1
    fi
}

# Generate checksums for all shell scripts
generate_checksums() {
    log "Generating checksums for dotfiles..."
    
    local temp_checksums
    temp_checksums=$(mktemp)
    trap "rm -f '$temp_checksums'" RETURN
    
    local checksums_count=0
    local failures=0
    
    # Find all shell scripts
    while IFS= read -r -d '' filepath; do
        debug "Processing: $filepath"
        
        if checksum=$(get_file_checksum "$filepath" 2>/dev/null); then
            # Store relative path and checksum
            local rel_path="${filepath#$DOTFILES_DIR/}"
            echo "$checksum  $rel_path" >> "$temp_checksums"
            ((checksums_count++))
        else
            warn "Could not generate checksum: $filepath"
            ((failures++))
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | \
             grep -zv ".git" | grep -zv ".checksums")
    
    # Sort checksums for consistency
    sort "$temp_checksums" > "$CHECKSUMS_FILE"
    chmod 0644 "$CHECKSUMS_FILE"
    
    success "Generated $checksums_count checksums"
    
    if [[ $failures -gt 0 ]]; then
        warn "Failed to generate checksums for $failures files"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Integrity Verification
#------------------------------------------------------------------------------

# Verify checksums of all files
verify_checksums() {
    log "Verifying file checksums..."
    
    if [[ ! -f "$CHECKSUMS_FILE" ]]; then
        error "Checksums file not found: $CHECKSUMS_FILE"
        error "Generate checksums first with: $0 --generate"
        return 1
    fi
    
    local verified=0
    local mismatches=0
    local missing=0
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Verify each checksum
    while IFS=' ' read -r expected_checksum rel_path; do
        # Skip empty lines and comments
        [[ -z "$expected_checksum" ]] && continue
        [[ "$expected_checksum" == "#"* ]] && continue
        
        local filepath="${DOTFILES_DIR}/${rel_path}"
        
        if [[ ! -f "$filepath" ]]; then
            error "Missing file: $rel_path"
            echo "[$timestamp] MISSING: $rel_path" >> "$INTEGRITY_LOG"
            ((missing++))
            continue
        fi
        
        # Calculate actual checksum
        if actual_checksum=$(get_file_checksum "$filepath" 2>/dev/null); then
            if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                success "OK: $rel_path"
                echo "[$timestamp] OK: $rel_path" >> "$INTEGRITY_LOG"
                ((verified++))
            else
                error "MISMATCH: $rel_path"
                error "  Expected: $expected_checksum"
                error "  Actual:   $actual_checksum"
                echo "[$timestamp] MISMATCH: $rel_path (expected: $expected_checksum, actual: $actual_checksum)" >> "$INTEGRITY_LOG"
                ((mismatches++))
            fi
        else
            warn "Could not verify: $rel_path"
            ((missing++))
        fi
    done < "$CHECKSUMS_FILE"
    
    # Print summary
    echo ""
    log "Integrity Check Summary:"
    success "$verified verified"
    
    if [[ $mismatches -gt 0 ]]; then
        error "$mismatches mismatches"
    fi
    
    if [[ $missing -gt 0 ]]; then
        warn "$missing missing/unreadable"
    fi
    
    # Return non-zero if there are mismatches in strict mode
    if [[ "$STRICT_MODE" == "true" ]] && [[ $mismatches -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Permission Verification
#------------------------------------------------------------------------------

# Verify file permissions are secure
verify_permissions() {
    log "Verifying file permissions..."
    
    local permission_issues=0
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check shell scripts for world-writable
    while IFS= read -r -d '' filepath; do
        local rel_path="${filepath#$DOTFILES_DIR/}"
        
        # Get permissions
        local perms
        perms=$(stat -f "%OLp" "$filepath" 2>/dev/null || stat -c "%a" "$filepath" 2>/dev/null)
        
        # Check if world-writable (last digit is 2 or 3)
        if [[ "${perms: -1}" =~ [23] ]]; then
            error "World-writable: $rel_path ($perms)"
            echo "[$timestamp] WORLD-WRITABLE: $rel_path ($perms)" >> "$INTEGRITY_LOG"
            ((permission_issues++))
        fi
        
        # Check if world-readable in sensitive locations (.ssh, .gnupg, etc.)
        if [[ "$rel_path" =~ (\/.ssh\/|\/.gnupg\/|\.ssh|\.gnupg) ]]; then
            if [[ "${perms: -1}" =~ [14567] ]]; then
                warn "Sensitive file is readable: $rel_path ($perms)"
            fi
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | \
             grep -zv ".git")
    
    if [[ $permission_issues -eq 0 ]]; then
        success "All file permissions are secure"
    else
        error "$permission_issues permission issues found"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Syntax Verification
#------------------------------------------------------------------------------

# Verify shell script syntax
verify_syntax() {
    log "Verifying shell script syntax..."
    
    local syntax_errors=0
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check all shell scripts
    while IFS= read -r -d '' filepath; do
        local rel_path="${filepath#$DOTFILES_DIR/}"
        
        if bash -n "$filepath" 2>/dev/null; then
            success "OK: $rel_path"
        else
            error "Syntax error: $rel_path"
            bash -n "$filepath" 2>&1 | sed 's/^/  /'
            echo "[$timestamp] SYNTAX_ERROR: $rel_path" >> "$INTEGRITY_LOG"
            ((syntax_errors++))
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | \
             grep -zv ".git")
    
    if [[ $syntax_errors -eq 0 ]]; then
        success "All shell scripts have valid syntax"
    else
        error "$syntax_errors syntax errors found"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Dependency Verification
#------------------------------------------------------------------------------

# Verify required dependencies are available
verify_dependencies() {
    log "Verifying dependencies..."
    
    local required_commands=("bash" "grep" "find" "sort")
    local missing_deps=0
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            success "Found: $cmd"
        else
            error "Missing: $cmd"
            ((missing_deps++))
        fi
    done
    
    if [[ $missing_deps -eq 0 ]]; then
        success "All required dependencies available"
    else
        error "$missing_deps required dependencies missing"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Comprehensive Verification
#------------------------------------------------------------------------------

# Run all verification checks
run_all_checks() {
    log "Running comprehensive integrity verification..."
    echo ""
    
    local checks_passed=0
    local checks_failed=0
    
    # Run all checks
    if verify_dependencies; then
        ((checks_passed++))
    else
        ((checks_failed++))
    fi
    echo ""
    
    if verify_syntax; then
        ((checks_passed++))
    else
        ((checks_failed++))
    fi
    echo ""
    
    if verify_checksums; then
        ((checks_passed++))
    else
        ((checks_failed++))
    fi
    echo ""
    
    if verify_permissions; then
        ((checks_passed++))
    else
        ((checks_failed++))
    fi
    echo ""
    
    # Print summary
    log "Verification Summary: $checks_passed passed, $checks_failed failed"
    
    if [[ $checks_failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Help and Usage
#------------------------------------------------------------------------------

usage() {
    cat << 'EOF'
Dotfiles Integrity Verification

Usage: verify-integrity.sh [OPTIONS]

Options:
  -h, --help           Display this help message
  -v, --verbose        Enable verbose output
  -g, --generate       Generate checksums
  -c, --checksums      Verify checksums only
  -p, --permissions    Verify permissions only
  -s, --syntax         Verify syntax only
  -d, --dependencies   Verify dependencies only
  --strict             Fail on any integrity issue
  --no-color           Disable colored output
  --all                Run all checks (default)

Examples:
  # Generate checksums
  verify-integrity.sh --generate

  # Verify all aspects
  verify-integrity.sh --all

  # Verify specific aspect
  verify-integrity.sh --checksums
  verify-integrity.sh --permissions

  # Run in strict mode
  verify-integrity.sh --strict
EOF
}

#------------------------------------------------------------------------------
# Main Script
#------------------------------------------------------------------------------

main() {
    local check_type="all"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -g|--generate)
                GENERATE_MODE=true
                shift
                ;;
            -c|--checksums)
                check_type="checksums"
                shift
                ;;
            -p|--permissions)
                check_type="permissions"
                shift
                ;;
            -s|--syntax)
                check_type="syntax"
                shift
                ;;
            -d|--dependencies)
                check_type="dependencies"
                shift
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --no-color)
                COLORS_ENABLED=false
                shift
                ;;
            --all)
                check_type="all"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log "Dotfiles Integrity Verification (v0.2.471)"
    echo ""
    
    if [[ "$GENERATE_MODE" == "true" ]]; then
        if generate_checksums; then
            success "Checksums generated successfully"
            exit 0
        else
            error "Failed to generate checksums"
            exit 1
        fi
    fi
    
    # Run requested checks
    case "$check_type" in
        checksums)
            verify_checksums
            ;;
        permissions)
            verify_permissions
            ;;
        syntax)
            verify_syntax
            ;;
        dependencies)
            verify_dependencies
            ;;
        all)
            run_all_checks
            ;;
        *)
            error "Unknown check type: $check_type"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
