#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Universal AI Toolchain Setup & Authentication.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/dot/lib/ui.sh"

ui_header "Universal AI Toolchain Setup"

setup_tool() {
  local name="$1"
  local cmd="$2"
  local auth_cmd="$3"

  ui_section "Setting up $name"
  if command -v "$cmd" >/dev/null 2>&1; then
    ui_info "Tool found, initiating authentication..."
    eval "$auth_cmd" || ui_warn "$name" "Setup/Auth skipped or failed."
  else
    ui_err "$name" "Binary not found. Run 'dot apply' or install via mise first."
  fi
}

# 1. Claude
setup_tool "Claude CLI" "claude" "claude --version" # Claude handles auth via web flow or env

# 2. Gemini
setup_tool "Gemini CLI" "gemini" "gemini info"

# 3. Kiro
setup_tool "Kiro CLI" "kiro-cli" "kiro-cli auth login"

# 4. Aider
setup_tool "Aider" "aider" "aider --version"

ui_header "AI Setup Complete"
ui_info "All tools are ready. Use 'dot ai' to check status."
