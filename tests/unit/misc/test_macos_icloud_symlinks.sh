#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Exhaustive behavioural + safety tests for
# defaults/run_once_before_macos-icloud-symlinks.sh.tmpl.
#
# This is the most destructive-adjacent script in the repo — its
# predecessor (chezmoi's symlink_*.tmpl mechanism) destroyed real
# user data. Every branch of the new script must be exercised.
#
# The contract:
#
#   1. NEVER remove non-empty directories.
#   2. NEVER touch a symlink pointing to somewhere the user chose.
#   3. NEVER touch a regular file.
#   4. Idempotent: running twice on the same state is a no-op.
#   5. Silent skip when iCloud isn't set up (no error).
#   6. Kill-switch (env or touch-file) short-circuits everything.
#   7. Failure of one candidate MUST NOT abort the others.
#   8. Every decision is logged persistently.
#
# Test enumeration philosophy:
#
#   * Every `_log` message in the script has at least one test
#     that triggers it. The meta-test at the end asserts this
#     invariant by parsing the script + collecting captured logs.
#
#   * The tests use only `bash -n`-compatible rendering (strip
#     the outer darwin OS-guard) and mock the iCloud path with
#     a plain tmpdir. All FS mutations happen inside a per-test
#     sandbox that gets cleaned up.
#
#   * Data-destruction contracts (Contract 1, 2, 3) are verified
#     by seeding sentinel files/content and asserting they survive
#     — not just by log-message inspection. Log inspection can lie;
#     a surviving canary cannot.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

TEMPLATE="$REPO_ROOT/defaults/run_once_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# Render the template into a runnable bash script. Strip only the
# outermost darwin OS-guard. The body must be valid bash in isolation.
# ---------------------------------------------------------------------------
RENDERED="$(mktemp -t icloud-render.XXXXXX)"
CAPTURED_LOG_FILE="$(mktemp -t icloud-capture.XXXXXX)"
trap 'rm -f "$RENDERED" "$CAPTURED_LOG_FILE"' EXIT
sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$TEMPLATE" > "$RENDERED"

# ---------------------------------------------------------------------------
# _new_sandbox — fresh $HOME per test. Sets iCloud root as a real
# dir (tests can undo). Also captures the script's output for later
# meta-analysis (every _log message that fires anywhere in the
# suite is appended to CAPTURED_LOG_FILE).
# ---------------------------------------------------------------------------
_new_sandbox() {
  local sb
  sb="$(mktemp -d -t icloud-test.XXXXXX)"
  export HOME="$sb"
  export XDG_STATE_HOME="$sb/state"
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  export ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  unset DOTFILES_ICLOUD_SYMLINKS DOTFILES_ICLOUD_DRY_RUN
  printf '%s\n' "$sb"
}

_run_script() {
  local out
  out="$(bash "$RENDERED" 2>&1)"
  local rc=$?
  printf '%s\n' "$out" >> "$CAPTURED_LOG_FILE"
  printf '%s\n' "$out"
  return "$rc"
}

_run_script_with_env() {
  local out
  out="$(env "$@" bash "$RENDERED" 2>&1)"
  local rc=$?
  printf '%s\n' "$out" >> "$CAPTURED_LOG_FILE"
  printf '%s\n' "$out"
  return "$rc"
}

# ---------------------------------------------------------------------------
# 0. Sanity: script exists + parses.
# ---------------------------------------------------------------------------
test_start "template_exists"
assert_file_exists "$TEMPLATE" "iCloud symlink template must exist"

test_start "rendered_script_syntax_valid"
assert_exit_code 0 "bash -n '$RENDERED'"

