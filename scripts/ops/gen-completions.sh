#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# gen-completions.sh — regenerate the deployed fish/nushell completion
# templates from `dot completion`, so they are sourced from the single
# _dot_help_specs registry instead of being hand-maintained (which drifted).
#
#   scripts/ops/gen-completions.sh           # rewrite the .tmpl files
#   scripts/ops/gen-completions.sh --check   # fail if they are out of sync
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOT="$REPO_ROOT/bin/dot"
FISH_TMPL="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"
NU_TMPL="$REPO_ROOT/defaults/dot_config/nushell/completions.nu.tmpl"
MODE="${1:-write}"

# Header lines are literal template text ({{ .dotfiles_version }} is rendered
# by chezmoi at apply time, not here) followed by the generated completion body.
render() {
  local shell="$1" title="$2"
  printf '# %s\n' "$title"
  printf '# 🅳🅾🆃🅵🅸🅻🅴🆂 (v{{ .dotfiles_version }})\n'
  printf '# AUTO-GENERATED from `dot completion %s` by scripts/ops/gen-completions.sh.\n' "$shell"
  printf '# Do not edit by hand — rerun that script after changing bin/dot commands.\n\n'
  REPO_ROOT="$REPO_ROOT" bash "$DOT" completion "$shell"
}

emit() {
  local shell="$1" title="$2" target="$3"
  local rendered
  rendered="$(render "$shell" "$title")"
  if [[ "$MODE" == "--check" ]]; then
    if ! diff -u "$target" <(printf '%s\n' "$rendered") >/dev/null 2>&1; then
      printf 'DRIFT: %s is out of sync with `dot completion %s`\n' "$target" "$shell" >&2
      printf '       run scripts/ops/gen-completions.sh to regenerate.\n' >&2
      return 1
    fi
    printf 'ok: %s in sync\n' "${target#"$REPO_ROOT"/}"
  else
    printf '%s\n' "$rendered" >"$target"
    printf 'wrote %s\n' "${target#"$REPO_ROOT"/}"
  fi
}

rc=0
emit fish "Fish completion for 'dot' CLI" "$FISH_TMPL" || rc=1
emit nu "Nushell completions for 'dot' CLI" "$NU_TMPL" || rc=1
exit "$rc"
