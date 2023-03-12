#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets configuration aliases.
# License: MIT
# Script: configuration.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂
# Bash aliases
alias brc='${=EDITOR} ~/.bashrc'         # brc: Open the Bash configuration file in the default text editor.
alias brhp='${=EDITOR} ~/.bash_profile'  # brhp: Open the Bash profile file in the default text editor.
alias benv='${=EDITOR} ~/.bash_env'      # benv: Open the Bash environment file in the default text editor.
alias bali='${=EDITOR} ~/.bash_aliases'  # bali: Open the Bash aliases file in the default text editor.
alias bhist='${=EDITOR} ~/.bash_history' # bhist: Open the Bash history file in the default text editor.
alias binput='${=EDITOR} ~/.inputrc'     # binput: Open the Bash input file in the default text editor.
alias bhlp='${=EDITOR} ~/.bash_help'     # bhlp: Open the Bash help file in the default text editor.

# Git aliases
alias gco='${=EDITOR} ~/.gitconfig'   # gco: Open the Git configuration file in the default text editor.
alias gign='${=EDITOR} ~/.gitignore'  # gign: Open the Git ignore file in the default text editor.
alias glog='${=EDITOR} ~/.git-log'    # glog: Open the Git log file in the default text editor.
alias gmsg='${=EDITOR} ~/.gitmessage' # gmsg: Open the Git commit message file in the default text editor.

# Nano aliases
alias n="nano"                      # n: Open Nano text editor.
alias nano="nano -w"                # nano: Open Nano text editor with automatic line wrapping.
alias nanow="nano -r -c -i -w -T 4" # nanow: Open Nano text editor with settings for editing whitespace.

# Zsh aliases
alias zrc='${=EDITOR} ~/.zshrc'           # zrc: Open the Zsh configuration file in the default text editor.
alias zenv='${=EDITOR} ~/.zshenv'         # zenv: Open the Zsh environment file in the default text editor.
alias zali='${=EDITOR} ~/.zsh_aliases'    # zali: Open the Zsh aliases file in the default text editor.
alias zfunc='${=EDITOR} ~/.zsh_functions' # zfunc: Open the Zsh functions file in the default text editor.
alias zhlp='${=EDITOR} ~/.zsh_help'       # zhlp: Open the Zsh help file in the default text editor.

# Vim aliases
alias vimrc='${=EDITOR} ~/.vimrc'            # vimrc: Open the Vim configuration file in the default text editor.
alias vimft='${=EDITOR} ~/.vim/filetype.vim' # vimft: Open the Vim filetype file in the default text editor.
alias vimftd='${=EDITOR} ~/.vim/ftdetect/'   # vimftd: Open the Vim ftdetect directory in the default file manager.
alias vimftpl='${=EDITOR} ~/.vim/ftplugin/'  # vimftpl: Open the Vim ftplugin directory in the default file manager.
alias vimplt='${=EDITOR} ~/.vim/plugin/'     # vimplt: Open the Vim plugin directory in the default file manager.
