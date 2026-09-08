#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/ops/heal-chezmoi.sh, plus the two one-line
# ops wrappers scripts/ops/chezmoi-diff.sh and
# scripts/ci/guard-gitleaks-checkout.sh.
#
# heal-chezmoi.sh is a function library: heal.sh sources it and supplies
# REPO_ROOT, BACKUP_DIR, DRY_RUN and the counters. These tests source it the
# same way, with a recording `chezmoi` stub and a sandboxed backup
# directory, so no drift is ever applied to the host.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_REAL="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

HEAL_CHEZMOI="$REPO_ROOT_REAL/scripts/ops/heal-chezmoi.sh"
CHEZMOI_DIFF="$REPO_ROOT_REAL/scripts/ops/chezmoi-diff.sh"
GITLEAKS_GUARD="$REPO_ROOT_REAL/scripts/ci/guard-gitleaks-checkout.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "ops_scripts_exist"
assert_file_exists "$HEAL_CHEZMOI" "scripts/ops/heal-chezmoi.sh must exist"
assert_file_exists "$CHEZMOI_DIFF" "scripts/ops/chezmoi-diff.sh must exist"
assert_file_exists "$GITLEAKS_GUARD" "scripts/ci/guard-gitleaks-checkout.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

CALLS="$WORK/calls"
: >"$CALLS"
# chezmoi: `status` prints $FAKE_STATUS then $FAKE_STATUS_AFTER on later
# calls, so "did apply clean the drift?" can be driven both ways; `apply`
# exits with $FAKE_APPLY_RC.
cat >"$BIN/chezmoi" <<EOF
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*" >>"$CALLS"
case "\${1:-}" in
  status)
    if [[ -f "$WORK/status-called" ]]; then
      [[ -n "\${FAKE_STATUS_AFTER:-}" ]] && printf '%s\n' "\$FAKE_STATUS_AFTER"
    else
      : >"$WORK/status-called"
      [[ -n "\${FAKE_STATUS:-}" ]] && printf '%s\n' "\$FAKE_STATUS"
    fi
    ;;
  apply)
    [[ -n "\${FAKE_APPLY_MESSAGE:-}" ]] && printf '%s\n' "\$FAKE_APPLY_MESSAGE"
    exit "\${FAKE_APPLY_RC:-0}"
    ;;
  diff) : ;;
