#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Feature-matrix rows for the commands that delete things: dot uninstall
# and dot chaos --force. They used to be --help smoke rows because the
# sandbox symlinked $HOME/.dotfiles to the real checkout, and on 2026-09-24
# an uninstall run that way purged the real ~/.dotfiles. Here every test
# runs in its own isolated copy (fm_sandbox_isolate), and fm_assert_isolated
# stops the file before any command runs if a path still leads out of it.
# Regression for: GH-881

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT

# fresh_isolated_sandbox — a new isolated sandbox per test, so one test's
# deletions cannot hide another's.
fresh_isolated_sandbox() {
  fm_sandbox_teardown
  fm_sandbox_setup
  fm_sandbox_isolate || {
    printf 'could not build an isolated sandbox\n' >&2
    exit 97
  }
}

# plant <path...> — create files (and their parents) under the sandbox.
plant() {
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$f")"
    printf 'planted\n' >"$f"
  done
}

# The real checkout must look the same after every destructive row.
real_checkout_intact() {
  test_start "$1_left_the_real_checkout_intact"
  if [[ -f "$REPO_ROOT/bin/dot" && -f "$REPO_ROOT/scripts/uninstall.sh" ]]; then
    fm_pass "real checkout untouched"
  else
    fm_fail "files are missing from the real checkout"
  fi
}

UNINSTALL_TARGETS=(
  .local/bin/dot .local/bin/dot-ai .local/bin/dot-theme-sync .local/bin/tour
  .config/chezmoi/chezmoi.toml .local/share/chezmoi/README.md
  .cache/dotfiles/x .cache/zsh/x .cache/bash/x
  .local/state/dotfiles/x .local/share/dotfiles.log
  .local/share/zsh/completions/_dot .local/share/bash-completion/completions/dot
)

test_fm_uninstall_declined() {
  fresh_isolated_sandbox
  plant "${UNINSTALL_TARGETS[@]/#/$HOME/}"
  test_start "fm_uninstall_declined"
  FM_STDIN="n" fm_run uninstall
  fm_expect_rc 0
  test_start "fm_uninstall_declined_says_aborted"
  fm_expect_out "Aborted."
  test_start "fm_uninstall_declined_deletes_nothing"
  local f missing=""
  for f in "${UNINSTALL_TARGETS[@]}"; do [[ -e "$HOME/$f" ]] || missing="$missing $f"; done
  [[ -d "$HOME/.dotfiles/.git" ]] || missing="$missing .dotfiles"
  if [[ -z "$missing" ]]; then fm_pass "nothing removed"; else fm_fail "removed after declining:$missing"; fi
  real_checkout_intact fm_uninstall_declined
}

test_fm_uninstall_force() {
  fresh_isolated_sandbox
  plant "${UNINSTALL_TARGETS[@]/#/$HOME/}" "$HOME/.config/keep/me.conf" "$HOME/.local/bin/not-ours"
  fm_stub chezmoi 'printf "%s\n" "$*" >>"$FM_SANDBOX/chezmoi.calls"'
  test_start "fm_uninstall_force"
  fm_run uninstall --force
  fm_expect_rc 0
  test_start "fm_uninstall_force_reports_completion"
  fm_expect_out "Uninstall complete."
  test_start "fm_uninstall_force_purges_through_chezmoi"
  if grep -qx "purge --force" "$FM_SANDBOX/chezmoi.calls" 2>/dev/null; then
    fm_pass "chezmoi purge --force called"
  else
    fm_fail "chezmoi purge --force was not called"
  fi
  test_start "fm_uninstall_force_removes_every_managed_path"
  local f left=""
  for f in "${UNINSTALL_TARGETS[@]}" .dotfiles; do [[ -e "$HOME/$f" ]] && left="$left $f"; done
  if [[ -z "$left" ]]; then fm_pass "all managed paths removed"; else fm_fail "still present:$left"; fi
  test_start "fm_uninstall_force_keeps_unmanaged_files"
  if [[ -f "$HOME/.config/keep/me.conf" && -f "$HOME/.local/bin/not-ours" ]]; then
    fm_pass "unmanaged files kept"
  else
    fm_fail "an unmanaged file was removed"
  fi
  real_checkout_intact fm_uninstall_force
}

test_fm_chaos_force() {
  fresh_isolated_sandbox
  plant "$HOME/.config/starship.toml" "$HOME/.zshrc" "$HOME/.config/alacritty/alacritty.toml" \
    "$HOME/.config/keep/me.conf"
  test_start "fm_chaos_force"
  fm_run chaos --force
  fm_expect_rc 0
  test_start "fm_chaos_force_reports_the_injection"
  fm_expect_out "Chaos injected"
  test_start "fm_chaos_force_deletes_its_three_targets"
  local f left=""
  for f in .config/starship.toml .zshrc .config/alacritty/alacritty.toml; do
    [[ -e "$HOME/$f" ]] && left="$left $f"
  done
  if [[ -z "$left" ]]; then fm_pass "targets deleted"; else fm_fail "still present:$left"; fi
  test_start "fm_chaos_force_plants_a_broken_symlink"
  if [[ -L "$HOME/.config/broken_symlink_test" && ! -e "$HOME/.config/broken_symlink_test" ]]; then
    fm_pass "broken symlink created"
  else
    fm_fail "no broken symlink at ~/.config/broken_symlink_test"
  fi
  test_start "fm_chaos_force_spares_everything_else"
  if [[ -f "$HOME/.config/keep/me.conf" && -d "$HOME/.dotfiles/.git" ]]; then
    fm_pass "other files and the source dir kept"
  else
    fm_fail "chaos removed something outside its targets"
  fi
  real_checkout_intact fm_chaos_force
}

test_fm_uninstall_declined
test_fm_uninstall_force
test_fm_chaos_force

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
