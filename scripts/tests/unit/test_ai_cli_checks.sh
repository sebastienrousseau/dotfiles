#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

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
check_contains "$HC_FILE" "optional_deps=(ripgrep fd bat fzf eza jq claude gemini sgpt ollama opencode aider)"

# Chezmoi apply should emit AI CLI checks
check_contains "$APPLY_FILE" "AI provider CLI checks (optional):"
check_contains "$APPLY_FILE" "check_ai_cli \"sgpt\""
check_contains "$APPLY_FILE" "check_ai_cli \"ollama\""

# Tools catalog should list sgpt and ollama
check_contains "$DOC_FILE" "| sgpt | shell-gpt |"
check_contains "$DOC_FILE" "| ollama | ollama |"

# Python tools should include key dev tools
check_contains "$PYTOOLS_FILE" "install_python_tool \"pytest\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"bandit\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"mypy\""

pass "AI CLI dependency checks and docs are wired"
