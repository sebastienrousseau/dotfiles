#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for three small entry points, driven inside the
# coverage sandbox so nothing on the host is rendered or committed:
#
#   lib/dot/bento.sh                       — the intelligence card
#   scripts/git-hooks/prepare-commit-msg   — commit-message branding hook
#   scripts/ci/check-copyright-headers.sh  — compat shim for the moved script
#
# Split from test_ops_small_entrypoints.sh so both files stay inside the
# coverage runner's 60s per-file budget.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LOCKS="$REPO_ROOT/scripts/diagnostics/version-locks.sh"
TUNING="$REPO_ROOT/scripts/tuning/linux.sh"
PREWARM="$REPO_ROOT/scripts/ops/prewarm.sh"
TELEPORT="$REPO_ROOT/scripts/ops/teleport.sh"
AI_SETUP="$REPO_ROOT/scripts/ops/ai-setup.sh"
BENTO="$REPO_ROOT/lib/dot/bento.sh"
HOOK="$REPO_ROOT/scripts/git-hooks/prepare-commit-msg"
COPYRIGHT_SHIM="$REPO_ROOT/scripts/ci/check-copyright-headers.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
export CALLS="$DOTFILES_COV_TMPDIR/calls.txt"

run() {
  : >"$CALLS"
  "$@" >"$OUTF" 2>"$ERRF" </dev/null
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
called() { assert_file_contains "$CALLS" "$1" "invoked $1"; }
record_stub() {
  cat >"$BIN/$1" <<STUB
#!$REAL_BASH
printf '$1 %s\\n' "\$*" >>"\$CALLS"
exit "\${${2:-STUB_RC}:-0}"
STUB
  chmod +x "$BIN/$1"
}

# ── bento ───────────────────────────────────────────────────────────────
test_start "bento_renders_the_intelligence_card"
run bash "$BENTO"
assert_equals 0 "$RC" "rc"
out_has "D O T F I L E S" "banner"
out_has "Platform" "platform row"
out_has "Security" "security row"
out_has "Hydrated" "footer"

test_start "bento_names_the_running_platform"
# The card detects the OS itself: macOS on Darwin, WSL when
# /proc/sys/kernel/osrelease says so, Linux otherwise.
if [[ "$(uname -s)" == "Darwin" ]]; then
  out_has "macOS" "macOS detected"
elif grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null; then
  out_has "WSL" "WSL detected"
else
  out_has "Linux" "Linux detected"
fi

# ── prepare-commit-msg ──────────────────────────────────────────────────
MSG="$DOTFILES_COV_TMPDIR/COMMIT_EDITMSG"
SIGNATURE="$HOME/.euxis/data/config/branding/signature.txt"

test_start "hook_is_a_no_op_without_a_message_file"
run bash "$HOOK"
assert_equals 0 "$RC" "rc"
run bash "$HOOK" "$DOTFILES_COV_TMPDIR/absent-msg"
assert_equals 0 "$RC" "rc"

test_start "hook_skips_merge_and_squash_commits"
printf 'feat: something\n' >"$MSG"
run bash "$HOOK" "$MSG" merge
assert_equals 0 "$RC" "rc"
assert_true "! grep -q ARCHITECT '$MSG'" "message untouched"
run bash "$HOOK" "$MSG" squash
assert_equals 0 "$RC" "rc"

test_start "hook_is_a_no_op_without_a_signature_file"
run bash "$HOOK" "$MSG"
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(wc -l <"$MSG" | tr -d ' ')" "message unchanged"

test_start "hook_appends_the_signature_once"
mkdir -p "$(dirname "$SIGNATURE")"
printf -- '-- THE ARCHITECT --\n' >"$SIGNATURE"
run bash "$HOOK" "$MSG"
assert_equals 0 "$RC" "rc"
assert_file_contains "$MSG" "THE ARCHITECT" "signature appended"
run bash "$HOOK" "$MSG"
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(grep -c 'THE ARCHITECT' "$MSG")" "not appended twice"

# ── copyright-header compat shim ────────────────────────────────────────
test_start "the_ci_shim_delegates_to_the_moved_validator"
# An extension nothing matches keeps the delegated scan instant while still
# proving the shim reached tools/ci/check-copyright-headers.sh.
run bash "$COPYRIGHT_SHIM" --extensions=zzz --excludes=node_modules
assert_equals 0 "$RC" "rc"
out_has "No files matched extensions: zzz" "the real validator ran"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
