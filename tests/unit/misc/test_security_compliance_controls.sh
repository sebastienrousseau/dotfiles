#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

gitconfig_template="$REPO_ROOT/dot_gitconfig.tmpl"
update_deps_workflow="$REPO_ROOT/.github/workflows/update-deps.yml"
sync_versions_workflow="$REPO_ROOT/.github/workflows/sync-versions.yml"
security_workflow="$REPO_ROOT/.github/workflows/security-enhanced.yml"
reliability_workflow="$REPO_ROOT/.github/workflows/reliability-gate.yml"
policy_release_workflow="$REPO_ROOT/.github/workflows/policy-bundle-release.yml"
policy_release_script="$REPO_ROOT/scripts/release/package-policy-bundles.sh"
package_managers_lib="$REPO_ROOT/install/lib/package_managers.sh"
allowed_signers_file="$REPO_ROOT/dot_config/git/allowed_signers.tmpl"
flake_lock_file="$REPO_ROOT/flake.lock"
soup_register_file="$REPO_ROOT/docs/security/SOUP_REGISTER.md"
automation_secrets_file="$REPO_ROOT/docs/security/AUTOMATION_SECRETS.md"
mcp_policy_file="$REPO_ROOT/dot_config/dotfiles/mcp-policy.json"
mcp_lock_file="$REPO_ROOT/dot_config/dotfiles/mcp-lock.json"
mcp_config_file="$REPO_ROOT/dot_config/claude/mcp_servers.json"

test_start "git_template_enforces_merge_signature_verification"
assert_file_contains "$gitconfig_template" "verifySignatures = true" "merge signature verification enabled"

test_start "git_template_points_to_allowed_signers"
assert_file_contains "$gitconfig_template" "allowedSignersFile" "allowed signers file configured"
assert_file_contains "$gitconfig_template" ".config/git/allowed_signers" "allowed signers file uses managed git config path"

test_start "update_deps_uses_signed_commits"
assert_file_contains "$update_deps_workflow" "git commit -S -m" "dependency updates use signed commits"

test_start "sync_versions_uses_signed_commits"
assert_file_contains "$sync_versions_workflow" "git commit -S -m" "version sync uses signed commits"

test_start "update_deps_avoids_unverified_yq_download"
if ! grep -q "wget -qO /usr/local/bin/yq" "$update_deps_workflow"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: yq is not installed from an unverified latest URL"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unverified yq latest download still present"
fi
assert_file_contains "$update_deps_workflow" "apt-get install -y jq curl yq" "yq installed from package manager"

test_start "homebrew_bootstrap_requires_checksum"
assert_file_contains "$package_managers_lib" "HOMEBREW_INSTALLER_SHA256" "homebrew bootstrap requires explicit checksum"
assert_file_contains "$package_managers_lib" "checksum mismatch" "homebrew bootstrap verifies checksum"

test_start "security_pipeline_runs_dependency_scan_on_core_events"
if ! sed -n '/dependency-scan:/,/infrastructure-scan:/p' "$security_workflow" | grep -q "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dependency scan is not schedule-only"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dependency scan is still schedule-only"
fi
assert_file_contains "$security_workflow" "anchore/grype:v" "grype uses pinned container image"
assert_file_contains "$security_workflow" "aquasec/trivy:" "trivy uses pinned container image"
assert_file_contains "$security_workflow" "GRYPE_VERSION: \"0.104.3\"" "grype version updated beyond known affected range"
assert_file_contains "$security_workflow" "TRIVY_VERSION: \"0.68.2\"" "trivy version updated beyond known affected range"

test_start "security_pipeline_runs_checkov_on_core_events"
if ! sed -n '/infrastructure-scan:/,/container-scan:/p' "$security_workflow" | grep -q "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checkov scan is not schedule-only"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: checkov scan is still schedule-only"
fi

test_start "allowed_signers_file_documented"
assert_file_contains "$allowed_signers_file" "Git verifies SSH-signed commits" "allowed signers file documents trust roster"
assert_file_contains "$allowed_signers_file" "sebastian.rousseau@gmail.com ssh-ed25519" "allowed signers file contains the current trusted signer"

test_start "root_flake_lock_present"
assert_file_exists "$flake_lock_file" "root flake.lock exists for deterministic Nix inputs"

test_start "summary_jobs_present_for_branch_protection"
assert_file_contains "$security_workflow" "name: Security Summary" "security summary job present"
assert_file_contains "$reliability_workflow" "name: Reliability Summary" "reliability summary job present"

test_start "policy_bundle_release_is_signed_and_attested"
assert_file_exists "$policy_release_workflow" "policy bundle release workflow exists"
assert_file_exists "$policy_release_script" "policy bundle release script exists"
assert_file_contains "$policy_release_workflow" "Verify signed source ref" "policy release verifies signed source refs"
assert_file_contains "$policy_release_workflow" "actions/attest-build-provenance" "policy release attests the bundle artifact"
assert_file_contains "$policy_release_script" "policy-bundles-" "policy release script packages versioned bundle archives"

test_start "compliance_docs_present"
assert_file_exists "$soup_register_file" "SOUP register exists"
assert_file_exists "$automation_secrets_file" "automation secrets doc exists"

test_start "mcp_policy_supply_chain_controls_present"
assert_file_exists "$mcp_policy_file" "mcp policy file exists"
assert_file_exists "$mcp_lock_file" "mcp lock file exists"
assert_file_contains "$mcp_policy_file" "\"requireApprovedPackageLock\": true" "mcp policy requires approved package lock"
assert_file_contains "$mcp_config_file" "@2026.3.0" "mcp config uses pinned release refs"
assert_file_contains "$mcp_config_file" "@2026.3.0" "mcp config uses pinned memory ref"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