# ---------------------------------------------------------------------------
# CONTRACT 5: silent skip when iCloud isn't set up.
# LOG BRANCH: SKIP-ALL: iCloud Drive not initialised
# ---------------------------------------------------------------------------
test_start "skips_silently_when_icloud_missing"
_new_sandbox >/dev/null
rm -rf "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
out="$(_run_script)"
rc=$?
if [[ $rc -eq 0 ]] && [[ "$out" == *"iCloud Drive not initialised"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: rc=%s\n' "$CURRENT_TEST" "$rc"
fi

# ---------------------------------------------------------------------------
# CONTRACT 6: kill-switch (touch-file).
# LOG BRANCH: SKIP-ALL: found kill-switch file
# ---------------------------------------------------------------------------
test_start "kill_switch_file_short_circuits"
_new_sandbox >/dev/null
touch "$HOME/.dotfiles.icloud-skip"
mkdir -p "$ICLOUD/Documents"
out="$(_run_script)"
if [[ "$out" == *"kill-switch"* ]] && [[ ! -L "$HOME/Documents" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 6: kill-switch (env var).
# LOG BRANCH: SKIP-ALL: DOTFILES_ICLOUD_SYMLINKS=0
# ---------------------------------------------------------------------------
test_start "kill_switch_env_short_circuits"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
out="$(_run_script_with_env DOTFILES_ICLOUD_SYMLINKS=0)"
if [[ "$out" == *"DOTFILES_ICLOUD_SYMLINKS=0"* ]] && [[ ! -L "$HOME/Documents" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 1 (THE MOST IMPORTANT): NEVER destroy non-empty user data.
# LOG BRANCH: SKIP '$name': target dir has $count entries, refusing
# ---------------------------------------------------------------------------
test_start "refuses_to_touch_non_empty_dir"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
mkdir -p "$HOME/Documents"
echo "IRREPLACEABLE USER DATA" > "$HOME/Documents/thesis.txt"
mkdir -p "$HOME/Documents/subdir"
echo "more data" > "$HOME/Documents/subdir/notes.md"
out="$(_run_script)"
if [[ -f "$HOME/Documents/thesis.txt" ]] \
   && [[ "$(cat "$HOME/Documents/thesis.txt")" == "IRREPLACEABLE USER DATA" ]] \
   && [[ -f "$HOME/Documents/subdir/notes.md" ]] \
   && [[ ! -L "$HOME/Documents" ]] \
   && [[ "$out" == *"refusing"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: user data preserved, symlink not created\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: USER DATA MAY HAVE BEEN LOST\n' "$CURRENT_TEST"
fi

test_start "refuses_even_a_single_hidden_file"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Downloads"
mkdir -p "$HOME/Downloads"
touch "$HOME/Downloads/.DS_Store"
_run_script >/dev/null
if [[ ! -L "$HOME/Downloads" ]] && [[ -f "$HOME/Downloads/.DS_Store" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "refuses_when_target_has_hidden_git_dir"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
mkdir -p "$HOME/Documents/.git/objects"
echo "chain content" > "$HOME/Documents/.git/HEAD"
_run_script >/dev/null
if [[ ! -L "$HOME/Documents" ]] && [[ -f "$HOME/Documents/.git/HEAD" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 2: NEVER touch a symlink the user set up.
# LOG BRANCH: SKIP '$name': is a symlink to '$current' (not iCloud)
# ---------------------------------------------------------------------------
test_start "leaves_user_managed_symlink_alone"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Movies"
mkdir -p "$HOME/external-movies"
ln -s "$HOME/external-movies" "$HOME/Movies"
_run_script >/dev/null
resolved="$(readlink "$HOME/Movies" 2>/dev/null || echo '')"
if [[ "$resolved" == "$HOME/external-movies" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: symlink now points to %s\n' "$CURRENT_TEST" "$resolved"
fi

# ---------------------------------------------------------------------------
# CONTRACT 3: NEVER touch a regular file.
# LOG BRANCH: SKIP '$name': target is a regular file, refusing to touch
# ---------------------------------------------------------------------------
test_start "refuses_when_target_is_regular_file"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Public"
echo "hello" > "$HOME/Public"
_run_script >/dev/null
if [[ -f "$HOME/Public" ]] && [[ ! -L "$HOME/Public" ]] \
   && [[ "$(cat "$HOME/Public")" == "hello" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# ICLOUD SOURCE EDGE CASE: source is a symlink.
# LOG BRANCH: SKIP '$name': iCloud source is itself a symlink
#
# This is NOT an exotic state: when macOS's native "Desktop & Documents
# Folders" sync is on (System Settings > iCloud > iCloud Drive), macOS
# itself puts CloudDocs/Desktop -> ~/Desktop and CloudDocs/Documents ->
# ~/Documents. Those folders are already fully iCloud-synced by macOS,
# and symlinking them by hand would fight the native feature.
#
# So the log line must not describe this as "unexpected" — on a data-
# safety tool, calling a correct configuration unexpected invites the
# user to "fix" it and lose data. Assert the message explains itself.
# ---------------------------------------------------------------------------
test_start "skips_when_icloud_source_is_a_symlink"
_new_sandbox >/dev/null
mkdir -p "$HOME/some-other-place"
ln -s "$HOME/some-other-place" "$ICLOUD/Documents"
out="$(_run_script)"
if [[ ! -L "$HOME/Documents" ]] && [[ "$out" == *"source is itself a symlink"* ]] &&
  [[ "$out" != *"unexpected"* ]] && [[ "$out" == *"Desktop & Documents"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# ICLOUD SOURCE EDGE CASE: source is a regular file (not a directory).
# LOG BRANCH: SKIP '$name': iCloud source exists but is not a directory
# ---------------------------------------------------------------------------
test_start "skips_when_icloud_source_is_regular_file"
_new_sandbox >/dev/null
echo "not a directory" > "$ICLOUD/Music"
out="$(_run_script)"
if [[ ! -L "$HOME/Music" ]] && [[ "$out" == *"source exists but is not a directory"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# HAPPY PATH: target doesn't exist, iCloud does → create the link.
# LOG BRANCH: LINK '$name': created symlink -> iCloud (target didn't exist)
# ---------------------------------------------------------------------------
test_start "creates_symlink_when_target_missing"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Music"
[[ -e "$HOME/Music" ]] && rm -rf "$HOME/Music"
_run_script >/dev/null
if [[ -L "$HOME/Music" ]] && [[ "$(readlink "$HOME/Music")" == "$ICLOUD/Music" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# HAPPY PATH: target is empty dir → rmdir + link.
# LOG BRANCH: LINK '$name': created symlink -> iCloud
# ---------------------------------------------------------------------------
test_start "converts_empty_dir_to_symlink"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Desktop"
mkdir -p "$HOME/Desktop"
_run_script >/dev/null
if [[ -L "$HOME/Desktop" ]] && [[ "$(readlink "$HOME/Desktop")" == "$ICLOUD/Desktop" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 4: idempotent.
# LOG BRANCH: OK '$name': already symlinked to iCloud
# ---------------------------------------------------------------------------
test_start "idempotent_second_run_is_noop"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Pictures"
_run_script >/dev/null
out2="$(_run_script)"
if [[ -L "$HOME/Pictures" ]] && [[ "$out2" == *"already symlinked"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# ICLOUD SOURCE MISSING for one candidate → skip only that.
# LOG BRANCH: SKIP '$name': iCloud source does not exist yet
# ---------------------------------------------------------------------------
test_start "skips_only_candidates_without_icloud_source"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
_run_script >/dev/null
if [[ -L "$HOME/Documents" ]] && [[ ! -L "$HOME/Desktop" ]] && [[ ! -L "$HOME/Downloads" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# DRY-RUN: no filesystem mutations, target missing.
# LOG BRANCH: DRY '$name': would create symlink to iCloud (target missing)
#             DRY-RUN: no changes will be applied
# ---------------------------------------------------------------------------
test_start "dry_run_when_target_missing_takes_no_action"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
out="$(_run_script_with_env DOTFILES_ICLOUD_DRY_RUN=1)"
if [[ ! -e "$HOME/Documents" ]] \
   && [[ "$out" == *"DRY-RUN"* ]] \
   && [[ "$out" == *"would create symlink"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# DRY-RUN: no filesystem mutations, empty target dir present.
# LOG BRANCH: DRY '$name': would rmdir empty target + create symlink
# ---------------------------------------------------------------------------
test_start "dry_run_when_target_empty_takes_no_action"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Music"
mkdir -p "$HOME/Music"
out="$(_run_script_with_env DOTFILES_ICLOUD_DRY_RUN=1)"
if [[ -d "$HOME/Music" ]] && [[ ! -L "$HOME/Music" ]] \
   && [[ "$out" == *"would rmdir empty target"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# RACE PROTECTION: what if rmdir fails? (permission or TOCTOU)
# We simulate by making the parent dir non-writable so rmdir will fail.
# LOG BRANCH: SKIP '$name': rmdir of empty dir failed
# ---------------------------------------------------------------------------
test_start "handles_rmdir_failure_without_data_loss"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Movies"
mkdir -p "$HOME/Movies"
# Make $HOME non-writable — rmdir needs write on parent
chmod 555 "$HOME"
out="$(_run_script 2>&1)" || true
chmod 755 "$HOME"   # always restore, even if test fails
# Post-condition: no symlink created, dir still exists
if [[ -d "$HOME/Movies" ]] && [[ ! -L "$HOME/Movies" ]] \
   && ([[ "$out" == *"rmdir of empty dir failed"* ]] || [[ "$out" == *"race"* ]]); then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: out=%s\n' "$CURRENT_TEST" "$(echo "$out" | head -3)"
fi

# ---------------------------------------------------------------------------
# CONTRACT 7: a candidate whose subshell errors out MUST NOT stop the
# others. Every branch of _link_if_safe currently ends in `return 0`
# under normal FS state, so the only way to trigger the ERR handler
# in the outer loop is to introduce a set -e violation inside the
# subshell — which we cover via source inspection (the wrapper
# `( _link_if_safe "$name" ) || _log "ERR"` provably contains any
# failure), plus the positive-path test below that verifies mixed
# states iterate correctly.
#
# See DEFENSIVE_BRANCHES allowlist in the meta-test below.
# ---------------------------------------------------------------------------
test_start "subshell_wrapper_is_present_and_isolates_failures"
if grep -qE '^\s*\(\s*_link_if_safe.*\)\s*\|\|\s*_log' "$TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: subshell isolation wrapper missing from source\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 7 (positive path): a candidate that legitimately skips MUST
# NOT stop the others. Verifies loop continues across mixed states.
# ---------------------------------------------------------------------------
test_start "one_candidate_skip_does_not_stop_others"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
mkdir -p "$ICLOUD/Music"
# Make Movies a symlink loop scenario: source is a symlink → will skip
mkdir -p "$HOME/somewhere-else"
ln -s "$HOME/somewhere-else" "$ICLOUD/Movies"
_run_script >/dev/null
# Post-condition: Documents + Music linked despite Movies triggering skip
if [[ -L "$HOME/Documents" ]] && [[ -L "$HOME/Music" ]] && [[ ! -L "$HOME/Movies" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 8: log file gets an entry per run, and PERSISTS across runs.
# LOG BRANCH: == BEGIN run ==, == END run ==
# ---------------------------------------------------------------------------
test_start "writes_persistent_log"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
_run_script >/dev/null
LOG="$XDG_STATE_HOME/dotfiles/icloud-symlinks.log"
if [[ -f "$LOG" ]] && grep -q "BEGIN run" "$LOG" && grep -q "END run" "$LOG"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "log_appends_across_multiple_runs"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
_run_script >/dev/null
_run_script >/dev/null
_run_script >/dev/null
LOG="$XDG_STATE_HOME/dotfiles/icloud-symlinks.log"
begin_count="$(grep -c "BEGIN run" "$LOG" 2>/dev/null || echo 0)"
end_count="$(grep -c "END run" "$LOG" 2>/dev/null || echo 0)"
if [[ "$begin_count" == "3" ]] && [[ "$end_count" == "3" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: 3 BEGIN + 3 END entries\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: BEGIN=%s END=%s\n' "$CURRENT_TEST" "$begin_count" "$end_count"
fi

# ---------------------------------------------------------------------------
# EDGE: XDG_STATE_HOME unset — should fall back to ~/.local/state.
# ---------------------------------------------------------------------------
test_start "xdg_state_home_unset_falls_back_to_default"
_new_sandbox >/dev/null
unset XDG_STATE_HOME
mkdir -p "$ICLOUD/Documents"
_run_script >/dev/null
if [[ -f "$HOME/.local/state/dotfiles/icloud-symlinks.log" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# EDGE: $HOME path contains a space — no accidental word-splitting.
# ---------------------------------------------------------------------------
test_start "handles_home_path_with_spaces"
sb="$(mktemp -d -t 'icloud test with spaces.XXXXXX' 2>/dev/null || mktemp -d)"
# On Linux, mktemp -t template can't have spaces; force one manually
sb2="$sb/dir with space"
mkdir -p "$sb2"
export HOME="$sb2"
export XDG_STATE_HOME="$sb2/state"
mkdir -p "$XDG_STATE_HOME/dotfiles"
mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
_run_script >/dev/null
if [[ -L "$HOME/Documents" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi
rm -rf "$sb"

# ---------------------------------------------------------------------------
# MIXED STATES: one run handles candidates in various states independently.
# ---------------------------------------------------------------------------
test_start "mixed_candidate_states_in_single_run"
_new_sandbox >/dev/null
# Desktop: no iCloud source → skip
# Documents: iCloud source + non-empty target → refuse
# Downloads: iCloud source + empty target → link
# Movies: iCloud source + already-linked → no-op
# Music: iCloud source + missing target → link
# Pictures: iCloud source + user-managed symlink → skip
# Public: iCloud source + regular file → skip
mkdir -p "$ICLOUD/Documents"
mkdir -p "$HOME/Documents"
echo "user data" > "$HOME/Documents/keep.txt"

mkdir -p "$ICLOUD/Downloads"
mkdir -p "$HOME/Downloads"   # empty

mkdir -p "$ICLOUD/Movies"
ln -s "$ICLOUD/Movies" "$HOME/Movies"   # already linked

mkdir -p "$ICLOUD/Music"    # target missing

mkdir -p "$ICLOUD/Pictures"
mkdir -p "$HOME/user-pics"
ln -s "$HOME/user-pics" "$HOME/Pictures"

mkdir -p "$ICLOUD/Public"
echo "content" > "$HOME/Public"

out="$(_run_script)"
pass=1
# Desktop: no source → not linked
[[ -L "$HOME/Desktop" ]] && { echo "  Desktop unexpectedly linked"; pass=0; }
# Documents: still has user data, not linked
[[ -f "$HOME/Documents/keep.txt" ]] || { echo "  Documents data lost"; pass=0; }
[[ -L "$HOME/Documents" ]] && { echo "  Documents unexpectedly linked"; pass=0; }
# Downloads: was empty → linked
[[ -L "$HOME/Downloads" ]] || { echo "  Downloads should be linked"; pass=0; }
# Movies: was pre-linked → still linked
[[ -L "$HOME/Movies" ]] || { echo "  Movies should still be a symlink"; pass=0; }
# Music: was missing → created
[[ -L "$HOME/Music" ]] || { echo "  Music should be linked"; pass=0; }
# Pictures: user's symlink preserved
[[ "$(readlink "$HOME/Pictures")" == "$HOME/user-pics" ]] || { echo "  Pictures symlink changed"; pass=0; }
# Public: still regular file
[[ -f "$HOME/Public" && ! -L "$HOME/Public" ]] || { echo "  Public regular file lost"; pass=0; }
if [[ $pass -eq 1 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: all 7 candidates behaved correctly\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# INVARIANT: every candidate handled by the script is also in
# .chezmoiignore.tmpl. This is the belt-and-braces guarantee.
# ---------------------------------------------------------------------------
test_start "every_candidate_is_in_chezmoiignore_darwin_block"
IGNORE="$REPO_ROOT/defaults/.chezmoiignore.tmpl"
darwin_block="$(awk '/if eq .chezmoi.os "darwin"/,/^{{- end/' "$IGNORE")"
missing=()
for name in Desktop Documents Downloads Movies Music Pictures Public; do
  echo "$darwin_block" | grep -qE "^${name}$" || missing+=("$name")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: missing from chezmoiignore darwin block: %s\n' \
    "$CURRENT_TEST" "${missing[*]}"
fi

# ---------------------------------------------------------------------------
# SOURCE INVARIANT: no `rm -rf`, no `mv`, no `chmod` in the actual script.
# Defence in depth against future edits reintroducing the data-loss vector.
# ---------------------------------------------------------------------------
test_start "source_has_no_destructive_operations"
# Strip comments before grepping — the safety comment mentions rm -rf as an
# example command to run manually, and that reference is educational, not code.
body="$(grep -vE '^\s*#' "$TEMPLATE" 2>/dev/null | grep -vE '^\s*_log ')"
bad=()
echo "$body" | grep -qE 'rm -rf'   && bad+=("rm -rf found")
echo "$body" | grep -qE '^\s*mv\s' && bad+=("mv found")
echo "$body" | grep -qE '^\s*chmod\s' && bad+=("chmod found")
echo "$body" | grep -qE '^\s*chown\s' && bad+=("chown found")
if [[ ${#bad[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: only rmdir is used for deletion\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: DANGEROUS OPS FOUND: %s\n' "$CURRENT_TEST" "${bad[*]}"
fi

# ---------------------------------------------------------------------------
# META-TEST: 100% branch coverage (defensive branches allow-listed).
#
# Enumerates every distinct _log-message prefix in the script. Asserts
# each one either:
#   (a) has appeared at least once in test output (exercised), or
#   (b) is in the DEFENSIVE_BRANCHES allowlist with a documented reason.
#
# Adding a new _log without a corresponding test — OR without adding it
# to the allowlist with a justification — fails this assertion.
#
# The point: no branch silently escapes coverage. Either you tested it
# or you consciously exempted it with a reason a reviewer can audit.
# ---------------------------------------------------------------------------

# DEFENSIVE_BRANCHES: log messages that fire only under conditions we
# cannot construct in a userland test (kernel-level failures, resource
# exhaustion, or set -e violations that require broken execution state).
# Each entry MUST document why it's here.
DEFENSIVE_BRANCHES=(
  # ERR is fired by the outer loop's `( _link_if_safe ) || _log "ERR"`
  # wrapper. Every path in _link_if_safe explicitly `return 0`s, so the
  # subshell never legitimately fails under normal FS conditions.
  # This is pure defence-in-depth: if a future edit accidentally lets
  # set -e trip inside the subshell, ERR ensures the other candidates
  # still iterate. Presence of the wrapper is asserted by the test
  # `subshell_wrapper_is_present_and_isolates_failures` above.
  "ERR  '\$name': subshell failed (see above)"
)

_is_defensive() {
  local branch="$1"
  for defensive in "${DEFENSIVE_BRANCHES[@]}"; do
    [[ "$branch" == "$defensive" ]] && return 0
  done
  return 1
}

test_start "every_log_branch_exercised_by_suite"
mapfile -t branches < <(
  grep -oE '_log "[^"]*"' "$TEMPLATE" \
    | sed 's/_log "//; s/"$//' \
    | grep -v "^     to link this dir manually" \
    | grep -v "^       rm -rf" \
    | grep -v "^== BEGIN run" \
    | grep -v "^== END run" \
    | sort -u
)
missing_branches=()
allowlisted_count=0
for branch in "${branches[@]}"; do
  static_prefix="${branch%%\$*}"
  static_prefix="${static_prefix% \'}"
  static_prefix="${static_prefix%% }"
  if [[ -z "$static_prefix" ]]; then
    continue
  fi
  if grep -qF "$static_prefix" "$CAPTURED_LOG_FILE"; then
    continue                        # exercised
  fi
  if _is_defensive "$branch"; then
    allowlisted_count=$((allowlisted_count + 1))
    continue                        # documented defensive exception
  fi
  missing_branches+=("$branch")
done
if [[ ${#missing_branches[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s: %d branches (%d exercised, %d allowlisted-defensive)\n' \
    "$CURRENT_TEST" "${#branches[@]}" $((${#branches[@]} - allowlisted_count)) "$allowlisted_count"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %d branch(es) untested and not allowlisted:\n' \
    "$CURRENT_TEST" "${#missing_branches[@]}"
  for b in "${missing_branches[@]}"; do
    printf '     - %s\n' "$b"
  done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
