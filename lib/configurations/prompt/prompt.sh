#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

## 🆂🅷🅴🅻🅻

# Exit early for non-interactive shells
if [[ $- != *i* ]]; then return; fi

# Check if we're running in a full-featured terminal
if [[ ${TERM} != *-256color* && ${TERM} != alacritty* && ${TERM} != *-kitty* ]]; then
  PS1='\h \w > '
  return
fi

# Color definitions
tmux_purple='\[\033[38;5;55m\]'     # Purple (#2D1681)
tmux_red='\[\033[38;5;196m\]'       # Red (#EB0000)
tmux_blue='\[\033[38;5;33m\]'       # Blue (#007ACC)
tmux_white='\[\033[38;5;15m\]'      # White (#FFFFFF)
tmux_green='\[\033[38;5;46m\]'      # Green for clean git status
tmux_yellow='\[\033[38;5;226m\]'    # Yellow for dirty git status
reset='\[\033[0m\]'

# Git status function for bash
function git_status() {
  local branch dirty
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      echo "${tmux_yellow}${branch}*${reset}"
    else
      echo "${tmux_green}${branch}${reset}"
    fi
  fi
}

# Function to set up zsh git prompt
function setup_zsh_git() {
  autoload -Uz vcs_info
  precmd_vcs_info() { vcs_info }
  precmd_functions+=( precmd_vcs_info )
  setopt prompt_subst

  zstyle ':vcs_info:git:*' formats '%F{46}%b%f'
  zstyle ':vcs_info:git:*' actionformats '%F{226}%b%f'
  zstyle ':vcs_info:git:*' check-for-changes true
  zstyle ':vcs_info:git:*' stagedstr '*'
  zstyle ':vcs_info:git:*' unstagedstr '*'
}

# Bash prompt configuration
if [[ -n "${BASH_VERSION}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PS1="${tmux_blue}  macOS ${tmux_purple}❭ ${tmux_white}\w \$(git_status) ${tmux_red}\$ ${reset}"
  elif [[ "${OSTYPE}" == "linux"* ]]; then
    PS1="${tmux_blue} 🐧 Linux ${tmux_purple}❭ ${tmux_white}\w \$(git_status) ${tmux_red}\$ ${reset}"
  elif [[ "${OSTYPE}" == "msys"* || "${OSTYPE}" == "mingw"* ]]; then
    PS1="${tmux_blue} 🪟 Windows ${tmux_purple}❭ ${tmux_white}\w \$(git_status) ${tmux_red}\$ ${reset}"
  else
    PS1="${tmux_blue} 🌐 Unknown ${tmux_purple}❭ ${tmux_white}\w \$(git_status) ${tmux_red}\$ ${reset}"
  fi
  export PS1

# Zsh prompt configuration
elif [[ -n "${ZSH_VERSION}" ]]; then
  setup_zsh_git

  if [[ "${OSTYPE}" == "darwin"* ]]; then
    PROMPT="%F{33}  macOS %F{55}❭ %F{15}%~ \${vcs_info_msg_0_} %F{196}\$ %f"
  elif [[ "${OSTYPE}" == "linux"* ]]; then
    PROMPT="%F{33} 🐧 Linux %F{55}❭ %F{15}%~ \${vcs_info_msg_0_} %F{196}\$ %f"
  elif [[ "${OSTYPE}" == "msys"* || "${OSTYPE}" == "mingw"* ]]; then
    PROMPT="%F{33} 🪟 Windows %F{55}❭ %F{15}%~ \${vcs_info_msg_0_} %F{196}\$ %f"
  else
    PROMPT="%F{33} 🌐 Unknown %F{55}❭ %F{15}%~ \${vcs_info_msg_0_} %F{196}\$ %f"
  fi
  export PROMPT
fi
