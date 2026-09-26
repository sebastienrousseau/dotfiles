#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

POLICY_BUNDLES="$REPO_ROOT/defaults/dot_config/dotfiles/policy-bundles.json"
MODEL_REGISTRY="$REPO_ROOT/defaults/dot_config/dotfiles/model-registry.json"
PROMPT_REGISTRY="$REPO_ROOT/defaults/dot_config/dotfiles/prompt-registry.json"
README_FILE="$REPO_ROOT/README.md"
WORKSTATION_DOC="$REPO_ROOT/docs/operations/TRUSTED_AGENT_WORKSTATION.md"

test_start "governance_artifacts_exist"
assert_file_exists "$POLICY_BUNDLES" "policy-bundles.json should exist"
assert_file_exists "$MODEL_REGISTRY" "model-registry.json should exist"
assert_file_exists "$PROMPT_REGISTRY" "prompt-registry.json should exist"
assert_file_exists "$WORKSTATION_DOC" "trusted workstation doc should exist"

test_start "policy_bundles_define_enterprise"
assert_equals "true" "$(jq '.bundles | has("enterprise") and has("regulated")' "$POLICY_BUNDLES")" "policy bundles define enterprise and regulated"

# Every entry, not just one: a model or prompt set added without signed
# change control would otherwise pass as long as another entry had it.
test_start "every_model_requires_signed_change_control"
assert_equals "true" "$(jq '[.models[].changeControl // ""] | length > 0 and all(startswith("signed-commit"))' "$MODEL_REGISTRY")" "each model's changeControl starts with signed-commit"

test_start "every_prompt_set_requires_signed_change_control"
assert_equals "true" "$(jq '[.promptSets[].changeControl // ""] | length > 0 and all(startswith("signed-commit"))' "$PROMPT_REGISTRY")" "each prompt set's changeControl starts with signed-commit"

test_start "readme_links_trusted_workstation_doc"
# The tagline no longer leads with "Trusted agent workstation" (it's been
# demoted from headline to feature-table row), but the README must still
# surface the trust/attestation story via the capability table or docs link.
# Match case-insensitively so the test doesn't trip on sentence-case
# variants ("Cryptographic attestation" vs "Cryptographic Attestation").
if grep -qi 'cryptographic attestation' "$README_FILE"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: README surfaces attestation as a capability"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: README surfaces attestation as a capability"
fi
assert_file_contains "$README_FILE" 'signed' "README mentions signed releases"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
