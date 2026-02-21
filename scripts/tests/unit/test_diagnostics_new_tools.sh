#!/usr/bin/env bash
# Unit tests for new diagnostics tools
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SCRIPTS=(
  "$REPO_ROOT/scripts/diagnostics/scorecard.sh"
  "$REPO_ROOT/scripts/diagnostics/perf.sh"
  "$REPO_ROOT/scripts/diagnostics/conflicts.sh"
  "$REPO_ROOT/scripts/diagnostics/version-locks.sh"
  "$REPO_ROOT/scripts/diagnostics/snapshot.sh"
  "$REPO_ROOT/scripts/ops/setup.sh"
)

echo "Testing new diagnostics tools..."

for file in "${SCRIPTS[@]}"; do
  test_start "script_exists"
  assert_file_exists "$file" "script should exist"

  test_start "script_valid_syntax"
  if bash -n "$file" 2>/dev/null; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
  fi
done

echo ""
echo "New diagnostics tools tests completed."
print_summary
