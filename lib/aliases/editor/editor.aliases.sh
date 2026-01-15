#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT
# Script: editor.aliases.sh
# Version: 0.2.470
# Website: https://dotfiles.io

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

# Note: This script assumes editor.sh has already been sourced
# to set up EDITOR, VISUAL, and other editor environment variables.

# Common editor aliases that work with any editor
alias e='${EDITOR}'
alias edit='${EDITOR}'
alias editor='${EDITOR}'
alias mate='${EDITOR}'
alias n='${EDITOR}'
alias v='${EDITOR}'

# Editor-specific aliases based on the current EDITOR/VISUAL
if [[ -n "${EDITOR}" ]]; then
  case "${EDITOR}" in
    nvim|*/nvim)
      # Neovim aliases
      alias vi="nvim"
      alias vim="nvim"
      alias nvimrc='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimlua='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimconf='nvim "${HOME}/.config/nvim"'
      ;;
    code|*/code)
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
    nano|*/nano)
      # Nano aliases
      alias nanorc='nano "${HOME}/.nanorc"'
      # Enhanced nano with line numbers and smooth scrolling
      function nanoedit() { nano -l -S "$@"; }
      alias ne="nanoedit"
      ;;
    emacs|*/emacs)
      # Emacs aliases
      alias em="emacs"
      alias emacs-nw="emacs -nw"
      alias emacsc="emacsclient"
      alias emacsrc="emacs ~/.emacs"
      alias et="emacs -nw"  # Terminal mode
      ;;
    subl|*/subl)
      # Sublime Text aliases
      alias st="subl"
      alias stt="subl ."  # Open current directory
      alias stn="subl -n" # Open in new window
      ;;
    atom|*/atom)
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
    bash)     "${EDITOR}" "${HOME}/.bashrc" ;;
    zsh)      "${EDITOR}" "${HOME}/.zshrc" ;;
    vim)      "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    nvim)     "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    tmux)     "${EDITOR}" "${HOME}/.tmux.conf" ;;
    git)      "${EDITOR}" "${HOME}/.gitconfig" ;;
    ssh)      "${EDITOR}" "${HOME}/.ssh/config" ;;
    alias)    "${EDITOR}" "${HOME}/.dotfiles/aliases" ;;
    dotfiles) "${EDITOR}" "${HOME}/.dotfiles" ;;
    *)        echo "Usage: editrc [bash|zsh|vim|nvim|tmux|git|ssh|alias|dotfiles]" ;;
  esac
}
