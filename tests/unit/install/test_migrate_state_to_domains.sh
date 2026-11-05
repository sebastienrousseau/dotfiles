#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/migrate/migrate-state-to-domains.sh and its rollback, end to end
# in a sandbox XDG_STATE_HOME: where each legacy entry lands, merges into a
# domain directory that exists, what it leaves behind and why, the marker,
# and that the rollback puts back what the migration moved.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

MIGRATE="$REPO_ROOT/install/migrate/migrate-state-to-domains.sh"
ROLLBACK="$REPO_ROOT/install/migrate/rollback-state-to-domains.sh"
WORK="$(mktemp -d)"
SLEEPER=""
trap '[[ -z "$SLEEPER" ]] || kill "$SLEEPER" 2>/dev/null; rm -rf "$WORK"' EXIT
N=0

# fresh: a new sandbox; S is its XDG_STATE_HOME, O the legacy dir.
fresh() {
  N=$((N + 1))
  S="$WORK/s$N"
  O="$S/dotfiles"
  mkdir -p "$O"
}

# run SCRIPT ARGS...: set OUT (stdout and stderr) and RC.
run() {
  RC=0
  OUT="$(XDG_STATE_HOME="$S" HOME="$WORK/home" bash "$@" 2>&1)" || RC=$?
}

test_start "every_known_entry_moves_to_its_domain"
fresh
mkdir -p "$O/checkpoints" "$O/snapshots/20260101" "$O/update" "$O/attestations" \
  "$O/fleet" "$O/ai-serve" "$O/registry" "$O/orphans.d" "$O/v0_2_503-migration"
for f in eval-timings.jsonl debug.log audit-bypass.log security-audit.log rollback.log \
  heal.log orphans icloud-symlinks.log dot.log metrics.jsonl agent-sessions.jsonl; do
  echo "$f" >"$O/$f"
done
echo cp >"$O/checkpoints/a.json"
echo t >"$O/ai-serve/gateway.token"
echo e >"$O/fleet/events.jsonl"
echo s >"$O/update/last.status"
run "$MIGRATE"
assert_equals "0|" "$RC|$OUT" "a clean migration exits 0 and prints nothing"
for pair in agent/checkpoints/a.json config/snapshots/20260101 config/update/last.status \
  attest/attestations fleet/events.jsonl ai/serve/gateway.token cli/registry \
  shell/eval-timings.jsonl shell/debug.log security/audit-bypass.log \
  security/security-audit.log doctor/rollback.log doctor/heal.log doctor/orphans \
  system/icloud-symlinks.log cli/legacy/dot.log cli/legacy/metrics.jsonl \
  cli/legacy/agent-sessions.jsonl; do
  assert_true "[[ -e '$S/dot/$pair' ]]" "dot/$pair"
done
assert_equals "eval-timings.jsonl" "$(cat "$S/dot/shell/eval-timings.jsonl")" "contents travel"
assert_equals "orphans.d v0_2_503-migration" "$(ls "$O" | tr '\n' ' ' | sed 's/ $//')" \
  "only the unknown entry and the 0.2.503 marker stay"
assert_true "[[ -f '$S/dot/cli/migrations/state-domains.done' ]]" "the run is marked done"
assert_equals "700" "$(stat -c %a "$S/dot/security" 2>/dev/null || stat -f %Lp "$S/dot/security")" \
  "a domain dir it makes is private"

test_start "a_second_run_does_nothing"
echo late >"$O/eval-timings.jsonl"
run "$MIGRATE"
assert_equals "0|late" "$RC|$(cat "$O/eval-timings.jsonl")" "the marker stops a second run"

