#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

DOC_FILE="$REPO_ROOT/docs/reference/TOOLS.md"
PYTOOLS_FILE="$REPO_ROOT/install/provision/run_onchange_25-python-tools.sh.tmpl"

# The apply-time AI provider offer is the ai plugin's on-apply hook, over
# the roster: tests/unit/dot-cli/test_ai_on_apply_hook.sh and
# tests/unit/ops/test_chezmoi_apply_phases.sh run it.
check_contains "$REPO_ROOT/lib/dot/ai-install.sh" "https://code.kimi.com/kimi-code/install.sh"
check_contains "$REPO_ROOT/defaults/dot_config/shell/00-core-paths.sh.tmpl" '${HOME}/.kimi-code/bin'
check_contains "$REPO_ROOT/defaults/dot_config/fish/conf.d/env.fish.tmpl" '$HOME/.kimi-code/bin'
check_contains "$REPO_ROOT/defaults/dot_config/nushell/env.nu.tmpl" '.kimi-code/bin'
check_contains "$REPO_ROOT/defaults/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl" '.kimi-code/bin'
check_contains "$REPO_ROOT/defaults/.chezmoitemplates/aliases/ai/ai.aliases.sh" "alias kiri='kiro-cli'"
check_contains "$REPO_ROOT/defaults/dot_local/share/mise/plugins/kiro-cli/bin/executable_install" 'ln -sf "kiro-cli" "$install_path/bin/kiri"'

# Tools catalog should list Copilot, sgpt, ollama, and new AI CLIs
check_contains "$DOC_FILE" "| **Copilot CLI** | GitHub Copilot in the terminal |"
check_contains "$DOC_FILE" "| **Kimi CLI** | Moonshot AI Kimi Code terminal coding agent |"
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
