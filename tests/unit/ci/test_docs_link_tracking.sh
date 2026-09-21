#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORKFLOW="$REPO_ROOT/.github/workflows/docs-link-check.yml"
README="$REPO_ROOT/README.md"
AUDIT="$REPO_ROOT/scripts/git-hooks/pre-commit-audit.sh"
PR_TEMPLATE="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
PR_SIGNATURE="$REPO_ROOT/.github/workflows/pr-signature.yml"

test_start "link_tracker_opens_on_failure"
assert_file_contains "$WORKFLOW" 'if: steps.lychee.outputs.exit_code != 0' \
  "failed online checks open or update one tracking issue"

test_start "link_tracker_closes_on_recovery"
assert_file_contains "$WORKFLOW" 'if: steps.lychee.outputs.exit_code == 0' \
  "clean online checks close the open tracking issue"

test_start "link_tracker_records_clean_run"
assert_file_contains "$WORKFLOW" 'Resolved by a clean external-link run: $RUN_URL' \
  "closure records the validating workflow run"

test_start "readme_avoids_unreachable_endpoints"
assert_output_not_contains "https://repology.org/project/dot-cli/versions" "cat '$README'"

test_start "readme_avoids_unreachable_euxis_endpoint"
assert_output_not_contains "https://euxis.co" "cat '$README'"

test_start "readme_engine_link_uses_official_repository"
expected='**THE ENGINE** ᛞ [EUXIS](https://github.com/sebastienrousseau/euxis) ᛫ Enterprise Unified Execution Intelligence System'
assert_file_contains "$README" "$expected" "README points to the healthy official EUXIS repository"

test_start "audit_engine_link_matches_readme"
assert_file_contains "$AUDIT" "$expected" "the signature guard enforces the same healthy destination"

test_start "pr_template_uses_official_euxis_repository"
signature='THE ENGINE ᛞ EUXIS ᛫ Enterprise Unified Execution Intelligence System ᛫ https://github.com/sebastienrousseau/euxis'
assert_file_contains "$PR_TEMPLATE" "$signature" \
  "new PR descriptions use the healthy official EUXIS repository"

test_start "pr_signature_policy_matches_template"
assert_file_contains "$PR_SIGNATURE" "$signature" \
  "the PR signature gate requires the same healthy destination"

test_start "github_policy_avoids_unreachable_euxis_endpoint"
assert_output_not_contains "https://euxis.co" \
  "cat '$PR_TEMPLATE' '$PR_SIGNATURE'"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
