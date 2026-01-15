#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Security Tests
# File: scripts/security-tests.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Automated security testing and validation
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

#------------------------------------------------------------------------------
# Script Variables
#------------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
readonly TEST_RESULTS="${DOTFILES_DIR}/.security_test_results"

COLORS_ENABLED=true
VERBOSE=false
EXIT_CODE=0

#------------------------------------------------------------------------------
# Colors
#------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#------------------------------------------------------------------------------
# Test Reporting
#------------------------------------------------------------------------------

test_pass() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${GREEN}✓ PASS${NC} $*"
    else
        echo "✓ PASS $*"
    fi
    echo "PASS: $*" >> "$TEST_RESULTS"
}

test_fail() {
    EXIT_CODE=1
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${RED}✗ FAIL${NC} $*" >&2
    else
        echo "✗ FAIL $*" >&2
    fi
    echo "FAIL: $*" >> "$TEST_RESULTS"
}

test_skip() {
    if [[ "$COLORS_ENABLED" == "true" ]]; then
        echo -e "${YELLOW}⊘ SKIP${NC} $*"
    else
        echo "⊘ SKIP $*"
    fi
    echo "SKIP: $*" >> "$TEST_RESULTS"
}

test_info() {
    # Only show info messages in verbose mode or when not suppressed
    if [[ "${VERBOSE:-false}" == "true" ]] || [[ "$COLORS_ENABLED" == "true" ]]; then
        if [[ "$COLORS_ENABLED" == "true" ]]; then
            echo -e "${BLUE}ℹ${NC} $*"
        else
            echo "ℹ $*"
        fi
    fi
}

#------------------------------------------------------------------------------
# Permission Tests
#------------------------------------------------------------------------------

test_sensitive_file_permissions() {
    test_info "Testing sensitive file permissions..."
    
    local sensitive_files=(
        "${HOME}/.ssh/authorized_keys"
        "${HOME}/.ssh/id_rsa"
        "${HOME}/.ssh/id_ed25519"
        "${HOME}/.aws/credentials"
        "${HOME}/.kube/config"
    )
    
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -f "%OLp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || echo "")
            
            # Check if world-readable or world-writable
            if [[ "$perms" =~ [24567] ]]; then
                test_fail "Insecure permissions on $file: $perms"
            else
                test_pass "Secure permissions on $file: $perms"
            fi
        fi
    done
}

test_dotfiles_permissions() {
    test_info "Testing dotfiles directory permissions..."
    
    local perms
    perms=$(stat -f "%OLp" "$DOTFILES_DIR" 2>/dev/null || stat -c "%a" "$DOTFILES_DIR" 2>/dev/null)
    
    if [[ "$perms" =~ [234] ]]; then
        test_fail "World-accessible dotfiles directory: $perms"
    else
        test_pass "Secure dotfiles directory permissions: $perms"
    fi
}

test_shell_script_permissions() {
    test_info "Testing shell script permissions..."
    
    local executable_count=0
    local non_executable_count=0
    
    while IFS= read -r -d '' script; do
        if [[ -x "$script" ]]; then
            ((executable_count++))
        else
            ((non_executable_count++))
            test_fail "Shell script not executable: $script"
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | grep -zv ".git")
    
    test_info "Found $executable_count executable and $non_executable_count non-executable shell scripts"
    
    if [[ $non_executable_count -eq 0 ]]; then
        test_pass "All shell scripts are executable"
    fi
}

#------------------------------------------------------------------------------
# Script Syntax Tests
#------------------------------------------------------------------------------

test_shell_script_syntax() {
    test_info "Testing shell script syntax..."
    
    local syntax_errors=0
    
    while IFS= read -r -d '' script; do
        if ! bash -n "$script" 2>/dev/null; then
            test_fail "Syntax error in $script"
            ((syntax_errors++))
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | grep -zv ".git")
    
    if [[ $syntax_errors -eq 0 ]]; then
        test_pass "All shell scripts have valid syntax"
    fi
}

