#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"
HEALTH_FILE="$REPO_ROOT/scripts/diagnostics/health.sh"
PERF_FILE="$REPO_ROOT/scripts/diagnostics/perf.sh"
SCORECARD_FILE="$REPO_ROOT/scripts/diagnostics/scorecard.sh"
SECURITY_SCORE_FILE="$REPO_ROOT/scripts/diagnostics/security-score.sh"
MCP_FILE="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"
ATTEST_FILE="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"
BENCHMARK_FILE="$REPO_ROOT/scripts/diagnostics/benchmark.sh"
SNAPSHOT_FILE="$REPO_ROOT/scripts/diagnostics/snapshot.sh"
VERIFY_FILE="$REPO_ROOT/scripts/diagnostics/verify.sh"
AI_FILE="$REPO_ROOT/scripts/dot/commands/ai.sh"

test_start "header_helpers_available"
assert_file_contains "$REPO_ROOT/scripts/dot/lib/ui.sh" "ui_product_banner()" "ui library exposes a product banner helper"
assert_file_contains "$REPO_ROOT/scripts/dot/lib/ui.sh" "ui_dot_banner()" "ui library exposes a dot banner helper"

test_start "diagnostics_scripts_use_shared_banner"
assert_file_contains "$HEALTH_FILE" 'ui_dot_banner "Diagnostics"' "health uses the shared diagnostics banner"
assert_file_contains "$PERF_FILE" 'ui_dot_banner "Diagnostics"' "perf uses the shared diagnostics banner"
assert_file_contains "$SCORECARD_FILE" 'ui_dot_banner "Diagnostics"' "scorecard uses the shared diagnostics banner"
assert_file_contains "$SECURITY_SCORE_FILE" 'ui_dot_banner "Diagnostics"' "security-score uses the shared diagnostics banner"
assert_file_contains "$ATTEST_FILE" 'ui_dot_banner "Diagnostics"' "attestation uses the shared diagnostics banner"
assert_file_contains "$BENCHMARK_FILE" 'ui_dot_banner "Diagnostics"' "benchmark uses the shared diagnostics banner"
assert_file_contains "$SNAPSHOT_FILE" 'ui_dot_banner "Diagnostics"' "snapshot uses the shared diagnostics banner"
assert_file_contains "$VERIFY_FILE" 'ui_dot_banner "Diagnostics"' "verify uses the shared diagnostics banner"
assert_file_contains "$MCP_FILE" 'ui_dot_banner "AI and Agents"' "mcp-doctor uses the shared AI banner"

test_start "command_modules_use_shared_banner"
assert_file_contains "$AI_FILE" 'dot_ui_command_banner "AI and Agents"' "ai command module uses the shared banner"
assert_file_contains "$DOT_CLI" 'ui_dot_banner "Reference"' "top-level reference views use the shared banner"

test_start "health_runtime_banner"
health_output=$(XDG_STATE_HOME=/tmp bash "$DOT_CLI" health 2>/dev/null || true)
if [[ "$health_output" == *"DOTFILES"* ]] && [[ "$health_output" == *"Dot • Diagnostics"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot health prints the standard banner"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot health should print the standard banner"
  printf '%b\n' "    Output: ${health_output:0:200}"
fi

test_start "mcp_runtime_banner"
mcp_output=$(XDG_STATE_HOME=/tmp bash "$DOT_CLI" mcp 2>/dev/null || true)
if [[ "$mcp_output" == *"DOTFILES"* ]] && [[ "$mcp_output" == *"Dot • AI and Agents"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot mcp prints the standard banner"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot mcp should print the standard banner"
  printf '%b\n' "    Output: ${mcp_output:0:200}"
fi

test_start "version_runtime_banner"
version_output=$(XDG_STATE_HOME=/tmp bash "$DOT_CLI" version 2>/dev/null || true)
if [[ "$version_output" == *"DOTFILES"* ]] && [[ "$version_output" == *"Dot • Reference"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot version prints the standard banner"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot version should print the standard banner"
  printf '%b\n' "    Output: ${version_output:0:200}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
