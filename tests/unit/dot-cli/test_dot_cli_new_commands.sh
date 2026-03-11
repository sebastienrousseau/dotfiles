#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for restructured CLI commands (Waves 1-4)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

echo "Testing restructured CLI commands..."

# --- Existing commands still have case handlers (hidden aliases) ---

test_start "dot_cli_has_verify"
assert_file_contains "$DOT_CLI" "verify)" "dot CLI should handle verify command"

test_start "dot_cli_has_scorecard"
assert_file_contains "$DOT_CLI" "scorecard | score)" "dot CLI should handle scorecard/score command"

test_start "dot_cli_has_snapshot"
assert_file_contains "$DOT_CLI" "snapshot)" "dot CLI should handle snapshot command"

test_start "dot_cli_has_heal"
assert_file_contains "$DOT_CLI" "heal)" "dot CLI should handle heal command"

test_start "dot_cli_has_update_alias"
assert_file_contains "$DOT_CLI" "update)" "dot CLI should handle update as hidden alias"

# --- Wave 1: _require_platform defined ---

test_start "dot_cli_has_require_platform"
assert_file_contains "$DOT_CLI" "_require_platform()" "dot CLI should define _require_platform helper"

# --- Wave 2: doctor-unified.sh exists and has valid syntax ---

test_start "doctor_unified_exists"
DOCTOR_UNIFIED="$REPO_ROOT/scripts/diagnostics/doctor-unified.sh"
assert_file_exists "$DOCTOR_UNIFIED" "doctor-unified.sh should exist"

test_start "doctor_unified_syntax"
assert_exit_code 0 "bash -n '$DOCTOR_UNIFIED'"

test_start "dot_cli_doctor_dispatches_unified"
assert_file_contains "$DOT_CLI" "doctor-unified.sh" "doctor should dispatch to doctor-unified.sh"

# --- Wave 3: sync with flags + env command ---

test_start "dot_cli_has_sync"
assert_file_contains "$DOT_CLI" "sync | apply)" "dot CLI should handle sync command"

test_start "dot_cli_sync_pull_flag"
assert_file_contains "$DOT_CLI" "--pull" "sync should support --pull flag"

test_start "dot_cli_sync_check_flag"
assert_file_contains "$DOT_CLI" "--check" "sync should support --check flag"

test_start "dot_cli_has_env"
assert_file_contains "$DOT_CLI" 'env)' "dot CLI should handle env command"

# --- Wave 4: profile + keys sign-check ---

test_start "dot_cli_has_profile"
assert_file_contains "$DOT_CLI" "profile)" "dot CLI should handle profile command"

test_start "dot_cli_keys_sign_check"
assert_file_contains "$DOT_CLI" "sign-check" "keys should support sign-check subcommand"

# --- Platform guard: dot_require_platform in platform.sh ---

test_start "platform_sh_has_dot_require_platform"
PLATFORM_SH="$REPO_ROOT/scripts/dot/lib/platform.sh"
assert_file_contains "$PLATFORM_SH" "dot_require_platform()" "platform.sh should define dot_require_platform"

echo ""
echo "Restructured CLI command tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
