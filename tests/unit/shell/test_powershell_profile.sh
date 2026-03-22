#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PROFILE_FILE="$REPO_ROOT/dot_config/powershell/Microsoft.PowerShell_profile.ps1.tmpl"
SUPPORT_FILE="$REPO_ROOT/docs/reference/SUPPORT_MATRIX.md"

test_start "powershell_profile_exists"
assert_file_exists "$PROFILE_FILE" "PowerShell profile should exist"

test_start "powershell_profile_sets_dot_wrapper"
assert_file_contains "$PROFILE_FILE" "function dot" "PowerShell profile defines dot wrapper"
assert_file_contains "$PROFILE_FILE" "function d" "PowerShell profile defines d wrapper"
assert_file_contains "$PROFILE_FILE" "Invoke-DotfilesCli" "PowerShell profile defines shared dot launcher"

test_start "powershell_profile_modern_helpers"
assert_file_contains "$PROFILE_FILE" "function ll" "PowerShell profile defines ll"
assert_file_contains "$PROFILE_FILE" "function la" "PowerShell profile defines la"
assert_file_contains "$PROFILE_FILE" "function cat" "PowerShell profile defines cat"

test_start "support_matrix_mentions_powershell"
assert_file_contains "$SUPPORT_FILE" "| PowerShell | 7.5+ | Supported |" "support matrix documents PowerShell"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
