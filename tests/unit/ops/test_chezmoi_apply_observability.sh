#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# chezmoi-apply.sh is observable and recoverable: a bad flag is a usage
# error before the lock or the log (D4); every apply, failed or not, logs
# apply_end with its status and duration in ms, and each step an apply_step
# event (O2, O3); the targets the apply changes are backed up first, capped,
# and `dot doctor rollback` (rollback.sh) restores them (O4). Trace ids are
# random (O7). Every run is sandboxed with a stub chezmoi.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/host_path.sh"

APPLY="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
ROLLBACK="$REPO_ROOT/scripts/ops/rollback.sh"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SYS="$(host_path_without "$WORK/sys" gum chezmoi mise dot flock)"
N=0

# new_case: a fresh sandbox whose chezmoi logs its calls, lists two flags
# for `apply --help`, reports STUB_STATUS for `status` and exits STUB_RC
# for `apply`.
new_case() {
  N=$((N + 1))
  D="$WORK/c$N"
  mkdir -p "$D/home/.local/state" "$D/run" "$D/stubs"
  : >"$D/calls"
  cat >"$D/stubs/chezmoi" <<EOF
#!$REAL_BASH
printf '%s\n' "chezmoi \$*" >>"$D/calls"
case "\$1 \${2:-}" in
  "apply --help") printf 'Flags:\n  -n, --dry-run   Do not\n      --force     Make all\n'; exit 0 ;;
  "status "*) printf '%b' "\${STUB_STATUS:-}"; exit 0 ;;
  "apply "*) exit "\${STUB_RC:-0}" ;;
esac
exit 0
EOF
  chmod +x "$D/stubs/chezmoi"
}

# apply [ARG...]: run the apply with STUB_* from the environment; sets RC,
# OUT and LOG (the cli domain's log.v1 file).
apply() {
  RC=0
  OUT="$(cd "$D" && env -i HOME="$D/home" XDG_STATE_HOME="$D/home/.local/state" \
    XDG_DATA_HOME="$D/home/.local/share" XDG_RUNTIME_DIR="$D/run" TMPDIR="$D/run" \
    PATH="$D/stubs:$SYS" TERM=dumb NO_COLOR=1 DOTFILES_NONINTERACTIVE=1 \
    DOTFILES_SNAPSHOT_ON_APPLY=0 DOTFILES_POST_APPLY_REPAIR=0 DOTFILES_PREWARM_ON_APPLY=0 \
    DOTFILES_CHEZMOI_STATUS=0 STUB_RC="${STUB_RC:-0}" STUB_STATUS="${STUB_STATUS:-}" \
    DOTFILES_MAX_BACKUPS="${DOTFILES_MAX_BACKUPS:-10}" \
    "$REAL_BASH" "$APPLY" "$@" </dev/null 2>&1)" || RC=$?
  LOG="$D/home/.local/state/dot/cli/log.jsonl"
}

# events NAME: the log.v1 records of event NAME.
events() { grep -F "\"event\":\"$1\"" "$LOG" 2>/dev/null; }

test_start "bad_flag_is_a_usage_error_before_the_lock_and_log"
new_case
apply --bogus
assert_equals "64" "$RC" "exit 64"
assert_contains "unknown flag '--bogus'" "$OUT" "names the flag"
assert_equals "" "$(events apply_start)" "no apply_start logged"
assert_equals "" "$(grep -E '^chezmoi apply( |$)' "$D/calls" | grep -v -- '--help')" "chezmoi apply never ran"
assert_equals "" "$(ls "$D/run")" "no lock taken"

test_start "a_known_flag_and_targets_after_double_dash_pass"
new_case
apply --dry-run -- --not-a-flag
assert_equals "0" "$RC" "exit 0"
assert_contains "chezmoi apply --dry-run -- --not-a-flag" "$(cat "$D/calls")" "passed on to chezmoi"

