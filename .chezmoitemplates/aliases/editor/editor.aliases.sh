# shellcheck shell=bash
# Copyright (c) 2015-2026. All rights reserved.
# Website: https://dotfiles.io
# License: MIT

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

# Note: This script assumes editor.sh has already been sourced
# to set up EDITOR, VISUAL, and other editor environment variables.

# Common editor aliases that work with any editor
alias e='${EDITOR}'
if [[ "${DOTFILES_LEGACY_EDITOR_ALIASES:-0}" == "1" ]]; then
  alias editor='${EDITOR}'
fi
if ! alias v >/dev/null 2>&1; then
  alias v='${EDITOR}'
fi

# Set vi/vim fallback once (avoids duplicate alias definitions in governance).
dot_editor_cmd() {
  if command -v nvim >/dev/null 2>&1; then
    nvim "$@"
    return
  fi
  if command -v vim >/dev/null 2>&1; then
    vim "$@"
    return
  fi
  "${EDITOR:-vi}" "$@"
}
alias vim='dot_editor_cmd'

vconf() {
  cd "${HOME}/.config/nvim" 2>/dev/null || cd "${HOME}/.vim" 2>/dev/null || return 1
}

# Editor-specific aliases based on the current EDITOR/VISUAL
if [[ -n "${EDITOR}" ]]; then
  case "${EDITOR}" in
    nvim | */nvim)
      # Neovim aliases
      alias nvimrc='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimconf='nvim "${HOME}/.config/nvim"'
      ;;
    vim | */vim)
      # Vim aliases
      alias vimrc='vim "${HOME}/.vimrc"'
      alias vimconf='vim "${HOME}/.vim"'
      ;;
    code | */code)
      # VS Code aliases
      alias vsc="code"
      alias vsca="code --add"
      alias vscd="code --diff"
      alias vscn="code --new-window"
      alias vscr="code --reuse-window"
      alias vscu="code --user-data-dir"
      alias vsced="code --extensions-dir"
      alias vscex="code --install-extension"
      alias vsclist="code --list-extensions"
      ;;
    nano | */nano)
      # Nano aliases
      alias nanorc='nano "${HOME}/.nanorc"'
      # Enhanced nano with line numbers and smooth scrolling
      function nanoedit() { nano -l -S "$@"; }
      alias ne="nanoedit"
      ;;
    emacs | */emacs)
      # Emacs aliases
      alias em="emacs"
      alias emacs-nw="emacs -nw"
      alias emacsc="emacsclient"
      alias emacsrc="emacs ~/.emacs"
      alias et="emacs -nw" # Terminal mode
      ;;
    subl | */subl)
      # Sublime Text aliases
      alias sublcmd="subl"
      alias stt="subl ."  # Open current directory
      alias stn="subl -n" # Open in new window
      ;;
    atom | */atom)
      # Atom aliases
      alias a="atom"
      alias at="atom ."
      alias an="atom -n"
      ;;
  esac
fi

# Quick edit function to edit common configuration files
function editrc() {
  case "$1" in
    bash) "${EDITOR}" "${HOME}/.bashrc" ;;
    zsh) "${EDITOR}" "${HOME}/.zshrc" ;;
    vim) "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    nvim) "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    tmux) "${EDITOR}" "${HOME}/.tmux.conf" ;;
    git) "${EDITOR}" "${HOME}/.gitconfig" ;;
    ssh) "${EDITOR}" "${HOME}/.ssh/config" ;;
    alias) "${EDITOR}" "${HOME}/.dotfiles/aliases" ;;
    dotfiles) "${EDITOR}" "${HOME}/.dotfiles" ;;
    *) echo "Usage: editrc [bash|zsh|vim|nvim|tmux|git|ssh|alias|dotfiles]" ;;
  esac
}
