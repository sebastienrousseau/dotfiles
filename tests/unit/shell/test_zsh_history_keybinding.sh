#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# zsh Ctrl+R: history search, not a typed `fzf` command.
#
# Renders rc.d/30-options.zsh.tmpl with chezmoi and sources it in an
# interactive `zsh -f` with a sandboxed HOME and an fzf stub on PATH.
# Without atuin (whose init runs later and binds its own widget), Ctrl+R
# must search history: fzf's history widget when fzf's key bindings
# loaded, zsh's incremental search otherwise.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

echo "Testing zsh Ctrl+R binding..."

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ZSH_BIN="$(command -v zsh)"
CHEZMOI_BIN="$(command -v chezmoi)"
: >"$SANDBOX/chezmoi.toml"
mkdir -p "$SANDBOX/render-home" "$SANDBOX/home" "$SANDBOX/bin"
printf '#!/bin/sh\nexit 0\n' >"$SANDBOX/bin/fzf"
chmod +x "$SANDBOX/bin/fzf"

test_start "options_render"
rc=0
env -i HOME="$SANDBOX/render-home" PATH="$PATH" \
  "$CHEZMOI_BIN" --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl" >"$SANDBOX/30-options.zsh" || rc=$?
assert_equals "0" "$rc" "30-options renders"

# ctrl_r <setup>: run <setup>, source the options, print the viins ^R binding.
ctrl_r() {
  env -i HOME="$SANDBOX/home" PATH="$SANDBOX/bin:/usr/bin:/bin" TERM=dumb \
    "$ZSH_BIN" -f -i -c "_dotfiles_add_precmd() { :; }; _dotfiles_add_preexec() { :; }
      $1
      source \"\$1\"; bindkey -M viins '^R'" _ "$SANDBOX/30-options.zsh" 2>/dev/null
}

test_start "ctrl_r_history_search_without_fzf_widget"
assert_equals '"^R" history-incremental-search-backward' "$(ctrl_r ':')" \
  "Ctrl+R searches history when fzf's key bindings are not loaded"

test_start "ctrl_r_keeps_fzf_history_widget"
assert_equals '"^R" fzf-history-widget' \
  "$(ctrl_r 'fzf-history-widget() { :; }; zle -N fzf-history-widget')" \
  "Ctrl+R uses fzf's history widget when fzf's key bindings loaded"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
