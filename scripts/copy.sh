#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.

# shellcheck disable=SC1091
. "${DF_DOTFILESDIR}/scripts/constants.sh"

## 🅲🅾🅿🆈 🅳🅾🆃🅵🅸🅻🅴🆂 - Copy dotfiles.
## 🅲🅾🅿🆈 - Copy the dotfiles on your system.
copy() {
  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Copying the Dotfiles on your system."

  # shellcheck disable=SC2154
  echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.bashrc${DF_NC}"

  cp -f "${DF_DOTFILESDIR}"/lib/configurations/bash/bashrc "${HOME}"/.bashrc &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}cacert.pem${DF_NC}"
  # shellcheck disable=SC2154
  cp -f "${DOTFILESDIR}"/lib/configurations/curl/cacert.pem "${HOME}"/cacert.pem &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.curlrc${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/curl/curlrc "${HOME}"/.curlrc &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.jshintrc${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/jshint/jshintrc "${HOME}"/.jshintrc &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.profile${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/profile/profile "${HOME}"/.profile &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.tmux.conf${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/tmux/tmux "${HOME}"/.tmux.conf &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.vimrc${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/vim/vimrc "${HOME}"/.vimrc &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.wgetrc${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/wget/wgetrc "${HOME}"/.wgetrc &&
    echo "${DF_BIRed}❭${DF_NC} Copying ${DF_BIGreen}.zshrc${DF_NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/zsh/zshrc "${HOME}"/.zshrc
}

# copy() {
#   pnpm run cp:bash &&
#     pnpm run cp:cert &&
#     pnpm run cp:curl &&
#     pnpm run cp:dirs &&
#     pnpm run cp:gemr &&
#     pnpm run cp:inpt &&
#     pnpm run cp:jsht &&
#     pnpm run cp:prof &&
#     pnpm run cp:tmux &&
#     pnpm run cp:vimr &&
#     pnpm run cp:wget &&
#     pnpm run cp:zshr
# }
# copy
