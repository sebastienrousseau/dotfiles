#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Regression: the 5 most critical safety invariants of
# defaults/run_once_before_macos-icloud-symlinks.sh.tmpl.
#
# This is a REGRESSION test — it runs on every commit as part of
# the standard regression suite. Its job is not to be exhaustive
# (that's what tests/unit/misc/test_macos_icloud_symlinks.sh does).
# Its job is to CATCH THE ONE CLASS OF BUG WE CAN NEVER HAVE AGAIN:
# accidentally deleting user data.
#
# Background: this script replaces defaults/symlink_*.tmpl entries
# that were removed in #1018 after chezmoi's built-in symlink-
# handling mechanism (`rm -rf $target; ln -s $source $target`)
# destroyed a real user's ~/Documents.
#
# Anyone editing the script MUST keep these 5 invariants intact:
#
#   1. A directory with any content is never touched.
#   2. A regular file at the target path is never touched.
#   3. A pre-existing symlink pointing elsewhere is never overwritten.
#   4. The source contains no `rm -rf`, `mv`, `chmod`, or `chown`.
#   5. Kill-switches (touch-file, env var) work.
#
# This test uses only bash 3.2-compatible features (macOS stock shell)
# and lives in tests/regression/ so it runs in the regression suite
# on every commit — not just when the unit-test directory changes.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TEMPLATE="$REPO_ROOT/defaults/run_once_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# Render the template into a runnable bash script (strip darwin guard).
# ---------------------------------------------------------------------------
RENDERED="$(mktemp -t icloud-regr.XXXXXX 2>/dev/null || mktemp)"
trap 'rm -f "$RENDERED"' EXIT
sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$TEMPLATE" > "$RENDERED"

_new_sandbox() {
  local sb
  sb="$(mktemp -d 2>/dev/null || mktemp -d -t 'icloud-regr')"
  export HOME="$sb"
  export XDG_STATE_HOME="$sb/state"
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  export ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  unset DOTFILES_ICLOUD_SYMLINKS DOTFILES_ICLOUD_DRY_RUN
  printf '%s\n' "$sb"
}

