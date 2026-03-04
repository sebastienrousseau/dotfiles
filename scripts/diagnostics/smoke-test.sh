#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Smoke tests to quickly verify toolchain health after installation/updates.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Running Dotfiles Smoke Tests..."
echo "==============================="

declare -i passed=0
declare -i failed=0

verify_cmd() {
    local cmd="$1"
    local expected_output="${2:-}"
    
    printf "Testing %-20s " "$cmd"
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf "[${RED}FAIL${NC}] (Command not found)
"
        failed+=1
        return 1
    fi
    
    if [[ -n "$expected_output" ]]; then
        local output
        output=$($cmd --version 2>&1 || $cmd version 2>&1 || true)
        if echo "$output" | grep -q "$expected_output"; then
             printf "[${GREEN}PASS${NC}]
"
             passed+=1
        else
             printf "[${RED}FAIL${NC}] (Output mismatch)
"
             failed+=1
        fi
    else
        printf "[${GREEN}PASS${NC}]
"
        passed+=1
    fi
}

# Core utilities
verify_cmd "git" "git version"
verify_cmd "zsh" "zsh"
verify_cmd "chezmoi" "chezmoi version"

# Rust Toolchain / Frontier
verify_cmd "rg" "ripgrep"
verify_cmd "bat" "bat"
verify_cmd "eza" "eza"
verify_cmd "zoxide" "zoxide"
verify_cmd "zellij" "zellij"

# Process management
verify_cmd "pueue" "Pueue client"

# AI Tools
verify_cmd "sgpt" "sgpt"

echo "==============================="
echo "Smoke Test Summary:"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
exit 0
