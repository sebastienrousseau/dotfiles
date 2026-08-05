#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_corralctl-sync.sh"

test_start "corralctl_sync_script_exists"
assert_file_exists "$SCRIPT_FILE" "scheduled corralctl sync wrapper must exist"

test_start "corralctl_sync_script_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

test_start "corralctl_sync_targets_owner"
assert_file_contains "$SCRIPT_FILE" 'OWNER="sebastienrousseau"' "wrapper must target the configured GitHub owner"

test_start "corralctl_sync_limits_concurrency"
assert_file_contains "$SCRIPT_FILE" "corralctl \"\$OWNER\" -c 8" "wrapper must bound repository concurrency"

test_start "corralctl_sync_writes_user_log"
assert_file_contains "$SCRIPT_FILE" 'Library/Logs/corralctl.log' "wrapper must write a stable user log"

test_start "corralctl_sync_notifies_failures"
assert_file_contains "$SCRIPT_FILE" 'display notification' "wrapper must notify on synchronization failures"

test_start "corralctl_sync_rotates_log"
assert_file_contains "$SCRIPT_FILE" 'tail -n 2000' "wrapper must cap its log size"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
