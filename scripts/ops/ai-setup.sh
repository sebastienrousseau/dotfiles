#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Universal AI Toolchain Setup & Authentication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ui.sh"

ui_header "Universal AI Toolchain Setup"

setup_tool() {
  local name="$1"
  local cmd="$2"
  shift 2
  # Remaining args are the auth command — passed as an array to avoid eval.
  local -a auth_argv=("$@")

  ui_section "Setting up $name"
  if command -v "$cmd" >/dev/null 2>&1; then
    if [[ ! -t 0 && "${auth_argv[*]}" != *"--version"* ]]; then
      ui_info "$name" "non-interactive shell; skipping login. Run '${auth_argv[*]}' in a terminal."
      return 0
    fi
    ui_info "Tool found, initiating authentication..."
    "${auth_argv[@]}" || ui_warn "$name" "Setup/Auth skipped or failed."
  else
    ui_err "$name" "Binary not found. Run 'dot apply' or install via mise first."
  fi
}

# 1. Claude
setup_tool "Claude CLI" "claude" claude --version # Claude handles auth via web flow or env

# 2. Antigravity CLI
setup_tool "Antigravity CLI" "agy" agy --version

# 3. Codex
setup_tool "Codex CLI" "codex" codex --version

# 4. Copilot
setup_tool "Copilot CLI" "copilot" copilot --version

# 5. Goose
setup_tool "Goose" "goose" goose --version

# 6. Kiro
setup_tool "Kiro CLI" "kiro-cli" kiro-cli login

# 7. Kimi
setup_tool "Kimi CLI" "kimi" kimi --version

# 8. Aider
setup_tool "Aider" "aider" aider --version

# 9. Autohand Code
setup_tool "Autohand Code" "autohand" autohand --version

# 10. Mistral Vibe
setup_tool "Mistral Vibe" "vibe" vibe --version

# 11. Qwen Code
setup_tool "Qwen Code" "qwen" qwen --version

# 12. ZAI
setup_tool "ZAI" "zai" zai --version

ui_header "AI Setup Complete"
ui_info "All tools are ready. Use 'dot ai' to check status."
