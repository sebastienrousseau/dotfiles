#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test suite for executable_extract

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EXTRACT_BIN="$REPO_ROOT/dot_local/bin/executable_extract"

# Load test framework
source "$REPO_ROOT/scripts/tests/framework/assertions.sh"

test_start "extract_coverage"

# Mock directory
MOCK_BIN_DIR=$(mktemp -d)
PATH="$MOCK_BIN_DIR:$PATH"

# Helper to mock a command
mock_cmd() {
  local cmd=$1
  local exit_code=${2:-0}
  echo "#!/bin/sh" >"$MOCK_BIN_DIR/$cmd"
  echo "echo 'mocked $cmd' \$@" >>"$MOCK_BIN_DIR/$cmd"
  echo "exit $exit_code" >>"$MOCK_BIN_DIR/$cmd"
  chmod +x "$MOCK_BIN_DIR/$cmd"
}

# Ensure essential tools are available in MOCK_BIN_DIR
ln -s "$(command -v sh)" "$MOCK_BIN_DIR/sh"
ln -s "$(command -v echo)" "$MOCK_BIN_DIR/echo"
ln -s "$(command -v sed)" "$MOCK_BIN_DIR/sed"
ln -s "$(command -v grep)" "$MOCK_BIN_DIR/grep"

# Test all supported extensions
for ext in tar.bz2 tar.gz zip rar 7z tar.xz tar.zst; do
  test_start "extract_$ext"

  # Case 1: Tool exists
  case $ext in
    tar.*) mock_cmd "tar" ;;
    zip) mock_cmd "unzip" ;;
    rar) mock_cmd "unrar" ;;
    7z) mock_cmd "7z" ;;
  esac

  output=$(env -i PATH="$MOCK_BIN_DIR" sh "$EXTRACT_BIN" "test.$ext" 2>&1)
  assert_contains "mocked" "$output" "Should use native tool for $ext"

  # Clean up mock tool
  rm -f "$MOCK_BIN_DIR"/{tar,unzip,unrar,7z}
done

# Test Nix fallback
test_start "extract_nix_fallback"
mock_cmd "nix"
# Ensure no extraction tools exist in MOCK_BIN_DIR
rm -f "$MOCK_BIN_DIR"/{tar,unzip,unrar,7z}

output=$(env -i PATH="$MOCK_BIN_DIR" sh "$EXTRACT_BIN" "test.zip" 2>&1)
assert_contains "Using Nix fallback" "$output" "Should use Nix when tool is missing"
assert_contains "nix shell nixpkgs#unzip" "$output" "Should call nix shell for unzip"

# Test Fail path (No tool, no Nix)
test_start "extract_fail_path"
rm -f "$MOCK_BIN_DIR"/* # Remove all mocks including nix
ln -s "$(command -v sh)" "$MOCK_BIN_DIR/sh"
ln -s "$(command -v echo)" "$MOCK_BIN_DIR/echo"

output=$(env -i PATH="$MOCK_BIN_DIR" sh "$EXTRACT_BIN" "test.zip" 2>&1)
assert_contains "Nix not available" "$output" "Should fail when no tool and no Nix"

# Test Unknown extension
test_start "extract_unknown"
output=$(sh "$EXTRACT_BIN" "test.unknown" 2>&1)
assert_contains "cannot be extracted" "$output" "Should handle unknown extensions"

# Clean up
rm -rf "$MOCK_BIN_DIR"

test_summary
