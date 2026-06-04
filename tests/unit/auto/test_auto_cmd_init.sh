#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/init.sh
# (the `dot init <github-user>` bootstrap). Covers existence, syntax,
# the URL-resolution helper across all five input shapes, and the
# safety guard (refuses plain HTTP, refuses invalid usernames).
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/init.sh"
DOT_BIN="$REPO_ROOT/bin/dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/init.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "dot_init_help"
if bash "$DOT_BIN" init --help >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Dry-run hits the URL resolver + ui_info path without touching disk.
# Bare user (alice), owner/repo (alice/cfg), full HTTPS, SSH form
# all exercise different case arms in _init_resolve_url.
for arg in "alice" "alice/cfg" "https://example.com/repo.git" "git@github.com:alice/cfg.git"; do
  test_start "dot_init_dry_run_$(echo "$arg" | tr -dc 'a-z0-9' | cut -c1-12)"
  if bash "$DOT_BIN" init "$arg" --dry-run >/dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  fi
done

# Negative cases — these exercise the safety-rejection branches.
test_start "dot_init_rejects_http"
if bash "$DOT_BIN" init "http://example.com/repo.git" --dry-run >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused plain HTTP"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "dot_init_rejects_shell_metachars"
if bash "$DOT_BIN" init "alice; rm -rf /" --dry-run >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused metacharacters"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "dot_init_rejects_missing_arg"
if bash "$DOT_BIN" init --dry-run >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused missing arg"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
