#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for the `cd` command.
# License: MIT
# Script: cd.aliases.sh
# Version: 0.2.464
# Website: https://dotfiles.io

# 🅲🅳 🅰🅻🅸🅰🆂🅴🆂

# Shortcut to go to previous directory
alias -- -='cd -'

# Shortcuts to go to parent directories
alias .....='cd ../../../../'
alias ....='cd ../../'
alias ...='cd ../'
alias ..='cd ..'

# Shortcuts to go to specific directories
alias '~'='cd ~'

# Shortcuts to go to frequently used directories
alias app='cd "${HOME}/Applications"; ls' # app: Shortcut to go to the Applications directory and list its contents.
alias cod='cd "${HOME}/Code"; ls'         # cod: Shortcut to go to the Code directory and list its contents.
alias des='cd "${HOME}/Desktop"; ls'      # des: Shortcut to go to the Desktop directory and list its contents.
alias doc='cd "${HOME}/Documents"; ls'    # doc: Shortcut to go to the Documents directory and list its contents.
alias dot='cd "${HOME}/.dotfiles"; ls'    # dot: Shortcut to go to the .dotfiles directory and list its contents.
alias dow='cd "${HOME}/Downloads"; ls'    # dow: Shortcut to go to the Downloads directory and list its contents.
alias hom='cd "${HOME}"; ls'              # hom: Shortcut to go to the home directory and list its contents.
alias mus='cd "${HOME}/Music"; ls'        # mus: Shortcut to go to the Music directory and list its contents.
alias pic='cd "${HOME}/Pictures"; ls'     # pic: Shortcut to go to the Pictures directory and list its contents.
alias vid='cd "${HOME}/Videos"; ls'       # vid: Shortcut to go to the Videos directory and list its contents.

# Shortcuts to navigate to system directories
alias etc='cd /etc; ls' # etc: Shortcut to go to the etc directory and list its contents.
alias var='cd /var; ls' # var: Shortcut to go to the var directory and list its contents.
alias tmp='cd /tmp; ls' # tmp: Shortcut to go to the tmp directory and list its contents.
