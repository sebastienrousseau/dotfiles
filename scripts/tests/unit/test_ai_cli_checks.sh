#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

check_contains() {
  local file="$1"
  local pattern="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n --fixed-strings "$pattern" "$file" >/dev/null || fail "Missing pattern in $file: $pattern"
  else
    grep -nF "$pattern" "$file" >/dev/null || fail "Missing pattern in $file: $pattern"
  fi
}

HC_FILE="$REPO_ROOT/scripts/ops/health-check.sh"
APPLY_FILE="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
DOC_FILE="$REPO_ROOT/docs/TOOLS.md"
PYTOOLS_FILE="$REPO_ROOT/install/provision/run_onchange_25-python-tools.sh.tmpl"

# Health check should include AI CLIs in optional deps
check_contains "$HC_FILE" "optional_deps=(ripgrep fd bat fzf eza jq claude gemini sgpt ollama opencode aider kiro-cli)"

# Chezmoi apply should emit AI CLI checks
check_contains "$APPLY_FILE" "AI provider CLI checks (optional)"
check_contains "$APPLY_FILE" "check_cmd \"sgpt\""
check_contains "$APPLY_FILE" "check_cmd \"ollama\""
check_contains "$APPLY_FILE" "check_cmd \"kiro-cli\""

# Tools catalog should list sgpt and ollama
check_contains "$DOC_FILE" "| **sgpt** | Shell-GPT for terminal AI queries |"
check_contains "$DOC_FILE" "| **Ollama** | Run large language models locally |"

# Python tools should include key dev tools
check_contains "$PYTOOLS_FILE" "install_python_tool \"pytest\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"bandit\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"mypy\""

pass "AI CLI dependency checks and docs are wired"
echo "RESULTS:1:1:0"
echo "RESULTS:1:1:0"
