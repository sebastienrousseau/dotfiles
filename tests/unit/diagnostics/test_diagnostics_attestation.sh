#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
DOT_CLI="$REPO_ROOT/bin/dot"

test_start "attestation_exists"
assert_file_exists "$TEST_SCRIPT" "workstation-attestation.sh should exist"

test_start "attestation_registered"
output=$(REPO_ROOT="$REPO_ROOT" bash "$DOT_CLI" attest -j 2>/dev/null) || true
assert_equals "true" "$(printf '%s' "$output" | jq 'has("dotfiles_version")' 2>/dev/null || echo false)" \
  "dot attest dispatches to the attestation script"

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

# -j is run below and -F/-I by the fleet-store test; -w writes the file.
test_start "attestation_short_flags_supported"
write_dir="$(mktemp -d)"
REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" -j -w "$write_dir/sub/att.json" >/dev/null 2>&1 || true
assert_equals "true" "$(jq 'has("dotfiles_version")' "$write_dir/sub/att.json" 2>/dev/null || echo false)" \
  "-w writes the attestation JSON, creating its directory"
rm -rf "$write_dir"

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

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
