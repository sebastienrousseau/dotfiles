#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

POLICY_BUNDLES="$REPO_ROOT/dot_config/dotfiles/policy-bundles.json"
MODEL_REGISTRY="$REPO_ROOT/dot_config/dotfiles/model-registry.json"
PROMPT_REGISTRY="$REPO_ROOT/dot_config/dotfiles/prompt-registry.json"
README_FILE="$REPO_ROOT/README.md"
WORKSTATION_DOC="$REPO_ROOT/docs/operations/TRUSTED_AGENT_WORKSTATION.md"

test_start "governance_artifacts_exist"
assert_file_exists "$POLICY_BUNDLES" "policy-bundles.json should exist"
assert_file_exists "$MODEL_REGISTRY" "model-registry.json should exist"
assert_file_exists "$PROMPT_REGISTRY" "prompt-registry.json should exist"
assert_file_exists "$WORKSTATION_DOC" "trusted workstation doc should exist"

test_start "policy_bundles_define_enterprise"
assert_file_contains "$POLICY_BUNDLES" '"enterprise"' "policy bundles define enterprise"
assert_file_contains "$POLICY_BUNDLES" '"regulated"' "policy bundles define regulated"

test_start "registries_require_signed_change_control"
assert_file_contains "$MODEL_REGISTRY" 'signed-commit' "model registry enforces signed change control"
assert_file_contains "$PROMPT_REGISTRY" 'signed-commit' "prompt registry enforces signed change control"

test_start "readme_positions_trusted_workstation"
assert_file_contains "$README_FILE" 'Trusted agent workstation' "README positions the repo as a trusted agent workstation"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
