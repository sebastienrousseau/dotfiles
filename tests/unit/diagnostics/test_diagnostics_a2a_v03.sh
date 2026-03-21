#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

A2A_CARD="$REPO_ROOT/.well-known/agent-card.json"
INTERNAL_CARD="$REPO_ROOT/dot_config/dotfiles/agent-card.json"
LEGACY_DOC="$REPO_ROOT/.well-known/agent.json"
CONFORMANCE_SCRIPT="$REPO_ROOT/scripts/diagnostics/a2a-conformance.sh"

test_start "a2a_v03_card_exists"
assert_file_exists "$A2A_CARD" "A2A v0.3 card should exist"

test_start "a2a_v03_card_valid_json"
if jq empty "$A2A_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid JSON"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid JSON"
fi

test_start "a2a_v03_spec_version"
sv="$(jq -r '.specVersion' "$A2A_CARD")"
assert_equals "0.3" "$sv" "specVersion should be 0.3"

test_start "a2a_v03_has_skills"
if jq -e '.skills | type == "array" and length > 0' "$A2A_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has skills array"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing skills array"
fi

test_start "a2a_v03_has_signing"
if jq -e '.signing.method' "$A2A_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has signing method"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing signing method"
fi

test_start "a2a_v03_has_authentication"
if jq -e '.authentication' "$A2A_CARD" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has authentication block"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing authentication block"
fi

test_start "a2a_v03_no_a2a_ready_in_card"
if jq -e '.protocols | index("a2a-ready")' "$A2A_CARD" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use 'a2a' not 'a2a-ready'"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no deprecated a2a-ready"
fi

test_start "a2a_v03_internal_card_spec_version"
isv="$(jq -r '.specVersion' "$INTERNAL_CARD")"
assert_equals "0.3" "$isv" "internal card specVersion should be 0.3"

test_start "a2a_v03_internal_card_no_a2a_ready"
if jq -e '.protocols | index("a2a-ready")' "$INTERNAL_CARD" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: internal card should use 'a2a' not 'a2a-ready'"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: internal card uses 'a2a'"
fi

test_start "a2a_v03_legacy_has_a2a_card_pointer"
if jq -e '.a2aCard' "$LEGACY_DOC" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: legacy doc has a2aCard pointer"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: legacy doc missing a2aCard"
fi

test_start "a2a_v03_conformance_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$CONFORMANCE_SCRIPT" --strict --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$(printf '%s' "$output" | jq -r '.status')" == "healthy" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: v0.3 conformance passes"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: v0.3 conformance should pass"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
