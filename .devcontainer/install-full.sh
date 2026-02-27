#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
set -euo pipefail

# install-full.sh — Full dotfiles bootstrap for devcontainer / Codespaces
#
# Applies chezmoi-managed dotfiles with the "server" profile (headless, no GUI).
# Idempotent: safe to run multiple times.

# ---------- helpers --------------------------------------------------------- #

info() { printf '\033[1;34m[devcontainer]\033[0m %s\n' "$*"; }

# ---------- chezmoi init & apply ------------------------------------------- #

DOTFILES_REPO="https://github.com/sebastienrousseau/dotfiles.git"
DOTFILES_SOURCE="${HOME}/.dotfiles"

# Clone dotfiles if not already present (Codespaces clones the repo as workspace)
if [[ -d "/workspaces/dotfiles" ]]; then
  info "Using Codespaces workspace as dotfiles source"
  DOTFILES_SOURCE="/workspaces/dotfiles"
elif [[ ! -d "$DOTFILES_SOURCE" ]]; then
  info "Cloning dotfiles..."
  git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_SOURCE"
fi

# Create chezmoi config for container environment
mkdir -p "${HOME}/.config/chezmoi"
cat > "${HOME}/.config/chezmoi/chezmoi.toml" <<TOML
sourceDir = "${DOTFILES_SOURCE}"

[data]
profile = "${DOTFILES_PROFILE:-server}"
theme = "catppuccin-mocha"
git_name = "$(git config --global user.name 2>/dev/null || echo 'Developer')"
git_email = "$(git config --global user.email 2>/dev/null || echo 'dev@example.com')"
git_signingkey = ""
git_signingformat = "ssh"
age_identity = ""
age_recipient = ""
TOML

info "Applying dotfiles (profile: ${DOTFILES_PROFILE:-server})..."
chezmoi init --source="$DOTFILES_SOURCE" \
  --promptDefaults \
  --no-tty

chezmoi apply --exclude=scripts --no-tty 2>&1 || {
  info "Warning: Some files failed to apply (expected in container)"
}

# ---------- mise tool install ---------------------------------------------- #

if command -v mise >/dev/null 2>&1; then
  info "Installing mise tools..."
  mise install --yes 2>&1 || info "Warning: Some mise tools failed to install"
fi

# ---------- fd/bat aliases for Debian/Ubuntu ------------------------------- #

ZSHRC_LOCAL="${HOME}/.zshrc.local"
if [[ ! -f "$ZSHRC_LOCAL" ]] || ! grep -q 'devcontainer' "$ZSHRC_LOCAL" 2>/dev/null; then
  info "Writing container-specific overrides to .zshrc.local..."
  cat >> "$ZSHRC_LOCAL" <<'ZSHRC'
# devcontainer overrides
export DOTFILES_CONTAINER=1

# fd-find / batcat aliases for Debian/Ubuntu
command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && alias fd='fdfind'
command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && alias bat='batcat'

# Activate mise if available
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
ZSHRC
fi

info "Dotfiles bootstrap complete."
info "Profile: ${DOTFILES_PROFILE:-server} | Theme: catppuccin-mocha"
