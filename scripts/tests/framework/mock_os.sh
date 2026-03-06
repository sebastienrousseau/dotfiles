#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# OS Mocking Framework for Shell Tests
# Allows simulating different platforms (macOS, Linux, WSL) regardless of host OS.

# Usage:
# source scripts/tests/framework/mock_os.sh
# mock_os "macos"
# ... run tests ...
# restore_os

ORIG_UNAME=$(command -v uname)
MOCK_BIN_DIR=$(mktemp -d)
export PATH="$MOCK_BIN_DIR:$PATH"

# Internal state
MOCKED_OS=""

mock_os() {
    local target_os="$1"
    MOCKED_OS="$target_os"

    # Mock uname
    case "$target_os" in
        macos)
            echo "#!/bin/sh" > "$MOCK_BIN_DIR/uname"
            echo "echo 'Darwin'" >> "$MOCK_BIN_DIR/uname"
            ;;
        linux|wsl)
            echo "#!/bin/sh" > "$MOCK_BIN_DIR/uname"
            echo "echo 'Linux'" >> "$MOCK_BIN_DIR/uname"
            ;;
        *)
            echo "#!/bin/sh" > "$MOCK_BIN_DIR/uname"
            echo "echo 'Unknown'" >> "$MOCK_BIN_DIR/uname"
            ;;
    esac
    chmod +x "$MOCK_BIN_DIR/uname"

    # Mock /proc/sys/kernel/osrelease if possible via a wrapper function
    # Note: we can't easily mock the file itself without LD_PRELOAD or similar,
    # but we can mock the functions that read it.

    if [[ "$target_os" == "wsl" ]]; then
        # Force dot_is_wsl to return true
        dot_is_wsl() { return 0; }
    else
        # Force dot_is_wsl to return false
        dot_is_wsl() { return 1; }
    fi
}

restore_os() {
    rm -f "$MOCK_BIN_DIR/uname"
    # Note: we don't remove MOCK_BIN_DIR from PATH here to avoid complexity,
    # but the mocks are gone.
    unset -f dot_is_wsl 2>/dev/null || true
}

cleanup_mock_framework() {
    rm -rf "$MOCK_BIN_DIR"
}
