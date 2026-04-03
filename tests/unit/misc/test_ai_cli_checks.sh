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

APPLY_FILE="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
DOC_FILE="$REPO_ROOT/docs/reference/TOOLS.md"
PYTOOLS_FILE="$REPO_ROOT/install/provision/run_onchange_25-python-tools.sh.tmpl"

# Chezmoi apply should list AI providers and offer mise installation
check_contains "$APPLY_FILE" "AI provider CLI checks (optional)"
check_contains "$APPLY_FILE" "copilot|npm:@github/copilot|Copilot CLI"
check_contains "$APPLY_FILE" "sgpt|pipx:shell-gpt|Shell-GPT"
check_contains "$APPLY_FILE" "ollama|aqua:ollama/ollama|Ollama"
check_contains "$APPLY_FILE" "kiro-cli|kiro-cli|Kiro CLI"
check_contains "$APPLY_FILE" "autohand|npm:autohand-cli|Autohand Code"
check_contains "$APPLY_FILE" "vibe|pipx:mistral-vibe|Mistral Vibe"
check_contains "$APPLY_FILE" "qwen|npm:@qwen-code/qwen-code|Qwen Code"
check_contains "$APPLY_FILE" "zai|npm:@guizmo-ai/zai-cli|ZAI"
check_contains "$APPLY_FILE" "mise use -g"

# Tools catalog should list Copilot, sgpt, ollama, and new AI CLIs
check_contains "$DOC_FILE" "| **Copilot CLI** | GitHub Copilot in the terminal |"
check_contains "$DOC_FILE" "| **sgpt** | Shell-GPT for terminal AI queries |"
check_contains "$DOC_FILE" "| **Ollama** | Run large language models locally |"
check_contains "$DOC_FILE" "| **Autohand Code** | Autohand coding agent CLI |"
check_contains "$DOC_FILE" "| **Mistral Vibe** | Mistral AI coding agent |"
check_contains "$DOC_FILE" "| **Qwen Code** | Qwen AI coding assistant |"
check_contains "$DOC_FILE" "| **ZAI** | Zhipu AI GLM coding agent |"

# Python tools should include key dev tools
check_contains "$PYTOOLS_FILE" "install_python_tool \"pytest\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"bandit\""
check_contains "$PYTOOLS_FILE" "install_python_tool \"mypy\""

pass "AI CLI dependency checks and docs are wired"
echo "RESULTS:1:1:0"
echo "RESULTS:1:1:0"
