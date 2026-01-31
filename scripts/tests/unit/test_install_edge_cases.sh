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

# Test: install.sh checks for existing chezmoi before installing
test_start "install_chezmoi_check"
if grep -q 'command -v chezmoi' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for existing chezmoi"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for existing chezmoi"
fi

# Test: install.sh installs chezmoi via Homebrew when available
test_start "install_chezmoi_brew"
if grep -q 'brew install chezmoi' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: installs chezmoi via Homebrew when available"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should install chezmoi via Homebrew"
fi

# Test: install.sh falls back to get.chezmoi.io for binary install
test_start "install_chezmoi_fallback"
if grep -q 'get.chezmoi.io' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: falls back to get.chezmoi.io"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should fall back to get.chezmoi.io"
fi

# Test: install.sh adds ~/.local/bin to PATH for fallback install
test_start "install_path_update"
if grep -q 'export PATH=.*local/bin' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: adds ~/.local/bin to PATH"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should add ~/.local/bin to PATH"
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

# Test: install.sh backs up user dotfiles (not source repo)
test_start "install_backup_user_dotfiles"
if grep -q 'chezmoi managed' "$INSTALL_SCRIPT" && grep -q 'cp -a' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backs up files chezmoi will overwrite"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should back up managed dotfiles"
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

# Test: install.sh handles legacy source migration
test_start "install_legacy_migration"
if grep -q 'Migrating from legacy source' "$INSTALL_SCRIPT"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: migrates legacy chezmoi source directory"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle legacy source migration"
fi

echo ""
echo "install.sh edge case tests completed."
print_summary
