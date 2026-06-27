#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/ai.sh and scripts/ops/chezmoi-apply.sh.
# Shared AI provider install helpers (mise-package map + Claude installer).
#
# Claude Code is installed via Anthropic's native installer rather than
# mise/npm: npm 11 silently drops the platform-native optionalDependency
# on global installs, leaving a broken binary. The native installer
# fetches the platform binary directly to ~/.local/bin/claude and
# self-updates. Requires ui_ok/ui_warn/ui_info to be defined by the caller.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_LIB_AI_INSTALL_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_AI_INSTALL_LOADED=1

# _ai_mise_pkg <binary> — map an AI provider binary to its mise package.
# claude is intentionally absent (native installer, not mise/npm: npm 11
# drops the platform-native optionalDependency on global installs).
_ai_mise_pkg() {
  case "$1" in
    codex) echo "npm:@openai/codex" ;;
    copilot) echo "npm:@github/copilot" ;;
    goose) echo "" ;;
    aider) echo "pipx:aider-chat" ;;
    opencode) echo "npm:opencode-ai" ;;
    sgpt) echo "pipx:shell-gpt" ;;
    agy) echo "" ;;
    ollama) echo "aqua:ollama/ollama" ;;
    kiro-cli) echo "kiro-cli" ;;
    autohand) echo "npm:autohand-cli" ;;
    vibe) echo "pipx:mistral-vibe" ;;
    qwen) echo "npm:@qwen-code/qwen-code" ;;
    zai) echo "npm:@guizmo-ai/zai-cli" ;;
    *) echo "" ;;
  esac
}

# install_claude_native [label] — download + run the native installer.
# Validates the installer's size and shebang before executing it. Never
# fatal: failures are reported and the caller continues.
# install_agy_native [label] — download + run the Antigravity CLI native installer.
# Validates the installer's size and shebang before executing it.
install_agy_native() {
  local label="${1:-Antigravity CLI}"
  local installer
  installer=$(umask 077 && mktemp)
  if curl -fsSL -o "$installer" https://antigravity.google/cli/install.sh &&
    [ "$(wc -c <"$installer")" -le 262144 ] &&
    head -1 "$installer" | grep -q '^#!'; then
    if command -v gum >/dev/null 2>&1; then
      if gum spin --spinner dot --title "Installing $label (native installer)" -- bash "$installer"; then
        ui_ok "$label" "installed"
      else
        ui_warn "$label" "install failed (continuing)"
      fi
    else
      ui_info "Installing" "$label via native installer"
      bash "$installer" || ui_warn "$label" "install failed (continuing)"
    fi
  else
    ui_warn "$label" "installer download/validation failed (continuing)"
  fi
  rm -f "$installer"
}

install_goose_native() {
  local label="${1:-Goose}"
  local installer
  installer=$(umask 077 && mktemp)
  # CONFIGURE=false: the goose installer otherwise runs `goose configure`
  # interactively after install, which hangs in non-interactive contexts
  # (gum spin, CI, `dot ai install`). Users can `goose configure` later.
  if curl -fsSL -o "$installer" https://github.com/block/goose/releases/download/stable/download_cli.sh &&
    [ "$(wc -c <"$installer")" -le 524288 ] &&
    head -1 "$installer" | grep -q '^#!'; then
    if command -v gum >/dev/null 2>&1; then
      if gum spin --spinner dot --title "Installing $label (native installer)" -- env CONFIGURE=false bash "$installer"; then
        ui_ok "$label" "installed"
      else
        ui_warn "$label" "install failed (continuing)"
      fi
    else
      ui_info "Installing" "$label via native installer"
      CONFIGURE=false bash "$installer" || ui_warn "$label" "install failed (continuing)"
    fi
  else
    ui_warn "$label" "installer download/validation failed (continuing)"
  fi
  rm -f "$installer"
}

install_claude_native() {
  local label="${1:-Claude Code}"
  local installer
  installer=$(umask 077 && mktemp)
  if curl -fsSL -o "$installer" https://claude.ai/install.sh &&
    [ "$(wc -c <"$installer")" -le 262144 ] &&
    head -1 "$installer" | grep -q '^#!'; then
    if command -v gum >/dev/null 2>&1; then
      if gum spin --spinner dot --title "Installing $label (native installer)" -- bash "$installer"; then
        ui_ok "$label" "installed"
      else
        ui_warn "$label" "install failed (continuing)"
      fi
    else
      ui_info "Installing" "$label via native installer"
      bash "$installer" || ui_warn "$label" "install failed (continuing)"
    fi
  else
    ui_warn "$label" "installer download/validation failed (continuing)"
  fi
  rm -f "$installer"
}
