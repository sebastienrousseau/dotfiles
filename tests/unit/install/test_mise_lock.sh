#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

config="$REPO_ROOT/mise.toml"
lock="$REPO_ROOT/mise.lock"

test_start "mise_lock_exists"
assert_file_exists "$lock" "cross-platform mise lockfile exists"

test_start "mise_lock_enabled"
assert_file_contains "$config" "lockfile = true" "mise consumes the committed lockfile"

test_start "mise_project_config_has_no_mutable_versions"
if rg -n '= "(latest|nightly|lts)"' "$config" >/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

for tool in node rust go bun starship wasmtime sops yazi zellij; do
  test_start "mise_lock_contains_${tool}"
  assert_file_contains "$lock" "[[tools.$tool]]" "lock contains $tool"
done

for platform in linux-arm64 linux-x64 macos-arm64 macos-x64 windows-x64; do
  test_start "mise_lock_contains_${platform}"
  assert_file_contains "$lock" "platforms.$platform" "lock contains $platform metadata"
done

test_start "mise_lock_has_sha256_metadata"
if [[ "$(rg -c '^checksum = "sha256:[0-9a-f]{64}"$' "$lock")" -ge 50 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: insufficient checksum records"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
