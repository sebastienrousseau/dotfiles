#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the shell functions shipped under
# defaults/.chezmoitemplates/functions: ren, rd, last, hiddenfiles, emoji and
# whoisport. Each function is sourced and called for real inside the coverage
# sandbox, against files created in a throwaway directory — including the
# interactive confirmation prompts, which are answered on stdin.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FN_DIR="$REPO_ROOT/defaults/.chezmoitemplates/functions"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

WORK="$DOTFILES_COV_TMPDIR/work"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
mkdir -p "$WORK"

# fn <file> <call…> — source a function file and run one call in a subshell,
# with the sandbox work dir as cwd. stdin comes from $STDIN_FILE when set.
STDIN_FILE=/dev/null
fn() {
  local file="$1"
  shift
  (
    cd "$WORK" || exit 1
    source "$FN_DIR/$file"
    "$@"
    # The child's stderr must stay a *stream we replay*, not be merged into the
    # captured output: `2>&1` would fold the child's xtrace into $OUTF, and the
    # coverage runner would then see none of the lines it executed. Assertions
    # read stdout plus stderr-minus-xtrace.
  ) >"$OUTF" 2>"$ERRF" <"$STDIN_FILE"
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}
out_lacks() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  if grep -qF -- "$1" "$MERGED"; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${2:-output should not contain $1}"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ${2:-output lacks $1}"
  fi
}

# ── ren ─────────────────────────────────────────────────────────────────
test_start "ren_requires_two_arguments"
fn files/ren.sh ren
assert_equals 1 "$RC" "rc"
out_has "Usage: ren OLD_EXT NEW_EXT" "usage"
fn files/ren.sh ren txt
assert_equals 1 "$RC" "rc"

