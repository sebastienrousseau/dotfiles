#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
UTILS_DOC="$REPO_ROOT/docs/reference/UTILS.md"
AI_DOC="$REPO_ROOT/docs/AI.md"
SCRIPTS_DOC="$REPO_ROOT/docs/reference/SCRIPTS.md"
ARCH_DOC="$REPO_ROOT/docs/architecture/ARCHITECTURE.md"
FUNCTION_GROUPS_JSON="$REPO_ROOT/.chezmoitemplates/functions/groups.json"

extract_public_commands() {
  awk '
    /_dot_help_specs\(\)/ { in_func=1; next }
    in_func && /cat <<'\''EOF'\''/ { in_block=1; next }
    in_block && /^EOF$/ { exit }
    in_block && /\|/ {
      split($0, parts, /\|/)
      print parts[2]
    }
  ' "$DOT_CLI"
}

check_dot_command_docs() {
  local failed=0
  local command=""

  while IFS= read -r command; do
    [ -n "$command" ] || continue
    if ! grep -Fq "\`dot $command" "$UTILS_DOC"; then
      printf 'Missing dot command docs: dot %s\n' "$command" >&2
      failed=1
    fi
  done < <(extract_public_commands)

  return "$failed"
}

check_ai_provider_docs() {
  local failed=0
  local provider=""

  for provider in cl copilot cline gemini kiro sgpt ollama opencode aider; do
    if ! grep -Fq "\`dot $provider\`" "$AI_DOC"; then
      printf 'Missing AI provider docs: dot %s\n' "$provider" >&2
      failed=1
    fi
  done

  return "$failed"
}

check_utility_docs() {
  local failed=0
  local utility=""

  for utility in \
    ai-update ai_core antigravity b64 bm cb dot dot-ai dot-bootstrap dot-launch-or-focus \
    dot-load-benchmark dot-load-benchmark-pty dot-theme-sync dtags epoch extract gbd gd \
    git-ai-commit git-ai-diff gl hash hashsum hex jsonv jwt kill-port lorem monitor myip \
    notify open pw rec-start rec-stop regex start-niri tmux-sessionizer tour up update uuid \
    win yamlv
  do
    if ! grep -Fq "\`$utility\`" "$SCRIPTS_DOC"; then
      printf 'Missing script docs: %s\n' "$utility" >&2
      failed=1
    fi
  done

  return "$failed"
}

check_function_group_docs() {
  local failed=0
  local group=""

  for group in $(python3 - <<'PY'
import json
from pathlib import Path
path = Path("/Users/seb/.dotfiles/.chezmoitemplates/functions/groups.json")
for key in json.loads(path.read_text()).keys():
    print(key)
PY
); do
    if ! grep -Fq "\`$group\`" "$ARCH_DOC"; then
      printf 'Missing function group docs: %s\n' "$group" >&2
      failed=1
    fi
  done

  return "$failed"
}

main() {
  local failed=0

  check_dot_command_docs || failed=1
  check_ai_provider_docs || failed=1
  check_utility_docs || failed=1
  check_function_group_docs || failed=1

  if [ "$failed" -ne 0 ]; then
    return 1
  fi

  printf 'PASS: public dot commands, utility entrypoints, AI providers, and function groups are documented\n'
}

main "$@"