# ---------------------------------------------------------------------------
# SANITY: script exists and parses.
# ---------------------------------------------------------------------------
test_start "icloud_symlink_template_exists"
if [[ -f "$TEMPLATE" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: %s missing\n' "$CURRENT_TEST" "$TEMPLATE"
fi

test_start "icloud_symlink_rendered_script_parses"
if bash -n "$RENDERED" 2>/dev/null; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# INVARIANT 1: a directory with any content is never touched.
# Seed a canary file with irreplaceable content; assert it survives.
# ---------------------------------------------------------------------------
test_start "icloud_never_touches_non_empty_dir"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
mkdir -p "$HOME/Documents"
echo "CANARY-DO-NOT-DELETE" > "$HOME/Documents/canary.txt"
mkdir -p "$HOME/Documents/deep/nested/dir"
echo "also-canary" > "$HOME/Documents/deep/nested/dir/file.txt"
bash "$RENDERED" >/dev/null 2>&1 || true
if [[ -f "$HOME/Documents/canary.txt" ]] \
   && [[ "$(cat "$HOME/Documents/canary.txt")" == "CANARY-DO-NOT-DELETE" ]] \
   && [[ -f "$HOME/Documents/deep/nested/dir/file.txt" ]] \
   && [[ ! -L "$HOME/Documents" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s: canary preserved\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: DATA LOSS DETECTED — this script may destroy user files\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# INVARIANT 2: a regular file at the target path is never touched.
# ---------------------------------------------------------------------------
test_start "icloud_never_touches_regular_file"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Public"
echo "regular-file-canary" > "$HOME/Public"
bash "$RENDERED" >/dev/null 2>&1 || true
if [[ -f "$HOME/Public" ]] && [[ ! -L "$HOME/Public" ]] \
   && [[ "$(cat "$HOME/Public")" == "regular-file-canary" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# INVARIANT 3 + 7: how the script treats a symlink that ALREADY exists.
#
# Both invariants interrogate the same code path (the `-L "$target"`
# branch), so they share one sandbox and one script run — the script
# walks every candidate per invocation, and a second invocation would
# push this file past its "instant" perf budget for no added coverage.
#
#   INVARIANT 3  a link the USER chose is never overwritten.
#   INVARIANT 7  a link that is ALREADY correct is recognised as correct,
#                whatever form it takes. Recognition was a literal string
#                compare of `readlink` against "$ICLOUD_ROOT/$name", which
#                misses three forms macOS and users produce routinely:
#                  * trailing slash  ln -s ".../Downloads/" ~/Downloads
#                  * relative        ln -s "Library/Mobile Documents/..." ~/Music
#                  * multi-hop       ~/Desktop -> ~/hop -> .../Desktop
#                All name the right directory but fail a string compare, so
#                the script fell through to the "symlink to somewhere else"
#                branch and reported a correct link as "(not iCloud)". Not
#                data loss — the fallthrough still skips — but it defeats
#                the idempotency contract and makes the audit log lie about
#                the state of user data.
# ---------------------------------------------------------------------------
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Movies" "$ICLOUD/Downloads" "$ICLOUD/Music" "$ICLOUD/Desktop"
# Invariant 3 fixture: a link the user pointed at their own disk.
mkdir -p "$HOME/external-drive"
ln -s "$HOME/external-drive" "$HOME/Movies"
# Invariant 7 fixtures: three spellings of an already-correct iCloud link.
ln -s "$ICLOUD/Downloads/" "$HOME/Downloads"
ln -s "Library/Mobile Documents/com~apple~CloudDocs/Music" "$HOME/Music"
ln -s "$ICLOUD/Desktop" "$HOME/.desktop-hop"
ln -s "$HOME/.desktop-hop" "$HOME/Desktop"
symlink_run_out="$(bash "$RENDERED" 2>&1 || true)"

test_start "icloud_never_overrides_user_managed_symlink"
resolved="$(readlink "$HOME/Movies" 2>/dev/null || echo '')"
if [[ "$resolved" == "$HOME/external-drive" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m\xe2\x9c\x93\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m\xe2\x9c\x97\033[0m %s: symlink now points to %s\n' "$CURRENT_TEST" "$resolved"
fi

test_start "icloud_recognises_existing_correct_link_regardless_of_link_form"
mismatched_forms=()
echo "$symlink_run_out" | grep -q "OK   'Downloads'" ||
  mismatched_forms=("${mismatched_forms[@]}" "trailing-slash")
echo "$symlink_run_out" | grep -q "OK   'Music'" ||
  mismatched_forms=("${mismatched_forms[@]}" "relative")
echo "$symlink_run_out" | grep -q "OK   'Desktop'" ||
  mismatched_forms=("${mismatched_forms[@]}" "multi-hop")
if [[ ${#mismatched_forms[@]} -eq 0 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m\xe2\x9c\x93\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m\xe2\x9c\x97\033[0m %s: correct links misreported as non-iCloud: %s\n' \
    "$CURRENT_TEST" "${mismatched_forms[*]}"
fi

# ---------------------------------------------------------------------------
# INVARIANT 4: source contains no destructive operations. Grep the
# template for `rm -rf`, `mv`, `chmod`, `chown` outside comments and
# log messages.
# ---------------------------------------------------------------------------
test_start "icloud_source_has_no_destructive_operations"
# Strip comments (leading #) and _log messages before checking.
body=$(grep -vE '^\s*#' "$TEMPLATE" | grep -vE '^\s*_log ')
bad_ops=()
echo "$body" | grep -qE 'rm -rf'   && bad_ops+=("rm -rf")
echo "$body" | grep -qE '^\s*mv\s' && bad_ops+=("mv")
echo "$body" | grep -qE '^\s*chmod\s' && bad_ops+=("chmod")
echo "$body" | grep -qE '^\s*chown\s' && bad_ops+=("chown")
if [[ ${#bad_ops[@]} -eq 0 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: DANGEROUS OPS FOUND: %s\n' "$CURRENT_TEST" "${bad_ops[*]}"
fi

# ---------------------------------------------------------------------------
# INVARIANT 5: kill-switches work (both file and env).
# ---------------------------------------------------------------------------
test_start "icloud_kill_switch_file_short_circuits"
_new_sandbox >/dev/null
touch "$HOME/.dotfiles.icloud-skip"
mkdir -p "$ICLOUD/Documents"
bash "$RENDERED" >/dev/null 2>&1 || true
if [[ ! -L "$HOME/Documents" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "icloud_kill_switch_env_short_circuits"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
env DOTFILES_ICLOUD_SYMLINKS=0 bash "$RENDERED" >/dev/null 2>&1 || true
if [[ ! -L "$HOME/Documents" ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# INVARIANT 6: chezmoi ignore list still matches script candidates.
# Belt-and-braces protection — if the script were ever deleted, chezmoi
# apply must still refuse to touch these paths on macOS.
# ---------------------------------------------------------------------------
test_start "icloud_candidates_are_in_chezmoiignore_darwin_block"
IGNORE="$REPO_ROOT/defaults/.chezmoiignore.tmpl"
darwin_block=$(awk '/if eq .chezmoi.os "darwin"/,/^{{- end/' "$IGNORE")
missing_from_ignore=()
for name in Desktop Documents Downloads Movies Music Pictures Public; do
  if ! echo "$darwin_block" | grep -qE "^${name}$"; then
    missing_from_ignore=("${missing_from_ignore[@]}" "$name")
  fi
done
if [[ ${#missing_from_ignore[@]} -eq 0 ]]; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  \033[0;31m✗\033[0m %s: missing from ignore: %s\n' \
    "$CURRENT_TEST" "${missing_from_ignore[*]}"
fi

# ---------------------------------------------------------------------------
# INVARIANT 7: an existing correct link to iCloud is RECOGNISED as correct.
#
# The script's idempotency contract is "already symlinked to iCloud -> no-op,
# logged OK". That recognition was a literal string compare of `readlink`
# output against "$ICLOUD_ROOT/$name", which breaks for three link forms
# macOS and users produce routinely:
#
#   * trailing slash   ln -s ".../CloudDocs/Downloads/" ~/Downloads
#   * relative link    ln -s "Library/Mobile Documents/..." ~/Downloads
#   * multi-hop link   ~/Downloads -> ~/link -> .../CloudDocs/Downloads
#
# All three point at exactly the right place, but a literal compare misses
# and the script falls through to the "symlink to somewhere else" branch —
# reporting a correctly-linked dir as "(not iCloud)". Not data loss (the
# fallthrough still skips), but it defeats the idempotency contract and
# makes the audit log actively misleading about the state of user data.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
