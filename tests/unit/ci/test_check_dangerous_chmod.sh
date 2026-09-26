#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for tools/ci/check-dangerous-chmod.sh — blocks any
# `chmod 777` / `chmod 666` from landing in shell sources.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/tools/ci/check-dangerous-chmod.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "tools/ci/check-dangerous-chmod.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# chk_case <name> <relative file> <line> <want rc>: a one-file tree scanned
# from its root; the checker must exit <want rc>.
chk_case() {
  local name="$1" rel="$2" line="$3" want="$4" dir="$HOME/chk-$1" rc=0
  mkdir -p "$dir/$(dirname "$rel")"
  printf '#!/usr/bin/env bash\n%s\n' "$line" >"$dir/$rel"
  (cd "$dir" && bash "$SCRIPT_FILE" >/dev/null 2>&1) || rc=$?
  test_start "$name"
  assert_equals "$want" "$rc" "$rel: $line"
}

chk_case rejects_666 bad.sh 'chmod 666 f' 1
chk_case rejects_after_sudo bad.sh 'sudo chmod 777 /srv' 1
chk_case rejects_mid_command bad.sh 'mkdir d && chmod 777 d' 1
chk_case rejects_leading_zero bad.sh 'chmod 0777 f' 1
chk_case rejects_with_flags bad.sh 'chmod -v -R 666 d' 1
chk_case scans_zsh bad.zsh 'chmod 777 f' 1
chk_case scans_bash_ext bad.bash 'chmod 777 f' 1
chk_case allows_sticky_tmp ok.sh 'chmod 1777 /tmp/shared' 0
chk_case ignores_comments ok.sh '# never chmod 777 anything' 0
chk_case skips_test_fixtures tests/fixture.sh 'chmod 777 f' 0

# Functional: scan a known-clean tree (HOME, sandboxed) — should exit 0.
test_start "passes_on_clean_tree"
mkdir -p "$HOME/clean"
cat >"$HOME/clean/safe.sh" <<'EOF'
#!/usr/bin/env bash
chmod 755 some-file
EOF
pushd "$HOME/clean" >/dev/null || exit 1
if bash "$SCRIPT_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should exit 0 on clean tree"
fi
popd >/dev/null || exit 1

# Functional: scan a tree with chmod 777 — must exit non-zero.
test_start "rejects_chmod_777_in_tree"
cat >"$HOME/clean/bad.sh" <<'EOF'
#!/usr/bin/env bash
chmod 777 /tmp/insecure
EOF
pushd "$HOME/clean" >/dev/null || exit 1
if ! bash "$SCRIPT_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject chmod 777"
fi
popd >/dev/null || exit 1

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
