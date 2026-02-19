#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Install dotfiles utilities via Nix profile
# Usage: ./install_nix_profile.sh [package]
# Default package: dot-utils (all utilities)
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PACKAGE="${1:-dot-utils}"

# Check if Nix is installed
if ! command -v nix &>/dev/null; then
  echo "Error: Nix is not installed."
  echo "Install Nix first: https://nixos.org/download.html"
  echo ""
  echo "Quick install (multi-user):"
  echo "  sh <(curl -L https://nixos.org/nix/install) --daemon"
  exit 1
fi

# Check if flakes are enabled
if ! nix flake --help &>/dev/null 2>&1; then
  echo "Error: Nix flakes are not enabled."
  echo "Add the following to ~/.config/nix/nix.conf:"
  echo "  experimental-features = nix-command flakes"
  exit 1
fi

# Navigate to dotfiles nix directory
if [ ! -f "$DOTFILES_DIR/nix/flake.nix" ]; then
  echo "Error: flake.nix not found at $DOTFILES_DIR/nix/flake.nix"
  exit 1
fi

cd "$DOTFILES_DIR/nix"

echo "Installing $PACKAGE from dotfiles flake..."
echo ""

# Install the package
if [ "$PACKAGE" = "dot-utils" ]; then
  nix profile install ".#dot-utils"
  echo ""
  echo "Installed dot-utils meta-package with:"
  echo "  - git, zsh, neovim, tmux (core)"
  echo "  - ripgrep, fd, bat, fzf, zoxide, eza (search)"
  echo "  - lazygit, delta (git tools)"
  echo "  - jq, yq (data processing)"
  echo "  - age, gnupg (security)"
else
  nix profile install ".#$PACKAGE"
fi

echo ""
echo "Done! Restart your shell or run: exec zsh"
