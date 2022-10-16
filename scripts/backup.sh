#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.459) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variable.
DF_DOTFILESDIR="${HOME}/.dotfiles" # Location of dotfiles.
export DF_DOTFILESDIR              # Exporting Location of dotfiles.

## 🅱🅰🅲🅺🆄🅿 - Backup existing files.
backup() {

  # shellcheck disable=SC1091
  . "./lib/configurations/default/constants.sh"

  echo ""
  # shellcheck disable=SC2154
  echo "${RED}❭${NC} Starting Backup Procedure."
  echo ""

  # Create backup directory.
  # shellcheck disable=SC2154
  if [[ -d "${DF_BACKUPDIR}" ]]; then
    echo "${RED}  ✘${NC} Skipping folder creation."
  else
    # shellcheck disable=SC2154
    echo "${GREEN}  ✔${NC} Creating backup directory '${GREEN}${DF_BACKUPDIR}${NC}'..."
    mkdir -p "${DF_BACKUPDIR}"
  fi

  # Backup existing Dotfiles directory.
  if [[ -d "${HOME}"/.dotfiles ]]; then
    echo "${GREEN}  ✔${NC} Backing up previous Dotfiles installation to '${GREEN}${DF_BACKUPDIR}/${DF_TIMESTAMP}/${NC}'..."
    # shellcheck disable=SC2154
    mv -f "${DF_DOTFILESDIR}" "${HOME}"/dotfiles_backup/"${DF_TIMESTAMP}"/
  fi

  # File list (use trailing slash for directories)
  FILES="
  .alias
  .bash_aliases
  .bash_profile
  .bash_prompt
  .bashrc
  .curlrc
  .dir_colors
  .exports
  .functions
  .gitattributes
  .gitconfig
  .gitignore
  .gitmessage
  .inputrc
  .npmrc
  .path
  .profile
  .tmux.conf
  .vimrc
  .wgetrc
  .yarnrc
  .zshenv
  .zshrc
  cacert.pem
  "

  for file in ${FILES}; do
    # shellcheck disable=SC2292
    if [ -e "${HOME}/${file}" ]; then
      echo "${GREEN}  ✔${NC} Backing up '${YELLOW}${file}${NC}'"
      cp -f "${HOME}"/"${file}" "${DF_BACKUPDIR}"/"${file}"
    fi
  done

  # shellcheck disable=SC2154
  echo "${GREEN}  ✔${NC} All files have been backed up to '${CYAN}${DF_BACKUPDIR}${NC}'"
  echo ""
}

args=$*               # Arguments passed to script.
export args="${args}" # Exporting arguments.
if [[ ${args} = "backup" ]]; then
  echo "$*"
  backup
fi
