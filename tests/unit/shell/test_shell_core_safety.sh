#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for 05-core-safety.sh structure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMPL_FILE="$REPO_ROOT/dot_config/shell/05-core-safety.sh"

test_start "core_safety_exists"
assert_file_exists "$TMPL_FILE" "05-core-safety.sh should exist"

test_start "core_safety_not_empty"
if [[ -s "$TMPL_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: file is not empty"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: file should not be empty"
fi

test_start "core_safety_has_shebang_or_comment"
first_line=$(head -n 1 "$TMPL_FILE")
if [[ "$first_line" == "#!/"* ]] || [[ "$first_line" == "#"* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has header"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have shebang or comment header"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
