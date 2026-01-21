#!/usr/bin/env bash
# Installer & Teleport Aliases

# Run the local installer (self-update/bootstrap)
alias dot-install='bash $HOME/.local/share/chezmoi/install.sh'

# Teleport config to a remote host
# Usage: dot-teleport user@host
alias telegram='bash $HOME/.local/share/chezmoi/scripts/teleport.sh'
alias dot-teleport='telegram'
