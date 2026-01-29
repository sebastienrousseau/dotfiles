#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: dot_zshenv PATH entries
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ZSHENV="$REPO_ROOT/dot_zshenv"

echo "Testing Wave 1: dot_zshenv PATH entries..."

test_start "zshenv_exists"
assert_file_exists "$ZSHENV" "dot_zshenv should exist"

test_start "zshenv_xdg_config"
assert_file_contains "$ZSHENV" 'XDG_CONFIG_HOME' "should set XDG_CONFIG_HOME"

test_start "zshenv_xdg_cache"
assert_file_contains "$ZSHENV" 'XDG_CACHE_HOME' "should set XDG_CACHE_HOME"

test_start "zshenv_xdg_data"
assert_file_contains "$ZSHENV" 'XDG_DATA_HOME' "should set XDG_DATA_HOME"

test_start "zshenv_xdg_state"
assert_file_contains "$ZSHENV" 'XDG_STATE_HOME' "should set XDG_STATE_HOME"

test_start "zshenv_local_bin_path"
assert_file_contains "$ZSHENV" '.local/bin' "should add ~/.local/bin to PATH"

test_start "zshenv_local_bin_guard"
# Should use idempotent guard (check before adding)
if grep -qF 'PATH' "$ZSHENV" && grep -qF '.local/bin' "$ZSHENV"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: ~/.local/bin has PATH guard"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use idempotent guard for ~/.local/bin"
fi

test_start "zshenv_local_bin_dir_check"
# grep -qF interprets -d as a flag, so use -- separator
if grep -qF -- '-d "${HOME}/.local/bin"' "$ZSHENV"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks ~/.local/bin directory exists"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check ~/.local/bin directory exists"
fi

test_start "zshenv_homebrew_path"
assert_file_contains "$ZSHENV" '/opt/homebrew/bin' "should add /opt/homebrew/bin to PATH"

test_start "zshenv_homebrew_guard"
# Should use idempotent guard for Homebrew
if grep -qF '/opt/homebrew/bin' "$ZSHENV" && grep -qF 'PATH' "$ZSHENV"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: /opt/homebrew/bin has PATH guard"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use idempotent guard for /opt/homebrew/bin"
fi

test_start "zshenv_homebrew_dir_check"
if grep -qF -- '-d "/opt/homebrew/bin"' "$ZSHENV"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks /opt/homebrew/bin directory exists"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check /opt/homebrew/bin directory exists"
fi

test_start "zshenv_zdotdir"
assert_file_contains "$ZSHENV" 'ZDOTDIR' "should set ZDOTDIR"

test_start "zshenv_no_heavy_init"
# zshenv should NOT contain eval statements (heavy init belongs in zshrc)
if grep -q '^eval ' "$ZSHENV" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: zshenv should not contain eval (heavy init)"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no heavy eval in zshenv"
fi

echo ""
echo "Wave 1 dot_zshenv PATH tests completed."
print_summary
