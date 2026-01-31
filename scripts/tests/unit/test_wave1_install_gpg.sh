#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Unit tests for Wave 1: install.sh chezmoi installation strategy
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"

echo "Testing Wave 1: install.sh chezmoi installation..."

test_start "install_brew_chezmoi"
assert_file_contains "$INSTALL_SCRIPT" "brew install chezmoi" "should install chezmoi via Homebrew when available"

test_start "install_fallback_get_chezmoi"
assert_file_contains "$INSTALL_SCRIPT" "get.chezmoi.io" "should fall back to get.chezmoi.io"

test_start "install_chezmoi_already_installed"
assert_file_contains "$INSTALL_SCRIPT" "chezmoi already installed" "should detect existing chezmoi"

test_start "install_local_bin_path"
assert_file_contains "$INSTALL_SCRIPT" 'BIN_DIR="$HOME/.local/bin"' "should install to ~/.local/bin as fallback"

test_start "install_version_pinned"
# VERSION is used for the dotfiles tag, not chezmoi binary
assert_file_contains "$INSTALL_SCRIPT" 'VERSION=' "should pin dotfiles version"

test_start "install_source_dir_defined"
assert_file_contains "$INSTALL_SCRIPT" 'SOURCE_DIR="$HOME/.dotfiles"' "should define source directory"

echo ""
echo "Wave 1 install.sh chezmoi installation tests completed."
print_summary
