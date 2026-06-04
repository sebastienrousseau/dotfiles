#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
PROFILE_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"

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

AGENT_MODULE="$REPO_ROOT/scripts/dot/commands/agent.sh"

test_start "meta_mode_handler_exists"
assert_file_contains "$AGENT_MODULE" "cmd_mode()" "meta command module defines cmd_mode"
assert_file_contains "$AGENT_MODULE" "Usage: dot mode [list|current|show|set|run|doctor|card|log|checkpoint|conformance|a2a-card]" "mode usage is documented"

test_start "dot_mode_list_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' mode list"

test_start "dot_mode_show_runs"
assert_output_contains "Read-only guidance with no unattended changes." "bash '$DOT_CLI' mode show ask"

test_start "dot_agent_alias_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' agent list"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$META_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
