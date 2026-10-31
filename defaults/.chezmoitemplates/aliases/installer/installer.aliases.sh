# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Installer & Teleport Aliases

# Run the local installer (self-update/bootstrap)
alias dot-install='bash "${DOTFILES_DIR:-$HOME/.dotfiles}/install.sh"'

# Teleport config to a remote host
# Usage: dot-teleport user@host
alias telegram='bash "${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/ops/teleport.sh"'
alias dot-teleport='telegram'