esac
exit 0
EOF
chmod +x "$BIN/chezmoi"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# heal <snippet> — source heal-chezmoi.sh with the variables and log
# helpers heal.sh would provide, then run the snippet. Stdout is captured;
# stderr is replayed so the coverage runner keeps its xtrace records.
heal() {
  local snippet="$1" rc=0
  rm -f "$WORK/status-called"
  PATH="${HEAL_PATH:-$BIN:/usr/bin:/bin}" \
    "$REAL_BASH" -c "
      set +e
      REPO_ROOT='${FAKE_REPO_ROOT:-$WORK/repo}'
      BACKUP_DIR='$WORK/backups'
      DRY_RUN='${DRY_RUN:-0}'
      ISSUES_FOUND=0
      FIXES_APPLIED=0
      CHEZMOI_APPLIED=0
      log_info() { printf 'log_info %s\n' \"\$*\"; }
      log_dry() { printf 'log_dry %s\n' \"\$*\"; }
      persist_log() { printf 'persist_log %s\n' \"\$*\"; }
      source '$HEAL_CHEZMOI'
      $snippet
    " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# create_pre_heal_backup
# ===========================================================================
test_start "pre_heal_backup_delegates_to_rollback_when_present"
FAKE_REPO="$WORK/repo"
mkdir -p "$FAKE_REPO/scripts/ops"
cat >"$FAKE_REPO/scripts/ops/rollback.sh" <<EOF
#!$REAL_BASH
printf 'rollback %s\n' "\$*" >>"$CALLS"
exit 0
EOF
chmod +x "$FAKE_REPO/scripts/ops/rollback.sh"
: >"$CALLS"
rc="$(heal 'create_pre_heal_backup')"
assert_equals "0" "$rc" "the backup step exits 0"
assert_file_contains "$OUT" "Creating backup before heal" "the step is announced"
assert_file_contains "$CALLS" "rollback backup --force" "rollback.sh performs the backup"

test_start "pre_heal_backup_falls_back_to_an_inline_copy"
rm -f "$FAKE_REPO/scripts/ops/rollback.sh"
INLINE_HOME="$WORK/inline-home"
mkdir -p "$INLINE_HOME"
printf 'export A=1\n' >"$INLINE_HOME/.bashrc"
printf 'export B=2\n' >"$INLINE_HOME/.zshrc"
rc=0
PATH="$BIN:/usr/bin:/bin" HOME="$INLINE_HOME" "$REAL_BASH" -c "
  set +e
  REPO_ROOT='$FAKE_REPO'
  BACKUP_DIR='$WORK/backups'
  DRY_RUN=0
  ISSUES_FOUND=0; FIXES_APPLIED=0; CHEZMOI_APPLIED=0
  log_info() { printf 'log_info %s\n' \"\$*\"; }
  log_dry() { :; }
  persist_log() { :; }
  source '$HEAL_CHEZMOI'
  create_pre_heal_backup
" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the inline backup exits 0"
assert_file_contains "$OUT" "Backup created at" "the destination is reported"
copied="$(find "$WORK/backups" -name '.bashrc' | wc -l | tr -d ' ')"
assert_equals "1" "$copied" "the shell rc files are copied into the backup"

# ===========================================================================
# heal_chezmoi_drift
# ===========================================================================
test_start "drift_healing_is_skipped_without_chezmoi"
NOCHEZMOI="$WORK/nochezmoi"
mkdir -p "$NOCHEZMOI"
for tool in bash sh printf awk wc tr mktemp rm date cp mkdir tail sed; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOCHEZMOI/$tool"
done
rc="$(HEAL_PATH="$NOCHEZMOI" heal 'heal_chezmoi_drift; echo "rc=$?"')"
assert_equals "0" "$rc" "a host without chezmoi is not an error"
assert_file_contains "$OUT" "rc=0" "the function returns 0"

test_start "a_clean_chezmoi_state_reports_and_returns"
: >"$CALLS"
rc="$(FAKE_STATUS="" heal 'heal_chezmoi_drift; echo "issues=$ISSUES_FOUND"')"
assert_equals "0" "$rc" "a clean state exits 0"
assert_file_contains "$OUT" "chezmoi state" "the clean state is reported"
assert_file_contains "$OUT" "issues=0" "no issue is counted"
assert_output_not_contains "chezmoi apply" "cat '$CALLS'"

test_start "dry_run_reports_the_fix_without_applying_it"
: >"$CALLS"
rc="$(DRY_RUN=1 FAKE_STATUS=" M .zshrc" heal 'heal_chezmoi_drift; echo "issues=$ISSUES_FOUND"')"
assert_equals "0" "$rc" "the dry run exits 0"
assert_file_contains "$OUT" "log_dry" "the fix is described, not performed"
assert_file_contains "$OUT" "chezmoi apply --force" "the command that would run is named"
assert_file_contains "$OUT" "issues=1" "the drift is still counted as an issue"
assert_output_not_contains "chezmoi apply" "cat '$CALLS'"

test_start "source_only_drift_is_reported_without_applying"
: >"$CALLS"
rc="$(FAKE_STATUS="M  scripts/x.sh" heal 'heal_chezmoi_drift')"
assert_equals "0" "$rc" "source-only drift exits 0"
assert_file_contains "$OUT" "modified in source only" "the user is told to commit or revert"
assert_output_not_contains "chezmoi apply" "cat '$CALLS'"

test_start "applicable_drift_is_applied_and_verified"
: >"$CALLS"
rc="$(FAKE_STATUS=" M .zshrc" FAKE_STATUS_AFTER="" heal 'heal_chezmoi_drift; echo "fixes=$FIXES_APPLIED applied=$CHEZMOI_APPLIED"')"
assert_equals "0" "$rc" "a successful apply exits 0"
assert_file_contains "$CALLS" "chezmoi apply --force" "apply is actually run"
assert_file_contains "$OUT" "chezmoi re-apply" "the result is reported"
assert_file_contains "$OUT" "1 file(s) synced" "the count of synced files is reported"
assert_file_contains "$OUT" "fixes=1 applied=1" "the counters are updated"
assert_file_contains "$OUT" "persist_log" "the action is journalled"

test_start "drift_remaining_after_apply_is_reported"
: >"$CALLS"
rc="$(FAKE_STATUS=$' M a\n M b' FAKE_STATUS_AFTER=" M b" heal 'heal_chezmoi_drift')"
assert_equals "0" "$rc" "a partial apply exits 0"
assert_file_contains "$OUT" "still drifted" "the leftover drift is reported"
assert_file_contains "$OUT" "chezmoi diff" "the user is pointed at the inspection command"

test_start "a_failed_apply_surfaces_the_log_tail"
: >"$CALLS"
rc="$(FAKE_STATUS=" M .zshrc" FAKE_APPLY_RC=1 FAKE_APPLY_MESSAGE="permission denied: /etc/hosts" heal 'heal_chezmoi_drift')"
assert_equals "1" "$rc" "a failed apply returns 1"
assert_file_contains "$OUT" "chezmoi re-apply" "the failure is reported"
assert_file_contains "$OUT" "permission denied" "the tail of the apply log is shown"

# ===========================================================================
# chezmoi-diff.sh
# ===========================================================================
test_start "chezmoi_diff_excludes_scripts_by_default"
: >"$CALLS"
rc=0
PATH="$BIN:/usr/bin:/bin" "$REAL_BASH" "$CHEZMOI_DIFF" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the wrapper exits 0"
assert_file_contains "$CALLS" "chezmoi diff --exclude scripts" "scripts are excluded by default"

test_start "chezmoi_diff_honours_the_exclude_override_and_extra_arguments"
: >"$CALLS"
rc=0
PATH="$BIN:/usr/bin:/bin" DOTFILES_CHEZMOI_DIFF_EXCLUDES="scripts,dot_config" \
  "$REAL_BASH" "$CHEZMOI_DIFF" --reverse >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the wrapper exits 0"
assert_file_contains "$CALLS" "--exclude scripts --exclude dot_config --reverse" "each exclusion becomes a flag and extra arguments are forwarded"

# ===========================================================================
# guard-gitleaks-checkout.sh (compat shim)
# ===========================================================================
test_start "the_gitleaks_guard_shim_delegates_to_the_canonical_script"
# The shim execs the tools/ci copy; PATH-shadow `bash` to record that
# hand-off instead of running the real guard.
cat >"$BIN/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  */tools/ci/guard-gitleaks-checkout.sh)
    printf 'delegated %s\n' "\${*:2}"
    exit 0
    ;;
esac
exec "$REAL_BASH" "\$@"
EOF
chmod +x "$BIN/bash"
rc=0
PATH="$BIN:/usr/bin:/bin" "$REAL_BASH" "$GITLEAKS_GUARD" --check >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the shim exits 0"
assert_file_contains "$OUT" "delegated --check" "arguments reach the canonical script"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
