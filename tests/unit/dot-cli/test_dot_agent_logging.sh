#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
STATE_ROOT="/tmp/dotfiles-agent-log-test-$$"
RUN_STATE_DIR="$STATE_ROOT/run"
REPLAY_STATE_DIR="$STATE_ROOT/replay"
rm -rf "$STATE_ROOT"
mkdir -p "$RUN_STATE_DIR" "$REPLAY_STATE_DIR"
trap 'rm -rf "$STATE_ROOT"' EXIT

test_start "agent_mode_run_logs_session"
assert_exit_code 0 "XDG_STATE_HOME='$RUN_STATE_DIR' bash '$DOT_CLI' mode run ask bash -lc 'exit 0'"

test_start "agent_log_outputs_jsonl"
output=$(XDG_STATE_HOME="$RUN_STATE_DIR" bash "$DOT_CLI" agent log 5 2>/dev/null) || true
if [[ "$output" == *"\"event\":\"log\""* ]] || [[ "$output" == *"\"event\":\"run_finish\""* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: agent log emits JSONL events"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected agent JSONL output"
  printf '%b\n' "    Output: $output"
fi

test_start "agent_checkpoint_list_outputs_entries"
output=$(XDG_STATE_HOME="$RUN_STATE_DIR" bash "$DOT_CLI" agent checkpoint list 5 2>/dev/null) || true
if [[ "$output" == *"Agent Checkpoints"* ]] || [[ "$output" == *"ready"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checkpoint list shows saved run state"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected checkpoint listing output"
  printf '%b\n' "    Output: $output"
fi

test_start "agent_checkpoint_replay_runs"
replay_file="$REPLAY_STATE_DIR/replayed.txt"
assert_exit_code 0 "XDG_STATE_HOME='$REPLAY_STATE_DIR' bash '$DOT_CLI' agent checkpoint save ask bash -lc 'printf replayed > \"$replay_file\"'"
checkpoint_id="$(find "$REPLAY_STATE_DIR/dotfiles/checkpoints" -type f -name '*.json' | xargs -r basename | sed 's/\.json$//')"
rm -f "$replay_file"
assert_exit_code 0 "XDG_STATE_HOME='$REPLAY_STATE_DIR' bash '$DOT_CLI' agent checkpoint replay \"$checkpoint_id\""
if [[ -f "$replay_file" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checkpoint replay re-runs the saved command"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected replayed command side effect"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
