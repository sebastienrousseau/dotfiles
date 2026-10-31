#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot system schedule list|set|run` and `dot system status`
# (plugins/system/libexec/system/schedule.sh): set writes and loads a launchd agent on macOS or a
# systemd user timer on Linux, off removes it, run does the maintenance and
# records its time and exit code. Fake launchctl, systemctl and dot record
# their calls; HOME is a temp dir, so no real agent is ever touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-system.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
for tool in launchctl systemctl dot; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\nexit "${FAIL_%s:-0}"\n' "$tool" "$WORK" "$tool" >"$WORK/bin/$tool"
  chmod +x "$WORK/bin/$tool"
done
UID_NOW="$(id -u)"
PLIST="$WORK/home/Library/LaunchAgents/com.sebastienrousseau.dot-maintenance.plist"
UNITS="$WORK/home/.config/systemd/user"
STATE="$WORK/home/.local/state/dot/system"

# sys OS ARGS...: the real `dot system` route on OS, with the fakes.
sys() {
  local os="$1"
  shift
  env -u XDG_STATE_HOME -u XDG_CONFIG_HOME HOME="$WORK/home" DOT_SYSTEM_OS="$os" \
    DOT_LAUNCHCTL="$WORK/bin/launchctl" DOT_SYSTEMCTL="${DOT_SYSTEMCTL:-$WORK/bin/systemctl}" \
    DOT_SYSTEM_DOT="$WORK/bin/dot" bash "$REPO_ROOT/bin/dot" system "$@"
}
calls() { paste -sd '|' "$WORK/calls"; }

test_start "macos_set_writes_and_loads_the_agent"
: >"$WORK/calls"
assert_equals "Maintenance: weekly (launchd)" "$(sys Darwin schedule set weekly)" "reports the schedule"
assert_equals "launchctl bootout gui/$UID_NOW/com.sebastienrousseau.dot-maintenance|launchctl bootstrap gui/$UID_NOW $PLIST" \
  "$(calls)" "replaces any loaded copy, then loads it"
assert_file_contains "$PLIST" "<string>$WORK/bin/dot</string>" "runs this dot"
assert_file_contains "$PLIST" "<key>Weekday</key><integer>0</integer><key>Hour</key><integer>10</integer>" "on Sundays at 10:00"
if command -v plutil >/dev/null 2>&1; then
  rc=0
  plutil -lint -s "$PLIST" >/dev/null 2>&1 || rc=$?
  assert_equals "0" "$rc" "a valid property list"
fi
assert_equals "weekly" "$(cat "$STATE/schedule")" "the schedule is recorded"
sys Darwin schedule set daily >/dev/null
assert_equals "0" "$(grep -c Weekday "$PLIST")" "daily has no weekday"

test_start "macos_list_and_off"
assert_contains "maintenance    daily    launchd  loaded" "$(sys Darwin schedule list)" "a loaded agent"
assert_contains "not loaded" "$(FAIL_launchctl=113 sys Darwin schedule)" "list is the default, and sees an unloaded one"
: >"$WORK/calls"
sys Darwin schedule set off >/dev/null
assert_equals "launchctl bootout gui/$UID_NOW/com.sebastienrousseau.dot-maintenance" "$(calls)" "off unloads it"
assert_file_not_exists "$PLIST" "and deletes it"
assert_equals "off" "$(cat "$STATE/schedule")" "and records off"

test_start "linux_set_writes_and_enables_the_timer"
: >"$WORK/calls"
assert_equals "Maintenance: daily (systemd)" "$(sys Linux schedule set daily)" "reports the schedule"
assert_equals "systemctl --user daemon-reload|systemctl --user enable --now dot-maintenance.timer" "$(calls)" \
  "reloads, then enables and starts the timer"
assert_file_contains "$UNITS/dot-maintenance.timer" "OnCalendar=daily" "the timer fires daily"
assert_file_contains "$UNITS/dot-maintenance.timer" "Persistent=true" "and catches up a missed run"
assert_file_contains "$UNITS/dot-maintenance.service" "ExecStart=$WORK/bin/dot system schedule run" "the service runs this dot"
assert_contains "systemd  loaded" "$(sys Linux schedule list)" "list asks systemd"
: >"$WORK/calls"
sys Linux schedule set off >/dev/null
assert_equals "systemctl --user disable --now dot-maintenance.timer|systemctl --user daemon-reload" "$(calls)" "off disables it"
assert_file_not_exists "$UNITS/dot-maintenance.timer" "and deletes the timer"
assert_file_not_exists "$UNITS/dot-maintenance.service" "and the service"

test_start "set_refuses_a_bad_word_or_no_scheduler"
rc=0
sys Darwin schedule set hourly 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "an unknown schedule"
assert_file_contains "$WORK/err" "Usage: dot system schedule set weekly|daily|off" "shows the words"
rc=0
sys FreeBSD schedule set weekly 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "no launchd or systemd"
assert_file_contains "$WORK/err" "scheduling needs launchd (macOS) or systemd (Linux)" "says what it needs"
rc=0
DOT_SYSTEMCTL=/nonexistent sys Linux schedule set weekly 2>/dev/null || rc=$?
assert_equals "1" "$rc" "Linux without systemd"
assert_contains "maintenance    off      none" "$(sys FreeBSD schedule list)" "list still works there"

test_start "run_does_the_maintenance_and_records_it"
mkdir -p "$WORK/home/.local/share"
head -c 1100000 /dev/zero >"$WORK/home/.local/share/dotfiles.log"
: >"$WORK/calls"
assert_equals "ok    shell caches|ok    log rotation" "$(sys Darwin schedule run | paste -sd '|' -)" "each step reports"
assert_equals "dot shell clean" "$(calls)" "clears the startup caches"
assert_file_exists "$WORK/home/.local/share/dotfiles.log.1.gz" "rotates a full log"
assert_contains ", exit 0" "$(sys Darwin status)" "status shows the run"
assert_contains "Schedule   off" "$(sys Darwin)" "status is the default, with the schedule"

test_start "run_keeps_going_and_records_a_failure"
rc=0
out="$(FAIL_dot=1 sys Linux schedule run)" || rc=$?
assert_equals "1" "$rc" "a failed step fails the run"
assert_contains "fail  shell caches (see $STATE/last-run.log)" "$out" "names the step and the log"
assert_contains "ok    log rotation" "$out" "the next step still runs"
assert_contains " 1" "$(cat "$STATE/last-run")" "the exit code is recorded"
assert_contains ", exit 1" "$(sys Linux status)" "and shown"

test_start "unknown_words_exit_2"
rc=0
sys Darwin schedule nope 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "an unknown schedule verb"
assert_file_contains "$WORK/err" "unknown 'dot system' command; see 'dot help system'" "points to help"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
