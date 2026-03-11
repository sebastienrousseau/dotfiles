#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Smoke tests to quickly verify toolchain health after installation/updates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
ui_init

ui_header "Dotfiles Smoke Tests"

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

  if ! check_cmd "$cmd"; then
    ui_err "$cmd" "not found"
    failed+=1
    return 1
  fi

  if [[ -n "$expected_output" ]]; then
    local output
    # shellcheck disable=SC2015
    output=$($cmd --version 2>&1 || $cmd version 2>&1 || true)
    if echo "$output" | grep -q "$expected_output"; then
      ui_ok "$cmd"
      passed+=1
    else
      ui_err "$cmd" "output mismatch"
      failed+=1
    fi
  else
    ui_ok "$cmd"
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

echo ""
if [[ $failed -eq 0 ]]; then
  ui_ok "All $passed tests passed"
else
  ui_err "$failed failed" "$passed passed"
  exit 1
fi
