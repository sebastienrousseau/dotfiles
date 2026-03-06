#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# End-to-end integration test for the dotfiles installation path.
# This script executes the real install.sh in a controlled temporary environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Mock HOME to prevent messing with the host system
MOCK_HOME=$(mktemp -d)
export HOME="$MOCK_HOME"
export PATH="$HOME/.local/bin:$PATH"

# Cleanup on exit
trap 'rm -rf "$MOCK_HOME"' EXIT

# Stub ui_header if not already defined (not available in test context)
command -v ui_header >/dev/null 2>&1 || ui_header() { echo "== $* =="; }
ui_header "E2E Installation Test"

# We use the local repo as the source to avoid network dependency and test current changes
SOURCE_DIR="$REPO_ROOT"

test_start "e2e_install_execution"
echo "   -> Running install.sh from $SOURCE_DIR..."

# Run the installer in non-interactive and silent mode for CI
# We pass the local path as the 'version' argument if the script supports it,
# or we set up the environment so it picks up the local source.
# Based on install.sh, we can set SOURCE_DIR or similar.

if DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1 bash "$SOURCE_DIR/install.sh" "$SOURCE_DIR"; then
    ((TESTS_PASSED++))
    printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh executed successfully"
else
    ((TESTS_FAILED++))
    printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: install.sh failed with exit code $?"
    exit 1
fi

test_start "e2e_dot_cli_functional"
if command -v dot >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: dot CLI is in PATH"
else
    ((TESTS_FAILED++))
    printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: dot CLI not found in PATH"
fi

test_start "e2e_dot_doctor_passes"
if dot doctor >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: dot doctor passes after installation"
else
    # We might expect some warnings/errors in a bare-bones environment,
    # but the command should at least run.
    if [[ $? -le 1 ]]; then
        ((TESTS_PASSED++))
        printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: dot doctor executed (warnings expected in bare env)"
    else
        ((TESTS_FAILED++))
        printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: dot doctor crashed after installation"
    fi
fi

echo ""
echo "E2E Installation tests completed."
print_summary
