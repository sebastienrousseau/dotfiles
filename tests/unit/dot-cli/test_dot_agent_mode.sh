#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"
PROFILE_FILE="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"

test_start "agent_profile_file_exists"
assert_file_exists "$PROFILE_FILE" "agent-profiles.json should exist"

test_start "agent_profiles_declared"
assert_file_contains "$PROFILE_FILE" "\"ask\"" "ask profile present"
assert_file_contains "$PROFILE_FILE" "\"plan\"" "plan profile present"
assert_file_contains "$PROFILE_FILE" "\"apply\"" "apply profile present"
assert_file_contains "$PROFILE_FILE" "\"audit\"" "audit profile present"

test_start "dot_cli_registers_mode_and_agent"
assert_file_contains "$DOT_CLI" "mode" "dot CLI lists mode command"
assert_file_contains "$DOT_CLI" "agent" "dot CLI lists agent command"

test_start "meta_mode_handler_exists"
assert_file_contains "$META_FILE" "cmd_mode()" "meta command module defines cmd_mode"
assert_file_contains "$META_FILE" "Usage: dot mode [list|current|show|set|run|doctor|card|log|checkpoint|conformance]" "mode usage is documented"

test_start "dot_mode_list_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' mode list"

test_start "dot_mode_show_runs"
assert_output_contains "Read-only guidance with no unattended changes." "bash '$DOT_CLI' mode show ask"

test_start "dot_agent_alias_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' agent list"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
