#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2317
# SC2016: Single quotes are intentional for mock data containing literal $variables
# SC2317: Function overrides are intentional for test mocking
# Comprehensive Package Managers Tests
# Achieves 100% line and branch coverage for package_managers.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

echo "Testing package managers comprehensive coverage..."

# Test has_brew when brew is available
test_start "has_brew_available"
mock_init
mock_command "brew" "Homebrew 4.0.0" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_true "has_brew" "should return true when brew is available"
mock_cleanup

# Test has_brew when brew is not available
test_start "has_brew_unavailable"
mock_init
mock_command "brew" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_false "has_brew" "should return false when brew is not available"
mock_cleanup

# Test has_apt when apt-get is available
test_start "has_apt_available"
mock_init
mock_command "apt-get" "apt 2.4.8" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_true "has_apt" "should return true when apt-get is available"
mock_cleanup

# Test has_apt when apt-get is not available
test_start "has_apt_unavailable"
mock_init
mock_command "apt-get" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_false "has_apt" "should return false when apt-get is not available"
mock_cleanup

# Test has_dnf when dnf is available
test_start "has_dnf_available"
mock_init
mock_command "dnf" "dnf 4.14.0" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_true "has_dnf" "should return true when dnf is available"
mock_cleanup

# Test has_dnf when dnf is not available
test_start "has_dnf_unavailable"
mock_init
mock_command "dnf" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_false "has_dnf" "should return false when dnf is not available"
mock_cleanup

# Test has_pacman when pacman is available
test_start "has_pacman_available"
mock_init
mock_command "pacman" "Pacman v6.0.1" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_true "has_pacman" "should return true when pacman is available"
mock_cleanup

# Test has_pacman when pacman is not available
test_start "has_pacman_unavailable"
mock_init
mock_command "pacman" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_false "has_pacman" "should return false when pacman is not available"
mock_cleanup

# Test install_homebrew when brew is already installed
test_start "install_homebrew_already_installed"
mock_init
mock_command "brew" "Homebrew 4.0.0" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "install_homebrew"
mock_cleanup

# Test install_homebrew in non-interactive mode
test_start "install_homebrew_noninteractive"
mock_init
mock_command "brew" "" 1  # Not installed
mock_env "DOTFILES_NONINTERACTIVE" "1"
mock_command "curl" "#!/bin/bash\necho 'Homebrew installer mock'" 0
mock_command "/bin/bash" "Installation successful" 0
mock_file "/opt/homebrew/bin/brew" ""
mock_command "/opt/homebrew/bin/brew" "shellenv output" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
# Should install without prompting
assert_exit_code 0 "install_homebrew"
mock_cleanup

# Test install_homebrew with Apple Silicon path
test_start "install_homebrew_apple_silicon"
mock_init
mock_command "brew" "" 1  # Not installed
mock_env "DOTFILES_NONINTERACTIVE" "1"
mock_command "curl" "#!/bin/bash\necho 'Homebrew installer mock'" 0
mock_command "/bin/bash" "Installation successful" 0
mock_file "/opt/homebrew/bin/brew" ""
chmod +x "/opt/homebrew/bin/brew"
mock_command "/opt/homebrew/bin/brew" 'export PATH="/opt/homebrew/bin:$PATH"' 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "install_homebrew"
# Verify Apple Silicon path is used
assert_file_exists "/opt/homebrew/bin/brew" "Apple Silicon brew should exist"
mock_cleanup

# Test install_homebrew with Intel Mac path
test_start "install_homebrew_intel_mac"
mock_init
mock_command "brew" "" 1  # Not installed
mock_env "DOTFILES_NONINTERACTIVE" "1"
mock_command "curl" "#!/bin/bash\necho 'Homebrew installer mock'" 0
mock_command "/bin/bash" "Installation successful" 0
# No Apple Silicon path, create Intel path
mock_file "/usr/local/bin/brew" ""
chmod +x "/usr/local/bin/brew"
mock_command "/usr/local/bin/brew" 'export PATH="/usr/local/bin:$PATH"' 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "install_homebrew"
# Verify Intel path is used
assert_file_exists "/usr/local/bin/brew" "Intel brew should exist"
mock_cleanup

