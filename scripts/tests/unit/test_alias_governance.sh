#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for alias governance checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

GOVERNANCE_SCRIPT="$REPO_ROOT/scripts/diagnostics/alias-governance.sh"
MANIFEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/aliases-manifest.sh"
CD_INIT_FILE="$REPO_ROOT/.chezmoitemplates/aliases/cd/cd-init.aliases.sh"

test_start "alias_governance_script_exists"
assert_file_exists "$GOVERNANCE_SCRIPT" "alias governance script should exist"

test_start "alias_manifest_script_exists"
assert_file_exists "$MANIFEST_SCRIPT" "alias manifest script should exist"

test_start "alias_governance_syntax"
if bash -n "$GOVERNANCE_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "alias_manifest_syntax"
if bash -n "$MANIFEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "cd_override_is_opt_in"
assert_file_contains "$CD_INIT_FILE" "DOTFILES_ENABLE_CD_ALIAS" "cd override should be opt-in"

test_start "governance_supports_policy_tiers"
assert_file_contains "$GOVERNANCE_SCRIPT" "DOTFILES_ALIAS_POLICY" "governance should support policy tiers"
assert_file_contains "$GOVERNANCE_SCRIPT" "Policy:" "governance should print active policy"

test_start "governance_enforces_deprecations"
assert_file_contains "$GOVERNANCE_SCRIPT" "alias-deprecations.tsv" "governance should check deprecated aliases"
assert_file_contains "$GOVERNANCE_SCRIPT" "expired deprecated aliases" "governance should fail when deprecated aliases are overdue"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
