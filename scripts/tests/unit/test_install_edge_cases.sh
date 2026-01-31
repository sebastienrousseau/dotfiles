#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for install.sh edge cases, idempotency, and input validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"

echo "Testing install.sh edge cases..."

# Test: install.sh has set -euo pipefail
test_start "install_strict_mode"
if grep -q "set -euo pipefail" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses strict mode (set -euo pipefail)"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# Test: install.sh has trap for cleanup
test_start "install_trap_cleanup"
if grep -q "trap" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has trap for cleanup"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have trap for cleanup"
fi

# Test: install.sh uses mktemp (not hardcoded temp paths)
test_start "install_uses_mktemp"
if grep -q "mktemp" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses mktemp for temp files"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use mktemp"
fi

# Test: install.sh pins chezmoi version (not latest)
test_start "install_chezmoi_version_pinned"
if grep -q 'CHEZMOI_VERSION=' "$INSTALL_SCRIPT"; then
  version=$(grep 'CHEZMOI_VERSION=' "$INSTALL_SCRIPT" | head -1 | cut -d'"' -f2)
  if [[ -n "$version" ]] && [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: chezmoi version pinned to $version"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: chezmoi version should be a valid semver"
  fi
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should pin chezmoi version"
fi

# Test: install.sh has SHA256 verification
test_start "install_checksum_verification"
if grep -q "sha256sum\|shasum" "$INSTALL_SCRIPT" && grep -q "expected.*actual\|actual.*expected" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: performs checksum verification"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should verify checksums"
fi

# Test: install.sh handles backup of existing .dotfiles
test_start "install_backup_existing"
if grep -q '\.dotfiles\.bak' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backs up existing .dotfiles directory"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should backup existing .dotfiles"
fi

# Test: install.sh supports noninteractive mode
test_start "install_noninteractive_mode"
if grep -q "DOTFILES_NONINTERACTIVE" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports DOTFILES_NONINTERACTIVE"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support noninteractive mode"
fi

# Test: install.sh uses --force --no-tty in noninteractive mode
test_start "install_noninteractive_flags"
if grep -q "\-\-force" "$INSTALL_SCRIPT" && grep -q "\-\-no-tty" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses --force --no-tty in noninteractive mode"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use --force --no-tty"
fi

# Test: install.sh uses HTTPS for all URLs
test_start "install_https_only"
http_urls=$(grep -n 'http://' "$INSTALL_SCRIPT" | grep -v '^#' | grep -v 'http://deb' || true)
if [[ -z "$http_urls" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all URLs use HTTPS"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: found non-HTTPS URLs"
  echo -e "    $http_urls"
fi

# Test: install.sh uses connect-timeout for curl
test_start "install_curl_timeout"
if grep -q "\-\-connect-timeout" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses --connect-timeout for curl"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use --connect-timeout"
fi

# Test: install.sh detects multiple OS types
test_start "install_multi_os_detection"
os_count=0
for os in "debian" "fedora" "arch" "macos" "wsl2"; do
  if grep -q "$os" "$INSTALL_SCRIPT"; then
    os_count=$((os_count + 1))
  fi
done
if [[ $os_count -ge 3 ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: detects $os_count OS types"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should detect at least 3 OS types, found $os_count"
fi

# Test: install.sh does not contain curl | sh (pipes to shell) # gitleaks:allow
test_start "install_no_curl_pipe_sh"
# The Homebrew install line is a known pattern but uses /bin/bash -c, not pipe
curl_pipe=$(grep 'curl.*|.*sh' "$INSTALL_SCRIPT" | grep -v "Homebrew" | grep -v "^#" || true) # gitleaks:allow
if [[ -z "$curl_pipe" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no unsafe curl|sh patterns" # gitleaks:allow
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: found curl piped to shell"
  echo -e "    $curl_pipe"
fi

# Test: ensure_chezmoi_source function exists
test_start "install_ensure_chezmoi_source"
if grep -q "ensure_chezmoi_source" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has ensure_chezmoi_source function"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have ensure_chezmoi_source"
fi

# Test: install.sh handles missing architecture gracefully
test_start "install_arch_error_handling"
if grep -q 'Unsupported architecture' "$INSTALL_SCRIPT" || grep -q 'Unsupported.*arch' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles unsupported architectures"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle unsupported architectures"
fi

echo ""
echo "install.sh edge case tests completed."
print_summary
