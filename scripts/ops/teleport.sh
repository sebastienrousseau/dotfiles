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

# Validate SSH target: must be user@host format, no shell metacharacters
if [[ ! "$TARGET" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$ ]]; then
  echo "Invalid SSH target: $TARGET" >&2
  echo "Expected format: user@hostname (alphanumeric, dots, hyphens, underscores only)" >&2
  exit 1
fi

echo " Teleporting dotfiles to ${TARGET}..."

# 1. Archive the current state
# 2. Pipe to SSH
# 3. Extract in remote home directory with safety flags
#    --no-same-owner: don't try to preserve owner (non-root)
#    --strip-components=0: don't strip path components
chezmoi archive | ssh "$TARGET" 'tar xz -C "$HOME" --no-same-owner'

echo " Teleport successful!"
echo "   Note: Changes are applied to files, but shell may need restart or sourcing."
