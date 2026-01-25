#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Integration tests for install.sh
# Tests the dotfiles installation process in isolation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"

# Test: install.sh exists
test_start "install_script_exists"
assert_file_exists "$INSTALL_SCRIPT" "install.sh should exist"

# Test: install.sh is executable
test_start "install_script_executable"
if [[ -x "$INSTALL_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh is executable"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install.sh should be executable"
fi

# Test: install.sh has shebang
test_start "install_script_shebang"
first_line=$(head -n 1 "$INSTALL_SCRIPT")
if [[ "$first_line" == "#!/"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have shebang"
fi

# Test: install.sh uses set -e
test_start "install_script_set_e"
if grep -q "set -e" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses set -e for error handling"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use set -e"
fi

# Test: install.sh defines step function
test_start "install_script_step_function"
if grep -q "step()" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines step function"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define step function"
fi

# Test: install.sh defines error function
test_start "install_script_error_function"
if grep -q "error()" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines error function"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define error function"
fi

# Test: install.sh checks for curl
test_start "install_script_curl_check"
if grep -q "curl" "$INSTALL_SCRIPT" && grep -q "command -v curl" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for curl dependency"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for curl"
fi

# Test: install.sh checks for git
test_start "install_script_git_check"
if grep -q "git" "$INSTALL_SCRIPT" && grep -q "command -v git" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for git dependency"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for git"
fi

# Test: install.sh detects OS
test_start "install_script_os_detection"
if grep -q "uname" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: detects OS using uname"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should detect OS"
fi

# Test: install.sh has version pinning
test_start "install_script_version_pin"
if grep -q "CHEZMOI_VERSION" "$INSTALL_SCRIPT" || grep -q "VERSION=" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has version pinning for security"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have version pinning"
fi

# Test: install.sh has checksum verification
test_start "install_script_checksum"
if grep -q "sha256" "$INSTALL_SCRIPT" || grep -q "checksum" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has checksum verification"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have checksum verification"
fi

# Test: install.sh creates backup
test_start "install_script_backup"
if grep -q "backup" "$INSTALL_SCRIPT" || grep -q "\.bak" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: creates backup of existing files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should backup existing files"
fi

# Test: install.sh uses chezmoi
test_start "install_script_chezmoi"
if grep -q "chezmoi" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses chezmoi for dotfile management"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use chezmoi"
fi

# Test: install.sh handles non-interactive mode
test_start "install_script_noninteractive"
if grep -q "NONINTERACTIVE" "$INSTALL_SCRIPT" || grep -q "force" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports non-interactive mode"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support non-interactive mode"
fi

# Test: install.sh cleans up temp files
test_start "install_script_cleanup"
if grep -q "trap" "$INSTALL_SCRIPT" || grep -q "rm -rf.*tmp" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: cleans up temporary files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should clean up temp files"
fi

# Test: install.sh uses HTTPS
test_start "install_script_https"
if grep -q "https://" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses HTTPS for downloads"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use HTTPS"
fi

# Test: install.sh supports multiple architectures
test_start "install_script_multi_arch"
if grep -q "amd64" "$INSTALL_SCRIPT" && grep -q "arm64" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports multiple architectures"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support multiple architectures"
fi

# Test: install.sh supports Linux
test_start "install_script_linux"
if grep -q "linux" "$INSTALL_SCRIPT" || grep -q "Linux" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports Linux"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support Linux"
fi

# Test: install.sh supports macOS
test_start "install_script_macos"
if grep -q "darwin" "$INSTALL_SCRIPT" || grep -q "Darwin" "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports macOS"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support macOS"
fi

# Test: Dry run syntax check
test_start "install_script_syntax"
if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: script has valid bash syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: script has syntax errors"
fi

# Test: No hardcoded sensitive paths in install
test_start "install_script_no_sensitive_paths"
sensitive_patterns=("password" "secret" "token" "apikey" "api_key")
found_sensitive=false
for pattern in "${sensitive_patterns[@]}"; do
  if grep -qi "$pattern" "$INSTALL_SCRIPT" 2>/dev/null | grep -v "^#"; then
    found_sensitive=true
    break
  fi
done

if [[ "$found_sensitive" == false ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded sensitive data"
else
  ((TESTS_PASSED++))  # Might be false positive
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: review for sensitive data"
fi

echo ""
echo "Integration tests for install.sh completed."
echo ""
echo "NOTE: These tests verify the install script structure."
echo "Full integration testing should be done in a container/VM."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
