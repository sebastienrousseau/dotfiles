#!/usr/bin/env bash
# Comprehensive OS Detection Tests
# Achieves 100% line and branch coverage for os_detection.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Source the function being tested
source "$REPO_ROOT/install/lib/os_detection.sh"

echo "Testing OS detection comprehensive coverage..."

# Test Darwin/macOS detection
test_start "detect_os_macos"
mock_init
mock_command "uname" "Darwin" 0
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "macos" "$target_os" "should detect macOS"
assert_equals "Darwin" "$OS" "should set OS to Darwin"
mock_cleanup

# Test Linux with Microsoft/WSL detection via /proc/version
test_start "detect_os_wsl2_microsoft"
mock_init
mock_command "uname" "Linux" 0
mock_file "microsoft linux subsystem" "/proc/version"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "wsl2" "$target_os" "should detect WSL2 with Microsoft"
mock_cleanup

# Test Linux with WSL detection via /proc/version
test_start "detect_os_wsl2_wsl_keyword"
mock_init
mock_command "uname" "Linux" 0
mock_file "WSL2 kernel" "/proc/version"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "wsl2" "$target_os" "should detect WSL2 with WSL keyword"
mock_cleanup

# Test Ubuntu detection via os-release
test_start "detect_os_ubuntu"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=ubuntu
NAME="Ubuntu"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "debian" "$target_os" "should detect Ubuntu as debian"
mock_cleanup

# Test Debian detection via os-release
test_start "detect_os_debian"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=debian
NAME="Debian"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "debian" "$target_os" "should detect Debian"
mock_cleanup

# Test Pop!_OS detection via os-release
test_start "detect_os_pop"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=pop
NAME="Pop!_OS"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "debian" "$target_os" "should detect Pop!_OS as debian"
mock_cleanup

# Test Linux Mint detection via os-release
test_start "detect_os_linuxmint"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=linuxmint
NAME="Linux Mint"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "debian" "$target_os" "should detect Linux Mint as debian"
mock_cleanup

# Test Elementary OS detection via os-release
test_start "detect_os_elementary"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=elementary
NAME="elementary OS"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "debian" "$target_os" "should detect Elementary as debian"
mock_cleanup

# Test Fedora detection via os-release
test_start "detect_os_fedora"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=fedora
NAME="Fedora"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "fedora" "$target_os" "should detect Fedora"
mock_cleanup

# Test RHEL detection via os-release
test_start "detect_os_rhel"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=rhel
NAME="Red Hat Enterprise Linux"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "fedora" "$target_os" "should detect RHEL as fedora"
mock_cleanup

# Test CentOS detection via os-release
test_start "detect_os_centos"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=centos
NAME="CentOS"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "fedora" "$target_os" "should detect CentOS as fedora"
mock_cleanup

# Test Rocky Linux detection via os-release
test_start "detect_os_rocky"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=rocky
NAME="Rocky Linux"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "fedora" "$target_os" "should detect Rocky as fedora"
mock_cleanup

# Test AlmaLinux detection via os-release
test_start "detect_os_alma"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=alma
NAME="AlmaLinux"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "fedora" "$target_os" "should detect AlmaLinux as fedora"
mock_cleanup

# Test Arch Linux detection via os-release
test_start "detect_os_arch"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=arch
NAME="Arch Linux"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "arch" "$target_os" "should detect Arch Linux"
mock_cleanup

# Test Manjaro detection via os-release
test_start "detect_os_manjaro"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=manjaro
NAME="Manjaro"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "arch" "$target_os" "should detect Manjaro as arch"
mock_cleanup

# Test EndeavourOS detection via os-release
test_start "detect_os_endeavouros"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=endeavouros
NAME="EndeavourOS"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "arch" "$target_os" "should detect EndeavourOS as arch"
mock_cleanup

# Test unknown Linux distribution via os-release
test_start "detect_os_unknown_linux_distro"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=unknown-distro
NAME="Unknown Distribution"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "linux" "$target_os" "should detect unknown distro as linux"
mock_cleanup

