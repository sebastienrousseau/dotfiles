#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

GUARD_SCRIPT="$REPO_ROOT/scripts/ci/guard-gitleaks-checkout.sh"

mk_workflows() {
  local dir="$1"
  mkdir -p "$dir/.github/workflows"
}

test_start "guard_gitleaks_checkout_passes_fetch_depth_1"
tmp_ok="$(mktemp -d)"
mk_workflows "$tmp_ok"
cat >"$tmp_ok/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1
      - uses: gitleaks/gitleaks-action@v2
EOF
cp "$tmp_ok/.github/workflows/ci.yml" "$tmp_ok/.github/workflows/security-enhanced.yml"
assert_exit_code 0 "cd '$tmp_ok' && bash '$GUARD_SCRIPT'"
rm -rf "$tmp_ok"

test_start "guard_gitleaks_checkout_fails_missing_fetch_depth_1"
tmp_missing="$(mktemp -d)"
mk_workflows "$tmp_missing"
cat >"$tmp_missing/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
      - uses: gitleaks/gitleaks-action@v2
EOF
cp "$tmp_missing/.github/workflows/ci.yml" "$tmp_missing/.github/workflows/security-enhanced.yml"
assert_exit_code 1 "cd '$tmp_missing' && bash '$GUARD_SCRIPT'"
rm -rf "$tmp_missing"

test_start "guard_gitleaks_checkout_fails_fetch_depth_0"
tmp_zero="$(mktemp -d)"
mk_workflows "$tmp_zero"
cat >"$tmp_zero/.github/workflows/ci.yml" <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
EOF
cp "$tmp_zero/.github/workflows/ci.yml" "$tmp_zero/.github/workflows/security-enhanced.yml"
assert_exit_code 1 "cd '$tmp_zero' && bash '$GUARD_SCRIPT'"
rm -rf "$tmp_zero"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
