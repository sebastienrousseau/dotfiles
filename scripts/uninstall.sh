#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Uninstall dotfiles and clean up all artifacts.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "Dotfiles Uninstall"
echo "=================="
echo ""
log_warn "This will remove all managed dotfiles and related artifacts."
echo ""

if [[ "${1:-}" != "--force" ]]; then
  printf "Continue? [y/N] "
  read -r confirm
  case "$confirm" in
    y | Y | yes) ;;
    *)
      echo "Aborted."
      exit 0
      ;;
  esac
fi

# 1. Revert chezmoi-managed files
if command -v chezmoi >/dev/null 2>&1; then
  log_info "Reverting chezmoi-managed files..."
  chezmoi purge --force 2>/dev/null || true
fi

# 2. Remove dotfiles repo
if [[ -d "$HOME/.dotfiles" ]]; then
  log_info "Removing ~/.dotfiles repository..."
  rm -rf "$HOME/.dotfiles"
fi

# 3. Remove chezmoi config and state
log_info "Removing chezmoi configuration..."
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"

# 4. Remove dotfiles artifacts
log_info "Removing dotfiles artifacts..."
rm -f "$HOME/.local/bin/dot"
rm -f "$HOME/.local/bin/dot-ai"
rm -f "$HOME/.local/bin/dot-theme-sync"
rm -f "$HOME/.local/bin/tour"
rm -f "$HOME/.local/bin/ai_core"
rm -f "$HOME/.local/bin/ai-update"
rm -f "$HOME/.local/bin/antigravity"
rm -f "$HOME/.local/bin/git-ai-commit"
rm -f "$HOME/.local/bin/git-ai-diff"

# 5. Remove shell caches
log_info "Removing shell caches..."
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/bash"

# 6. Remove state and logs
log_info "Removing state and logs..."
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles.log"

# 7. Remove completions
log_info "Removing shell completions..."
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions/_dot"
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/dot"

echo ""
log_info "Uninstall complete."
log_info "You may need to manually:"
log_info "  - Remove mise tools: mise implode"
log_info "  - Reset your shell: chsh -s /bin/zsh"
log_info "  - Restart your terminal"
