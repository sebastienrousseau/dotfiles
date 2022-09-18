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

# if [ "$TMUX" = "" ]; then tmux; fi
function custom_build_prompt {
    local cyan='\e[0;36m'
    local green='\e[0;32m'
    local pink='\e[0;35m'
    local reset='\e[0m]'
    local white='\e[0;37m'

    export PS1="${pink} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"
}

export PROMPT_COMMAND=custom_build_prompt
