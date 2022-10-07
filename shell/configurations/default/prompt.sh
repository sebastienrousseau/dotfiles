#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.454) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆂🅷🅴🅻🅻

# Non-interactive shells don't have a prompt, exit early.
[[ $- =~ i ]] || return 0

# Set a simple prompt for non-256color, non-alacritty and non-kitty terminals.
if [[ ${TERM} != *-256color ]] && [[ ${TERM} != alacritty* ]] && [[ ${TERM} != *-kitty ]]; then
  PS1='\h \w > '
  return 0
fi

if [[ -n "${BASH_VERSION}" ]]; then
  cyan='\[\033[1;96m\]'
  green='\[\033[1;92m\]'
  purple='\[\033[1;95m\]'
  reset='\[\033[0m\]'

  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PS1="  $(uname)${purple} ❭${reset} ${green} \w ${reset} ${cyan}$ ${reset}"
  else
    PS1=" 🐧 $(uname)${purple} ❭${reset} ${green} \w ${reset} ${cyan}$ ${reset}"
  fi
  export PS1
elif [[ -n "${ZSH_VERSION}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PROMPT='  %F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
  else
    PROMPT=' 🐧 %F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
  fi
  export PROMPT
  export RPROMPT='%F{cyan}%t%f'
fi
