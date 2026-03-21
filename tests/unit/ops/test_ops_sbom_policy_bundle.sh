#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BUNDLE_SCRIPT="$REPO_ROOT/scripts/release/package-policy-bundles.sh"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/policy-bundle-release.yml"

test_start "sbom_bundle_script_exists"
assert_file_exists "$BUNDLE_SCRIPT" "package-policy-bundles.sh should exist"

test_start "sbom_bundle_script_syntax"
assert_exit_code 0 "bash -n '$BUNDLE_SCRIPT'"

test_start "sbom_bundle_generates_cyclonedx"
assert_file_contains "$BUNDLE_SCRIPT" "sbom.cyclonedx.json" "script should reference SBOM file"

test_start "sbom_bundle_uses_syft_or_jq"
assert_file_contains "$BUNDLE_SCRIPT" "syft" "script should check for syft"
assert_file_contains "$BUNDLE_SCRIPT" "CycloneDX" "script should generate CycloneDX format"

test_start "sbom_bundle_json_output_includes_sbom"
assert_file_contains "$BUNDLE_SCRIPT" "sbom" "JSON output should include sbom field"

test_start "sbom_workflow_has_syft_step"
assert_file_contains "$WORKFLOW_FILE" "download-syft" "workflow should install syft"

test_start "sbom_workflow_has_verification_step"
assert_file_contains "$WORKFLOW_FILE" "Verify SBOM presence" "workflow should verify SBOM"

test_start "sbom_bundle_includes_a2a_card"
assert_file_contains "$BUNDLE_SCRIPT" "agent-card.json" "bundle should include A2A card"

test_start "sbom_bundle_includes_mcp_server_card"
assert_file_contains "$BUNDLE_SCRIPT" "server-card.json" "bundle should include MCP server card"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
