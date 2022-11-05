#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅽🅰🆅🅸🅶🅰🆃🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂
alias -- -='cd -'                       # -: Shortcut to go to previous directory.
alias .....='cd ../../../..'            # .....: Shortcut to go to great-great-grandparent directory.
alias ....='cd ../../..'                # ....: Shortcut to go to great-grandparent directory.
alias ...='cd ../..'                    # ...: Shortcut to go to grandparent directory.
alias ..='cd ..'                        # ..: Shortcut to go to parent directory.
alias -1='cd -1'                        # -1: Shortcut to go to first directory in the directory stack.
alias -2='cd -2'                        # -2: Shortcut to go to second directory in the directory stack.
alias -3='cd -3'                        # -3: Shortcut to go to third directory in the directory stack.
alias -4='cd -4'                        # -4: Shortcut to go to fourth directory in the directory stack.
alias -5='cd -5'                        # -5: Shortcut to go to fifth directory in the directory stack.
alias '~'='cd ~'                        # ~: Shortcut to go to home directory.
alias app='cd ${HOME}/Applications; ls' # app: Shortcut to go to the Applications directory.
alias cod='cd ${HOME}/Code; ls'         # cod: Shortcut to go to the Code directory and list its contents.
alias des='cd ${HOME}/Desktop; ls'      # des Shortcut to go to the Desktop directory and list its contents.
alias doc='cd ${HOME}/Documents; ls'    # doc: Shortcut to go to the Documents directory and list its contents.
alias dot='cd ${HOME}/.dotfiles; ls'    # dot: Shortcut to go to the dotfiles directory.
alias dow='cd ${HOME}/Downloads; ls'    # dow: Shortcut to go to the Downloads directory and list its contents.
alias hom='cd ${HOME}/; ls'             # hom: Shortcut to go to home directory and list its contents.
alias mus='cd ${HOME}/Music; ls'        # mus: Shortcut to go to the Music directory and list its contents.
alias pic='cd ${HOME}/Pictures; ls'     # pic: Shortcut to go to the Pictures directory and list its contents.
alias vid='cd ${HOME}/Videos; ls'       # vid: Shortcut to go to the Videos directory and list its contents.
