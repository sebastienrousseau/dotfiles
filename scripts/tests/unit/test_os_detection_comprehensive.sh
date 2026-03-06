#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Comprehensive OS Detection Unit Tests
# Targets 100% coverage of platform.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load test framework
source "$REPO_ROOT/scripts/tests/framework/assertions.sh"
source "$REPO_ROOT/scripts/tests/framework/mock_os.sh"

# Note: We need to source platform.sh AFTER defining mock functions
# because it might be sourced multiple times or use cached results.
# To ensure coverage, we'll re-source it for each test case or use a fresh shell.

test_macos_detection() {
    test_start "macos_detection"
    mock_os "macos"

    # Define mocks locally to override platform.sh if it was already sourced
    dot_is_wsl() { return 1; }

    source "$REPO_ROOT/scripts/dot/lib/platform.sh"

    local platform_id
    platform_id=$(dot_platform_id)
    assert_equals "macos" "$platform_id" "Should detect macOS platform ID"

    local host_os
    host_os=$(dot_host_os)
    assert_equals "macos" "$host_os" "Should detect macOS host OS"

    restore_os
}

test_linux_detection() {
    test_start "linux_detection"
    mock_os "linux"

    dot_is_wsl() { return 1; }

    source "$REPO_ROOT/scripts/dot/lib/platform.sh"

    local platform_id
    platform_id=$(dot_platform_id)
    assert_equals "linux" "$platform_id" "Should detect Linux platform ID"

    local host_os
    host_os=$(dot_host_os)
    assert_equals "linux" "$host_os" "Should detect Linux host OS"

    restore_os
}

test_wsl_detection() {
    test_start "wsl_detection"
    mock_os "wsl"

    dot_is_wsl() { return 0; }

    source "$REPO_ROOT/scripts/dot/lib/platform.sh"

    local platform_id
    platform_id=$(dot_platform_id)
    assert_equals "wsl" "$platform_id" "Should detect WSL platform ID"

    local host_os
    host_os=$(dot_host_os)
    assert_equals "windows" "$host_os" "Should detect Windows as host OS in WSL"

    restore_os
}

test_path_translation() {
    test_start "path_translation_wsl"
    mock_os "wsl"
    dot_is_wsl() { return 0; }

    # Mock wslpath
    echo "#!/bin/sh" > "$MOCK_BIN_DIR/wslpath"
    echo "if [ \"\$1\" = \"-u\" ]; then echo \"/mnt/c/Users\"; else echo \"C:\\\\Users\"; fi" >> "$MOCK_BIN_DIR/wslpath"
    chmod +x "$MOCK_BIN_DIR/wslpath"

    source "$REPO_ROOT/scripts/dot/lib/platform.sh"

    local unix_path
    unix_path=$(dot_path_to_unix "C:\\Users")
    assert_equals "/mnt/c/Users" "$unix_path" "Should convert Windows path to Unix in WSL"

    local native_path
    native_path=$(dot_path_to_native "/mnt/c/Users")
    assert_equals "C:\\Users" "$native_path" "Should convert Unix path to Windows in WSL"

    rm -f "$MOCK_BIN_DIR/wslpath"
    restore_os
}

test_open_path_dispatch() {
    test_start "open_path_dispatch_macos"
    mock_os "macos"
    dot_is_wsl() { return 1; }

    echo "#!/bin/sh" > "$MOCK_BIN_DIR/open"
    echo "echo \"opened \$@\"" >> "$MOCK_BIN_DIR/open"
    chmod +x "$MOCK_BIN_DIR/open"

    source "$REPO_ROOT/scripts/dot/lib/platform.sh"

    local output
    output=$(dot_open_path "test.txt")
    assert_contains "opened test.txt" "$output" "Should use 'open' on macOS"

    rm -f "$MOCK_BIN_DIR/open"
    restore_os
}

# Run tests
test_macos_detection
test_linux_detection
test_wsl_detection
test_path_translation
test_open_path_dispatch

cleanup_mock_framework
test_summary
