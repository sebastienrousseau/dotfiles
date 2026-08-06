#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Chezmoi Installation Library
# Handles chezmoi binary installation and configuration

set -euo pipefail

INSTALL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/verified-download.sh disable=SC1091
source "$INSTALL_LIB_DIR/../../lib/dot/verified-download.sh"

# Cross-platform sed in-place (BSD vs GNU)
sed_in_place() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@" # GNU
  else
    sed -i '' "$@" # BSD (macOS)
  fi
}

# Check if chezmoi is installed
has_chezmoi() {
  command -v chezmoi >/dev/null 2>&1
}

# Get chezmoi version
chezmoi_version() {
  chezmoi --version 2>/dev/null | head -1
}

# Install chezmoi via Homebrew
install_chezmoi_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi
  echo "   Installing chezmoi via Homebrew..."
  brew install chezmoi
}

# Install chezmoi via binary download
# Arguments:
#   $1 - Target binary directory (default: ~/.local/bin)
# shellcheck disable=SC2120
install_chezmoi_binary() {
  local bin_dir="${1:-$HOME/.local/bin}"
  mkdir -p "$bin_dir"

  echo "   Installing chezmoi via binary download..."
  printf '%b\n' "${CYAN:-}   SECURITY NOTE: Downloading from get.chezmoi.io with integrity check${NC:-}"

  # Download installer script first for inspection
  local installer
  installer=$(umask 077 && mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$installer'" RETURN

  if ! download_verified_script https://get.chezmoi.io "$installer" 102400; then
    rm -f "$installer"
    echo "Error: Failed to download chezmoi installer." >&2
    return 1
  fi

  # Execute the verified installer
  if ! sh "$installer" -- -b "$bin_dir" 2>/dev/null; then
    rm -f "$installer"
    echo "Error: Failed to install chezmoi." >&2
    return 1
  fi

  rm -f "$installer"

  # Add to PATH for the rest of the script
  export PATH="$bin_dir:$PATH"
  return 0
}

# Install chezmoi using the best available method
install_chezmoi() {
  if has_chezmoi; then
    echo "   chezmoi already installed: $(chezmoi_version)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    install_chezmoi_brew
  else
    install_chezmoi_binary
  fi
}

# Ensure chezmoi source directory is configured
# Arguments:
#   $1 - Source directory path
ensure_chezmoi_source() {
  local dir="$1"
  local config_dir="$HOME/.config/chezmoi"
  local config_file="$config_dir/chezmoi.toml"

  mkdir -p "$config_dir"

  # Escape sed metacharacters in replacement string
  local escaped_dir
  escaped_dir=$(printf '%s\n' "$dir" | sed -e 's/[\/&]/\\&/g')

  if [[ -f "$config_file" ]] && grep -q '^sourceDir' "$config_file"; then
    sed_in_place "s,^sourceDir.*$,sourceDir = \"$escaped_dir\"," "$config_file"
  else
    printf 'sourceDir = "%s"\n' "$dir" >"$config_file"
  fi
}

# Apply chezmoi configuration
# Arguments:
#   $1 - Source directory path
#   $2 - Non-interactive mode (0 or 1)
apply_chezmoi() {
  local source_dir="$1"
  local non_interactive="${2:-0}"
  local governance_script

  ensure_chezmoi_source "$source_dir"

  local apply_flags=()
  if [[ "$non_interactive" = "1" ]]; then
    apply_flags=(--force --no-tty)
  fi

  if [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" = "1" ]]; then
    governance_script="$source_dir/scripts/diagnostics/alias-governance.sh"
    if [[ -f "$governance_script" ]]; then
      DOTFILES_ALIAS_POLICY=strict bash "$governance_script"
    fi
  fi

  chezmoi apply "${apply_flags[@]}"
}

# Initialize chezmoi from a Git repository
# Arguments:
#   $1 - Target source directory
#   $2 - Git repository URL
#   $3 - Version/tag to checkout
init_chezmoi_from_git() {
  local source_dir="$1"
  local repo_url="$2"
  local version="$3"

  echo "   Initializing from GitHub (Branch/Tag: $version)..."
  printf '%b\n' "${CYAN:-}   SECURITY NOTE: Cloning pinned version $version for supply-chain safety${NC:-}"

  # Clone with specific tag for supply-chain security
  if ! git clone --depth 1 --branch "$version" "$repo_url" "$source_dir" 2>/dev/null; then
    git clone "$repo_url" "$source_dir"
    git -C "$source_dir" checkout "$version"
  fi

  # Verify the checkout succeeded (use git -C to avoid && chaining)
  local actual_ref
  if ! actual_ref=$(git -C "$source_dir" describe --tags --exact-match 2>/dev/null); then
    actual_ref=$(git -C "$source_dir" rev-parse --short HEAD)
  fi

  if [[ "$actual_ref" != "$version" ]] && [[ "${actual_ref#v}" != "${version#v}" ]]; then
    printf '%b\n' "${CYAN:-}   INFO: Checked out ref $actual_ref (requested: $version)${NC:-}"
  fi
}
