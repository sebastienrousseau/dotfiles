#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# rc.d/20-zinit.zsh: zinit loads at the first command when installed, and
# is never cloned from a prompt hook.
#
# The deferred loader skipped init whenever `zinit` was a function, which
# its own stub always is, so zinit never loaded. Cloning belongs to an
# explicit `zinit` call only: a network clone in a hook blocks the shell.
#
# Sources the file in `zsh -f` with a fake zinit.zsh that logs every zinit
# call and a fake git that logs clones (and "installs" zinit).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v zsh >/dev/null 2>&1; then
  echo "SKIP: zsh not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
LOG="$SANDBOX/log"
ZINIT_FILE="$REPO_ROOT/defaults/dot_config/zsh/rc.d/20-zinit.zsh"
mkdir -p "$SANDBOX/bin"

FAKE_ZINIT="$SANDBOX/zinit.zsh"
echo "zinit() { print -r -- \"zinit \$*\" >>'$LOG'; }" >"$FAKE_ZINIT"
cat >"$SANDBOX/bin/git" <<EOF
#!/bin/sh
echo "git \$*" >>"$LOG"
if [ "\$1" = clone ]; then
  mkdir -p "\$3" && cp "$FAKE_ZINIT" "\$3/zinit.zsh"
fi
EOF
chmod +x "$SANDBOX/bin/git"

# run <data-home> <code>: source the file, then run <code> (preexec hooks
# are collected in an array so the test can fire them).
run() {
  : >"$LOG"
  env -i HOME="$SANDBOX" XDG_DATA_HOME="$1" PATH="$SANDBOX/bin:/usr/bin:/bin" \
    zsh -f -c '
      typeset -ga hooks
      _dotfiles_add_preexec() { hooks+=("$1"); }
      _dotfiles_del_preexec() { hooks=(${hooks:#$1}); }
      source "$1"
      eval "$2"
    ' _ "$ZINIT_FILE" "$2" >/dev/null 2>&1
}

test_start "zinit_loads_at_first_command"
mkdir -p "$SANDBOX/installed/zinit/zinit.git"
cp "$FAKE_ZINIT" "$SANDBOX/installed/zinit/zinit.git/zinit.zsh"
run "$SANDBOX/installed" 'for h in $hooks; do $h; done'
assert_true "grep -q 'zinit light zsh-users/zsh-syntax-highlighting' '$LOG'" \
  "the first command loads zinit and its plugins"

test_start "zinit_not_cloned_from_a_hook"
run "$SANDBOX/missing" 'for h in $hooks; do $h; done'
assert_equals "0" "$(grep -c '^git clone' "$LOG")" "a missing zinit is not cloned at the first command"

test_start "zinit_explicit_call_installs_and_runs"
run "$SANDBOX/missing" 'zinit self-update'
assert_equals "1" "$(grep -c '^git clone' "$LOG")" "an explicit zinit call clones it"
assert_true "grep -q '^zinit self-update' '$LOG'" "and runs the command"

print_summary
