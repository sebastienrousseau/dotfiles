#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SERVER_CARD="$REPO_ROOT/.well-known/mcp/server-card.json"
MCP_DOCTOR="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

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

# The card is a promise a client acts on: the transport it names must be the
# command that actually starts the MCP server, and the module it names must
# exist. The full tool/resource/capability equivalence is asserted by the Go
# side (TestServerCardMatchesRegistry) which can enumerate the live registry.
test_start "mcp_server_card_transport_starts_the_server"
if [[ "$(jq -r '.transport.stdio.command + " " + (.transport.stdio.args | join(" "))' "$SERVER_CARD")" == "dot mcp serve" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}\u2713${NC} $CURRENT_TEST: transport is 'dot mcp serve'"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}\u2717${NC} $CURRENT_TEST: transport does not start the MCP server"
fi

test_start "mcp_server_card_names_its_implementation"
CARD_MODULE="$(jq -r '.implementation.module // empty' "$SERVER_CARD")"
assert_file_exists "$REPO_ROOT/$CARD_MODULE/go.mod" "card implementation.module should be a Go module"

test_start "mcp_serve_subcommand_exists"
assert_file_contains "$REPO_ROOT/scripts/dot/commands/meta.sh" "cmd_mcp_serve" "dot mcp serve should be implemented"

test_start "mcp_server_card_declares_no_prompts"
if [[ "$(jq -r '.capabilities.prompts' "$SERVER_CARD")" == "false" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}\u2713${NC} $CURRENT_TEST: prompts capability is false"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}\u2717${NC} $CURRENT_TEST: prompts is declared but no prompts/* handler exists"
fi

test_start "mcp_doctor_validates_server_card"
assert_file_contains "$MCP_DOCTOR" "Server Card (SEP-1649)" "mcp-doctor should validate server card"

test_start "agent_json_references_mcp_card"
assert_file_contains "$REPO_ROOT/.well-known/agent.json" "mcpCard" "agent.json should reference MCP card"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$MCP_DOCTOR"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
