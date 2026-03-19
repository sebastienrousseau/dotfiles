#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"
MCP_CONFIG_FILE="$REPO_ROOT/dot_config/claude/mcp_servers.json"
MCP_POLICY_FILE="$REPO_ROOT/dot_config/dotfiles/mcp-policy.json"
MCP_LOCK_FILE="$REPO_ROOT/dot_config/dotfiles/mcp-lock.json"
MCP_REGISTRY_FILE="$REPO_ROOT/dot_config/dotfiles/mcp-registry.json"
META_COMMANDS_SCRIPT="$REPO_ROOT/scripts/dot/commands/meta.sh"

test_start "mcp_doctor_exists"
assert_file_exists "$TEST_SCRIPT" "mcp-doctor.sh should exist"

test_start "mcp_doctor_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "mcp_doctor_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "mcp_meta_accepts_flag_form"
assert_file_contains "$META_COMMANDS_SCRIPT" "[[ \"\${1:-}\" == --* ]]" "dot mcp accepts flag-only form"

test_start "mcp_policy_exists"
assert_file_exists "$MCP_POLICY_FILE" "mcp-policy.json should exist"

test_start "mcp_lock_exists"
assert_file_exists "$MCP_LOCK_FILE" "mcp-lock.json should exist"

test_start "mcp_registry_exists"
assert_file_exists "$MCP_REGISTRY_FILE" "mcp-registry.json should exist"

test_start "mcp_config_local_only_defaults"
for server in filesystem github brave-search fetch puppeteer; do
  if grep -q "\"$server\"" "$MCP_CONFIG_FILE"; then
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: default MCP config should exclude $server"
  else
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: default MCP config excludes $server"
  fi
done

test_start "mcp_config_uses_pinned_package_refs"
for package_ref in "mcp-server-git@2025.1.14" "@modelcontextprotocol/server-memory@2025.8.4" "mcp-server-sqlite@2025.1.14"; do
  if grep -q "$package_ref" "$MCP_CONFIG_FILE"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: pinned ref present for $package_ref"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing pinned ref $package_ref"
  fi
done

test_start "mcp_doctor_json_output"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]] && [[ "$output" == *"\"policy_path\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits JSON summary"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should emit JSON summary"
  printf '%b\n' "    Output: $output"
fi

test_start "mcp_doctor_short_flags_supported"
assert_file_contains "$TEST_SCRIPT" "--strict | -s" "mcp-doctor supports -s"
assert_file_contains "$TEST_SCRIPT" "--json | -j" "mcp-doctor supports -j"

test_start "mcp_doctor_short_flag_json_output"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" -s -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -s -j emits JSON summary"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -s -j should emit JSON summary"
  printf '%b\n' "    Output: $output"
fi

test_start "mcp_policy_requires_registry_controls"
assert_file_contains "$MCP_POLICY_FILE" "\"requireRegistryEntry\": true" "policy requires tracked registry entries"
assert_file_contains "$MCP_POLICY_FILE" "\"requireHttpsForHttpTransports\": true" "policy requires HTTPS for HTTP transports"
assert_file_contains "$MCP_POLICY_FILE" "\"requireOauthForHttpTransports\": true" "policy requires OAuth for HTTP transports"

test_start "mcp_meta_registry_subcommand"
assert_file_contains "$META_COMMANDS_SCRIPT" "registry)" "dot mcp supports registry subcommand"
assert_file_contains "$META_COMMANDS_SCRIPT" "Usage: dot mcp [doctor|registry]" "dot mcp usage includes registry"

test_start "mcp_doctor_strict_local_passes"
if REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" --strict >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: strict-local baseline passes"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: strict-local baseline should pass"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
