#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 Smoke Tests
# File: scripts/smoke-tests.sh
# Version: 0.2.471
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Interactive shell smoke tests for CI/validation
# Website: https://dotfiles.io
# License: MIT
################################################################################

set -euo pipefail

DOTFILES_ROOT="${HOME}/.dotfiles"
TESTS_PASSED=0
TESTS_FAILED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

test_pass() {
    echo -e "${GREEN}✓${NC} $*"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $*"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘${NC} $*"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

################################################################################
# Test Suite
################################################################################

test_dotfiles_command() {
    print_header "Test: dotfiles command"
    
    if command -v dotfiles &>/dev/null; then
        test_pass "dotfiles command found in PATH"
    else
        test_fail "dotfiles command not found in PATH"
    fi
    
    if dotfiles --help &>/dev/null; then
        test_pass "dotfiles --help works"
    else
        test_fail "dotfiles --help failed"
    fi
    
    if dotfiles version &>/dev/null; then
        test_pass "dotfiles version works"
    else
        test_fail "dotfiles version failed"
    fi
}

test_aliases() {
    print_header "Test: Aliases"
    
    # Count aliases
    local alias_count=$(alias | wc -l)
    if [[ $alias_count -gt 10 ]]; then
        test_pass "Aliases loaded ($alias_count aliases)"
    else
        test_fail "Few aliases loaded ($alias_count aliases)"
    fi
    
    # Test some core aliases
    if alias | grep -q "^alias c="; then
        test_pass "Core aliases present"
    else
        test_skip "Some core aliases not found"
    fi
}

test_functions() {
    print_header "Test: Functions"
    
    # Count functions
    local func_count=$(declare -F | wc -l)
    if [[ $func_count -gt 20 ]]; then
        test_pass "Functions loaded ($func_count functions)"
    else
        test_fail "Few functions loaded ($func_count functions)"
    fi
    
    # Test specific functions
    if declare -f is_macos &>/dev/null; then
        test_pass "compat.sh functions available"
    else
        test_skip "compat.sh functions not loaded"
    fi
    
    if declare -f dotfiles_history &>/dev/null; then
        test_pass "history functions available"
    else
        test_skip "history functions not loaded"
    fi
}

test_completions() {
    print_header "Test: Completions"
    
    # Check for bash completion functions
    if declare -f _git_completion &>/dev/null 2>&1; then
        test_pass "Git completions loaded"
    else
        test_skip "Git completions not loaded"
    fi
    
    # Check complete command availability
    if command -v complete &>/dev/null; then
        test_pass "Bash completions available"
    else
        test_skip "Bash completions not available"
    fi
}

test_mise() {
    print_header "Test: mise (Version Manager)"
    
    if command -v mise &>/dev/null; then
        test_pass "mise installed"
        local mise_version=$(mise --version 2>/dev/null || echo "unknown")
        test_pass "mise version: $mise_version"
    else
        test_skip "mise not installed (optional)"
    fi
}

test_prompt() {
    print_header "Test: Prompt"
    
    if [[ -n "${PS1:-}" ]]; then
        test_pass "PS1 is set"
    else
        test_fail "PS1 not set"
    fi
    
    # Test that prompt renders without errors
    if eval "$PS1" &>/dev/null 2>&1; then
        test_pass "Prompt evaluates without errors"
    else
        test_skip "Could not evaluate prompt"
    fi
}

test_env_vars() {
    print_header "Test: Environment Variables"
    
    if [[ -n "${DOTFILES_ROOT:-}" ]]; then
        test_pass "DOTFILES_ROOT is set: $DOTFILES_ROOT"
    else
        test_fail "DOTFILES_ROOT not set"
    fi
    
    if [[ -n "${LANG:-}" ]]; then
        test_pass "LANG is set: $LANG"
    else
        test_skip "LANG not set"
    fi
}

test_git() {
    print_header "Test: Git"
    
    if command -v git &>/dev/null; then
        local git_version=$(git --version)
        test_pass "Git installed: $git_version"
    else
        test_fail "Git not installed"
    fi
    
    if [[ -d "${DOTFILES_ROOT}/.git" ]]; then
        test_pass "Dotfiles is a git repository"
    else
        test_skip "Dotfiles is not a git repository"
    fi
}

test_syntax() {
    print_header "Test: Shell Syntax"
    
    if bash -n "${HOME}/.bashrc" 2>/dev/null; then
        test_pass ".bashrc syntax valid"
    else
        test_fail ".bashrc has syntax errors"
    fi
    
    if command -v zsh &>/dev/null && zsh -n "${HOME}/.zshrc" 2>/dev/null; then
        test_pass ".zshrc syntax valid"
    else
        test_skip ".zshrc validation skipped"
    fi
}

################################################################################
# Main
################################################################################

main() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🧪 DOTFILES SMOKE TEST SUITE${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Run all tests
    test_dotfiles_command
    test_syntax
    test_env_vars
    test_git
    test_aliases
    test_functions
    test_completions
    test_mise
    test_prompt
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    else
        echo -e "${GREEN}Failed: 0${NC}"
    fi
    echo ""
    
    # Exit code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

main "$@"
