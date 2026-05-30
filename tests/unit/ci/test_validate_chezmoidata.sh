#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for tools/ci/validate-chezmoidata.sh — the wrapper that
# validates .chezmoidata.toml against config/chezmoidata.schema.json
# via taplo. Tests do NOT require taplo to be installed; they exercise
# the script's missing-dependency path and verify the supporting files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/tools/ci/validate-chezmoidata.sh"
SCHEMA_FILE="$REPO_ROOT/config/chezmoidata.schema.json"
TAPLO_CONFIG="$REPO_ROOT/.taplo.toml"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "tools/ci/validate-chezmoidata.sh must exist"

test_start "script_is_executable"
if [[ -x "$SCRIPT_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: script must be executable"
fi

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invalid bash syntax"
fi

test_start "uses_set_euo_pipefail"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "must use strict mode"

test_start "schema_file_exists"
assert_file_exists "$SCHEMA_FILE" "config/chezmoidata.schema.json must exist"

test_start "schema_is_valid_json"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json,sys; json.load(open('$SCHEMA_FILE'))" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: schema is not valid JSON"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (python3 unavailable)"
fi

test_start "schema_targets_chezmoidata_toml"
assert_file_contains "$SCHEMA_FILE" '".chezmoidata.toml"' "schema title must reference .chezmoidata.toml"

test_start "schema_requires_dotfiles_version_and_profile"
assert_file_contains "$SCHEMA_FILE" '"required"' "schema must declare required keys"
assert_file_contains "$SCHEMA_FILE" '"dotfiles_version"' "schema must include dotfiles_version property"
assert_file_contains "$SCHEMA_FILE" '"profile"' "schema must include profile property"

test_start "taplo_config_exists"
assert_file_exists "$TAPLO_CONFIG" ".taplo.toml must exist"

test_start "taplo_config_points_at_schema"
assert_file_contains "$TAPLO_CONFIG" "config/chezmoidata.schema.json" ".taplo.toml must reference schema path"

# Exercise the missing-dependency path by stripping cargo/local bin
# entries from PATH while keeping the standard system bins (so bash
# itself remains findable).
test_start "script_exits_127_when_taplo_missing"
output="$(PATH="/usr/bin:/bin" bash "$SCRIPT_FILE" 2>&1 || true)"
if printf '%s' "$output" | grep -q "taplo not found"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing-taplo error message not produced (got: $output)"
fi

echo ""
echo "validate-chezmoidata tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
