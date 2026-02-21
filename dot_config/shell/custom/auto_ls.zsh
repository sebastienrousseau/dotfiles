# Auto-list directory contents on cd (zsh only)
# Uses eza when available, otherwise falls back to ls.

autoload -Uz add-zsh-hook

dot_auto_ls() {
  if command -v eza >/dev/null 2>&1; then
    eza -alF --sort Name --icons --group-directories-first
  else
    command ls -alF
  fi
}

add-zsh-hook chpwd dot_auto_ls
