#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

# tls_case <name> <relative file> <line> <want rc>: scan a one-file tree.
tls_case() {
  local name="$1" rel="$2" line="$3" want="$4" dir="$DOTFILES_COV_TMPDIR/tls-$1" rc=0
  mkdir -p "$dir/$(dirname "$rel")"
  printf '#!/usr/bin/env bash\n%s\n' "$line" >"$dir/$rel"
  bash "$SCRIPT_FILE" "$dir" >/dev/null 2>&1 || rc=$?
  test_start "$name"
  assert_equals "$want" "$rc" "$rel: $line"
}

tls_case flags_curl_insecure bad.sh 'curl --insecure https://x' 1
tls_case flags_curl_k_in_cluster bad.sh 'curl -fsSLk https://x' 1
tls_case flags_curl_sk bad.sh 'curl -sk https://x -o f' 1
tls_case flags_wget_no_check bad.sh 'wget --no-check-certificate https://x' 1
tls_case scans_templates bad.sh.tmpl 'curl -k https://x' 1
tls_case allows_plain_curl ok.sh 'curl -fsSL https://x' 0
tls_case allows_keyring_package ok.sh 'apt-get install -y ubuntu-keyring && curl -fsSL https://x' 0
tls_case skips_test_fixtures tests/fixture.sh 'curl -k https://x' 0
tls_case passes_tree_without_curl ok.sh 'echo no downloads here' 0

test_start "repo_scan_is_clean"
assert_exit_code 0 "bash '$SCRIPT_FILE' '$REPO_ROOT'"

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
