#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI fleet commands

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FLEET_FILE="$REPO_ROOT/scripts/dot/commands/fleet.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: fleet.sh file exists
test_start "fleet_cmd_file_exists"
assert_file_exists "$FLEET_FILE" "fleet.sh should exist"

# Test: fleet.sh is valid shell syntax
test_start "fleet_cmd_syntax_valid"
if bash -n "$FLEET_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: fleet.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: fleet.sh has syntax errors"
fi

# The subcommands run through `dot fleet` with a private state dir; each
# one is expected to answer and to append its structured event.
DOT_CLI="$REPO_ROOT/bin/dot"
FLEET_TMP="$DOTFILES_COV_TMPDIR/fleet"
export XDG_STATE_HOME="$FLEET_TMP/state"
EVENTS="$XDG_STATE_HOME/dotfiles/fleet/events.jsonl"
last_event() { tail -n 1 "$EVENTS" 2>/dev/null | jq -r .event 2>/dev/null; }

test_start "fleet_status_json_is_structured"
assert_equals "true" "$(bash "$DOT_CLI" fleet status --json 2>/dev/null | jq 'has("node_id") and has("namespace") and has("drift")' 2>/dev/null)" "status --json emits the node record"

test_start "fleet_status_emits_event"
bash "$DOT_CLI" fleet status >/dev/null 2>&1 || true
assert_equals "status" "$(last_event)" "status appends a status event"

test_start "fleet_drift_emits_event"
bash "$DOT_CLI" fleet drift >/dev/null 2>&1 || true
assert_equals "drift_check" "$(last_event)" "drift appends a drift_check event"

test_start "fleet_events_are_valid_jsonl"
assert_exit_code 0 "jq -e -s 'length >= 2 and all(has(\"time\") and has(\"node_id\") and has(\"trace_id\"))' '$EVENTS'"

test_start "fleet_events_lists_recorded_events"
assert_output_contains "drift_check" "XDG_STATE_HOME='$XDG_STATE_HOME' bash '$DOT_CLI' fleet events"

test_start "fleet_namespace_reports_active"
assert_output_contains "Active" "XDG_STATE_HOME='$XDG_STATE_HOME' bash '$DOT_CLI' fleet namespace"

# Test: no hardcoded paths
test_start "fleet_cmd_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$FLEET_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

echo ""
echo "Fleet commands tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$FLEET_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