test_start "ren_reports_when_nothing_matches"
rm -f "$WORK"/*
fn files/ren.sh ren txt md
assert_equals 0 "$RC" "rc"
out_has "No files found with extension .txt" "warning"

test_start "ren_cancels_on_a_negative_answer"
: >"$WORK/a.txt"
printf 'n\n' >"$DOTFILES_COV_TMPDIR/stdin"
STDIN_FILE="$DOTFILES_COV_TMPDIR/stdin" fn files/ren.sh ren txt md
assert_equals 0 "$RC" "rc"
out_has "Operation cancelled" "cancellation"
assert_file_exists "$WORK/a.txt" "file untouched"

test_start "ren_renames_every_match_when_confirmed"
: >"$WORK/b.txt"
printf 'y\n' >"$DOTFILES_COV_TMPDIR/stdin"
STDIN_FILE="$DOTFILES_COV_TMPDIR/stdin" fn files/ren.sh ren txt md
assert_equals 0 "$RC" "rc"
out_has "The following files will be renamed" "preview"
out_has "Successfully renamed: 2" "summary counts both files"
assert_file_exists "$WORK/a.md" "first file renamed"
assert_file_exists "$WORK/b.md" "second file renamed"
assert_file_not_exists "$WORK/a.txt" "original gone"

# ── rd ──────────────────────────────────────────────────────────────────
test_start "rd_requires_exactly_one_argument"
fn files/rd.sh rd
assert_equals 1 "$RC" "rc"
out_has "Please add one argument" "usage"
fn files/rd.sh rd one two
assert_equals 1 "$RC" "rc"

test_start "rd_rejects_a_path_that_is_not_a_directory"
fn files/rd.sh rd "$WORK/nope"
assert_equals 1 "$RC" "rc"
out_has "Directory does not exist" "error"

test_start "rd_refuses_protected_paths"
fn files/rd.sh rd /tmp
assert_equals 1 "$RC" "rc"
out_has "Refusing to delete protected path" "guard"
fn files/rd.sh rd "$HOME"
assert_equals 1 "$RC" "rc"
out_has "Refusing to delete protected path" "guard covers \$HOME"

test_start "rd_prompts_before_deleting_a_top_level_home_directory"
# rd compares the *physical* path against $HOME, so the guard only engages
# when HOME itself is physical (on macOS /var is a symlink to /private/var).
PHYS_HOME="$(cd "$HOME" && pwd -P)"
mkdir -p "$PHYS_HOME/toplevel"
printf 'n\n' >"$DOTFILES_COV_TMPDIR/stdin"
STDIN_FILE="$DOTFILES_COV_TMPDIR/stdin" HOME="$PHYS_HOME" fn files/rd.sh rd "$PHYS_HOME/toplevel"
assert_equals 1 "$RC" "rc"
out_has "About to delete top-level home directory" "warning"
out_has "Aborted." "abort"
assert_dir_exists "$PHYS_HOME/toplevel" "directory kept"

test_start "rd_deletes_a_confirmed_top_level_home_directory"
printf 'y\n' >"$DOTFILES_COV_TMPDIR/stdin"
STDIN_FILE="$DOTFILES_COV_TMPDIR/stdin" HOME="$PHYS_HOME" fn files/rd.sh rd "$PHYS_HOME/toplevel"
assert_equals 0 "$RC" "rc"
out_has "Successfully deleted" "confirmation"
assert_dir_not_exists "$PHYS_HOME/toplevel" "directory removed"

test_start "rd_deletes_a_nested_directory_without_prompting"
mkdir -p "$WORK/nested/deep"
fn files/rd.sh rd "$WORK/nested"
assert_equals 0 "$RC" "rc"
out_has "Successfully deleted" "confirmation"
assert_dir_not_exists "$WORK/nested" "directory removed"

# ── last ────────────────────────────────────────────────────────────────
test_start "last_help_documents_the_time_range"
fn misc/last.sh last --help
assert_equals 0 "$RC" "rc"
out_has "Recently Modified Files Viewer" "banner"
out_has "Maximum time range is 7 days" "limit documented"

test_start "last_rejects_a_non_numeric_range"
fn misc/last.sh last abc
assert_equals 1 "$RC" "rc"
out_has "Invalid input: 'abc'" "error"

test_start "last_rejects_a_range_beyond_seven_days"
fn misc/last.sh last 10081
assert_equals 1 "$RC" "rc"
out_has "Time range too large" "error"

test_start "last_lists_recently_modified_files"
: >"$WORK/fresh.txt"
fn misc/last.sh last 60
assert_equals 0 "$RC" "rc"
out_has "Listing files modified in the last 60 minutes" "header"
out_has "fresh.txt" "file listed"

test_start "last_defaults_to_sixty_minutes"
fn misc/last.sh last
assert_equals 0 "$RC" "rc"
out_has "last 60 minutes" "default range"

test_start "last_falls_back_to_its_own_logging_helpers"
# The function file defines log_error/log_info only when they are not
# already defined; calling it in a clean subshell exercises that fallback.
fn misc/last.sh log_info "hello from the fallback"
assert_equals 0 "$RC" "rc"
out_has "[INFO] hello from the fallback" "fallback logger"

# ── hiddenfiles ─────────────────────────────────────────────────────────
# The function refuses to run anywhere but macOS, so each platform gets the
# arm it actually reaches.
if [[ "$(uname -s)" != "Darwin" ]]; then
  test_start "hiddenfiles_refuses_to_run_off_macos"
  fn files/hiddenfiles.sh hiddenfiles
  assert_equals 1 "$RC" "rc"
  out_has "hiddenfiles: macOS only" "refusal"

  test_start "hiddenfiles_refuses_before_reading_its_arguments"
  fn files/hiddenfiles.sh hiddenfiles --help
  assert_equals 1 "$RC" "rc"
  out_has "hiddenfiles: macOS only" "the guard runs before the help arm"
else
  test_start "hiddenfiles_help_lists_both_actions"
  fn files/hiddenfiles.sh hiddenfiles --help
  assert_equals 0 "$RC" "rc"
  out_has "Hidden Files Visibility Toggle" "banner"
  out_has "hiddenfiles [show|hide]" "usage"

  test_start "hiddenfiles_rejects_an_unknown_action"
  fn files/hiddenfiles.sh hiddenfiles sideways
  assert_equals 1 "$RC" "rc"
  out_has "Invalid argument: 'sideways'" "error"

  test_start "hiddenfiles_defaults_to_hiding"
  # `defaults` and `osascript` are sandbox no-op shims.
  fn files/hiddenfiles.sh hiddenfiles
  assert_equals 0 "$RC" "rc"
  out_has "Hiding hidden files" "action"
  out_has "Finder settings updated successfully" "completion"

  test_start "hiddenfiles_can_show_them_too"
  fn files/hiddenfiles.sh hiddenfiles show
  assert_equals 0 "$RC" "rc"
  out_has "Showing hidden files" "action"
fi

# ── emoji ───────────────────────────────────────────────────────────────
test_start "emoji_reports_a_missing_picker"
DOTFILES_DIR="$WORK/no-such-dotfiles" fn interactive/emoji.sh emoji
assert_equals 1 "$RC" "rc"
out_has "Emoji picker not found" "error"

test_start "emoji_runs_the_picker_from_the_configured_source_dir"
mkdir -p "$WORK/fake-dotfiles/scripts/tools"
cat >"$WORK/fake-dotfiles/scripts/tools/emoji-picker.sh" <<'STUB'
#!/usr/bin/env bash
echo "picker ran: $*"
STUB
chmod +x "$WORK/fake-dotfiles/scripts/tools/emoji-picker.sh"
DOTFILES_DIR="$WORK/fake-dotfiles" fn interactive/emoji.sh emoji --search cat
assert_equals 0 "$RC" "rc"
out_has "picker ran: --search cat" "args forwarded"

# ── whoisport ───────────────────────────────────────────────────────────
test_start "whoisport_probes_the_requested_port"
cat >"$DOTFILES_COV_TMPDIR/bin/fuser" <<'STUB'
#!/usr/bin/env bash
printf '%s: 4242\n' "$1"
STUB
chmod +x "$DOTFILES_COV_TMPDIR/bin/fuser"
fn system/whoisport.sh whoisport 8080
out_has "/proc/ 4242/exe" "looks up the reported pid's exe"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
