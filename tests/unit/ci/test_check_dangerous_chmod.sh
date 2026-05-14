#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for scripts/ci/check-dangerous-chmod.sh — blocks any
# `chmod 777` / `chmod 666` from landing in shell sources.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ci/check-dangerous-chmod.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/ci/check-dangerous-chmod.sh must exist"

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

test_start "rejects_chmod_777"
assert_file_contains "$SCRIPT_FILE" "777" "must scan for chmod 777"

test_start "rejects_chmod_666"
assert_file_contains "$SCRIPT_FILE" "666" "must scan for chmod 666"

# Functional: scan a known-clean tree (HOME, sandboxed) — should exit 0.
test_start "passes_on_clean_tree"
mkdir -p "$HOME/clean"
cat >"$HOME/clean/safe.sh" <<'EOF'
#!/usr/bin/env bash
chmod 755 some-file
EOF
pushd "$HOME/clean" >/dev/null
if bash "$SCRIPT_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should exit 0 on clean tree"
fi
popd >/dev/null

# Functional: scan a tree with chmod 777 — must exit non-zero.
test_start "rejects_chmod_777_in_tree"
cat >"$HOME/clean/bad.sh" <<'EOF'
#!/usr/bin/env bash
chmod 777 /tmp/insecure
EOF
pushd "$HOME/clean" >/dev/null
if ! bash "$SCRIPT_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should reject chmod 777"
fi
popd >/dev/null

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
