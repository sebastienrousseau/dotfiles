#!/usr/bin/env bash
# Interactive setup for dotfiles preferences
# Usage: dot setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CONFIG_FILE="$CONFIG_DIR/chezmoi.toml"
BACKUP_FILE="$CONFIG_DIR/chezmoi.toml.bak.$(date +%Y%m%d_%H%M%S)"
mkdir -p "$CONFIG_DIR"

choose() {
  local prompt="$1"; shift
  if command -v gum >/dev/null 2>&1; then
    gum choose --cursor.foreground=212 --selected.foreground=212 --header "$prompt" "$@"
  else
    echo "$prompt"
    select opt in "$@"; do
      echo "$opt"
      return
    done
  fi
}

confirm() {
  local prompt="$1"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$prompt"
  else
    read -r -p "$prompt [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]]
  fi
}

ui_header "Dotfiles Setup"

profile=$(choose "Select profile" laptop desktop server minimal)

feature_zsh=true
feature_nvim=true
feature_tmux=true
feature_gui=true
feature_secrets=true

confirm "Enable Zsh config?" || feature_zsh=false
confirm "Enable Neovim config?" || feature_nvim=false
confirm "Enable tmux config?" || feature_tmux=false
confirm "Enable GUI extras (fonts/themes)?" || feature_gui=false
confirm "Enable secrets integration?" || feature_secrets=false

alias_profile=$(choose "Alias profile" standard minimal)
strict_mode=false
confirm "Enable strict alias governance?" && strict_mode=true

secrets_provider=$(choose "Secrets provider" auto sops onepassword bitwarden)

theme=$(choose "Theme" catppuccin-mocha catppuccin-latte)

if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  ui_info "Backup" "$BACKUP_FILE"
fi

cat >"$CONFIG_FILE" <<TOML
[data]
profile = "$profile"
theme = "$theme"

[data.features]
zsh = ${feature_zsh}
nvim = ${feature_nvim}
tmux = ${feature_tmux}
gui = ${feature_gui}
secrets = ${feature_secrets}

[data.aliases]
profile = "$alias_profile"

[data.aliases.policy]
strict_mode = ${strict_mode}

[data.aliases.buckets]
system = true
svn = true

[data.secrets]

[data.secrets.policy]
provider = "$secrets_provider"
auto_load = true
TOML

ui_ok "Config" "Updated $CONFIG_FILE"

if confirm "Apply dotfiles now?"; then
  if command -v chezmoi >/dev/null 2>&1; then
    chezmoi apply
    ui_ok "Apply" "Complete"
  else
    ui_warn "chezmoi" "Not installed"
  fi
fi
