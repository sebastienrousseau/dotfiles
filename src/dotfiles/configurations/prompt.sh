#! /bin/bash
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
    # cyan='\e[0;36m'
    # green='\e[0;32m'
    # pink='\e[0;35m'
    # reset='\e[0m]'
    #export PS1="${pink} ❭${reset} ${green}\w${reset} ${cyan}$ ${reset}"
    export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
elif [[ -n "$ZSH_VERSION" ]]; then
    export PROMPT='%F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
    export RPROMPT='%B%F{cyan}%*%f%b'
fi
