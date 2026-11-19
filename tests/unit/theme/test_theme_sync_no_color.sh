#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# dot-theme-sync prints colour only on a terminal, and never under NO_COLOR
# or TERM=dumb (D6, ADR-020 N14). Its --help has colour headings, so it
# shows the rule without touching any theme.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SYNC="$REPO_ROOT/bin/dot-theme-sync"
BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ESC=$'\033'

# on_tty VAR=value...: --help on a pseudo-terminal, NO_COLOR cleared from the
# inherited environment (the mutation runner exports it); prints what it wrote.
on_tty() {
  local cmd
  cmd="$(printf '%q ' env -u NO_COLOR HOME="$WORK" DOTFILES_DIR="$REPO_ROOT" "$@" "$BASH_BIN" "$SYNC" --help)"
  if script -q /dev/null true >/dev/null 2>&1; then
    script -q /dev/null "$BASH_BIN" -c "$cmd" </dev/null 2>/dev/null # BSD script
  else
    script -qec "$cmd" /dev/null </dev/null 2>/dev/null # util-linux script
  fi
}

test_start "piped_help_has_no_escapes"
out="$(HOME="$WORK" DOTFILES_DIR="$REPO_ROOT" TERM=xterm-256color "$BASH_BIN" "$SYNC" --help 2>&1)"
assert_contains "USAGE" "$out" "the help printed"
assert_equals "" "$(printf '%s' "$out" | grep -F "$ESC")" "no colour through a pipe"

if ! command -v script >/dev/null 2>&1; then
  echo "SKIP: the terminal cases need script(1)"
else
  test_start "terminal_help_is_coloured"
  out="$(on_tty TERM=xterm-256color)"
  assert_contains "${ESC}[1m" "$out" "bold headings on a terminal"

  test_start "no_color_on_a_terminal_has_no_escapes"
  out="$(on_tty TERM=xterm-256color NO_COLOR=1)"
  assert_contains "USAGE" "$out" "the help printed"
  assert_equals "" "$(printf '%s' "$out" | grep -F "${ESC}[")" "no colour under NO_COLOR"
  out="$(on_tty TERM=dumb)"
  assert_equals "" "$(printf '%s' "$out" | grep -F "${ESC}[")" "no colour under TERM=dumb"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
