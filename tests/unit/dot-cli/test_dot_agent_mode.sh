#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

for profile in ask plan apply audit; do
  test_start "agent_profile_${profile}_resolves"
  assert_output_contains "Profile                             $profile" "bash '$DOT_CLI' mode show $profile"
done

test_start "unknown_profile_rejected"
assert_exit_code 1 "bash '$DOT_CLI' mode show no-such-profile"

test_start "unknown_mode_subcommand_prints_usage"
assert_output_contains "Usage: dot mode [list|current|show|set|run|doctor|card|log|checkpoint|conformance|a2a-card]" "bash '$DOT_CLI' mode bogus 2>&1 || true"

test_start "unknown_mode_subcommand_fails"
assert_exit_code 1 "bash '$DOT_CLI' mode bogus"

test_start "dot_mode_list_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' mode list"

test_start "dot_mode_show_runs"
assert_output_contains "Read-only guidance with no unattended changes." "bash '$DOT_CLI' mode show ask"

test_start "dot_agent_alias_runs"
assert_output_contains "Agent Modes" "bash '$DOT_CLI' agent list"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$META_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
