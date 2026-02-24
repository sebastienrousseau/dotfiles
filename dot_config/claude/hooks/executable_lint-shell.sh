#!/usr/bin/env bash
# Claude Code hook: Lint shell files after edit
# Runs shellcheck on .sh, .bash, .zsh files

set -euo pipefail

# Read hook input from stdin
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Exit early if no file path
[[ -z "$file_path" ]] && exit 0

# Only lint shell files
case "$file_path" in
  *.sh|*.bash|*.zsh|*dot_*)
    ;;
  *)
    exit 0
    ;;
esac

# Check if file exists
[[ -f "$file_path" ]] || exit 0

# Run shellcheck if available
if command -v shellcheck >/dev/null 2>&1; then
  output=$(shellcheck -x -f gcc "$file_path" 2>&1 || true)
  if [[ -n "$output" ]]; then
    # Return warnings as additional context
    jq -n --arg ctx "$output" '{
      "additionalContext": ("ShellCheck warnings:\n" + $ctx)
    }'
  fi
fi
