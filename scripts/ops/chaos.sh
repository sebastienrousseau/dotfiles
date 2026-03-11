#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Chaos Engineering: Randomly corrupt config files to test self-healing (dot heal)
# USE WITH CAUTION: This intentionally breaks your environment.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
ui_init

if [[ "${1:-}" != "--force" ]]; then
  ui_err "WARNING" "This script will intentionally break your dotfiles configuration."
  ui_info "Purpose" "Tests 'dot heal' auto-repair capabilities."
  echo ""
  ui_info "To run, execute" "${0} --force"
  exit 1
fi

ui_warn "Initiating Chaos Engineering Sequence..."

# Target files for corruption/deletion
TARGETS=(
  "$HOME/.config/starship.toml"
  "$HOME/.zshrc"
  "$HOME/.config/alacritty/alacritty.toml"
)

# 1. Configuration Deletion
for target in "${TARGETS[@]}"; do
  if [[ -f "$target" ]] || [[ -L "$target" ]]; then
    ui_err "Destroying" "$target"
    rm -f "$target"
  fi
done

# 2. Symlink Corruption
ui_err "Creating" "broken symlinks..."
ln -sf /tmp/nonexistent_file_xyz "$HOME/.config/broken_symlink_test"

# 3. Path Mutation
ui_err "Corrupting" "PATH..."
export PATH="/bin"

echo ""
ui_ok "Chaos injected" "State is drifted and broken."
ui_info "Recover" "dot heal"
