#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
STATE_DIR="/tmp/dotfiles-agent-log-test"
rm -rf "$STATE_DIR"

test_start "agent_mode_run_logs_session"
assert_exit_code 0 "XDG_STATE_HOME='$STATE_DIR' bash '$DOT_CLI' mode run ask bash -lc 'exit 0'"

test_start "agent_log_outputs_jsonl"
output=$(XDG_STATE_HOME="$STATE_DIR" bash "$DOT_CLI" agent log 5 2>/dev/null) || true
if [[ "$output" == *"\"event\":\"log\""* ]] || [[ "$output" == *"\"event\":\"run_finish\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: agent log emits JSONL events"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected agent JSONL output"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
