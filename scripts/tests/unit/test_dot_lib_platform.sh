#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot/lib/platform.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

PLATFORM_FILE="$REPO_ROOT/scripts/dot/lib/platform.sh"

test_start "platform_file_exists"
assert_file_exists "$PLATFORM_FILE" "platform.sh should exist"

test_start "platform_syntax_valid"
if bash -n "$PLATFORM_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: platform.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: platform.sh has syntax errors"
fi

test_start "platform_defines_functions"
if grep -qE 'dot_platform_id\(\)|dot_host_os\(\)|dot_path_to_native\(\)|dot_path_to_unix\(\)' "$PLATFORM_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: core platform helpers are defined"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: required helper functions missing"
fi

test_start "platform_returns_known_id"
platform_id="$(bash -lc "source '$PLATFORM_FILE'; dot_platform_id" 2>/dev/null || true)"
if [[ "$platform_id" == "macos" || "$platform_id" == "linux" || "$platform_id" == "wsl" || "$platform_id" == "unknown" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: returned '$platform_id'"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected value '$platform_id'"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
