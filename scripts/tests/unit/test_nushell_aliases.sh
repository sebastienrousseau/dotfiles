#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TARGET="$REPO_ROOT/dot_config/nushell/aliases.nu.tmpl"

test_start "nushell_aliases_exists"
assert_file_exists "$TARGET" "aliases.nu.tmpl should exist"

test_start "nushell_aliases_not_empty"
if [[ -s "$TARGET" ]]; then
  ((TESTS_PASSED++)); printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)); printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: file is empty"
fi

test_start "nushell_aliases_is_template"
if grep -q '{{' "$TARGET" 2>/dev/null || grep -q 'source' "$TARGET" 2>/dev/null; then
  ((TESTS_PASSED++)); printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses template syntax or source"
else
  ((TESTS_FAILED++)); printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use template syntax"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
