#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/diagnostics/drift-dashboard.sh — all four
# drift classes (managed, untracked source, orphan deployed, stale source),
# both output modes and the exit contract.
#
# `chezmoi` and `git` are replaced by PATH-shadowing stubs written into the
# sandbox, so every class can be produced on demand without touching the
# host's chezmoi state.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DRIFT="$REPO_ROOT/scripts/diagnostics/drift-dashboard.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/drift-out.txt"
SRC="$DOTFILES_COV_TMPDIR/src"
mkdir -p "$SRC/.git"

# Stub chezmoi: each subcommand's answer comes from a file we rewrite per
# test, so one stub covers every drift shape.
cat >"$BIN/chezmoi" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  status)      cat "$DRIFT_FIX/status" 2>/dev/null ;;
  source-path)
    if [[ -n "${2:-}" ]]; then
      cat "$DRIFT_FIX/source-path" 2>/dev/null
    else
      cat "$DRIFT_FIX/src-dir" 2>/dev/null
    fi
    ;;
  managed)     cat "$DRIFT_FIX/managed" 2>/dev/null ;;
  diff)        echo "stub chezmoi diff $*" ;;
  *)           : ;;
esac
exit 0
STUB
chmod +x "$BIN/chezmoi"

export DRIFT_FIX="$DOTFILES_COV_TMPDIR/fix"
mkdir -p "$DRIFT_FIX"
: >"$DRIFT_FIX/status"
: >"$DRIFT_FIX/managed"
: >"$DRIFT_FIX/source-path"
printf '%s\n' "$SRC" >"$DRIFT_FIX/src-dir"

# Stub git so `git -C <src> ls-files --others` reports what we choose.
cat >"$BIN/git" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [[ "$a" == "ls-files" ]]; then
    cat "$DRIFT_FIX/untracked" 2>/dev/null
    exit 0
  fi
done
exit 0
STUB
chmod +x "$BIN/git"
: >"$DRIFT_FIX/untracked"

ORPHANS="$XDG_STATE_HOME/dotfiles/orphans"
mkdir -p "$(dirname "$ORPHANS")"

drift() {
  bash "$DRIFT" "$@" >"$OUTF" </dev/null
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

test_start "script_exists_and_parses"
assert_file_exists "$DRIFT" "drift-dashboard.sh must exist"
assert_true "bash -n '$DRIFT'" "valid bash syntax"

test_start "help_exits_before_any_probing"
drift --help
assert_equals 0 "$RC" "rc"
out_has "Usage: drift-dashboard.sh" "usage"
out_has "--json" "documents json mode"

test_start "clean_tree_reports_no_drift_and_exits_0"
drift
assert_equals 0 "$RC" "rc"
out_has "Dotfiles Drift Dashboard" "header"
out_has "Managed drift" "class 1"
out_has "Untracked source" "class 2"
out_has "Orphan deployed" "class 3"
out_has "Stale source" "class 4"
out_has "no drift detected" "verdict"

test_start "clean_tree_json_is_all_zeroes"
drift --json
assert_equals 0 "$RC" "rc"
assert_equals "0" "$(jq -r .total <"$OUTF")" "total"
assert_equals "0" "$(jq -r .managed_drift <"$OUTF")" "managed"
assert_equals "0" "$(jq -r .stale_source <"$OUTF")" "stale"

test_start "managed_drift_is_counted_and_listed"
printf 'MM .zshrc\nMM .gitconfig\n' >"$DRIFT_FIX/status"
drift
assert_equals 1 "$RC" "any drift exits 1"
out_has "2 file(s)" "count"
out_has ".zshrc" "status echoed"
out_has "Total drift signals" "summary"

test_start "managed_drift_is_counted_in_json"
drift -j
assert_equals 1 "$RC" "rc"
assert_equals "2" "$(jq -r .managed_drift <"$OUTF")" "managed count"
assert_equals "2" "$(jq -r .total <"$OUTF")" "total"

test_start "diff_flag_appends_the_chezmoi_diff"
drift --diff
assert_equals 1 "$RC" "rc"
out_has "chezmoi diff (excluding" "section"
out_has "stub chezmoi diff" "diff output included"

test_start "diff_can_be_requested_by_environment"
DOTFILES_DRIFT_SHOW_DIFF=1 drift
assert_equals 1 "$RC" "rc"
out_has "stub chezmoi diff" "env var honoured"

test_start "untracked_source_files_are_counted"
: >"$DRIFT_FIX/status"
printf 'notes.md\nwip.sh\n' >"$DRIFT_FIX/untracked"
drift
assert_equals 1 "$RC" "rc"
out_has "2 file(s) in chezmoi source not tracked by git" "warning"
out_has "wip.sh" "file listed"

test_start "orphan_file_is_counted"
: >"$DRIFT_FIX/untracked"
printf '%s\n' ".config/gone.conf" >"$ORPHANS"
drift
assert_equals 1 "$RC" "rc"
out_has "1 file(s) — review" "orphan warning"

test_start "stale_source_is_detected_by_mtime"
rm -f "$ORPHANS"
printf 'deployed.conf\n' >"$DRIFT_FIX/managed"
SRC_FILE="$SRC/deployed.conf"
printf 'source\n' >"$SRC_FILE"
printf '%s\n' "$SRC_FILE" >"$DRIFT_FIX/source-path"
printf 'deployed\n' >"$HOME/deployed.conf"
touch -t 202001010000 "$SRC_FILE"
drift
assert_equals 1 "$RC" "rc"
out_has "1 target(s) newer than source" "stale warning"
out_has "deployed.conf" "path listed"

test_start "stale_source_is_counted_in_json"
drift --json
assert_equals 1 "$RC" "rc"
assert_equals "1" "$(jq -r .stale_source <"$OUTF")" "stale count"

test_start "an_up_to_date_source_is_not_stale"
touch "$SRC_FILE"
drift
assert_equals 0 "$RC" "rc"
out_has "Stale source" "row"
out_has "no drift detected" "clean"

test_start "missing_chezmoi_is_a_prerequisite_failure"
NOCM="$DOTFILES_COV_TMPDIR/nocm"
mkdir -p "$NOCM"
ln -sf "$(command -v bash)" "$NOCM/bash"
for c in jq python3 wc tr git sed grep cat head date printf uname dirname basename tty locale; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOCM/$c"
done
PATH="$NOCM" drift
assert_equals 2 "$RC" "rc"
out_has "chezmoi" "error names the missing tool"

test_start "missing_chezmoi_reports_json_when_asked"
PATH="$NOCM" drift --json
assert_equals 2 "$RC" "rc"
assert_equals "chezmoi not found" "$(jq -r .error <"$OUTF")" "json error"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
