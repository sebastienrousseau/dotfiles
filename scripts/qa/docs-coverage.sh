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
MIN_DOCS_COVERAGE="${MIN_DOCS_COVERAGE:-100}"

TOTAL_CHECKS=0
COVERED_CHECKS=0

record_doc_check() {
  local label="$1"
  local needle="$2"
  local file="$3"

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if grep -Fq "$needle" "$file"; then
    COVERED_CHECKS=$((COVERED_CHECKS + 1))
  else
    printf 'Missing documentation: %s\n' "$label" >&2
  fi
}

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
  local command=""

  while IFS= read -r command; do
    [ -n "$command" ] || continue
    record_doc_check "dot $command in UTILS.md" "\`dot $command" "$UTILS_DOC"
  done < <(extract_public_commands)
}

check_ai_provider_docs() {
  local provider=""

  for provider in cl copilot gemini kiro sgpt ollama opencode aider; do
    record_doc_check "dot $provider in AI.md" "\`dot $provider\`" "$AI_DOC"
  done
}

check_utility_docs() {
  local utility=""

  for utility in \
    ai-update ai_core antigravity b64 bm cb dot dot-ai dot-bootstrap dot-launch-or-focus \
    dot-load-benchmark dot-load-benchmark-pty dot-theme-sync dtags epoch extract gbd gd \
    git-ai-commit git-ai-diff gl hash hashsum hex jsonv jwt kill-port lorem monitor myip \
    notify open pw rec-start rec-stop regex start-niri tmux-sessionizer tour up update uuid \
    win yamlv; do
    record_doc_check "$utility in SCRIPTS.md" "\`$utility\`" "$SCRIPTS_DOC"
  done
}

check_function_group_docs() {
  local group=""

  for group in $(
    FUNCTION_GROUPS_JSON="$FUNCTION_GROUPS_JSON" python3 - <<'PY'
import json
import os
from pathlib import Path
path = Path(os.environ["FUNCTION_GROUPS_JSON"])
for key in json.loads(path.read_text()).keys():
    print(key)
PY
  ); do
    record_doc_check "function group $group in ARCHITECTURE.md" "\`$group\`" "$ARCH_DOC"
  done
}

report_coverage() {
  local pct
  pct="$(awk -v c="$COVERED_CHECKS" -v t="$TOTAL_CHECKS" 'BEGIN{if(t==0){print "0.00"}else{printf "%.2f", (100*c/t)}}')"

  printf 'Docs coverage: %s/%s (%s%%)\n' "$COVERED_CHECKS" "$TOTAL_CHECKS" "$pct"
  printf 'Threshold: %s%%\n' "$MIN_DOCS_COVERAGE"

  awk -v p="$pct" -v min="$MIN_DOCS_COVERAGE" 'BEGIN{exit !(p+0 >= min+0)}'
}

main() {
  check_dot_command_docs
  check_ai_provider_docs
  check_utility_docs
  check_function_group_docs
  report_coverage

  printf 'PASS: public dot commands, utility entrypoints, AI providers, and function groups are documented at or above the required threshold\n'
}

main "$@"
