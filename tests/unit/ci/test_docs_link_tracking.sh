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
assert_output_not_contains "https://euxis.co" "cat '$README'"

test_start "readme_engine_link_is_policy_consistent"
expected='**THE ENGINE** ᛞ [EUXIS](https://github.com/sebastienrousseau/euxis) ᛫ Enterprise Unified Execution Intelligence System'
assert_file_contains "$README" "$expected" "README points to the healthy official EUXIS repository"
assert_file_contains "$AUDIT" "$expected" "the signature guard enforces the same healthy destination"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
