#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for tools/ci/check-insecure-tls.sh — the curl-k/--insecure +
# wget --no-check-certificate scanner used by the compliance guard.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/tools/ci/check-insecure-tls.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "tools/ci/check-insecure-tls.sh must exist"

test_start "script_is_executable"
if [[ -x "$SCRIPT_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: must be executable"
fi

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "uses_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "must use strict mode"

test_start "self_excludes_from_grep"
# Source has quoted exclude, e.g. `--exclude='check-insecure-tls.sh'`,
# so match the value alone rather than the verbatim `=value` form.
assert_file_contains "$SCRIPT_FILE" "check-insecure-tls.sh" "must skip itself"

# Exercise the scanner against a tmp dir with one clean file: should
# return 0 (no insecure patterns).
clean_dir="$DOTFILES_COV_TMPDIR/clean"
mkdir -p "$clean_dir"
cat >"$clean_dir/safe.sh" <<'EOF'
#!/usr/bin/env bash
curl -fsSL https://example.com/ok > /dev/null
EOF

test_start "scanner_returns_0_on_clean_input"
if bash "$SCRIPT_FILE" "$clean_dir" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should exit 0 on clean input"
fi

# Now seed an offending file and confirm the scanner exits non-zero.
cat >"$clean_dir/bad.sh" <<'EOF'
#!/usr/bin/env bash
curl -k https://example.com/skip-tls > /dev/null
EOF
test_start "scanner_flags_curl_minus_k"
if ! bash "$SCRIPT_FILE" "$clean_dir" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should exit non-zero on curl -k"
fi

cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
