#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016 # the fakes are written with literal $*
# `dot ai watch service on|off|status` (plugins/ai/libexec/ai/watch-service.sh):
# on writes and loads a launchd agent on macOS or a systemd user service on
# Linux that keeps `dot-ai-tui watch` running, off unloads and deletes it,
# status says whether it is loaded. Fake launchctl, systemctl and dot-ai-tui
# record their calls; HOME is a temp dir, so no real agent is ever touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-watch.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
for tool in launchctl systemctl dot-ai-tui; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\nexit "${FAIL_%s:-0}"\n' "$tool" "$WORK" "${tool//-/_}" >"$WORK/bin/$tool"
  chmod +x "$WORK/bin/$tool"
done
UID_NOW="$(id -u)"
LABEL="com.sebastienrousseau.dot-ai-watch"
PLIST="$WORK/home/Library/LaunchAgents/$LABEL.plist"
UNIT="$WORK/home/.config/systemd/user/dot-ai-watch.service"

# watch OS ARGS...: the real `dot ai watch` route on OS, with the fakes on
# PATH ahead of the system's ($WATCH_PATH replaces it).
watch() {
  local os="$1"
  shift
  env -u XDG_STATE_HOME -u XDG_CONFIG_HOME -u XDG_RUNTIME_DIR HOME="$WORK/home" PATH="${WATCH_PATH:-$WORK/bin:$PATH}" \
    TMPDIR="$WORK/tmp/" DOT_SYSTEM_OS="$os" DOT_LAUNCHCTL="$WORK/bin/launchctl" \
    DOT_SYSTEMCTL="${DOT_SYSTEMCTL:-$WORK/bin/systemctl}" bash "$REPO_ROOT/bin/dot" ai watch "$@"
}
calls() { paste -sd '|' "$WORK/calls"; }

test_start "macos_on_writes_and_loads_the_agent"
: >"$WORK/calls"
assert_equals "dot ai watch: on (launchd)" "$(watch Darwin service on)" "reports it"
assert_equals "launchctl bootout gui/$UID_NOW/$LABEL|launchctl bootstrap gui/$UID_NOW $PLIST" \
  "$(calls)" "replaces any loaded copy, then loads it"
plist="$(cat "$PLIST" 2>/dev/null)"
assert_contains "<string>$WORK/bin/dot-ai-tui</string>" "$plist" "runs this cockpit binary"
assert_contains "<string>watch</string>" "$plist" "as the watcher"
assert_contains "<key>RunAtLoad</key>" "$plist" "from login"
assert_contains "<key>SuccessfulExit</key>" "$plist" "restarted when it fails"
assert_contains "<key>TMPDIR</key>" "$plist" "with the TMPDIR the hook looks in for the socket"
assert_contains "<string>$WORK/tmp/</string>" "$plist" "this shell's TMPDIR"
assert_contains "$WORK/home/.local/state/dot/ai/watch.log" "$plist" "logging under the ai state dir"
if command -v plutil >/dev/null 2>&1; then
  rc=0
  plutil -lint -s "$PLIST" >/dev/null 2>&1 || rc=$?
  assert_equals "0" "$rc" "a valid property list"
fi

test_start "macos_status_and_off"
assert_equals "dot ai watch: loaded (launchd)" "$(watch Darwin service status)" "a loaded agent"
assert_equals "dot ai watch: not loaded (launchd)" "$(FAIL_launchctl=113 watch Darwin service)" \
  "status is the default, and sees an unloaded one"
: >"$WORK/calls"
assert_equals "dot ai watch: off (launchd)" "$(watch Darwin service off)" "reports it"
assert_equals "launchctl bootout gui/$UID_NOW/$LABEL" "$(calls)" "off unloads it"
assert_file_not_exists "$PLIST" "and deletes it"

test_start "linux_on_writes_and_starts_the_service"
: >"$WORK/calls"
assert_equals "dot ai watch: on (systemd)" "$(watch Linux service on)" "reports it"
assert_equals "systemctl --user daemon-reload|systemctl --user enable --now dot-ai-watch.service" "$(calls)" \
  "reloads, then enables and starts it"
unit="$(cat "$UNIT" 2>/dev/null)"
assert_contains "ExecStart=$WORK/bin/dot-ai-tui watch" "$unit" "runs this cockpit binary"
assert_contains "Restart=on-failure" "$unit" "restarted when it fails"
assert_contains "WantedBy=default.target" "$unit" "from login"
assert_equals "dot ai watch: loaded (systemd)" "$(watch Linux service status)" "status asks systemd"
: >"$WORK/calls"
watch Linux service off >/dev/null
assert_equals "systemctl --user disable --now dot-ai-watch.service|systemctl --user daemon-reload" "$(calls)" \
  "off disables, then reloads"
assert_file_not_exists "$UNIT" "and deletes the unit"

test_start "service_refuses_a_bad_word_no_manager_or_no_binary"
rc=0
watch Darwin service sometimes >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "a bad word fails"
assert_contains "dot ai watch service on|off|status" "$(cat "$WORK/err")" "and gives the usage"
rc=0
watch FreeBSD service on >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "no launchd or systemd fails"
assert_contains "launchd (macOS) or systemd (Linux)" "$(cat "$WORK/err")" "and says what it needs"
rc=0
DOT_SYSTEMCTL="$WORK/none" watch Linux service on >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "Linux without systemctl fails"
mv "$WORK/bin/dot-ai-tui" "$WORK/dot-ai-tui"
rc=0
WATCH_PATH="$WORK/bin:/usr/bin:/bin" watch Darwin service on >/dev/null 2>"$WORK/err" || rc=$?
assert_equals "1" "$rc" "no cockpit binary fails"
assert_contains "DOTFILES_AI=1" "$(cat "$WORK/err")" "and says how to build it"
assert_file_not_exists "$PLIST" "and writes no agent"
mv "$WORK/dot-ai-tui" "$WORK/bin/dot-ai-tui"

test_start "watch_without_service_still_runs_the_watcher"
: >"$WORK/calls"
watch Darwin >/dev/null
assert_equals "dot-ai-tui watch" "$(calls)" "dot ai watch runs dot-ai-tui watch"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
