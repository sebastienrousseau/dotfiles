#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Uninstall dotfiles and clean up all artifacts.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# remove_tree <dir>: rm -rf, retried once. On macOS Finder or a sync client
# can drop a .DS_Store into a directory while rm -rf empties it, failing
# "Directory not empty".
remove_tree() {
  rm -rf "$1" 2>/dev/null || {
    sleep 0.2
    rm -rf "$1"
  }
}

# remove_chezmoi_config <dir>: remove chezmoi's config directory but keep
# any age identity in it (a file with an AGE-SECRET-KEY line, whatever its
# name): without it the secrets this setup encrypted cannot be decrypted,
# and nothing else holds a copy.
remove_chezmoi_config() {
  local f
  [[ -d "$1" ]] || return 0
  while IFS= read -r -d '' f; do
    if grep -q '^AGE-SECRET-KEY-' "$f" 2>/dev/null; then
      log_warn "Kept your age key: $f (delete it once you no longer need the secrets it decrypts)"
    else
      rm -f "$f"
    fi
  done < <(find "$1" ! -type d -print0)
  find "$1" -depth -type d -empty -delete 2>/dev/null || true
}

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

# chezmoi purge is not used: it deletes chezmoi's whole config directory,
# the age key with it. Its other removals are steps 2 and 3. Deployed
# files stay where they are, as they would after purge. A source directory
# configured elsewhere may be the user's own repository: it is named at the
# end, not deleted.
src_dir=""
if command -v chezmoi >/dev/null 2>&1; then
  src_dir="$(chezmoi source-path 2>/dev/null || true)"
fi

# 2. Remove dotfiles repo
if [[ -d "$HOME/.dotfiles" ]]; then
  log_info "Removing ~/.dotfiles repository..."
  remove_tree "$HOME/.dotfiles"
fi

# 3. Remove chezmoi config, state and cache (the age key stays)
log_info "Removing chezmoi configuration..."
remove_chezmoi_config "${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi"

# 4. Remove dotfiles artifacts
log_info "Removing dotfiles artifacts..."
for bin in dot dot-ai dot-theme-sync tour ai_core ai-update antigravity git-ai-commit git-ai-diff; do
  rm -f "$HOME/.local/bin/$bin"
done

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

if [[ -n "$src_dir" && -d "$src_dir" ]]; then
  log_warn "Left in place: $src_dir (chezmoi's source directory; delete it yourself if you no longer need it)"
fi

echo ""
log_info "Uninstall complete."
log_info "You may need to manually:"
log_info "  - Remove mise tools: mise implode"
log_info "  - Reset your shell: chsh -s /bin/zsh"
log_info "  - Restart your terminal"
