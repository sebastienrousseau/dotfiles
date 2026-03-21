#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SERVER_CARD="$REPO_ROOT/.well-known/mcp/server-card.json"
MCP_DOCTOR="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

test_start "mcp_server_card_exists"
assert_file_exists "$SERVER_CARD" "server-card.json should exist"

test_start "mcp_server_card_valid_json"
if jq empty "$SERVER_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid JSON"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid JSON"
fi

test_start "mcp_server_card_has_card_version"
if jq -e '.cardVersion' "$SERVER_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has cardVersion"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing cardVersion"
fi

test_start "mcp_server_card_has_name"
if jq -e '.name' "$SERVER_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has name"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing name"
fi

test_start "mcp_server_card_has_capabilities"
if jq -e '.capabilities' "$SERVER_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has capabilities"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing capabilities"
fi

test_start "mcp_server_card_has_transport"
if jq -e '.transport' "$SERVER_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has transport"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing transport"
fi

test_start "mcp_doctor_validates_server_card"
assert_file_contains "$MCP_DOCTOR" "Server Card (SEP-1649)" "mcp-doctor should validate server card"

test_start "agent_json_references_mcp_card"
assert_file_contains "$REPO_ROOT/.well-known/agent.json" "mcpCard" "agent.json should reference MCP card"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
