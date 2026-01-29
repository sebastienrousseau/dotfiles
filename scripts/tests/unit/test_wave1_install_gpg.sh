#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: install.sh GPG signature verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"

echo "Testing Wave 1: install.sh GPG verification..."

test_start "install_gpg_verify_block"
assert_file_contains "$INSTALL_SCRIPT" "gpg --verify" "should attempt GPG signature verification"

test_start "install_gpg_key_defined"
assert_file_contains "$INSTALL_SCRIPT" "CHEZMOI_GPG_KEY=" "should define CHEZMOI_GPG_KEY variable"

test_start "install_gpg_key_fingerprint"
# Verify the correct chezmoi GPG key fingerprint is used
assert_file_contains "$INSTALL_SCRIPT" "FD93980B3D3173B6894CBB0A3C270B7E4E6B46F4" "should use correct chezmoi GPG key"

test_start "install_gpg_gitleaks_allow"
# The GPG key line should have gitleaks:allow annotation
if grep -q 'CHEZMOI_GPG_KEY=.*# gitleaks:allow' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: GPG key has gitleaks:allow annotation"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: GPG key should have gitleaks:allow annotation"
fi

test_start "install_gpg_graceful_no_gpg"
# Should handle gpg not being installed
assert_file_contains "$INSTALL_SCRIPT" "gpg not installed" "should handle missing gpg gracefully"

test_start "install_gpg_graceful_no_sig"
# Should handle .sig file not being available
assert_file_contains "$INSTALL_SCRIPT" "signature file not available" "should handle missing sig file gracefully"

test_start "install_gpg_graceful_no_key"
# Should handle key import failure
assert_file_contains "$INSTALL_SCRIPT" "Could not import GPG" "should handle key import failure gracefully"

test_start "install_gpg_hard_fail_bad_sig"
# Should abort on actual verification failure
assert_file_contains "$INSTALL_SCRIPT" "signature verification FAILED" "should abort on bad signature"

test_start "install_gpg_keyserver_primary"
assert_file_contains "$INSTALL_SCRIPT" "keys.openpgp.org" "should use openpgp.org as primary keyserver"

test_start "install_gpg_keyserver_fallback"
assert_file_contains "$INSTALL_SCRIPT" "keyserver.ubuntu.com" "should use ubuntu.com as fallback keyserver"

test_start "install_gpg_checksums_sig_download"
assert_file_contains "$INSTALL_SCRIPT" "checksums.txt.sig" "should download checksums signature file"

test_start "install_chezmoi_version_pinned"
# Verify version is a proper semver
version=$(grep 'CHEZMOI_VERSION=' "$INSTALL_SCRIPT" | head -1 | grep -oP '"[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"')
if [[ -n "$version" && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: chezmoi version pinned to $version"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should pin chezmoi to valid semver"
fi

echo ""
echo "Wave 1 install.sh GPG verification tests completed."
print_summary