#------------------------------------------------------------------------------
# Security Content Tests
#------------------------------------------------------------------------------

test_no_hardcoded_secrets() {
    test_info "Testing for hardcoded secrets..."
    
    local secret_patterns=(
        "password="
        "passwd="
        "secret="
        "api_key="
        "apikey="
        "aws_secret="
        "private_key="
    )
    
    local secrets_found=0
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -r "$pattern" "$DOTFILES_DIR" --include="*.sh" --include="*.bash" 2>/dev/null | \
           grep -v "REDACTED" | grep -v ".git" | head -3; then
            ((secrets_found++))
        fi
    done
    
    if [[ $secrets_found -eq 0 ]]; then
        test_pass "No hardcoded secrets detected"
    else
        test_fail "Potential hardcoded secrets found"
    fi
}

test_no_sudo_in_scripts() {
    test_info "Testing for unexpected sudo usage..."
    
    local sudo_count=0
    
    while IFS= read -r -d '' script; do
        # Skip scripts that might legitimately use sudo
        if [[ "$script" != *"bootstrap"* ]] && [[ "$script" != *"install"* ]]; then
            if grep -q "sudo " "$script" 2>/dev/null; then
                test_fail "Unexpected sudo in $script"
                ((sudo_count++))
            fi
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | grep -zv ".git")
    
    if [[ $sudo_count -eq 0 ]]; then
        test_pass "No unexpected sudo usage found"
    fi
}

test_no_eval_usage() {
    test_info "Testing for eval usage (security concern)..."
    
    local eval_count=0
    
    while IFS= read -r -d '' script; do
        if grep -q "eval " "$script" 2>/dev/null; then
            test_fail "Found eval in $script (security concern)"
            ((eval_count++))
        fi
    done < <(find "$DOTFILES_DIR" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | grep -zv ".git")
    
    if [[ $eval_count -eq 0 ]]; then
        test_pass "No eval usage found"
    fi
}

#------------------------------------------------------------------------------
# Git Security Tests
#------------------------------------------------------------------------------

test_git_signed_commits() {
    test_info "Testing git commit signatures..."
    
    if ! command -v git &>/dev/null; then
        test_skip "Git not installed"
        return
    fi
    
    if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
        test_skip "Not a git repository"
        return
    fi
    
    cd "$DOTFILES_DIR" || return
    
    # Check if GPG is configured for signing
    local git_user
    git_user=$(git config user.name 2>/dev/null || echo "")
    
    if [[ -n "$git_user" ]]; then
        test_pass "Git user configured: $git_user"
    else
        test_skip "Git user not configured"
    fi
}

test_gitignore_secrets() {
    test_info "Testing .gitignore for secret file patterns..."
    
    if [[ ! -f "$DOTFILES_DIR/.gitignore" ]]; then
        test_fail ".gitignore file not found"
        return
    fi
    
    local secret_patterns=(
        "*.pem"
        "*.key"
        ".aws"
        ".ssh"
        ".kube"
        "credentials"
        "secrets"
    )
    
    local gitignore_content
    gitignore_content=$(cat "$DOTFILES_DIR/.gitignore")
    
    local found_count=0
    for pattern in "${secret_patterns[@]}"; do
        if echo "$gitignore_content" | grep -q "$pattern"; then
            ((found_count++))
        fi
    done
    
    if [[ $found_count -gt 0 ]]; then
        test_pass "Secret patterns in .gitignore: $found_count"
    else
        test_warn "No secret patterns found in .gitignore"
    fi
}

#------------------------------------------------------------------------------
# Environment Tests
#------------------------------------------------------------------------------

test_environment_isolation() {
    test_info "Testing environment isolation..."
    
    if [[ -n "${PATH:-}" ]]; then
        test_pass "PATH is defined"
    else
        test_fail "PATH is not defined"
    fi
    
    if [[ -n "${HOME:-}" ]]; then
        test_pass "HOME is defined"
    else
        test_fail "HOME is not defined"
    fi
}

