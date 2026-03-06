#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
## Dotfiles AI Bridge.
##
## Wraps AI CLI tools with contextual patterns and system metadata.
## Usage: dot cl --pattern [architect|hardener|refactor] "prompt"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/dot/lib/ui.sh"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"

# Fallback to source tree if patterns don't exist in config (common in CI)
if [[ ! -d "$PATTERN_DIR" ]]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
  if [[ -d "$SRC_DIR/dot_config/ai/patterns" ]]; then
    PATTERN_DIR="$SRC_DIR/dot_config/ai/patterns"
  fi
fi

show_usage() {
  echo "Usage: dot cl|gemini|kiro --pattern [name] "prompt""
  echo ""
  echo "Available Patterns:"
  ls -1 "$PATTERN_DIR" | sed 's/\.md$//' | sed 's/^/  - /'
}

run_ai_with_context() {
  local tool="$1"
  local pattern_name=""
  local prompt=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help | -h)
        show_usage
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
    show_usage
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
      printf "%b" "$full_prompt" | claude
      ;;
    gemini)
      printf "%b" "$full_prompt" | gemini chat
      ;;
    kiro | kiro-cli)
      printf "%b" "$full_prompt" | kiro-cli chat
      ;;
    sgpt)
      printf "%b" "$full_prompt" | sgpt --chat shell-gpt
      ;;
    ollama)
      printf "%b" "$full_prompt" | ollama run llama3.2
      ;;
    opencode)
      printf "%b" "$full_prompt" | opencode query
      ;;
    aider)
      printf "%b" "$full_prompt" | aider --msg "-"
      ;;
    *)
      ui_err "Unsupported tool" "$tool"
      exit 1
      ;;
  esac
}

run_ai_with_context "$@"
