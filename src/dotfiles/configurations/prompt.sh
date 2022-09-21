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
    cyan='\[\033[1;36m\]'
    green='\[\033[1;32m\]'
    pink='\[\033[1;35m\]'
    reset='\[\033[0m\]'

    if [[ "$OSTYPE" == "darwin" ]]; then
        PS1="  $(uname)${pink} ❭${reset} ${green} \w ${reset} ${cyan}$ ${reset}"
    else
        PS1=" 🐧 $(uname)${pink} ❭${reset} ${green} \w ${reset} ${cyan}$ ${reset}"
    fi
    export PS1
    #export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
elif [[ -n "$ZSH_VERSION" ]]; then
    export PROMPT='%F{magenta} ❭%f %F{green}%~%f %F{cyan}$ %f'
    export RPROMPT='%B%F{cyan}%*%f%b'
fi
