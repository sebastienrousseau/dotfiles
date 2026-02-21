# Auto-list directory contents on cd (zsh only)
# Uses eza when available, otherwise falls back to ls.

autoload -Uz add-zsh-hook

dot_auto_ls() {
  [[ -o interactive ]] || return
  [[ -t 1 ]] || return
  [[ "${DOTFILES_AUTO_LS:-1}" == "1" ]] || return
  [[ "${PWD}" == "${_DOTFILES_AUTO_LS_LAST:-}" ]] && return
  _DOTFILES_AUTO_LS_LAST="${PWD}"

  if command -v eza >/dev/null 2>&1; then
    eza -alF --sort Name --icons --group-directories-first
  else
    command ls -alF
  fi
}

add-zsh-hook chpwd dot_auto_ls
