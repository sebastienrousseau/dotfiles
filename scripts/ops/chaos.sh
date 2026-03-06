#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Chaos Engineering: Randomly corrupt config files to test self-healing (dot heal)
# USE WITH CAUTION: This intentionally breaks your environment.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [[ "${1:-}" != "--force" ]]; then
  echo -e "${RED}WARNING: This script will intentionally break your dotfiles configuration.${NC}"
  echo "It is designed to test the 'dot heal' auto-repair capabilities."
  echo ""
  echo "To run, execute: ${0} --force"
  exit 1
fi

echo -e "${YELLOW}Initiating Chaos Engineering Sequence...${NC}"

# Target files for corruption/deletion
TARGETS=(
  "$HOME/.config/starship.toml"
  "$HOME/.zshrc"
  "$HOME/.config/alacritty/alacritty.toml"
)

# 1. Configuration Deletion
for target in "${TARGETS[@]}"; do
  if [[ -f "$target" ]] || [[ -L "$target" ]]; then
    echo "💥 Destroying: $target"
    rm -f "$target"
  fi
done

# 2. Symlink Corruption
echo "💥 Creating broken symlinks..."
ln -sf /tmp/nonexistent_file_xyz "$HOME/.config/broken_symlink_test"

# 3. Path Mutation
echo "💥 Corrupting PATH..."
export PATH="/bin"

echo ""
echo -e "${GREEN}Chaos injected successfully.${NC}"
echo "Current state is drifted and broken. To recover, run:"
echo "  dot heal"
