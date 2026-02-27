# shellcheck shell=bash
# Copyright (c) 2015-2026. All rights reserved.
# Version: 0.2.491
# Website: https://dotfiles.io
# License: MIT

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

# Note: This script assumes editor.sh has already been sourced
# to set up EDITOR, VISUAL, and other editor environment variables.

# Common editor aliases that work with any editor
alias e='${EDITOR}'
alias edit='${EDITOR}'
alias editor='${EDITOR}'
alias mate='${EDITOR}'
alias n='${EDITOR}'
if ! alias v >/dev/null 2>&1; then
  alias v='${EDITOR}'
fi

# Legacy editor aliases are opt-in.
: "${DOTFILES_LEGACY_EDITOR_ALIASES:=0}"

# Editor-specific aliases based on the current EDITOR/VISUAL
if [[ -n "${EDITOR}" ]]; then
  case "${EDITOR}" in
    nvim | */nvim)
      # Neovim aliases
      if [[ "${DOTFILES_LEGACY_EDITOR_ALIASES}" == "1" ]]; then
        alias vi="nvim"
        alias vim="nvim"
      fi
      alias nvimrc='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimlua='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimconf='nvim "${HOME}/.config/nvim"'
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
      nanoedit() { nano -l -S "$@"; }
      if [[ "${DOTFILES_LEGACY_EDITOR_ALIASES}" == "1" ]]; then
        alias ne="nanoedit"
      fi
      ;;
    emacs | */emacs)
      # Emacs aliases
      alias emacs-nw="emacs -nw"
      alias emacsc="emacsclient"
      alias emacsrc="emacs ~/.emacs"
      if [[ "${DOTFILES_LEGACY_EDITOR_ALIASES}" == "1" ]]; then
        alias em="emacs"
        alias et="emacs -nw" # Terminal mode
      fi
      ;;
    subl | */subl)
      # Sublime Text aliases
      if [[ "${DOTFILES_LEGACY_EDITOR_ALIASES}" == "1" ]]; then
        if ! alias st >/dev/null 2>&1; then
          alias st="subl"
        fi
      fi
      alias stt="subl ."  # Open current directory
      alias stn="subl -n" # Open in new window
      ;;
  esac
fi

# Quick edit function to edit common configuration files
editrc() {
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
