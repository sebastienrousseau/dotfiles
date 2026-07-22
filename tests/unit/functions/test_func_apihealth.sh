#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/api/apihealth.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "func_file_exists"
assert_file_exists "$FUNC_FILE" "apihealth.sh should exist"

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

test_start "apihealth_deep_branches_execute"
apihealth_tmp="$DOTFILES_COV_TMPDIR/apihealth-deep"
mkdir -p "$apihealth_tmp/bin"
cat >"$apihealth_tmp/bin/curl" <<'EOF_CURL'
#!/usr/bin/env bash
if [[ -n "${DOTFILES_FAKE_CURL_FAIL:-}" ]]; then
  exit 7
fi
printf '%s\n' "${DOTFILES_FAKE_CURL_CODE:-200}"
EOF_CURL
chmod +x "$apihealth_tmp/bin/curl"
(
  set +e
  export PATH="$apihealth_tmp/bin:$PATH"
  # shellcheck disable=SC1090
  source "$FUNC_FILE"
  apihealth --help
  apihealth --version
  apihealth --method POST --expect 201 --header "Authorization: Bearer token" \
    --timeout 2 https://example.test/created
  DOTFILES_FAKE_CURL_CODE=500 apihealth https://example.test/fail
  DOTFILES_FAKE_CURL_FAIL=1 apihealth https://example.test/no-response
  apihealth --method
  apihealth --expect
  apihealth --header "broken"
  apihealth --timeout nope https://example.test
  apihealth --unknown
  apihealth
) >/dev/null || true
assert_file_exists "$apihealth_tmp/bin/curl" \
  "apihealth deep branches used sandbox curl shim"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
