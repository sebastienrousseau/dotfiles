#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

check_contains() {
  local file="$1"
  local pattern="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n --fixed-strings "$pattern" "$file" >/dev/null || fail "Missing pattern in $file: $pattern"
  else
    grep -nF "$pattern" "$file" >/dev/null || fail "Missing pattern in $file: $pattern"
  fi
}

APPLY_FILE="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
REPAIR_FILE="$REPO_ROOT/scripts/ops/post-apply-repair.sh"
CONFIG_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/configuration/configuration.aliases.sh"

check_contains "$APPLY_FILE" 'args=("$@")'
check_contains "$APPLY_FILE" 'DOTFILES_NONINTERACTIVE'
check_contains "$APPLY_FILE" 'DOTFILES_POST_APPLY_REPAIR'
check_contains "$APPLY_FILE" "post-apply-repair.sh"
check_contains "$APPLY_FILE" "Run 'exec zsh' or restart your terminal"

check_contains "$CONFIG_ALIASES" "unalias dot 2>/dev/null || true"
check_contains "$CONFIG_ALIASES" "alias dot=\"\$HOME/.local/bin/dot\""

if bash -n "$REPAIR_FILE" 2>/dev/null; then
  pass "apply upgrade path checks are wired"
else
  fail "post-apply repair script has syntax errors"
fi