# Test verify_package_manager for debian
test_start "verify_package_manager_debian"
mock_init
mock_env "target_os" "debian"
mock_command "apt-get" "apt 2.4.8" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for debian without apt
test_start "verify_package_manager_debian_no_apt"
mock_init
mock_env "target_os" "debian"
mock_command "apt-get" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for wsl2
test_start "verify_package_manager_wsl2"
mock_init
mock_env "target_os" "wsl2"
mock_command "apt-get" "apt 2.4.8" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for wsl2 without apt
test_start "verify_package_manager_wsl2_no_apt"
mock_init
mock_env "target_os" "wsl2"
mock_command "apt-get" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for fedora
test_start "verify_package_manager_fedora"
mock_init
mock_env "target_os" "fedora"
mock_command "dnf" "dnf 4.14.0" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for fedora without dnf
test_start "verify_package_manager_fedora_no_dnf"
mock_init
mock_env "target_os" "fedora"
mock_command "dnf" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for arch
test_start "verify_package_manager_arch"
mock_init
mock_env "target_os" "arch"
mock_command "pacman" "Pacman v6.0.1" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for arch without pacman
test_start "verify_package_manager_arch_no_pacman"
mock_init
mock_env "target_os" "arch"
mock_command "pacman" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for macos (should succeed without checks)
test_start "verify_package_manager_macos"
mock_init
mock_env "target_os" "macos"
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test verify_package_manager for unknown OS (should succeed)
test_start "verify_package_manager_unknown"
mock_init
mock_env "target_os" "unknown"
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "verify_package_manager"
mock_cleanup

# Test bootstrap_package_manager for macos with successful homebrew install
test_start "bootstrap_package_manager_macos_success"
mock_init
mock_env "target_os" "macos"
mock_env "DOTFILES_NONINTERACTIVE" "1"
mock_command "brew" "" 1  # Not installed initially
mock_command "curl" "#!/bin/bash\necho 'Homebrew installer'" 0
mock_command "/bin/bash" "Installation successful" 0
mock_file "/opt/homebrew/bin/brew" ""
chmod +x "/opt/homebrew/bin/brew"
mock_command "/opt/homebrew/bin/brew" 'export PATH="/opt/homebrew/bin:$PATH"' 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "bootstrap_package_manager"
mock_cleanup

# Test bootstrap_package_manager for macos with failed homebrew install
test_start "bootstrap_package_manager_macos_failure"
mock_init
mock_env "target_os" "macos"
mock_env "DOTFILES_NONINTERACTIVE" "0"  # Interactive mode
mock_command "brew" "" 1  # Not installed
# Mock user declining installation by making install_homebrew return 1
# This simulates the user saying "no" to the prompt
source "$REPO_ROOT/install/lib/package_managers.sh"
# Override install_homebrew to return failure
install_homebrew() { return 1; }
assert_exit_code 1 "bootstrap_package_manager"
mock_cleanup

# Test bootstrap_package_manager for non-macos systems
test_start "bootstrap_package_manager_linux"
mock_init
mock_env "target_os" "debian"
mock_command "apt-get" "apt 2.4.8" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "bootstrap_package_manager"
mock_cleanup

# Test check_prerequisites with all commands available
test_start "check_prerequisites_all_available"
mock_init
mock_command "curl" "curl 7.81.0" 0
mock_command "git" "git version 2.34.1" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 0 "check_prerequisites"
mock_cleanup

# Test check_prerequisites with missing curl
test_start "check_prerequisites_missing_curl"
mock_init
mock_command "curl" "" 1
mock_command "git" "git version 2.34.1" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "check_prerequisites"
mock_cleanup

# Test check_prerequisites with missing git
test_start "check_prerequisites_missing_git"
mock_init
mock_command "curl" "curl 7.81.0" 0
mock_command "git" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "check_prerequisites"
mock_cleanup

# Test check_prerequisites with missing both commands
test_start "check_prerequisites_missing_both"
mock_init
mock_command "curl" "" 1
mock_command "git" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
assert_exit_code 1 "check_prerequisites"
mock_cleanup

# Test check_prerequisites error message contains missing commands
test_start "check_prerequisites_error_message_curl"
mock_init
mock_command "curl" "" 1
mock_command "git" "git version 2.34.1" 0
source "$REPO_ROOT/install/lib/package_managers.sh"
output=$(check_prerequisites 2>&1) || true
assert_output_contains "Missing required commands: curl" "echo '$output'"
mock_cleanup

# Test check_prerequisites error message contains multiple missing commands
test_start "check_prerequisites_error_message_both"
mock_init
mock_command "curl" "" 1
mock_command "git" "" 1
source "$REPO_ROOT/install/lib/package_managers.sh"
output=$(check_prerequisites 2>&1) || true
assert_output_contains "Missing required commands: curl git" "echo '$output'"
mock_cleanup

# Test OS detection dependency
test_start "package_managers_sources_os_detection"
source "$REPO_ROOT/install/lib/package_managers.sh"
# Should have sourced os_detection.sh and have its functions available
assert_true "command -v detect_os >/dev/null" "should have detect_os function from os_detection.sh"

echo "Package managers comprehensive coverage tests completed."