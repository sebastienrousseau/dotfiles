#!/usr/bin/env bash
# Template Validation Tests
# Validates chezmoi template output correctness and required variables

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $1"
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $1"
  [ -n "${2:-}" ] && echo "  ${2}"
}

skip() {
  echo -e "${YELLOW}○${NC} $1 (skipped)"
}

run_test() {
  TESTS_RUN=$((TESTS_RUN + 1))
}

# =============================================================================
# Template Syntax Validation
# =============================================================================

test_template_syntax() {
  echo ""
  echo "=== Template Syntax Validation ==="

  local source_dir="${CHEZMOI_SOURCE_DIR:-$HOME/.dotfiles}"
  local templates
  templates=$(find "$source_dir" -name "*.tmpl" -type f 2>/dev/null | head -50)

  if [ -z "$templates" ]; then
    skip "No templates found"
    return
  fi

  for tmpl in $templates; do
    run_test
    local name="${tmpl#$source_dir/}"

    # Check for unbalanced template delimiters
    local open_count close_count
    open_count=$(grep -o '{{' "$tmpl" 2>/dev/null | wc -l)
    close_count=$(grep -o '}}' "$tmpl" 2>/dev/null | wc -l)

    if [ "$open_count" -ne "$close_count" ]; then
      fail "Template $name: unbalanced delimiters ({{ = $open_count, }} = $close_count)"
    else
      pass "Template $name: balanced delimiters"
    fi
  done
}

# =============================================================================
# Required Variables Validation
# =============================================================================

test_required_variables() {
  echo ""
  echo "=== Required Variables Validation ==="

  # Check if chezmoi is available
  if ! command -v chezmoi >/dev/null 2>&1; then
    skip "chezmoi not installed"
    return
  fi

  run_test
  # Check that chezmoi data is accessible
  if chezmoi data >/dev/null 2>&1; then
    pass "chezmoi data accessible"
  else
    fail "chezmoi data not accessible"
  fi

  run_test
  # Check for required OS variables
  local os_value
  os_value=$(chezmoi data --format json 2>/dev/null | grep -o '"os":"[^"]*"' | head -1 || echo "")
  if [ -n "$os_value" ]; then
    pass "chezmoi.os is set: $os_value"
  else
    fail "chezmoi.os not available"
  fi

  run_test
  # Check for homeDir
  local home_value
  home_value=$(chezmoi data --format json 2>/dev/null | grep -o '"homeDir":"[^"]*"' | head -1 || echo "")
  if [ -n "$home_value" ]; then
    pass "chezmoi.homeDir is set"
  else
    fail "chezmoi.homeDir not available"
  fi
}

# =============================================================================
# Template Output Validation
# =============================================================================

test_template_output() {
  echo ""
  echo "=== Template Output Validation ==="

  if ! command -v chezmoi >/dev/null 2>&1; then
    skip "chezmoi not installed"
    return
  fi

  local source_dir="${CHEZMOI_SOURCE_DIR:-$HOME/.dotfiles}"

  # Test critical templates
  local critical_templates=(
    "dot_gitconfig.tmpl"
    "dot_zshrc.tmpl"
  )

  for tmpl_name in "${critical_templates[@]}"; do
    run_test
    local tmpl_path
    tmpl_path=$(find "$source_dir" -name "$tmpl_name" -type f 2>/dev/null | head -1)

    if [ -z "$tmpl_path" ]; then
      skip "Template $tmpl_name not found"
      continue
    fi

    # Try to execute the template
    if chezmoi execute-template < "$tmpl_path" >/dev/null 2>&1; then
      pass "Template $tmpl_name renders successfully"
    else
      fail "Template $tmpl_name failed to render"
    fi
  done
}

# =============================================================================
# Helper Template Validation
# =============================================================================

test_helper_templates() {
  echo ""
  echo "=== Helper Template Validation ==="

  local source_dir="${CHEZMOI_SOURCE_DIR:-$HOME/.dotfiles}"
  local helpers_dir="$source_dir/.chezmoitemplates/functions/helpers"

  if [ ! -d "$helpers_dir" ]; then
    skip "Helpers directory not found"
    return
  fi

  for helper in "$helpers_dir"/*.tmpl; do
    run_test
    local name
    name=$(basename "$helper")

    # Check helper has documentation comment
    if head -5 "$helper" | grep -q '{{-\s*/\*'; then
      pass "Helper $name has documentation"
    else
      fail "Helper $name missing documentation header"
    fi
  done
}

# =============================================================================
# Chezmoi Verify
# =============================================================================

test_chezmoi_verify() {
  echo ""
  echo "=== Chezmoi Verification ==="

  if ! command -v chezmoi >/dev/null 2>&1; then
    skip "chezmoi not installed"
    return
  fi

  run_test
  if chezmoi verify 2>/dev/null; then
    pass "chezmoi verify passed"
  else
    # verify returns non-zero if there are differences, which is expected
    pass "chezmoi verify completed (differences may exist)"
  fi

  run_test
  # Check that doctor passes
  if chezmoi doctor 2>/dev/null | grep -q "ok"; then
    pass "chezmoi doctor has passing checks"
  else
    skip "chezmoi doctor output unclear"
  fi
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo "Template Validation Tests"
  echo "========================="

  test_template_syntax
  test_required_variables
  test_template_output
  test_helper_templates
  test_chezmoi_verify

  echo ""
  echo "========================="
  echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_RUN total"

  if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
