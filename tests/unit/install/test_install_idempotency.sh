#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Idempotency Unit Test for Font Installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FONT_INSTALL_SCRIPT="$REPO_ROOT/install/provision/run_onchange_50-install-fonts.sh.tmpl"

# Load test framework
source "$REPO_ROOT/tests/framework/assertions.sh"

test_start "font_idempotency"

# Mock environment
MOCK_HOME=$(mktemp -d)
export HOME="$MOCK_HOME"
export DOTFILES_SILENT=1

# Prepare mock font directory
if [[ "$(uname)" == "Darwin" ]]; then
  FONT_DIR="$HOME/Library/Fonts"
else
  FONT_DIR="$HOME/.local/share/fonts"
fi
mkdir -p "$FONT_DIR"

# Case 1: First run (should install)
# We'll mock curl/unzip to avoid network/large files
MOCK_BIN=$(mktemp -d)
export PATH="$MOCK_BIN:$PATH"

echo "#!/bin/sh" >"$MOCK_BIN/curl"
echo "touch \$3" >>"$MOCK_BIN/curl" # mock -o/Lo behavior
chmod +x "$MOCK_BIN/curl"

echo "#!/bin/sh" >"$MOCK_BIN/unzip"
echo "exit 0" >>"$MOCK_BIN/unzip"
chmod +x "$MOCK_BIN/unzip"

echo "#!/bin/sh" >"$MOCK_BIN/fc-cache"
echo "exit 0" >>"$MOCK_BIN/fc-cache"
chmod +x "$MOCK_BIN/fc-cache"

output=$(bash "$FONT_INSTALL_SCRIPT" 2>&1)
assert_file_exists "$FONT_DIR/.nerd-fonts-version" "Marker file should be created after first run"

# Case 2: Second run (should skip)
export DOTFILES_SILENT=0
output=$(bash "$FONT_INSTALL_SCRIPT" 2>&1)
assert_contains "already installed. Skipping" "$output" "Should skip installation on second run"

# Cleanup
rm -rf "$MOCK_HOME" "$MOCK_BIN"
test_summary
