#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for diagnostics/mcp-doctor.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

test_start "mcp_doctor_exists"
assert_file_exists "$SCRIPT_FILE" "mcp-doctor.sh should exist"

test_start "mcp_doctor_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "mcp_doctor_checks_json"
if grep -qE 'jq empty|mcpServers' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: validates JSON structure"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: JSON validation missing"
fi

test_start "mcp_doctor_checks_scope"
if grep -qE 'Filesystem scope|"/home"|"/Users"|"/"' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks broad filesystem scope"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: scope check missing"
fi

test_start "mcp_doctor_checks_policy"
if grep -qE 'Launcher policy|Arg policy|allowlisted' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks launcher/arg policy"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: launcher/arg policy checks missing"
fi

test_start "mcp_doctor_checks_tokens"
if grep -qE 'GITHUB_TOKEN|BRAVE_API_KEY|Token check' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks required token env vars"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: token checks missing"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
