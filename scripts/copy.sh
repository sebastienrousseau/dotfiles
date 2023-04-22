#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🅲🅾🅿🆈 - Copy the dotfiles on your system.
copy() {

  # shellcheck disable=SC1091
  . "./lib/configurations/default/constants.sh"

  echo ""
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Starting Copying Procedure."
  echo ""

  # shellcheck disable=SC2154
  # if [[ -d "${DF_DIR}" ]]; then
  #   echo "${RED}❭${NC} Copying Binaries to ${DF_DIR}."
  #   cp -f -R ./bin/ "${DF_DIR}"bin/
  # else
  #   echo "${RED}❭${NC} Copying Binaries to ${DF_DIR}."
  #   mkdir -p "${DF_DIR}"
  #   cp -f -R ./bin/ "${DF_DIR}"bin/
  # fi

  # shellcheck disable=SC2154
  if [[ -d "${DF_DIR}" ]]; then
    echo "${RED}❭${NC} Copying ${GREEN}Dotfiles v${DF_VERSION}${NC} to ${CYAN}${DF_DIR}${NC}"
    cp -f -R ./lib/ "${DF_DIR}"lib/
  else
    echo "${RED}❭${NC} Copying ${GREEN}Dotfiles v${DF_VERSION}${NC} to ${CYAN}${DF_DIR}${NC}"
    mkdir -p "${DF_DIR}"
    cp -f -R ./lib/ "${DF_DIR}"lib/
  fi

  # shellcheck disable=SC2154
  # if [[ -d "${DF_DIR}" ]]; then
  #   echo "${RED}❭${NC} Copying Scripts to ${CYAN}${DF_DIR}${NC}"
  #   cp -f -R ./scripts/ "${DF_DIR}"scripts/
  # else
  #   echo "${RED}❭${NC} Copying Scripts to ${CYAN}${DF_DIR}${NC}"
  #   mkdir -p "${DF_DIR}"
  #   cp -f -R ./scripts/ "${DF_DIR}"scripts/
  # fi

  # cacert -- Copying cacert.pem file.
  # shellcheck disable=SC2154
  cp -f "${PWD}"/lib/configurations/curl/cacert.pem "${HOME}"/.cacert.pem &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}cacert.pem${NC}'" &&

    # bashrc -- Copying .bashrc file.
    cp -f "${PWD}"/lib/configurations/bash/bashrc "${HOME}"/.bashrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.bashrc${NC}'" &&

    # curlrc -- Copying .curlrc file.
    cp -f "${PWD}"/lib/configurations/curl/curlrc "${HOME}"/.curlrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.curlrc${NC}'" &&

    # gemrc -- Copying .gemrc file.
    cp -f "${PWD}"/lib/configurations/gem/gemrc "${HOME}"/.gemrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.gemrc${NC}'" &&

    # inputrc -- Copying .inputrc file.
    cp -f "${PWD}"/lib/configurations/input/inputrc "${HOME}"/.inputrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.inputrc${NC}'" &&

    # jshintrc -- Copying .jshintrc file.
    cp -f "${PWD}"/lib/configurations/jshint/jshintrc "${HOME}"/.jshintrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.jshintrc${NC}'" &&

    # nanorc -- Copying .nanorc file.
    cp -f "${PWD}"/lib/configurations/nano/nanorc "${HOME}"/.nanorc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.nanorc${NC}'" &&

    # profile -- Copying .profile file.
    cp -f "${PWD}"/lib/configurations/profile/profile "${HOME}"/.profile &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.profile${NC}'" &&

    # tmux -- Copying .tmux.conf file.
    cp -f "${PWD}"/lib/configurations/tmux/tmux "${HOME}"/.tmux.conf &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.tmux.conf${NC}'" &&

    # vimrc -- Copying .vimrc file.
    cp -f "${PWD}"/lib/configurations/vim/vimrc "${HOME}"/.vimrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.vimrc${NC}'" &&

    # wgetrc -- Copying .wgetrc file.
    cp -f "${PWD}"/lib/configurations/wget/wgetrc "${HOME}"/.wgetrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.wgetrc${NC}'" &&

    # zshrc -- Copying .zshrc file.
    cp -f "${PWD}"/lib/configurations/zsh/zshrc "${HOME}"/.zshrc &&
    echo "${GREEN}  ✔${NC} Copying '${YELLOW}.zshrc${NC}'"

  # shellcheck disable=SC2154
  echo "${GREEN}  ✔${NC} All files have been copied up'"
  echo ""
}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "copy" ]]; then
  echo "$*"
  copy
fi
