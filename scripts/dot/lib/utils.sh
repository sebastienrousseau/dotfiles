#!/usr/bin/env bash
# Dotfiles CLI Utilities
# Shared functions for dot command modules

# Resolve the dotfiles source directory
resolve_source_dir() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return
  fi
  if [ -d "$HOME/.dotfiles" ]; then
    echo "$HOME/.dotfiles"
    return
  fi
  if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "$HOME/.local/share/chezmoi"
    return
  fi
  echo ""
}

# Generic dispatcher: resolve source dir, find script, exec it.
# Usage: run_script <relative-script-path> <not-found-label> [args...]
run_script() {
  local script_rel="$1"
  local label="$2"
  shift 2
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  if [ -f "$src_dir/$script_rel" ]; then
    exec bash "$src_dir/$script_rel" "$@"
  else
    echo "$label not found." >&2
    exit 1
  fi
}

# Require source directory or exit
require_source_dir() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -z "$src_dir" ]; then
    echo "Dotfiles source not found." >&2
    exit 1
  fi
  echo "$src_dir"
}

# Check if a command exists
has_command() {
  command -v "$1" >/dev/null 2>&1
}

# Print error message and exit
die() {
  echo "Error: $1" >&2
  exit "${2:-1}"
}

# Print warning message
warn() {
  echo "Warning: $1" >&2
}

# Print info message
info() {
  echo "$1"
}
