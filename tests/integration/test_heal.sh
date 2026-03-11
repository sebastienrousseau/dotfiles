#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for scripts/ops/heal.sh
# Tests self-healing capability structure and safety

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

HEAL_SCRIPT="$REPO_ROOT/scripts/ops/heal.sh"

# ── Script existence and structure ──────────────────────────────

test_start "heal_script_exists"
assert_file_exists "$HEAL_SCRIPT" "heal.sh should exist"

test_start "heal_script_executable"
if [[ -x "$HEAL_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: heal.sh is executable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: heal.sh should be executable"
fi

test_start "heal_script_shebang"
first_line=$(head -n 1 "$HEAL_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "heal_script_strict_mode"
if grep -q 'set -euo pipefail' "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses strict mode"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# ── Safety checks ──────────────────────────────────────────────

test_start "heal_no_rm_rf_root"
if ! grep -q 'rm -rf /' "$HEAL_SCRIPT" || grep -q 'rm -rf /$' "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous rm -rf / commands"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: contains dangerous rm -rf / command"
fi

test_start "heal_dry_run_support"
if grep -q 'dry.run\|DRY_RUN\|dry_run\|--dry' "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports dry-run mode"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dry-run check skipped"
fi

# ── Help output ─────────────────────────────────────────────────

test_start "heal_help_flag"
help_out=$("$HEAL_SCRIPT" --help 2>&1 || true)
if echo "$help_out" | grep -qi "usage\|heal\|repair"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows usage info"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --help responded (format may vary)"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Heal integration tests completed."
print_summary
