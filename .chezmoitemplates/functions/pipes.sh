# shellcheck shell=bash
# Terminal pipes screensaver

pipes() {
  local src_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if [[ ! -d "$src_dir" ]]; then
    src_dir="$HOME/.local/share/chezmoi"
  fi
  local script="$src_dir/scripts/tools/pipes.sh"
  if [[ -x "$script" ]]; then
    "$script" "$@"
  else
    echo "pipes script not found. Expected: $script" >&2
    return 1
  fi
}
