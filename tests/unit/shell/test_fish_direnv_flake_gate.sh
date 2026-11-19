#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# fish follows zsh (test_zsh_direnv_flake_gate.sh): mise is the
# per-directory environment loader, and direnv's hook is installed only in
# flake mode (DOTFILES_USE_FLAKE=1), where an .envrc does `use flake`.
#
# Renders conf.d/init.fish.tmpl with chezmoi, sources it in an interactive
# `fish --no-config`, runs its hydration with a stub _cached_eval that logs
# what it is asked to cache, and counts the direnv hooks.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v fish >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: fish and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

FISH="$(command -v fish)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/bin" "$SANDBOX/cache"
: >"$SANDBOX/chezmoi.toml"
LOG="$SANDBOX/cached.log"
env -i HOME="$SANDBOX/home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/fish/conf.d/init.fish.tmpl" >"$SANDBOX/init.fish"
printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/bin/direnv"
chmod +x "$SANDBOX/bin/direnv"

# hooks_with <DOTFILES_USE_FLAKE>: how many times hydration caches direnv.
hooks_with() {
  : >"$LOG"
  env -i HOME="$SANDBOX/home" XDG_CACHE_HOME="$SANDBOX/cache" PATH="$SANDBOX/bin:/usr/bin:/bin" \
    DOTFILES_USE_FLAKE="$1" LOG="$LOG" \
    "$FISH" --no-config -i -c '
      function _cached_eval; echo $argv >>$LOG; end
      source $argv[1]
      _dotfiles_async_init
    ' "$SANDBOX/init.fish" >/dev/null 2>&1
  grep -c '^direnv hook fish' "$LOG"
}

test_start "fish_direnv_hook_off_by_default"
assert_equals "0" "$(hooks_with 0)" "without flake mode fish installs no direnv hook"

test_start "fish_direnv_hook_in_flake_mode"
assert_equals "1" "$(hooks_with 1)" "in flake mode fish installs the direnv hook once"

print_summary
