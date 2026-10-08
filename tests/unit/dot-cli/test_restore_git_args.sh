#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# dot restore --git / --diff run against a real sandboxed git repository:
# every flag is parsed before anything runs, so `--git REF --dry-run` is a
# dry run, and a ref that looks like an option never reaches git.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

RESTORE_FILE="$REPO_ROOT/scripts/dot/commands/restore.sh"

WORK="$(mktemp -d -t restore-git.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home" "$WORK/data" "$WORK/bin"
REPO="$WORK/home/.dotfiles"

# chezmoi stub: a real apply must never touch this machine from a test.
printf '#!/bin/sh\necho "chezmoi:$*" >>"%s/chezmoi.log"\n' "$WORK" >"$WORK/bin/chezmoi"
chmod +x "$WORK/bin/chezmoi"

g() { git -C "$REPO" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
mkdir -p "$REPO"
git init -q "$REPO"
printf 'one\n' >"$REPO/file.txt"
g add file.txt
g commit -q -m one
printf 'two\n' >"$REPO/file.txt"
g commit -q -am two

reset_state() { # a local edit on top of HEAD, no backups, no side effects
  rm -rf "$WORK/data/dotfiles" "$WORK/chezmoi.log" "$WORK/pwned"
  printf 'local edit\n' >"$REPO/file.txt"
}

restore() {
  RC=0
  OUT="$(cd "$WORK" && env HOME="$WORK/home" XDG_DATA_HOME="$WORK/data" \
    DOTFILES_DIR="$REPO" PATH="$WORK/bin:$PATH" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    bash "$RESTORE_FILE" "$@" </dev/null 2>&1)" || RC=$?
}

test_start "restore_git_then_dry_run_is_a_dry_run"
reset_state
restore --git HEAD~1 --dry-run
assert_equals "0" "$RC" "--git REF --dry-run exits 0"
assert_equals "local edit" "$(cat "$REPO/file.txt")" "the modified file is left untouched"
assert_false '[[ -d "$WORK/data/dotfiles/backups" ]]' "no backup is taken"
assert_false '[[ -e "$WORK/chezmoi.log" ]]' "chezmoi apply is not run"
assert_contains "file.txt" "$OUT" "the dry run shows what would change"

test_start "restore_dry_run_then_git_is_a_dry_run"
reset_state
restore --dry-run --git HEAD~1
assert_equals "local edit" "$(cat "$REPO/file.txt")" "the order of the flags does not matter"

for bad in "--output=$WORK/pwned" -p; do
  test_start "restore_git_refuses_option_like_ref_${bad%%=*}"
  reset_state
  restore --git "$bad" --dry-run
  assert_not_equals "0" "$RC" "--git $bad is refused"
  assert_false '[[ -e "$WORK/pwned" ]]' "and creates nothing"
  reset_state
  restore --git "$bad"
  assert_not_equals "0" "$RC" "--git $bad without --dry-run is refused"
  assert_false '[[ -e "$WORK/pwned" ]]' "and creates nothing"
  assert_equals "local edit" "$(cat "$REPO/file.txt")" "and restores nothing"
  reset_state
  restore --diff "$bad"
  assert_not_equals "0" "$RC" "--diff $bad is refused"
  assert_false '[[ -e "$WORK/pwned" ]]' "and creates nothing"
done

test_start "restore_git_refuses_unknown_ref"
reset_state
restore --git no-such-ref --dry-run
assert_not_equals "0" "$RC" "an unknown ref is refused"
assert_contains "no-such-ref" "$OUT" "and named"

test_start "restore_git_requires_a_ref"
reset_state
restore --git
assert_not_equals "0" "$RC" "--git without a ref is refused"
restore --diff
assert_not_equals "0" "$RC" "--diff without a ref is refused"

test_start "restore_diff_shows_ref_diff"
reset_state
restore --diff HEAD~1
assert_equals "0" "$RC" "--diff REF exits 0"
assert_contains "+local edit" "$OUT" "and prints the diff"

test_start "restore_git_restores_the_ref"
reset_state
restore --git HEAD~1
assert_equals "0" "$RC" "--git REF exits 0"
assert_equals "one" "$(cat "$REPO/file.txt")" "the file is restored from the ref"
assert_true '[[ -d "$WORK/data/dotfiles/backups" ]]' "a backup is taken first"
assert_contains "chezmoi:apply" "$(cat "$WORK/chezmoi.log" 2>/dev/null)" "and chezmoi is re-applied"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
