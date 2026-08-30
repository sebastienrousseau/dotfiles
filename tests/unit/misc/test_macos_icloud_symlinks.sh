#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Behavioural + safety tests for defaults/run_once_before_macos-
# icloud-symlinks.sh.tmpl. The script's contract is:
#
#   1. NEVER remove non-empty directories.
#   2. NEVER touch a symlink pointing to somewhere the user chose.
#   3. NEVER touch a regular file.
#   4. Idempotent: running twice on the same state is a no-op.
#   5. Silent skip when iCloud isn't set up (no error).
#   6. Kill-switch (env or touch-file) short-circuits everything.
#
# Each contract clause has at least one test.
#
# The tests render the .tmpl into a plain bash script by stripping
# the darwin-guard, then run it in a sandbox with $HOME pointing to
# a tmpdir. iCloud paths are mocked as regular dirs.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

TEMPLATE="$REPO_ROOT/defaults/run_once_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# Render the template into a runnable bash script. We strip only the
# darwin OS-guard (the outermost {{- if ... -}} ... {{- end -}}). The
# body must be valid bash even in isolation.
# ---------------------------------------------------------------------------
RENDERED="$(mktemp -t icloud-render.XXXXXX)"
trap 'rm -f "$RENDERED"' EXIT
sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$TEMPLATE" > "$RENDERED"

# ---------------------------------------------------------------------------
# Sandbox per test.
# ---------------------------------------------------------------------------
_new_sandbox() {
  local sb
  sb="$(mktemp -d -t icloud-test.XXXXXX)"
  export HOME="$sb"
  export XDG_STATE_HOME="$sb/state"
  mkdir -p "$XDG_STATE_HOME/dotfiles"
  # Default: iCloud is set up. Tests can un-set to test the missing-iCloud path.
  mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  export ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
  # Reset any test-inherited env toggles.
  unset DOTFILES_ICLOUD_SYMLINKS DOTFILES_ICLOUD_DRY_RUN
  printf '%s\n' "$sb"
}

_run_script() {
  bash "$RENDERED" 2>&1
}

# ---------------------------------------------------------------------------
# Sanity: script exists + parses.
# ---------------------------------------------------------------------------
test_start "template_exists"
assert_file_exists "$TEMPLATE" "iCloud symlink template must exist"

test_start "rendered_script_syntax_valid"
assert_exit_code 0 "bash -n '$RENDERED'"

# ---------------------------------------------------------------------------
# CONTRACT 5: silent skip when iCloud isn't set up.
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
# ---------------------------------------------------------------------------
test_start "kill_switch_file_short_circuits"
_new_sandbox >/dev/null
touch "$HOME/.dotfiles.icloud-skip"
mkdir -p "$ICLOUD/Documents"                                    # would otherwise link
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
# ---------------------------------------------------------------------------
test_start "kill_switch_env_short_circuits"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
out="$(DOTFILES_ICLOUD_SYMLINKS=0 bash "$RENDERED" 2>&1)"
if [[ "$out" == *"DOTFILES_ICLOUD_SYMLINKS=0"* ]] && [[ ! -L "$HOME/Documents" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 1 (THE MOST IMPORTANT ONE): NEVER destroy non-empty user data.
# ---------------------------------------------------------------------------
test_start "refuses_to_touch_non_empty_dir"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
mkdir -p "$HOME/Documents"
echo "IRREPLACEABLE USER DATA" > "$HOME/Documents/thesis.txt"
mkdir -p "$HOME/Documents/subdir"
echo "more data" > "$HOME/Documents/subdir/notes.md"
out="$(_run_script)"
# Post-condition: files MUST still exist untouched.
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
touch "$HOME/Downloads/.DS_Store"   # macOS ubiquity — must still be treated as "has data"
_run_script >/dev/null
if [[ ! -L "$HOME/Downloads" ]] && [[ -f "$HOME/Downloads/.DS_Store" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 2: NEVER touch a symlink the user set up.
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
# HAPPY PATH: target doesn't exist, iCloud does → create the link.
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
# ---------------------------------------------------------------------------
test_start "converts_empty_dir_to_symlink"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Desktop"
mkdir -p "$HOME/Desktop"   # empty
_run_script >/dev/null
if [[ -L "$HOME/Desktop" ]] && [[ "$(readlink "$HOME/Desktop")" == "$ICLOUD/Desktop" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# CONTRACT 4: idempotent. Run twice → no different final state.
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
# ICLOUD SIDE: source doesn't exist for one candidate → skip that ONLY.
# ---------------------------------------------------------------------------
test_start "skips_only_candidates_without_icloud_source"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"       # only this one has an iCloud source
# Desktop, Downloads, etc. — no iCloud source
_run_script >/dev/null
if [[ -L "$HOME/Documents" ]] && [[ ! -L "$HOME/Desktop" ]] && [[ ! -L "$HOME/Downloads" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# DRY-RUN: no filesystem mutations.
# ---------------------------------------------------------------------------
test_start "dry_run_makes_no_changes"
_new_sandbox >/dev/null
mkdir -p "$ICLOUD/Documents"
out="$(DOTFILES_ICLOUD_DRY_RUN=1 bash "$RENDERED" 2>&1)"
if [[ ! -e "$HOME/Documents" ]] && [[ "$out" == *"DRY-RUN"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# LOGGING: log file gets an entry per run.
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

# ---------------------------------------------------------------------------
# INVARIANT: every candidate we handle is also in .chezmoiignore.tmpl.
# This is the belt-and-braces guarantee — the script and the ignore
# list can't drift.
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
# Summary
# ---------------------------------------------------------------------------
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
