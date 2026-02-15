#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

args=()
if [[ -n "${DOTFILES_CHEZMOI_UPDATE_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_UPDATE_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

ui_logo_dot "Dot Update • Chezmoi"
ui_info "Updating dotfiles..."
chezmoi update "${args[@]}"