test_start "an_existing_domain_dir_is_merged_and_a_clash_is_left"
fresh
mkdir -p "$O/fleet" "$S/dot/fleet"
echo old-events >"$O/fleet/events.jsonl"
echo old-drift >"$O/fleet/drift-history.jsonl"
echo new-log >"$S/dot/fleet/log.jsonl"
echo new-drift >"$S/dot/fleet/drift-history.jsonl"
run "$MIGRATE"
assert_equals "3" "$RC" "a clash exits 3"
assert_contains "drift-history.jsonl exists" "$OUT" "and names it"
assert_equals "old-events|new-log|new-drift|old-drift" \
  "$(cat "$S/dot/fleet/events.jsonl")|$(cat "$S/dot/fleet/log.jsonl")|$(cat "$S/dot/fleet/drift-history.jsonl")|$(cat "$O/fleet/drift-history.jsonl")" \
  "the free name moves; neither side of the clash is touched"
assert_false "[[ -e '$S/dot/cli/migrations/state-domains.done' ]]" "not marked done, so the next apply retries"

test_start "a_merged_dir_with_no_clash_is_removed"
fresh
mkdir -p "$O/fleet" "$S/dot/fleet"
echo e >"$O/fleet/events.jsonl"
run "$MIGRATE"
assert_equals "0|e" "$RC|$(cat "$S/dot/fleet/events.jsonl")" "every entry moved"
assert_false "[[ -e '$O/fleet' ]]" "and the emptied old dir is gone"

test_start "a_dir_whose_new_name_is_a_file_is_left_whole"
fresh
mkdir -p "$O/orphans" "$S/dot/doctor"
echo o >"$O/orphans/one"
echo f >"$S/dot/doctor/orphans"
run "$MIGRATE"
assert_equals "3" "$RC" "it is left"
assert_contains "left $O/orphans: $S/dot/doctor/orphans exists" "$OUT" "as a whole, not merged into the file"
assert_equals "o|f" "$(cat "$O/orphans/one")|$(cat "$S/dot/doctor/orphans")" "both sides untouched"

test_start "a_log_whose_new_file_exists_is_prepended"
fresh
mkdir -p "$S/dot/shell"
printf 'a\nb\n' >"$O/eval-timings.jsonl"
printf 'c\n' >"$S/dot/shell/eval-timings.jsonl"
run "$MIGRATE"
assert_equals "0|a b c" "$RC|$(tr '\n' ' ' <"$S/dot/shell/eval-timings.jsonl" | sed 's/ $//')" \
  "old lines first, then the new"
assert_false "[[ -e '$O/eval-timings.jsonl' ]]" "the old file is gone"

test_start "a_file_whose_new_name_exists_is_left"
fresh
mkdir -p "$S/dot/doctor"
echo old >"$O/orphans"
echo new >"$S/dot/doctor/orphans"
run "$MIGRATE"
assert_equals "3|old|new" "$RC|$(cat "$O/orphans")|$(cat "$S/dot/doctor/orphans")" \
  "an orphans list is not a log: both stay"

test_start "every_directory_it_makes_is_private"
fresh
echo d >"$O/dot.log"
(umask 022 && run "$MIGRATE")
for d in dot dot/cli dot/cli/migrations dot/cli/legacy; do
  assert_equals "drwx------" "$(ls -ld "$S/$d" | cut -c1-10)" "$d is 0700"
done

test_start "a_merged_log_keeps_its_permissions"
fresh
mkdir -p "$S/dot/security"
echo old >"$O/security-audit.log"
echo new >"$S/dot/security/security-audit.log"
chmod 0600 "$S/dot/security/security-audit.log"
run "$MIGRATE"
assert_equals "0|-rw-------" "$RC|$(ls -l "$S/dot/security/security-audit.log" | cut -c1-10)" \
  "a private log stays private"

test_start "a_move_that_fails_is_left_and_the_rest_moves"
fresh
mkdir -p "$O/checkpoints" "$S/dot/agent"
echo d >"$O/debug.log"
chmod 0500 "$S/dot/agent"
run "$MIGRATE"
chmod 0700 "$S/dot/agent"
if [[ "$(id -u)" == 0 ]]; then
  echo "  (skipped: root can write a read-only directory)"
