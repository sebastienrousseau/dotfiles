#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/tools/log-rotate.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "script should exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# The maintenance job's rotation step prunes the log.v1 logs to the
# retention window, even when the installer log it also rotates is absent.
test_start "rotation_prunes_the_log_v1_logs"
rot_state="$(mktemp -d "${TMPDIR:-/tmp}/log-rotate.XXXXXX")"
mkdir -p "$rot_state/dot/theme"
printf '%s\n' '{"schema":"cli/log.v1","time":"2020-01-01T00:00:00Z","event":"old"}' \
  "{\"schema\":\"cli/log.v1\",\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"new\"}" \
  >"$rot_state/dot/theme/log.jsonl"
rot_rc=0
HOME="$rot_state/home" XDG_STATE_HOME="$rot_state" bash "$SCRIPT_FILE" || rot_rc=$?
assert_equals "0|0|1" "$rot_rc|$(grep -c '"old"' "$rot_state/dot/theme/log.jsonl")|$(grep -c '"new"' "$rot_state/dot/theme/log.jsonl")" \
  "a record older than 30 days goes, today's stays, with no installer log"
rm -rf "$rot_state"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
