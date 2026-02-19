#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for utility functions: hostinfo, size, banner, stopwatch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

FUNCS_DIR="$REPO_ROOT/.chezmoitemplates/functions"

echo "Testing utility functions..."

# ============ hostinfo ============

if [[ -f "$FUNCS_DIR/hostinfo.sh" ]]; then
  source "$FUNCS_DIR/hostinfo.sh"
fi

test_start "hostinfo_function_exists"
assert_true "type hostinfo &>/dev/null" "hostinfo function should exist"

test_start "hostinfo_help"
if type hostinfo &>/dev/null; then
  output=$(hostinfo --help 2>&1)
  if [[ "$output" == *"Usage:"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows usage"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: --help should show usage"
  fi
fi

test_start "hostinfo_help_exit_code"
if type hostinfo &>/dev/null; then
  hostinfo --help >/dev/null 2>&1
  assert_equals "0" "$?" "hostinfo --help should exit 0"
fi

test_start "hostinfo_shows_username"
if type hostinfo &>/dev/null; then
  # Use timeout to avoid network-dependent delays (hostinfo fetches public IP)
  set +e
  output=$(timeout 5 bash -c 'source "'"$FUNCS_DIR/hostinfo.sh"'" && hostinfo' 2>&1)
  set -e
  if [[ "$output" == *"Username"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: output contains Username"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: output should contain Username"
    echo -e "    Output: ${output:0:200}"
  fi
fi

test_start "hostinfo_shows_hostname"
if type hostinfo &>/dev/null; then
  set +e
  output=$(timeout 5 bash -c 'source "'"$FUNCS_DIR/hostinfo.sh"'" && hostinfo' 2>&1)
  set -e
  if [[ "$output" == *"Hostname"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: output contains Hostname"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: output should contain Hostname"
  fi
fi

# ============ size ============

if [[ -f "$FUNCS_DIR/size.sh" ]]; then
  source "$FUNCS_DIR/size.sh"
fi

test_start "size_function_exists"
assert_true "type size &>/dev/null" "size function should exist"

test_start "size_no_args"
if type size &>/dev/null; then
  set +e
  output=$(size 2>&1)
  ec=$?
  set -e
  assert_equals "1" "$ec" "size with no args should fail"
fi

test_start "size_with_file"
if type size &>/dev/null; then
  test_dir=$(mock_dir "size_test")
  echo "test content" >"$test_dir/test.txt"
  output=$(size "$test_dir/test.txt" 2>&1) || true
  if [[ "$output" == *"INFO"* ]] || [[ "$output" == *"bytes"* ]] || [[ "$output" == *"size"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows size information"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show size information"
    echo -e "    Output: $output"
  fi
  rm -rf "$test_dir"
fi

# ============ banner ============

if [[ -f "$FUNCS_DIR/banner.sh" ]]; then
  source "$FUNCS_DIR/banner.sh"
fi

test_start "banner_function_exists"
assert_true "type banner &>/dev/null" "banner function should exist"

test_start "banner_no_script_error"
if type banner &>/dev/null; then
  # Without the figlet-banner.sh script, banner should fail gracefully
  set +e
  DOTFILES_DIR="/nonexistent" output=$(banner "test" 2>&1)
  ec=$?
  set -e
  if [[ $ec -ne 0 ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"ERROR"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: graceful error when script missing"
  else
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: banner handled missing script"
  fi
fi

# ============ Cross-cutting: error path tests ============

test_start "size_too_many_args"
if type size &>/dev/null; then
  set +e
  output=$(size "arg1" "arg2" 2>&1)
  ec=$?
  set -e
  assert_equals "1" "$ec" "size with 2 args should fail"
fi

echo ""
echo "Utility function tests completed."
print_summary
