#!/usr/bin/env bash
# Script: teleport.sh
# Description: Deploys dotfiles to a remote host ephemerally.
# Usage: ./teleport.sh user@hostname

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

TARGET="$1"

if [[ -z "$TARGET" ]]; then
  ui_logo_dot "Dot Teleport • Ops"
  ui_error "Usage: $0 user@host"
  exit 1
fi

# Validate SSH target: must be user@host format, no shell metacharacters
if [[ ! "$TARGET" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$ ]]; then
  ui_logo_dot "Dot Teleport • Ops"
  ui_error "Invalid SSH target: $TARGET"
  ui_info "Expected format: user@hostname (alphanumeric, dots, hyphens, underscores only)"
  exit 1
fi

ui_logo_dot "Dot Teleport • Ops"
ui_info "Teleporting dotfiles to ${TARGET}..."

# 1. Archive the current state
# 2. Pipe to SSH
# 3. Extract in remote home directory with safety flags
#    --no-same-owner: don't try to preserve owner (non-root)
#    --strip-components=0: don't strip path components
chezmoi archive | ssh "$TARGET" 'tar xz -C "$HOME" --no-same-owner'

ui_success "Teleport successful!"
ui_info "Note: Changes are applied to files, but shell may need restart or sourcing."
