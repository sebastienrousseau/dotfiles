#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"
DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

test_start "attestation_exists"
assert_file_exists "$TEST_SCRIPT" "workstation-attestation.sh should exist"

test_start "attestation_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "attestation_registered"
assert_file_contains "$DOT_CLI" "attest" "dot CLI should register attest command"

test_start "attestation_json_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"dotfiles_version\""* ]] && [[ "$output" == *"\"git_signing\""* ]] && [[ "$output" == *"\"governance\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits attestation JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should emit attestation JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "attestation_short_flags_supported"
assert_file_contains "$TEST_SCRIPT" "--json | -j" "attestation supports -j"
assert_file_contains "$TEST_SCRIPT" "--write | -w" "attestation supports -w"
assert_file_contains "$TEST_SCRIPT" "--fleet-store | -F" "attestation supports -F"
assert_file_contains "$TEST_SCRIPT" "--fleet-id | -I" "attestation supports -I"

test_start "attestation_short_json_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"dotfiles_version\""* ]] && [[ "$output" == *"\"policy_bundles\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -j emits attestation JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -j should emit attestation JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "attestation_fleet_store_writes"
fleet_dir="$(mktemp -d)"
hostname_value="$(hostname 2>/dev/null || echo unknown-host)"
REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" -F "$fleet_dir" -I ci-fleet >/dev/null 2>&1 || true
if [[ -f "$fleet_dir/ci-fleet/$hostname_value/workstation-attestation.json" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: fleet store export writes latest attestation"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected fleet attestation export"
fi
rm -rf "$fleet_dir"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