else
  assert_equals "3" "$RC" "the run reports what it left"
  assert_contains "left $O/checkpoints" "$OUT" "and names it"
  assert_true "[[ -d '$O/checkpoints' && -f '$S/dot/shell/debug.log' ]]" \
    "the failed entry stays, the next one still moves"
  assert_false "[[ -e '$S/dot/cli/migrations/state-domains.done' ]]" "so the run is retried"
fi

test_start "a_running_gateway_is_left_until_it_stops"
fresh
mkdir -p "$O/ai-serve"
sleep 60 &
SLEEPER=$!
echo "$SLEEPER" >"$O/ai-serve/serve.pid"
run "$MIGRATE"
assert_equals "3" "$RC" "a running gateway exits 3"
assert_contains "dot-ai-proxy stop" "$OUT" "and says how to stop it"
assert_true "[[ -f '$O/ai-serve/serve.pid' ]]" "its state stays"
kill "$SLEEPER" 2>/dev/null
wait "$SLEEPER" 2>/dev/null
SLEEPER=""
run "$MIGRATE"
assert_equals "0" "$RC" "once it stops, the next run moves it"
assert_true "[[ -f '$S/dot/ai/serve/serve.pid' ]]" "to ai/serve"

test_start "dry_run_moves_nothing"
fresh
echo x >"$O/heal.log"
run "$MIGRATE" --dry-run
assert_equals "0" "$RC" "a dry run exits 0"
assert_contains "move $O/heal.log -> $S/dot/doctor/heal.log" "$OUT" "it lists the move"
assert_true "[[ -f '$O/heal.log' && ! -e '$S/dot/doctor' && ! -e '$S/dot/cli/migrations/state-domains.done' ]]" \
  "and changes nothing"

test_start "no_legacy_dir_is_done"
fresh
rmdir "$O"
run "$MIGRATE"
assert_equals "0" "$RC" "nothing to move exits 0"
assert_true "[[ -f '$S/dot/cli/migrations/state-domains.done' ]]" "and marks the run done"

test_start "bad_usage_exits_1"
fresh
run "$MIGRATE" --bogus
assert_equals "1" "$RC" "an unknown option exits 1"
assert_contains "unknown option --bogus" "$OUT" "and says which"

test_start "rollback_puts_back_what_moved"
fresh
mkdir -p "$O/snapshots/s1" "$S/dot/shell"
echo h >"$O/heal.log"
echo a >"$O/eval-timings.jsonl"
echo b >"$S/dot/shell/eval-timings.jsonl"
run "$MIGRATE"
assert_equals "0" "$RC" "migrated"
run "$ROLLBACK" --dry-run
assert_equals "0" "$RC" "a dry rollback exits 0"
assert_contains "move $S/dot/doctor/heal.log -> $O/heal.log" "$OUT" "and lists the move back"
assert_true "[[ -f '$S/dot/doctor/heal.log' ]]" "without making it"
run "$ROLLBACK"
assert_equals "3" "$RC" "a prepended log cannot be split: exits 3"
assert_contains "prepended" "$OUT" "and says so"
assert_equals "h" "$(cat "$O/heal.log")" "a moved file is back"
assert_true "[[ -d '$O/snapshots/s1' && ! -e '$S/dot/config/snapshots' ]]" "a moved dir is back"
assert_false "[[ -e '$S/dot/cli/migrations/state-domains.done' ]]" "the marker is gone, so apply migrates again"
run "$ROLLBACK"
assert_equals "0" "$RC" "a second rollback has nothing to do"

test_start "a_clean_rollback_is_silent_and_skips_blank_lines"
fresh
echo h >"$O/heal.log"
run "$MIGRATE"
printf '\n' >>"$S/dot/cli/migrations/state-domains.manifest"
run "$ROLLBACK"
assert_equals "0|" "$RC|$OUT" "everything back, nothing printed, a blank line is not an entry"
assert_equals "h" "$(cat "$O/heal.log")" "the file is back"

