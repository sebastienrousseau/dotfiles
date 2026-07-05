#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Integration tests for install URLs
# Validates that documented install URLs are internally consistent and
# reachable. Post default-branch rename from master → main, all URLs
# should use /main/. During the rename grace period, /master/ is kept
# alive by the mirror-main-to-master workflow, so either would resolve —
# but the source-of-truth is /main/.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../" && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# ── Every documented install URL must use /main/, not /master/ ─────

test_start "install_urls_use_main_branch"
stale_refs=$(grep -rn 'raw.githubusercontent.com/sebastienrousseau/dotfiles/master/' \
  "$REPO_ROOT/README.md" \
  "$REPO_ROOT/install.sh" \
  "$REPO_ROOT/docs/guides/INSTALL.md" \
  "$REPO_ROOT/bin/dot-bootstrap" \
  2>/dev/null || true)
if [[ -z "$stale_refs" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no /master/ references left in install URLs"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: found /master/ branch references (should be /main/)"
  printf '%b\n' "    $stale_refs"
fi

# ── Verify install.sh URL is reachable ───────────────────────────────
# The install URL on the current default branch must return HTTP 200.
# Accepts either /main/ (post-rename source of truth) or /master/
# (mirror kept alive during the grace period) so this test doesn't
# flake in either state.

test_start "install_url_reachable"
if command -v curl >/dev/null 2>&1; then
  main_code=$(curl -sI -o /dev/null -w '%{http_code}' \
    "https://raw.githubusercontent.com/sebastienrousseau/dotfiles/main/install.sh" 2>/dev/null || echo "000")
  master_code=$(curl -sI -o /dev/null -w '%{http_code}' \
    "https://raw.githubusercontent.com/sebastienrousseau/dotfiles/master/install.sh" 2>/dev/null || echo "000")
  if [[ "$main_code" == "200" || "$master_code" == "200" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh reachable (main=$main_code, master=$master_code)"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: neither /main/ nor /master/ install.sh returned 200 (main=$main_code, master=$master_code)"
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

# ── Bootstrap script must use /main/ ─────────────────────────────

test_start "bootstrap_url_consistency"
bootstrap="$REPO_ROOT/bin/dot-bootstrap"
if [[ -f "$bootstrap" ]]; then
  if grep -q 'raw.githubusercontent.com/sebastienrousseau/dotfiles/main/' "$bootstrap"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bootstrap uses /main/ branch URL"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bootstrap should reference /main/ branch"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (bootstrap not found)"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "Install URL integration tests completed."
print_summary
