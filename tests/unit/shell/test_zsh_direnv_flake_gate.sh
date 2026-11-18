#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# mise is the per-directory environment loader. direnv's chpwd hook runs
# only in flake mode (DOTFILES_USE_FLAKE=1), where an .envrc does
# `use flake`, which mise cannot. Unconditionally, it added a `direnv
# export` to every cd on top of mise's own hook-env.
#
# Renders rc.d/30-options.zsh.tmpl with chezmoi and sources it in `zsh -f`
# with a stub direnv that logs each call, then changes directory.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: zsh and chezmoi are both required"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home" "$SANDBOX/bin" "$SANDBOX/dir"
: >"$SANDBOX/chezmoi.toml"
LOG="$SANDBOX/direnv.log"
env -i HOME="$SANDBOX/home" PATH="$PATH" \
  chezmoi --config "$SANDBOX/chezmoi.toml" --source "$REPO_ROOT/defaults" \
  --persistent-state "$SANDBOX/state.boltdb" execute-template \
  <"$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl" >"$SANDBOX/options.zsh"

cat >"$SANDBOX/bin/direnv" <<EOF
#!/bin/sh
echo "direnv \$*" >>"$LOG"
EOF
chmod +x "$SANDBOX/bin/direnv"

# cd_with <DOTFILES_USE_FLAKE>: source the options, cd once; print how many
# times direnv ran.
cd_with() {
  : >"$LOG"
  env -i HOME="$SANDBOX/home" PATH="$SANDBOX/bin:/usr/bin:/bin" DOTFILES_USE_FLAKE="$1" \
    zsh -f -c '
      _dotfiles_add_preexec() { :; }
      _dotfiles_del_preexec() { :; }
      source "$1"
      cd "$2"
    ' _ "$SANDBOX/options.zsh" "$SANDBOX/dir" >/dev/null 2>&1
  grep -c '^direnv export' "$LOG"
}

test_start "direnv_hook_off_by_default"
assert_equals "0" "$(cd_with 0)" "without flake mode a cd does not run direnv"

test_start "direnv_hook_in_flake_mode"
assert_equals "1" "$(cd_with 1)" "in flake mode a cd runs direnv export once"

print_summary
