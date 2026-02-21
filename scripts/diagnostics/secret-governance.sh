#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/secrets_provider.sh
source "$REPO_ROOT/scripts/lib/secrets_provider.sh"

STRICT="${DOTFILES_ALIAS_STRICT_MODE:-${DOTFILES_SECRETS_STRICT_MODE:-0}}"

cd "$REPO_ROOT"

mapfile -t staged_files < <(git diff --cached --name-only --diff-filter=ACM || true)
if [[ "${#staged_files[@]}" -eq 0 ]]; then
  echo "Secret governance: no staged files."
  exit 0
fi

staged_content() {
  local f
  for f in "${staged_files[@]}"; do
    git show -- ":$f" 2>/dev/null || true
  done
}

violations=0
tmp_content="$(mktemp)"
trap 'rm -f "$tmp_content"' EXIT
staged_content >"$tmp_content"

scan_patterns="(api[_-]?key|api[_-]?secret|token|password)[[:space:]]*[:=][[:space:]]*[\"'][^\"']{8,}[\"']"
if grep -Eqi "$scan_patterns" "$tmp_content"; then
  echo "Secret governance: potential plaintext secret pattern detected in staged content."
  violations=$((violations + 1))
fi

if [[ "$STRICT" == "1" ]]; then
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    value="$(dot_secrets_get "$key" || true)"
    [[ -n "$value" ]] || continue
    [[ "${#value}" -ge 8 ]] || continue

    if grep -Fq "$value" "$tmp_content"; then
      echo "Secret governance: exact managed secret value leaked for key: $key"
      violations=$((violations + 1))
    fi
  done < <(dot_secrets_index_list)
fi

if [[ "$violations" -gt 0 ]]; then
  echo "Secret governance failed: $violations violation(s)."
  exit 1
fi

echo "Secret governance passed."
