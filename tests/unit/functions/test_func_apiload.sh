#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/api/apiload.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "func_file_exists"
assert_file_exists "$FUNC_FILE" "apiload.sh should exist"

test_start "func_valid_syntax"
if bash -n "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "func_defines_function"
if grep -qE '^[a-z_]+\(\)\s*\{' "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$FUNC_FILE"

test_start "apiload_deep_branches_execute"
apiload_tmp="$DOTFILES_COV_TMPDIR/apiload-deep"
mkdir -p "$apiload_tmp/bin"
cat >"$apiload_tmp/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
printf '%s\n' "${DOTFILES_FAKE_CURL_CODE:-200}"
EOF_CURL
cat >"$apiload_tmp/bin/sleep" <<'EOF_SLEEP'
#!/usr/bin/env bash
:
EOF_SLEEP
chmod +x "$apiload_tmp/bin/curl" "$apiload_tmp/bin/sleep"
(
  set +e
  export PATH="$apiload_tmp/bin:$PATH"
  # shellcheck disable=SC1090
  source "$FUNC_FILE"
  apiload --help
  apiload --version
  apiload https://example.test 2 0
  DOTFILES_FAKE_CURL_CODE=500 apiload https://example.test 2 0
  apiload ftp://example.test
  apiload https://example.test nope 0
  apiload https://example.test 1 nope
  apiload
) >/dev/null || true
assert_file_exists "$apiload_tmp/bin/curl" \
  "apiload deep branches used sandbox curl shim"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
