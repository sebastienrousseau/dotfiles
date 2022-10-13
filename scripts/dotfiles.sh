#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set variables.
BACKUPDIR="${HOME}/dotfiles_backup"  # Backup directory.
BIGreen='\033[1;92m'                  # Green color.
BIRed='\033[1;91m'                    # Red color.
DOTFILESDIR="${HOME}/.dotfiles"       # Location of dotfiles.
DOWNLOADDIR="${HOME}/Downloads"       # Download directory.
NC='\033[0m'                          # Reset/No Color
VERSION="0.2.458"                     # Dotfiles Version number.

## 🅱🅰🅲🅺🆄🅿 - Backup existing files.
backup() {
  echo "${BIRed}❭${NC} Creating a backup directory '${BIGreen}${BACKUPDIR}${NC}'."
  mkdir -p "${BACKUPDIR}"

  echo "${BIRed}❭${NC} Backing up existing dotfiles in '${BIGreen}${BACKUPDIR}${NC}'..."
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
      echo "${BIRed}❭${NC} Backing up ${BIGreen}${file}${NC}..."
      cp -f "${HOME}"/"${file}" "${BACKUPDIR}"/"${file}"
    fi
  done
}

## 🅲🅻🅴🅰🅽 - Clean up.
clean() {
  echo "${BIRed}❭${NC} Cleaning up..."
  rm -rfi "${DOTFILESDIR}"
  rm -rfi "${BACKUPDIR}"
  rm -rfi "${DOWNLOADDIR}"/dotfiles*
}

## 🅳🅾🆆🅽🅻🅾🅰🅳 - Download the dotfiles on your system.
download() {
  echo "${BIRed}❭${NC} Downloading ${BIGreen}Dotfiles v${VERSION}${NC} on your system."
  # wget https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${VERSION}".zip -N -O "${DOWNLOADDIR}/v${VERSION}.zip"
  curl https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${VERSION}".zip -o "${DOWNLOADDIR}"/v"${VERSION}".zip
}

## 🆄🅽🅿🅰🅲🅺 - Unpack the dotfiles on your system.
unpack() {
  echo "${BIRed}❭${NC} Unpacking ${BIGreen}Dotfiles v${VERSION}${NC}."
  unzip -qq -u "${DOWNLOADDIR}"/v"${VERSION}".zip -d "${DOWNLOADDIR}"
  mv "${DOWNLOADDIR}/dotfiles-${VERSION}/lib/" "${DOTFILESDIR}"
  rm "${DOWNLOADDIR}/v${VERSION}.zip"
}

## 🅰🆂🆂🅴🅼🅱🅻🅴 - Assemble the dotfiles on your system.
assemble() {
  echo "${BIRed}❭${NC} Preparing the dotfiles on your system."
  backup &&
  download &&
  unpack &&
  copy
}

## 🅲🅾🅿🆈 - Copy the dotfiles on your system.
copy() {
  # echo "${BIRed}❭${NC} Copying the Dotfiles on your system."
  # cd "${DOTFILESDIR}" &&

  echo "${BIRed}❭${NC} Copying the Dotfiles on your system."
  echo "${BIRed}❭${NC} Copying ${BIGreen}.bashrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/bash/bashrc "${HOME}"/.bashrc &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}cacert.pem${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/curl/cacert.pem "${HOME}"/cacert.pem &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.curlrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/curl/curlrc "${HOME}"/.curlrc &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.jshintrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/jshint/jshintrc "${HOME}"/.jshintrc &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.profile${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/profile/profile "${HOME}"/.profile &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.tmux.conf${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/tmux/tmux "${HOME}"/.tmux.conf &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.vimrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/vim/vimrc "${HOME}"/.vimrc &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.wgetrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/wget/wgetrc "${HOME}"/.wgetrc &&
  echo "${BIRed}❭${NC} Copying ${BIGreen}.zshrc${NC}"
  cp -f "${DOTFILESDIR}"/lib/configurations/zsh/zshrc "${HOME}"/.zshrc

  echo "${BIRed}❭${NC} Cleaning up installation files."
  rm -Rf "${DOTFILESDIR}"/lib/configurations/bash &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/curl &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/jshint &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/profile &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/tmux &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/vim &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/wget &&
  rm -Rf "${DOTFILESDIR}"/lib/configurations/zsh &&

  echo "${BIRed}❭${NC} ${BIGreen}Dotfiles v${VERSION}${NC} has been installed on your system."
}

## 🅷🅴🅻🅿 🅼🅴🅽🆄 - Display help menu.
help() {
  clear
  cat <<EOF

┌───────────────────────────────────────────┐
│             Dotfiles (v${VERSION})           │
├───────────────────────────────────────────┤
│   Simply designed to fit your shell life. │
└───────────────────────────────────────────┘

USAGE:

  dotfiles [COMMAND]

COMMANDS:

  backup    - Backup existing dotfiles from the '${HOME}' directory
  clean     - Removes any previous setup directories
  copy      - Copy the new dotfiles files to your '${HOME}' directory
  download  - Download the latest Dotfiles (v${VERSION})
  assemble  - Run the full installation process
  unpack    - Unpack the Dotfiles
  help      - Show the help menu

DOCUMENTATION:
  website   - https://dotfiles.io

LICENSE:
  This project is licensed under the MIT License.

EOF
}

# shellcheck disable=SC2292
if [ "$1" = "backup" ]; then
  echo "${BIRed}❭${NC} Backing up.${NC}"
  backup
elif [ "$1" = "clean" ]; then
  echo "${BIRed}❭${NC} Removes any previous setup directories.${NC}"
  clean
elif [ "$1" = "copy" ]; then
  echo "${BIRed}❭${NC} Copying dotfiles.${NC}"
  copy
elif [ "$1" = "download" ]; then
  echo "${BIRed}❭${NC} Downloading ${BIGreen}Dotfiles v${VERSION}${NC}."
  download
elif [ "$1" = "help" ]; then
  help
elif [ "$1" = "assemble" ]; then
  echo "${BIRed}❭${NC} Installing ${BIGreen}Dotfiles v${VERSION}${NC}."
  assemble
elif [ "$1" = "unpack" ]; then
  echo "${BIRed}❭${NC} Unpacking ${BIGreen}Dotfiles v${VERSION}${NC}."
  unpack
else
  help
fi