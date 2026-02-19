# shellcheck shell=bash
# Figlet banner generator

banner() {
  local src_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if [[ ! -d "$src_dir" ]]; then
    src_dir="$HOME/.local/share/chezmoi"
  fi
  local script="$src_dir/scripts/tools/figlet-banner.sh"
  if [[ -x "$script" ]]; then
    "$script" "$@"
  else
    echo "Banner script not found. Expected: $script" >&2
    return 1
  fi
}
