#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Prompt configuration.

## 🆂🅷🅴🅻🅻

if [ "$TMUX" = "" ]; then tmux; fi

# Non-interactive shells don't have a prompt, exit early.
[[ $- =~ i ]] || return 0

# Set a simple prompt for non-256color, non-alacritty and non-kitty terminals.
if [[ $TERM != *-256color ]] && [[ $TERM != alacritty* ]] && [[ $TERM != *-kitty ]]; then
    PS1='\h \w > '
    return 0
fi

if [[ -n "$BASH_VERSION" ]]; then
    cyan='\e[0;36m'
    green='\e[0;32m'
    pink='\e[0;35m'
    reset='\e[0m]'
    export PS1="${pink} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"
elif [[ -n "$ZSH_VERSION" ]]; then
    export PROMPT='%F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
    export RPROMPT='%B%F{cyan}%*%f%b'
fi