test_start "failed_apply_logs_apply_end_with_status_and_ms"
new_case
STUB_RC=3 apply
assert_not_equals "0" "$RC" "the apply fails"
assert_not_empty "$(events apply_start)" "apply_start"
end="$(events apply_end)"
assert_contains '"level":"error"' "$end" "apply_end at error level"
assert_contains '"status":"1"' "$end" "with the apply's exit status"
assert_not_empty "$(printf '%s' "$end" | grep -E '"duration_ms":"[0-9]+"')" "and a duration in ms"
step="$(events apply_step)"
assert_contains '"step":"Chezmoi apply","status":"3"' "$step" "the failed step has its own event"
assert_not_empty "$(printf '%s' "$step" | grep -E '"duration_ms":"[0-9]+"')" "with its duration in ms"

test_start "successful_apply_logs_apply_end_status_0"
new_case
apply
assert_equals "0" "$RC" "exit 0"
assert_contains '"status":"0"' "$(events apply_end)" "apply_end status 0"
assert_contains '"name":"chezmoi_apply_duration"' "$(events metric)" "the duration metric"
assert_contains '"unit":"ms"' "$(events metric)" "in ms"

test_start "changed_targets_are_backed_up_and_rollback_restores_them"
new_case
printf 'mine\n' >"$D/home/.zshrc"
STUB_STATUS=' M .zshrc\n A .config/new\n R 10-script.sh\n' apply
B="$(find "$D/home/.local/share/dotfiles/backups" -maxdepth 1 -name 'backup_*_pre_apply' 2>/dev/null)"
assert_not_empty "$B" "a pre_apply backup"
assert_equals "mine" "$(cat "$B/.zshrc" 2>/dev/null)" "holds the target as it was"
assert_file_contains "$B/.backup_meta" "files_backed_up=1" "only existing targets"
assert_contains '"files":"1"' "$(events apply_backup)" "and is logged"
printf 'applied\n' >"$D/home/.zshrc"
env -i HOME="$D/home" XDG_STATE_HOME="$D/home/.local/state" XDG_DATA_HOME="$D/home/.local/share" \
  XDG_RUNTIME_DIR="$D/run" PATH="$D/stubs:$SYS" TERM=dumb NO_COLOR=1 DOTFILES_DIR="$D/none" \
  "$REAL_BASH" "$ROLLBACK" rollback --force </dev/null >/dev/null 2>&1
assert_equals "mine" "$(cat "$D/home/.zshrc")" "rollback returns to the state before the apply"

test_start "dry_run_takes_no_backup"
new_case
printf 'mine\n' >"$D/home/.zshrc"
STUB_STATUS=' M .zshrc\n' apply --dry-run
assert_equals "" "$(find "$D/home/.local/share/dotfiles/backups" -name 'backup_*' 2>/dev/null)" "none"

test_start "backups_are_capped"
new_case
printf 'mine\n' >"$D/home/.zshrc"
mkdir -p "$D/home/.local/share/dotfiles/backups"
for i in 1 2 3 4; do mkdir "$D/home/.local/share/dotfiles/backups/backup_2000010${i}_000000_manual"; done
DOTFILES_MAX_BACKUPS=3 STUB_STATUS=' M .zshrc\n' apply
kept="$(find "$D/home/.local/share/dotfiles/backups" -mindepth 1 -maxdepth 1 -name 'backup_*' | sort)"
assert_equals "3" "$(printf '%s\n' "$kept" | grep -c .)" "only the newest three remain"
assert_contains "_pre_apply" "$kept" "the new backup is among them"
assert_equals "" "$(printf '%s\n' "$kept" | grep backup_20000101)" "the oldest went first"

test_start "trace_ids_are_random"
ids="$(for _ in 1 2 3 4 5 6 7 8 9 10; do
  env -u DOT_TRACE_ID "$REAL_BASH" -c 'source "$1"; printf "%s\n" "$DOT_TRACE_ID"' _ "$REPO_ROOT/lib/dot/log.sh"
done)"
assert_equals "10" "$(printf '%s\n' "$ids" | sort -u | grep -c .)" "ten runs, ten ids"
assert_equals "10" "$(printf '%s\n' "$ids" | grep -cE '^[0-9a-f]{12}$')" "12 hex digits each"
assert_not_equals "10" "$(printf '%s\n' "$ids" | grep -c '000$')" "not all ending in 000"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
