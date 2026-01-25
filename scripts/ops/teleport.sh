#!/usr/bin/env bash
# Script: teleport.sh
# Description: Deploys dotfiles to a remote host ephemerally.
# Usage: ./teleport.sh user@hostname

set -e

TARGET="$1"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 user@host"
    exit 1
fi

echo " Teleporting dotfiles to ${TARGET}..."

# 1. Archive the current state
# 2. Pipe to SSH
# 3. Extract in remote home directory
chezmoi archive | ssh "$TARGET" "tar xz -C ~"

echo " Teleport successful!"
echo "   Note: Changes are applied to files, but shell may need restart or sourcing."
