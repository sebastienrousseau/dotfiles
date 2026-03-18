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
package_managers_lib="$REPO_ROOT/install/lib/package_managers.sh"
allowed_signers_file="$REPO_ROOT/dot_config/git/allowed_signers"
flake_lock_file="$REPO_ROOT/flake.lock"

test_start "git_template_enforces_merge_signature_verification"
assert_file_contains "$gitconfig_template" "verifySignatures = true" "merge signature verification enabled"

test_start "git_template_points_to_allowed_signers"
assert_file_contains "$gitconfig_template" "allowedSignersFile" "allowed signers file configured"

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

test_start "allowed_signers_file_documented"
assert_file_contains "$allowed_signers_file" "Git verifies SSH-signed commits" "allowed signers file documents trust roster"

test_start "root_flake_lock_present"
assert_file_exists "$flake_lock_file" "root flake.lock exists for deterministic Nix inputs"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
