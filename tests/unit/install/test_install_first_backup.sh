#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# A first install backs up the user's dotfiles before chezmoi overwrites
# them. The backup used to run before the source was cloned, when chezmoi
# had no config and so listed nothing, and the first `chezmoi apply` then
# replaced the user's files with no copy kept. install.sh runs here against
# a stubbed git (the clone makes a source tree) and a stubbed chezmoi
# (`managed` lists ~/.zshrc and ~/.gitconfig; `apply` overwrites both).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-install-backup.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# stub <dir> <name> <body>: an executable stub that also logs its call.
stub() {
  printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >>"$TMP_LOG"\n%s\n' "$2" "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# new_case NAME: a case directory with a HOME, install.sh and the stubs.
new_case() {
  C="$WORK/$1"
  mkdir -p "$C/bin" "$C/home"
  cp "$REPO_ROOT/install.sh" "$C/install.sh"
  : >"$C/log"
  stub "$C/bin" curl 'exit 1'
  stub "$C/bin" git '
if [[ "$1" == "clone" ]]; then
  dest="${*: -1}"
  mkdir -p "$dest/.git" "$dest/defaults"
  printf "profile = \"default\"\n" >"$dest/defaults/.chezmoidata.toml"
fi
[[ "$1" == "describe" ]] && exit 1
[[ "$1" == "rev-parse" ]] && echo v0.2.500
exit 0'
  stub "$C/bin" chezmoi '
case "$1" in
  managed) printf "%s\n" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.config" ;;
  apply) printf "framework\n" >"$HOME/.zshrc"; printf "framework\n" >"$HOME/.gitconfig" ;;
esac
exit 0'
}

# run_install: install.sh with the case's stubs first on PATH and its HOME.
run_install() {
  RC=0
  TMP_LOG="$C/log" PATH="$C/bin:/usr/bin:/bin" HOME="$C/home" \
    DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 \
    bash "$C/install.sh" >"$C/out" 2>&1 || RC=$?
}

# backup_of FILE: the backed-up copy of ~/FILE, if any.
backup_of() {
  local d
  for d in "$C"/home/.dotfiles.bak.*; do
    [[ -f "$d/$1" ]] && cat "$d/$1"
  done
}

test_start "a_first_install_backs_up_what_apply_overwrites"
new_case first
printf 'mine\n' >"$C/home/.zshrc"
printf 'my identity\n' >"$C/home/.gitconfig"
mkdir -p "$C/home/.config/keep"
run_install
assert_equals "0" "$RC" "install.sh succeeds"
assert_equals "framework" "$(cat "$C/home/.zshrc")" "apply wrote the framework's ~/.zshrc"
assert_equals "mine" "$(backup_of .zshrc)" "and the user's own is in the backup"
assert_equals "my identity" "$(backup_of .gitconfig)" "so is ~/.gitconfig"
assert_contains "Backed up 2 files" "$(cat "$C/out")" "and the user is told how many"
assert_contains "chezmoi apply --force --no-tty" "$(cat "$C/log")" "a non-interactive install applies without prompting"

test_start "a_home_with_nothing_to_overwrite_keeps_no_backup"
new_case empty
run_install
assert_equals "0" "$RC" "install.sh succeeds"
assert_equals "" "$(find "$C/home" -maxdepth 1 -name '.dotfiles.bak.*' -print)" "no empty backup directory is left"
assert_contains "No existing dotfiles to back up." "$(cat "$C/out")" "and the user is told"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
