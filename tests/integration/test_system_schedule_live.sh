#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The scheduled maintenance job against the real scheduler: `dot system
# schedule set daily` installs it in launchd (macOS) or the systemd user
# manager (Linux), the scheduler itself runs it, the run exits 0, and
# `set off` removes it again. It changes the user's real agents, so it runs
# only with DOT_SCHEDULE_LIVE=1, on CI runners (cross-platform-test.yml).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

if [[ "${DOT_SCHEDULE_LIVE:-0}" != 1 ]]; then
  echo "  - skipped: set DOT_SCHEDULE_LIVE=1 to touch the real scheduler"
  echo "RESULTS:0:0:0"
  exit 0
fi

DOT="$REPO_ROOT/bin/dot"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dot/system"
LABEL="com.sebastienrousseau.dot-maintenance"
rm -f "$STATE/last-run"

# kick: have the scheduler start the job now, the way its timer would.
kick() {
  if [[ "$(uname -s)" == Darwin ]]; then
    launchctl kickstart "gui/$(id -u)/$LABEL"
  else
    systemctl --user start dot-maintenance.service
  fi
}

test_start "the_scheduler_runs_the_job"
rc=0
"$DOT" system schedule set daily || rc=$?
assert_equals "0" "$rc" "set daily installs the job"
assert_contains " loaded" "$("$DOT" system schedule list)" "the scheduler has it"
kick
for _ in $(seq 1 60); do
  [[ -s "$STATE/last-run" ]] && break
  sleep 2
done
assert_file_exists "$STATE/last-run" "the job ran"
assert_contains ", exit 0" "$("$DOT" system status)" "and exited 0"
sed 's/^/    /' "$STATE/last-run.log" 2>/dev/null || true

test_start "off_removes_the_job"
"$DOT" system schedule set off >/dev/null
assert_contains "not loaded" "$("$DOT" system schedule list)" "the scheduler no longer has it"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
