#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Dotfiles AI Commands.
##
## Provides AI CLI status, setup, RAG query, and bridge commands.
## Wraps AI CLI tools with contextual patterns and system metadata.
## Usage: dot ai|ai-setup|ai-query|cl|gemini|kiro|sgpt|ollama|opencode|aider

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"

# Fallback to source tree if patterns don't exist in config (common in CI)
if [[ ! -d "$PATTERN_DIR" ]]; then
  _AI_SRC="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  if [[ -d "$_AI_SRC/dot_config/ai/patterns" ]]; then
    PATTERN_DIR="$_AI_SRC/dot_config/ai/patterns"
  fi
fi

_show_ai_bridge_usage() {
  echo "Usage: dot cl|gemini|kiro --pattern [name] \"prompt\""
  echo ""
  echo "Available Patterns:"
  ls -1 "$PATTERN_DIR" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  - /' || echo "  (none)"
}

cmd_ai_status() {
  ui_header "AI CLI Status"

  # Define AI CLIs: name|binary|description
  local -a ai_clis=(
    "Claude Code|claude|Anthropic CLI agent"
    "Gemini CLI|gemini|Google AI CLI"
    "OpenCode|opencode|Terminal AI coding"
    "Aider|aider|AI pair programming"
    "Shell-GPT|sgpt|ChatGPT in terminal"
    "Ollama|ollama|Local LLM runner"
    "Kiro CLI|kiro-cli|AWS AI assistant"
  )

  local -a installed=()
  local name bin desc ver
  for entry in "${ai_clis[@]}"; do
    IFS='|' read -r name bin desc <<<"$entry"
    if command -v "$bin" >/dev/null 2>&1; then
      ver=$("$bin" --version 2>/dev/null | head -1 | sed 's/^[^0-9]*//' | cut -d' ' -f1) || true
      [ -z "$ver" ] && ver="installed"
      ui_ok "$name" "$ver — $desc"
      installed+=("$name|$bin")
    else
      ui_info "$name" "— $desc"
    fi
  done

  echo ""
  if [ ${#installed[@]} -eq 0 ]; then
    ui_warn "No AI CLIs installed"
  elif command -v gum >/dev/null 2>&1; then
    ui_info "Launch" "Select an AI CLI to start"
    local -a choices=()
    for entry in "${installed[@]}"; do
      IFS='|' read -r name bin <<<"$entry"
      choices+=("$name")
    done
    local pick
    pick=$(printf '%s\n' "${choices[@]}" | gum choose --header "Pick an AI CLI") || true
    if [ -n "$pick" ]; then
      for entry in "${installed[@]}"; do
        IFS='|' read -r name bin <<<"$entry"
        if [ "$name" = "$pick" ]; then
          echo ""
          ui_info "Starting" "$name ($bin)"
          exec "$bin"
        fi
      done
    fi
  else
    ui_info "Tip" "Install gum for interactive launcher: mise use -g gum"
  fi
}

cmd_ai_setup() {
  run_script "scripts/ops/ai-setup.sh" "AI setup script" "$@"
}

cmd_ai_query() {
  run_script "dot_local/bin/executable_dot-ai" "AI RAG script" "$@"
}

run_ai_with_context() {
  local tool="$1"
  shift
  local pattern_name=""
  local prompt=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help | -h)
        _show_ai_bridge_usage
        exit 0
        ;;
      --pattern | -p)
        pattern_name="$2"
        shift 2
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$prompt" ]]; then
    _show_ai_bridge_usage
    exit 1
  fi

  local system_context=""
  if [[ -n "$pattern_name" ]]; then
    local pattern_file="$PATTERN_DIR/${pattern_name}.md"
    if [[ -f "$pattern_file" ]]; then
      system_context=$(cat "$pattern_file")
    else
      ui_err "Pattern not found" "$pattern_name"
      exit 1
    fi
  fi

  # Inject dynamic system metadata
  local metadata="## System Metadata
- OS: $(uname -s) $(uname -r)
- Arch: $(uname -m)
- Date: $(date -u)"

  local full_prompt="${system_context}

${metadata}

## User Request
${prompt}"

  ui_info "Executing $tool with pattern: ${pattern_name:-none}"

  case "$tool" in
    cl | claude)
      printf "%s" "$full_prompt" | claude
      ;;
    gemini)
      printf "%s" "$full_prompt" | gemini chat
      ;;
    kiro | kiro-cli)
      printf "%s" "$full_prompt" | kiro-cli chat
      ;;
    sgpt)
      printf "%s" "$full_prompt" | sgpt --chat shell-gpt
      ;;
    ollama)
      printf "%s" "$full_prompt" | ollama run llama3.2
      ;;
    opencode)
      printf "%s" "$full_prompt" | opencode query
      ;;
    aider)
      printf "%s" "$full_prompt" | aider --msg "-"
      ;;
    *)
      ui_err "Unsupported tool" "$tool"
      exit 1
      ;;
  esac
}

# Dispatch
case "${1:-}" in
  ai)
    shift
    cmd_ai_status "$@"
    ;;
  ai-setup)
    shift
    cmd_ai_setup "$@"
    ;;
  ai-query)
    shift
    cmd_ai_query "$@"
    ;;
  cl | claude | gemini | kiro | sgpt | ollama | opencode | aider)
    tool="$1"
    shift
    run_ai_with_context "$tool" "$@"
    ;;
  *)
    echo "Unknown ai command: ${1:-}" >&2
    exit 1
    ;;
esac
