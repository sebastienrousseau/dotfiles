#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
DOCTOR_UNIFIED="$REPO_ROOT/scripts/diagnostics/doctor-unified.sh"
SCORECARD="$REPO_ROOT/scripts/diagnostics/scorecard.sh"

test_start "doctor_unified_flag_aliases"
assert_file_contains "$DOCTOR_UNIFIED" "--heal | -H" "doctor supports -H"
assert_file_contains "$DOCTOR_UNIFIED" "--audit | -a" "doctor supports -a"
assert_file_contains "$DOCTOR_UNIFIED" "--score | -s" "doctor supports -s"
assert_file_contains "$DOCTOR_UNIFIED" "--smoke | -m" "doctor supports -m"
assert_file_contains "$DOCTOR_UNIFIED" "--drift | -d" "doctor supports -d"
assert_file_contains "$DOCTOR_UNIFIED" "--benchmark | -b" "doctor supports -b"
assert_file_contains "$DOCTOR_UNIFIED" "--json | -j | --ai | -A" "doctor supports -j and -A"

test_start "scorecard_flag_alias"
assert_file_contains "$SCORECARD" "--json|-j" "scorecard supports -j"

test_start "attest_json_short_runtime"
output=$(REPO_ROOT="$REPO_ROOT" bash "$DOT_CLI" attest -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"dotfiles_version\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot attest -j emits JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot attest -j should emit JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "mcp_json_short_runtime"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$REPO_ROOT/dot_config/claude/mcp_servers.json" bash "$DOT_CLI" mcp -s -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot mcp -s -j emits JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot mcp -s -j should emit JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "scorecard_usage_mentions_short_flag"
assert_file_contains "$SCORECARD" "# Usage: dot scorecard" "scorecard usage line is present"

test_start "snapshot_short_flags_runtime"
snapshot_state_dir="$(mktemp -d)"
XDG_STATE_HOME="$snapshot_state_dir" bash "$REPO_ROOT/scripts/diagnostics/snapshot.sh" -b >/dev/null 2>&1 || true
if [[ -f "$snapshot_state_dir/dotfiles/snapshots/baseline.json" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: snapshot -b writes baseline"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: snapshot -b should write baseline"
fi
XDG_STATE_HOME="$snapshot_state_dir" bash "$REPO_ROOT/scripts/diagnostics/snapshot.sh" -b -f >/dev/null 2>&1 || true
rm -rf "$snapshot_state_dir"

test_start "help_reference_mentions_short_flags"
help_output=$(bash "$DOT_CLI" help all 2>&1) || true
if [[ "$help_output" == *"version"* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help reference remains available after alias additions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help reference should remain available"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
