#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../plugins/secret/libexec/secret/secrets_provider.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/plugins/secret/libexec/secret/secrets_provider.sh"

STRICT="${DOTFILES_ALIAS_STRICT_MODE:-${DOTFILES_SECRETS_STRICT_MODE:-0}}"

cd "$REPO_ROOT"

# Portable read — `mapfile` is bash 4 only, and this runs from the
# pre-commit hook on macOS where /bin/bash is 3.2. Without this the
# hook exits 127 and the secret scan is skipped entirely.
staged_files=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && staged_files+=("$_line")
done < <(git diff --cached --name-only --diff-filter=ACM || true)
if [[ "${#staged_files[@]}" -eq 0 ]]; then
  echo "Secret governance: no staged files."
  exit 0
fi

# The lines the commit adds: a match already in history is not this
# commit's, and a removed line is not a leak.
staged_content() {
  git diff --cached -U0 --no-color --no-ext-diff --diff-filter=ACM 2>/dev/null |
    sed -n 's/^+//p' | grep -v '^++ ' || true
}

violations=0
tmp_content="$(umask 077 && mktemp)"
trap 'rm -f "$tmp_content"' EXIT
staged_content >"$tmp_content"

# A quoted value of 8 or more characters, not one taken from a variable.
scan_patterns="(api[_-]?key|api[_-]?secret|token|password)[[:space:]]*[:=][[:space:]]*[\"'][^\"'\$][^\"']{7,}[\"']"
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