test_start "rollback_bad_usage_exits_1"
fresh
run "$ROLLBACK" --bogus
assert_equals "1" "$RC" "an unknown option exits 1"
assert_contains "unknown option --bogus" "$OUT" "and says which"

test_start "rollback_leaves_an_entry_whose_old_name_is_taken"
fresh
echo h >"$O/heal.log"
run "$MIGRATE"
echo newer >"$O/heal.log"
run "$ROLLBACK"
assert_equals "3|newer|h" "$RC|$(cat "$O/heal.log")|$(cat "$S/dot/doctor/heal.log")" \
  "neither file is overwritten"

# render_hook SOURCE: the apply hook rendered by chezmoi with SOURCE as its
# source dir (the script is SOURCE/../install/migrate/...), into $HOOK.
HOOK="$WORK/hook.sh"
render_hook() {
  chezmoi --config "$WORK/chezmoi.json" --source "$1" --destination "$WORK/home" \
    --cache "$WORK/cache" --persistent-state "$WORK/state.boltdb" \
    execute-template <"$REPO_ROOT/defaults/run_before_migrate-state.sh.tmpl" >"$HOOK" 2>/dev/null
}

if command -v chezmoi >/dev/null 2>&1; then
  echo '{}' >"$WORK/chezmoi.json"
  test_start "the_apply_hook_migrates_and_never_fails_the_apply"
  render_hook "$REPO_ROOT/defaults"
  assert_contains "script=\"$REPO_ROOT/install/migrate/migrate-state-to-domains.sh\"" "$(cat "$HOOK")" \
    "the hook runs the script beside its source dir"
  fresh
  echo h >"$O/heal.log"
  run "$HOOK"
  assert_equals "0" "$RC" "a migration exits 0"
  assert_true "[[ -f '$S/dot/doctor/heal.log' ]]" "and the hook ran it"
  fresh
  mkdir -p "$S/dot/doctor"
  echo old >"$O/orphans"
  echo new >"$S/dot/doctor/orphans"
  run "$HOOK"
  assert_equals "0" "$RC" "something left behind still lets the apply go on"
  assert_contains "the next apply tries again" "$OUT" "and says it will retry"
  mkdir -p "$WORK/packaged/defaults"
  render_hook "$WORK/packaged/defaults"
  run "$HOOK"
  assert_equals "0|" "$RC|$OUT" "no script beside the source (a packaged install): a silent no-op"
else
  echo "  (skip) chezmoi not available: the apply hook is not rendered"
fi

test_start "install_sh_runs_the_migration_from_the_checkout_that_has_it"
mkdir -p "$WORK/src-a" "$WORK/src-b/install/migrate"
printf 'echo "ran b $*"\nexit 3\n' >"$WORK/src-b/install/migrate/m.sh"
# install_run SCRIPT [NOTICE]: run_migration from install.sh, sourced in a
# subshell.
install_run() {
  (
    source "$REPO_ROOT/install.sh" >/dev/null 2>&1
    SOURCE_DIR="$WORK/src-a" LEGACY_SOURCE_DIR="$WORK/src-b"
    run_migration "$1" "it warned" "${2:-}"
  ) 2>&1
}
assert_equals "ran b |   it warned" "$(install_run m.sh | tr '\n' '|' | sed 's/|$//')" \
  "the first checkout with the script runs it, and a failure only warns"
assert_equals "" "$(install_run absent.sh)" "no checkout with it: nothing runs, nothing printed"
assert_equals "   running m|ran b |   it warned" "$(install_run m.sh "running m" | tr '\n' '|' | sed 's/|$//')" \
  "the notice comes first"
assert_equals "" "$(install_run absent.sh "running absent")" "and only when there is a script to run"
rc=0
install_run m.sh >/dev/null || rc=$?
assert_equals "0" "$rc" "a failed migration never fails the install"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