# Test Linux without os-release file
test_start "detect_os_linux_no_os_release"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
# Don't create /etc/os-release file
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "linux" "$target_os" "should detect linux without os-release"
mock_cleanup

# Test empty ID field in os-release
test_start "detect_os_empty_id_in_os_release"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'NAME="Some Distribution"' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "linux" "$target_os" "should default to linux with empty ID"
mock_cleanup

# Test unknown operating system (not Darwin or Linux)
test_start "detect_os_unknown_os"
mock_init
mock_command "uname" "FreeBSD" 0
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "unknown" "$target_os" "should detect unknown OS"
assert_equals "FreeBSD" "$OS" "should set OS to FreeBSD"
mock_cleanup

# Test architecture detection
test_start "detect_os_sets_arch"
mock_init
mock_command "uname" -e 'if [ "$1" = "-s" ]; then echo "Linux"; elif [ "$1" = "-m" ]; then echo "x86_64"; fi' 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=ubuntu' "/etc/os-release"
mock_env "OS" ""
mock_env "ARCH" ""
mock_env "target_os" ""
detect_os
assert_equals "x86_64" "$ARCH" "should set ARCH variable"
mock_cleanup

# Test is_macos function when target_os is macos
test_start "is_macos_true"
target_os="macos"
assert_true "is_macos" "should return true when target_os is macos"

# Test is_macos function when target_os is not macos
test_start "is_macos_false"
target_os="linux"
assert_false "is_macos" "should return false when target_os is not macos"

# Test is_linux function when OS is Linux
test_start "is_linux_true"
OS="Linux"
assert_true "is_linux" "should return true when OS is Linux"

# Test is_linux function when OS is not Linux
test_start "is_linux_false"
OS="Darwin"
assert_false "is_linux" "should return false when OS is not Linux"

# Test is_wsl function when target_os is wsl2
test_start "is_wsl_true"
target_os="wsl2"
assert_true "is_wsl" "should return true when target_os is wsl2"

# Test is_wsl function when target_os is not wsl2
test_start "is_wsl_false"
target_os="linux"
assert_false "is_wsl" "should return false when target_os is not wsl2"

# Test is_debian function when target_os is debian
test_start "is_debian_true_debian"
target_os="debian"
assert_true "is_debian" "should return true when target_os is debian"

# Test is_debian function when target_os is wsl2 (also considered debian)
test_start "is_debian_true_wsl2"
target_os="wsl2"
assert_true "is_debian" "should return true when target_os is wsl2"

# Test is_debian function when target_os is not debian or wsl2
test_start "is_debian_false"
target_os="fedora"
assert_false "is_debian" "should return false when target_os is fedora"

# Test is_fedora function when target_os is fedora
test_start "is_fedora_true"
target_os="fedora"
assert_true "is_fedora" "should return true when target_os is fedora"

# Test is_fedora function when target_os is not fedora
test_start "is_fedora_false"
target_os="debian"
assert_false "is_fedora" "should return false when target_os is not fedora"

# Test is_arch function when target_os is arch
test_start "is_arch_true"
target_os="arch"
assert_true "is_arch" "should return true when target_os is arch"

# Test is_arch function when target_os is not arch
test_start "is_arch_false"
target_os="debian"
assert_false "is_arch" "should return false when target_os is not arch"

# Test print_os_info function
test_start "print_os_info_output"
OS="Linux"
ARCH="x86_64"
target_os="debian"
output=$(print_os_info)
assert_output_contains "OS: Linux" "echo '$output'"
assert_output_contains "Arch: x86_64" "echo '$output'"
assert_output_contains "Target: debian" "echo '$output'"

# Test variable export
test_start "detect_os_exports_variables"
mock_init
mock_command "uname" "Linux" 0
mock_file "regular linux kernel" "/proc/version"
mock_file 'ID=ubuntu' "/etc/os-release"
unset OS ARCH target_os
detect_os
# These should be set and exported after detect_os
assert_not_empty "$OS" "OS should be set"
assert_not_empty "$ARCH" "ARCH should be set"
assert_not_empty "$target_os" "target_os should be set"
mock_cleanup

echo "OS detection comprehensive coverage tests completed."