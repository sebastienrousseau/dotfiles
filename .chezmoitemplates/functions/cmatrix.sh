# shellcheck shell=bash
# CMatrix wrapper with defaults

cmatrix() {
  local src_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if [[ ! -d "$src_dir" ]]; then
    src_dir="$HOME/.local/share/chezmoi"
  fi
  local script="$src_dir/scripts/tools/cmatrix.sh"
  if [[ -x "$script" ]]; then
    "$script" "$@"
  else
    command cmatrix "$@"
  fi
}