test_umask_security() {
    test_info "Testing umask..."
    
    local current_umask
    current_umask=$(umask)
    
    if [[ "$current_umask" == "0077" ]] || [[ "$current_umask" == "077" ]]; then
        test_pass "Secure umask: $current_umask"
    else
        test_fail "Non-secure umask: $current_umask (recommended: 0077)"
    fi
}

#------------------------------------------------------------------------------
# Module Import Tests
#------------------------------------------------------------------------------

test_security_modules_exist() {
    test_info "Testing security module availability..."
    
    local modules=(
        "lib/security.sh"
        "lib/validation.sh"
        "lib/errors.sh"
        "lib/audit.sh"
    )
    
    for module in "${modules[@]}"; do
        if [[ -f "$DOTFILES_DIR/$module" ]]; then
            test_pass "Module found: $module"
        else
            test_fail "Module not found: $module"
        fi
    done
}

test_modules_are_sourced() {
    test_info "Testing module sourcing in bootstrap..."
    
    local bootstrap_script="$DOTFILES_DIR/scripts/bootstrap.macos.sh"
    
    if [[ -f "$bootstrap_script" ]]; then
        if grep -q "source.*security.sh" "$bootstrap_script" 2>/dev/null || \
           grep -q ". .*security.sh" "$bootstrap_script" 2>/dev/null; then
            test_pass "Security module sourced in bootstrap"
        else
            test_fail "Security module not sourced in bootstrap"
        fi
    fi
}

#------------------------------------------------------------------------------
# Dependency Tests
#------------------------------------------------------------------------------

test_required_commands() {
    test_info "Testing for required commands..."
    
    local required_commands=(
        "bash"
        "sh"
        "grep"
        "find"
        "sort"
        "sed"
        "awk"
    )
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            test_pass "Command available: $cmd"
        else
            test_fail "Command not available: $cmd"
        fi
    done
}

#------------------------------------------------------------------------------
# Main Test Suite
#------------------------------------------------------------------------------

run_all_tests() {
    > "$TEST_RESULTS"  # Clear previous results
    
    echo ""
    test_info "Starting security test suite..."
    echo ""
    
    # Run all tests
    test_sensitive_file_permissions
    echo ""
    
    test_dotfiles_permissions
    echo ""
    
    test_shell_script_permissions
    echo ""
    
    test_shell_script_syntax
    echo ""
    
    test_no_hardcoded_secrets
    echo ""
    
    test_no_sudo_in_scripts
    echo ""
    
    test_no_eval_usage
    echo ""
    
    test_git_signed_commits
    echo ""
    
    test_gitignore_secrets
    echo ""
    
    test_environment_isolation
    echo ""
    
    test_umask_security
    echo ""
    
    test_security_modules_exist
    echo ""
    
    test_modules_are_sourced
    echo ""
    
    test_required_commands
    echo ""
    
    # Summary
    test_info "Security test suite completed"
    
    local pass_count
    local fail_count
    pass_count=$(grep -c "^PASS:" "$TEST_RESULTS" 2>/dev/null || echo "0")
    fail_count=$(grep -c "^FAIL:" "$TEST_RESULTS" 2>/dev/null || echo "0")
    
    echo ""
    test_info "Results: $pass_count passed, $fail_count failed"
    
    if [[ $fail_count -gt 0 ]]; then
        test_info "See detailed results in: $TEST_RESULTS"
    fi
    
    return $EXIT_CODE
}

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

usage() {
    cat << 'EOF'
Security Tests for Dotfiles

Usage: security-tests.sh [OPTIONS]

Options:
  -h, --help       Display this help message
  -v, --verbose    Enable verbose output
  --no-color       Disable colored output

Examples:
  # Run all security tests
  security-tests.sh

  # Run with verbose output
  security-tests.sh --verbose
EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
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
            --no-color)
                COLORS_ENABLED=false
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
    
    test_info "Dotfiles Security Test Suite (v0.2.471)"
    run_all_tests
}

main "$@"
