#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

## 🆂🅷🅴🅻🅻

# Exit early for non-interactive shells
if [[ $- != *i* ]]; then return; fi

# Set a simple prompt for non-256color, non-Alacritty, and non-Kitty terminals
if [[ ${TERM} != *-256color* && ${TERM} != alacritty* && ${TERM} != *-kitty* ]]; then
  PS1='\h \w > '
  return
fi

# Bash prompt configuration
if [[ -n "${BASH_VERSION}" ]]; then
  # Define colors
  cyan='\[\033[1;96m\]'
  green='\[\033[1;92m\]'
  purple='\[\033[1;95m\]'
  reset='\[\033[0m\]'

  # Set prompt based on OS
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PS1="  $(uname)${purple} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"
  else
    PS1=" 🐧 $(uname)${purple} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"
  fi

  export PS1

# Zsh prompt configuration
elif [[ -n "${ZSH_VERSION}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PROMPT='  %F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
  else
    PROMPT=' 🐧 %F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
  fi

  # Optional right-side prompt
  export RPROMPT='%F{cyan}%T%f'
  export PROMPT

fi
