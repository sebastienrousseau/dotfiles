#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for global standards synchronization in defaults/Code
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

STANDARD_FILES=(
  "AGENTS.md"
  "GEMINI.md"
  "PR-TEMPLATE.md"
  "README-TEMPLATE.md"
  "REPO-STANDARD.md"
)

for file in "${STANDARD_FILES[@]}"; do
  test_start "standards_${file//./_}_present"
  target="$REPO_ROOT/defaults/Code/$file"
  if [[ -f "$target" && -s "$target" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defaults/Code/$file exists and is non-empty"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: defaults/Code/$file is missing or empty"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
