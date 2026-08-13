#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Idempotency Unit Test for Font Installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FONT_INSTALL_SCRIPT="$REPO_ROOT/install/provision/run_onchange_50-install-fonts.sh"
FONT_CHECK_SCRIPT="$REPO_ROOT/defaults/run_onchange_after_fonts.sh"

# Load test framework
source "$REPO_ROOT/tests/framework/assertions.sh"

test_start "font_hooks_normalize_chezmoi_defaults_source"
assert_file_contains "$FONT_INSTALL_SCRIPT" 'basename "$SOURCE_ROOT")" == "defaults"' \
  "font installer should normalize a chezmoi defaults source path"
assert_file_contains "$FONT_CHECK_SCRIPT" 'basename "$SOURCE_ROOT")" == "defaults"' \
  "font checker should normalize a chezmoi defaults source path"

test_start "font_idempotency"

# Mock environment
MOCK_HOME=$(mktemp -d)
export HOME="$MOCK_HOME"
export DOTFILES_SILENT=1
export DOTFILES_SOURCE_DIR="$REPO_ROOT/defaults"

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

cat >"$MOCK_BIN/curl" <<'EOF'
#!/bin/sh
set -eu
destination=""
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) destination="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
if [ "${url##*/}" = "SHA-256.txt" ]; then
  digest="$(printf 'fake archive' | shasum -a 256 | awk '{print $1}')"
  printf '%s  JetBrainsMono.zip\n%s  NerdFontsSymbolsOnly.zip\n' "$digest" "$digest" >"$destination"
else
  printf 'fake archive' >"$destination"
fi
EOF
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
