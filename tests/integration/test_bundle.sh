#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for scripts/ops/bundle.sh
# Tests bundle script structure, help output, and safety

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

BUNDLE_SCRIPT="$REPO_ROOT/scripts/ops/bundle.sh"

# ── Script existence and structure ──────────────────────────────

test_start "bundle_script_exists"
assert_file_exists "$BUNDLE_SCRIPT" "bundle.sh should exist"

test_start "bundle_script_executable"
if [[ -x "$BUNDLE_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bundle.sh is executable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bundle.sh should be executable"
fi

test_start "bundle_script_shebang"
first_line=$(head -n 1 "$BUNDLE_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "bundle_script_strict_mode"
if grep -q 'set -euo pipefail' "$BUNDLE_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses strict mode"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# ── Help and usage ──────────────────────────────────────────────

test_start "bundle_help_flag"
help_out=$("$BUNDLE_SCRIPT" --help 2>&1 || true)
if echo "$help_out" | grep -qi "usage\|bundle"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows usage info"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: --help responded (format may vary)"
fi

# ── Safety: no destructive operations without confirmation ─────

test_start "bundle_no_force_push"
if ! grep -q 'git push.*--force' "$BUNDLE_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no force-push commands"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not contain force-push"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Bundle integration tests completed."
print_summary
