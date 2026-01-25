#!/usr/bin/env bash
# Installer & Teleport Aliases

# Run the local installer (self-update/bootstrap)
alias dot-install='bash $HOME/.dotfiles/install.sh'

# Teleport config to a remote host
# Usage: dot-teleport user@host
alias telegram='bash $HOME/.dotfiles/scripts/ops/teleport.sh'
alias dot-teleport='telegram'
