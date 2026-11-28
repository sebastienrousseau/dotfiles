#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
#
# `dot` runs chezmoi with DOTFILES_AI=1 (the shipped profiles' value, and
# what install.sh applies with) when the calling shell has not set it, so
# a shell opened before the install renders run_onchange_25-build-dot-ai-tui
# the way the install recorded it and `dot doctor` sees no drift. An
# explicit value, 0 included, is kept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
cat >"$WORK/bin/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf 'DOTFILES_AI=%s\n' "${DOTFILES_AI-unset}" >>"$CHEZMOI_LOG"
STUB
chmod +x "$WORK/bin/chezmoi"

# dot_status [VALUE]: `dot config status` with DOTFILES_AI unset, or VALUE.
dot_status() {
  local -a env_args=(-u DOTFILES_AI)
  [[ $# -eq 0 ]] || env_args=("DOTFILES_AI=$1")
  : >"$WORK/chezmoi.log"
  env "${env_args[@]}" HOME="$WORK/home" PATH="$WORK/bin:$PATH" \
    CHEZMOI_LOG="$WORK/chezmoi.log" NO_COLOR=1 \
    bash "$REPO_ROOT/bin/dot" config status >/dev/null 2>&1 || true
  cat "$WORK/chezmoi.log"
}

test_start "dot_defaults_DOTFILES_AI_to_1_for_chezmoi"
assert_equals "DOTFILES_AI=1" "$(dot_status)" "unset DOTFILES_AI reaches chezmoi as 1"

test_start "dot_keeps_an_explicit_DOTFILES_AI_0"
assert_equals "DOTFILES_AI=0" "$(dot_status 0)" "an explicit 0 is kept"
