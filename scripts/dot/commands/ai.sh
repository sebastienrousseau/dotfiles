#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Dotfiles AI Commands.
##
## Provides AI CLI status, setup, RAG query, and bridge commands.
## Wraps AI CLI tools with contextual patterns and system metadata.
## Usage: dot ai|ai-setup|ai-query|cl|copilot|cline|gemini|kiro|sgpt|ollama|opencode|aider

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

dot_ui_command_banner "AI and Agents" "${1:-}"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"
AI_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/ai"
AI_STATUS_TTL="${DOTFILES_AI_STATUS_TTL:-300}"
AI_STATUS_CACHE_FILE="${AI_CACHE_DIR}/status.tsv"

# Fallback to source tree if patterns don't exist in config (common in CI)
if [[ ! -d "$PATTERN_DIR" ]]; then
  _AI_SRC="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  if [[ -d "$_AI_SRC/dot_config/ai/patterns" ]]; then
    PATTERN_DIR="$_AI_SRC/dot_config/ai/patterns"
  fi
fi

_show_ai_bridge_usage() {
  echo "Usage: dot cl|copilot|cline|gemini|kiro --pattern [name] \"prompt\""
  echo ""
  echo "Available Patterns:"
  ls -1 "$PATTERN_DIR" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  - /' || echo "  (none)"
}

_ai_cache_fresh() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(stat -f %m "$file" 2>/dev/null || echo 0)
  (( now - mtime < AI_STATUS_TTL ))
}

_ai_extract_version() {
  local bin="$1"
  local output version
  output=$("$bin" --version 2>/dev/null | head -1) || true
  version=$(printf '%s' "$output" | sed 's/^[^0-9]*//' | sed 's/[[:space:]]*$//' | sed 's/\.$//')
  [[ -n "$version" ]] && printf '%s\n' "$version" || printf 'installed\n'
}

_ai_refresh_status_cache() {
  local -n ai_entries=$1
  local tmp_file
  tmp_file="$(mktemp)"
  mkdir -p "$AI_CACHE_DIR"

  local entry category role name bin desc present version
  for entry in "${ai_entries[@]}"; do
    IFS='|' read -r category role name bin desc <<<"$entry"
    if has_command "$bin"; then
      present=1
      version=$(_ai_extract_version "$bin")
    else
      present=0
      version=""
    fi
    printf '%s\t%s\t%s\n' "$bin" "$present" "$version" >>"$tmp_file"
  done

  mv "$tmp_file" "$AI_STATUS_CACHE_FILE"
}

cmd_ai_status() {
  ui_header "AI CLI Status"

  # category|name|binary|description
  local -a ai_clis=(
    "Agents (autonomous)|agent|Claude Code|claude|Anthropic CLI agent"
    "Agents (autonomous)|agent|Copilot CLI|copilot|GitHub Copilot CLI"
    "Agents (autonomous)|agent|Cline CLI|cline|Terminal coding agent"
    "Coding (interactive)|coding|Aider|aider|AI pair programmer"
    "Coding (interactive)|coding|OpenCode|opencode|Terminal coding assistant"
    "General (prompt-based)|general|Shell-GPT|sgpt|ChatGPT terminal interface"
    "General (prompt-based)|general|Gemini CLI|gemini|Google AI CLI"
    "Runtime (local)|local|Ollama|ollama|Local LLM runner"
    "Cloud (platform)|cloud|Kiro CLI|kiro-cli|AWS AI assistant"
  )

  if ! _ai_cache_fresh "$AI_STATUS_CACHE_FILE"; then
    _ai_refresh_status_cache ai_clis
  fi

  declare -A ai_present=()
  declare -A ai_version=()
  local cached_bin cached_present cached_version
  while IFS=$'\t' read -r cached_bin cached_present cached_version; do
    ai_present["$cached_bin"]="$cached_present"
    ai_version["$cached_bin"]="$cached_version"
  done <"$AI_STATUS_CACHE_FILE"

  local -a installed=()
  local current_category=""
  local category role name bin desc ver
  for entry in "${ai_clis[@]}"; do
    IFS='|' read -r category role name bin desc <<<"$entry"
    if [[ "$category" != "$current_category" ]]; then
      echo ""
      ui_section "$category"
      current_category="$category"
    fi
    if [[ "${ai_present[$bin]:-0}" == "1" ]]; then
      ver="${ai_version[$bin]:-installed}"
      [[ "$bin" == "claude" ]] && ver="${ver%% *}"
      ui_ok "$name" "$ver — $desc"
      installed+=("$name|$bin|$role")
    else
      ui_info "$name" "— $desc"
    fi
  done

  echo ""
  if [ ${#installed[@]} -eq 0 ]; then
    ui_warn "No AI CLIs installed"
  elif has_command gum; then
    ui_info "Launch" "Select an AI CLI to start"
    local -a choices=()
    for entry in "${installed[@]}"; do
      IFS='|' read -r name bin role <<<"$entry"
      choices+=("$(printf '%-16s — %s' "$name" "$role")")
    done
    local pick
    pick=$(printf '%s\n' "${choices[@]}" | gum choose --header "Select an AI CLI") || true
    if [ -n "$pick" ]; then
      pick="${pick%% — *}"
      pick="${pick%"${pick##*[![:space:]]}"}"
      for entry in "${installed[@]}"; do
        IFS='|' read -r name bin role <<<"$entry"
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
    copilot)
      copilot -sp "$full_prompt"
      ;;
    cline)
      cline "$full_prompt"
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
  cl | claude | copilot | cline | gemini | kiro | sgpt | ollama | opencode | aider)
    tool="$1"
    shift
    run_ai_with_context "$tool" "$@"
    ;;
  *)
    echo "Unknown ai command: ${1:-}" >&2
    exit 1
    ;;
esac
