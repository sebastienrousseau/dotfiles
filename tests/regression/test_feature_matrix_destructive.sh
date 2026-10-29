#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Feature-matrix rows for the commands that delete things: dot config uninstall
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
  FM_STDIN="n" fm_run config uninstall
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
  mkdir -p "$HOME/.config/chezmoi"
  printf 'AGE-SECRET-KEY-1PLANTED\n' >"$HOME/.config/chezmoi/key.txt"
  fm_stub chezmoi 'printf "%s\n" "$*" >>"$FM_SANDBOX/chezmoi.calls"'
  test_start "fm_uninstall_force"
  fm_run config uninstall --force
  fm_expect_rc 0
  test_start "fm_uninstall_force_reports_completion"
  fm_expect_out "Uninstall complete."
  # chezmoi purge deletes chezmoi's whole config directory, the age key
  # with it, so uninstall removes the rest itself and keeps the key.
  test_start "fm_uninstall_force_keeps_the_age_key"
  if [[ -f "$HOME/.config/chezmoi/key.txt" ]] && ! grep -q purge "$FM_SANDBOX/chezmoi.calls" 2>/dev/null; then
    fm_pass "the age key is kept and chezmoi purge is not run"
  else
    fm_fail "the age key was removed, or chezmoi purge ran"
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

# On macOS another process (Finder, a sync client) can drop a .DS_Store into
# ~/.dotfiles while rm -rf is deleting it; rm then fails "Directory not
# empty". The stub rm plays that writer once, after the real removal.
test_fm_uninstall_force_outlasts_a_concurrent_writer() {
  fresh_isolated_sandbox
  plant "${UNINSTALL_TARGETS[@]/#/$HOME/}"
  fm_stub chezmoi 'true'
  fm_stub rm '
target="${*: -1}"
/bin/rm "$@" || exit
if [[ "$target" == */.dotfiles && ! -e "$FM_SANDBOX/rm.raced" ]]; then
  : >"$FM_SANDBOX/rm.raced"
  mkdir -p "$target" && : >"$target/.DS_Store"
  printf "rm: %s: Directory not empty\n" "$target" >&2
  exit 1
fi'
  test_start "fm_uninstall_force_outlasts_a_concurrent_writer"
  fm_run config uninstall --force
  fm_expect_rc 0
  test_start "fm_uninstall_force_outlasts_a_concurrent_writer_removes_the_checkout"
  if [[ -f "$FM_SANDBOX/rm.raced" && ! -e "$HOME/.dotfiles" ]]; then
    fm_pass "~/.dotfiles removed despite the late .DS_Store"
  else
    fm_fail "~/.dotfiles survived (raced: $([[ -f "$FM_SANDBOX/rm.raced" ]] && echo yes || echo no))"
  fi
  real_checkout_intact fm_uninstall_force_outlasts_a_concurrent_writer
}

# A writer that never stops: the retries run out and uninstall must fail,
# not report a completed uninstall over a checkout that is still there.
test_fm_uninstall_force_reports_a_persistent_writer() {
  fresh_isolated_sandbox
  plant "${UNINSTALL_TARGETS[@]/#/$HOME/}"
  fm_stub chezmoi 'true'
  fm_stub rm '
target="${*: -1}"
/bin/rm "$@" || exit
if [[ "$target" == */.dotfiles ]]; then
  mkdir -p "$target" && : >"$target/.DS_Store"
  printf "rm: %s: Directory not empty\n" "$target" >&2
  exit 1
fi'
  test_start "fm_uninstall_force_reports_a_persistent_writer"
  fm_run config uninstall --force
  if [[ "$FM_RC" -ne 0 && "$FM_OUT" != *"Uninstall complete."* ]]; then
    fm_pass "uninstall failed (rc=$FM_RC) instead of claiming success"
  else
    fm_fail "rc=$FM_RC with ~/.dotfiles still present"
  fi
  real_checkout_intact fm_uninstall_force_reports_a_persistent_writer
}

test_fm_chaos_force() {
  fresh_isolated_sandbox
  plant "$HOME/.config/starship.toml" "$HOME/.zshrc" "$HOME/.config/alacritty/alacritty.toml" \
    "$HOME/.config/keep/me.conf"
  test_start "fm_chaos_force"
  fm_run_route diagnostics chaos --force
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
test_fm_uninstall_force_outlasts_a_concurrent_writer
test_fm_uninstall_force_reports_a_persistent_writer
test_fm_chaos_force

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
