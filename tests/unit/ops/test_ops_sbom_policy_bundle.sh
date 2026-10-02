#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BUNDLE_SCRIPT="$REPO_ROOT/tools/release/package-policy-bundles.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/policy-bundle-release.yml"

test_start "sbom_bundle_script_exists"
assert_file_exists "$BUNDLE_SCRIPT" "package-policy-bundles.sh should exist"

test_start "sbom_workflow_has_syft_step"
assert_file_contains "$WORKFLOW_FILE" "download-syft" "workflow should install syft"

test_start "sbom_workflow_has_verification_step"
assert_file_contains "$WORKFLOW_FILE" "Verify SBOM presence" "workflow should verify SBOM"

# Build a bundle into a temp dir and check what it contains.
BUNDLE_OUT="$(mktemp -d -t dot-policy-bundle.XXXXXX)"
bundle_json="$(bash "$BUNDLE_SCRIPT" --output-dir "$BUNDLE_OUT" --json 2>/dev/null)"
bundle_field() { python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$bundle_json" "$1" 2>/dev/null; }
archive="$(bundle_field archive)"

test_start "sbom_bundle_json_names_its_artifacts"
assert_file_exists "$archive" "the archive the JSON names exists"
assert_file_exists "$(bundle_field checksum)" "so does its checksum file"
assert_file_exists "$(bundle_field sbom)" "and the SBOM"

test_start "sbom_bundle_checksum_matches_the_archive"
expected_sum="$(awk '{print $1}' "$(bundle_field checksum)")"
actual_sum="$( (sha256sum "$archive" 2>/dev/null || shasum -a 256 "$archive") | awk '{print $1}')"
assert_equals "$expected_sum" "$actual_sum" "the published checksum is the archive's"

test_start "sbom_bundle_carries_the_sbom_and_both_cards"
listing="$(tar -tzf "$archive")"
assert_contains "/sbom.cyclonedx.json" "$listing" "the CycloneDX SBOM"
assert_contains "/.well-known/agent-card.json" "$listing" "the A2A agent card"
assert_contains "/.well-known/mcp/server-card.json" "$listing" "the MCP server card"
assert_equals "CycloneDX" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("bomFormat"))' "$(bundle_field sbom)" 2>&1)" \
  "the SBOM is CycloneDX"
rm -rf "$BUNDLE_OUT"

test_start "sbom_bundle_help_and_unknown_options_build_nothing"
help_out="$(mktemp -d -t dot-policy-help.XXXXXX)"
OUTPUT_DIR="$help_out/out" bash "$BUNDLE_SCRIPT" --help >/dev/null 2>&1
assert_equals "0" "$?" "--help exits 0"
OUTPUT_DIR="$help_out/out" bash "$BUNDLE_SCRIPT" --bogus >/dev/null 2>&1
assert_equals "2" "$?" "an unknown option exits 2"
assert_equals "false" "$([[ -e "$help_out/out" ]] && echo true || echo false)" "neither builds a bundle"
rm -rf "$help_out"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$BUNDLE_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
