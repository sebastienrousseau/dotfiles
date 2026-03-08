#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Smoke tests to quickly verify toolchain health after installation/updates.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Running Dotfiles Smoke Tests..."
echo "==============================="

declare -i passed=0
declare -i failed=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if command -v mise >/dev/null 2>&1; then
    if mise ls --installed 2>/dev/null | grep -qE "($cmd|aqua:.*$cmd)"; then
      return 0
    fi
  fi
  return 1
}

verify_cmd() {
  local cmd="$1"
  local expected_output="${2:-}"

  printf "Testing %-20s " "$cmd"

  if ! check_cmd "$cmd"; then
    printf "[${RED}FAIL${NC}] (Command not found)\n"
    failed+=1
    return 1
  fi

  if [[ -n "$expected_output" ]]; then
    local output
    # shellcheck disable=SC2015
    output=$($cmd --version 2>&1 || $cmd version 2>&1 || true)
    if echo "$output" | grep -q "$expected_output"; then
      printf "[${GREEN}PASS${NC}]\n"
      passed+=1
    else
      printf "[${RED}FAIL${NC}] (Output mismatch)\n"
      failed+=1
    fi
  else
    printf "[${GREEN}PASS${NC}]\n"
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
verify_cmd "shfmt" "3."

# Process management
verify_cmd "pueue" "pueue"

# AI Tools
# Prevent sgpt from prompting for a key by piping empty string
export OPENAI_API_KEY="sk-placeholder-for-testing"
verify_cmd "sgpt" "ShellGPT"
verify_cmd "kiro-cli" "kiro-cli"

echo "==============================="
echo "Smoke Test Summary:"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
