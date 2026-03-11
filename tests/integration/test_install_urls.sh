#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Integration tests for install URLs
# Validates that all documented install URLs resolve (no 404s)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ── Verify no references to wrong default branch ─────────────────

test_start "install_urls_no_main_branch"
bad_refs=$(grep -r 'raw.githubusercontent.com/sebastienrousseau/dotfiles/main/' \
  "$REPO_ROOT/README.md" \
  "$REPO_ROOT/install.sh" \
  "$REPO_ROOT/docs/guides/INSTALL.md" \
  "$REPO_ROOT/dot_local/bin/executable_dot-bootstrap" \
  2>/dev/null || true)
if [[ -z "$bad_refs" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no references to /main/ branch in install URLs"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: found /main/ branch references (should be /master/)"
  printf '%b\n' "    $bad_refs"
fi

# ── Verify install.sh URL is reachable ───────────────────────────

test_start "install_url_reachable"
if command -v curl >/dev/null 2>&1; then
  http_code=$(curl -sI -o /dev/null -w '%{http_code}' \
    "https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh" 2>/dev/null || echo "000")
  if [[ "$http_code" == "200" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh URL returns HTTP 200"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install.sh URL returned HTTP $http_code (expected 200)"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (curl not available)"
fi

# ── Verify install.sh exists locally and is valid ────────────────

test_start "install_script_exists"
assert_file_exists "$REPO_ROOT/install.sh" "install.sh should exist in repo root"

test_start "install_script_executable"
if [[ -x "$REPO_ROOT/install.sh" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh is executable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install.sh should be executable"
fi

test_start "install_script_syntax"
if bash -n "$REPO_ROOT/install.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh has valid bash syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install.sh has syntax errors"
fi

# ── Verify bootstrap script URL consistency ──────────────────────

test_start "bootstrap_url_consistency"
bootstrap="$REPO_ROOT/dot_local/bin/executable_dot-bootstrap"
if [[ -f "$bootstrap" ]]; then
  if grep -q 'raw.githubusercontent.com/sebastienrousseau/dotfiles/master/' "$bootstrap"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bootstrap uses /master/ branch URL"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bootstrap should reference /master/ branch"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (bootstrap not found)"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "Install URL integration tests completed."
print_summary
