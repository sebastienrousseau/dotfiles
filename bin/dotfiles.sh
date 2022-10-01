#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set variables.
BACKUPDIR="${HOME}/.dotfiles/backup"  # Backup directory.
BIGreen='\033[1;92m'               # Green color.
BIRed='\033[1;91m'                 # Red color.
DOTFILESDIR="${HOME}/.dotfiles"    # Location of dotfiles.
DOWNLOADDIR="${HOME}/Downloads"    # Download directory.
NC='\033[0m'                       # Reset/No Color
VERSION="0.2.452"                  # Dotfiles Version number.

## 🅱🅰🅲🅺🆄🅿 - Backup existing files.
backup() {
  echo "${BIRed}❭${NC} Creating a backup directory '${BIGreen}${DOTFILESDIR}${NC}'."
  mkdir -p "${BACKUPDIR}"

  echo "${BIRed}❭${NC} Backing up existing dotfiles in '${BIGreen}${BACKUPDIR}${NC}'..."
  # File list (use trailing slash for directories)
  FILES="
  .bashrc
  .curlrc
  .gitattributes
  .gitconfig
  .gitignore
  .gitmessage
  .inputrc
  .npmrc
  .profile
  .tmux.conf
  .vimrc
  .wgetrc
  .yarnrc
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

## 🅸🅽🆂🆃🅰🅻🅻🅴🆁 - Install dotfiles.
download() {
  echo "${BIRed}❭${NC} Installing ${BIGreen}Dotfiles v${VERSION}${NC}"
  # wget https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${VERSION}".zip -N -O "${DOWNLOADDIR}/v${VERSION}.zip"
  curl https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v"${VERSION}".zip -o "${DOWNLOADDIR}"/v"${VERSION}".zip
}

## 🆄🅽🅿🅰🅲🅺 - Unpack installer.
unpack() {
  echo "${BIRed}❭${NC} Unpacking ${BIGreen}Dotfiles v${VERSION}${NC}"
  unzip -qq -u "${DOWNLOADDIR}"/v"${VERSION}".zip -d "${DOWNLOADDIR}"
  mv "${DOWNLOADDIR}/dotfiles-${VERSION}/shell/" "${DOTFILESDIR}"
  rm "${DOWNLOADDIR}/v${VERSION}.zip"
}

## 🅸🅽🆂🆃🅰🅻🅻 - Install dotfiles.
install() {
  echo "${BIRed}❭${NC} Installing dotfiles..."
  backup &&
  download &&
  unpack &&
  copy
}

## 🅲🅾🅿🆈 - Copy dotfiles.
copy() {
  # echo "${BIRed}❭${NC} Switching to the Dotfiles directory"
  # cd "${DOTFILESDIR}" &&

  echo "${BIRed}❭${NC} Launching the installation script..."
  cp -f "${DOTFILESDIR}"/shell/configurations/bash/bashrc "${HOME}"/.bashrc &&
  cp -f "${DOTFILESDIR}"/shell/configurations/curl/cacert.pem "${HOME}"/cacert.pem &&
  cp -f "${DOTFILESDIR}"/shell/configurations/curl/curlrc "${HOME}"/.curlrc &&
  cp -f "${DOTFILESDIR}"/shell/configurations/jshint/jshintrc "${HOME}"/.jshintrc &&
  cp -f "${DOTFILESDIR}"/shell/configurations/profile/profile "${HOME}"/.profile &&
  cp -f "${DOTFILESDIR}"/shell/configurations/tmux/tmux "${HOME}"/.tmux.conf &&
  cp -f "${DOTFILESDIR}"/shell/configurations/vim/vimrc "${HOME}"/.vimrc &&
  cp -f "${DOTFILESDIR}"/shell/configurations/wget/wgetrc "${HOME}"/.wgetrc &&
  cp -f "${DOTFILESDIR}"/shell/configurations/zsh/zshrc "${HOME}"/.zshrc

  echo "${BIRed}❭${NC} Cleaning up..."
  rm -Rf "${DOTFILESDIR}"/shell/configurations/bash &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/curl &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/jshint &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/profile &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/tmux &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/vim &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/wget &&
  rm -Rf "${DOTFILESDIR}"/shell/configurations/zsh &&

  echo "${BIRed}❭${NC} ${BIGreen}Dotfiles v${VERSION}${NC} installed."
  ${SHELL}

}

## 🅷🅴🅻🅿 🅼🅴🅽🆄 - Display help menu.
help() {
  cat <<EOF

┌───────────────────────────────────────────┐
│             Dotfiles (v${VERSION})           │
├───────────────────────────────────────────┤
│   Simply designed to fit your shell life. │
└───────────────────────────────────────────┘

USAGE:

  dotfiles.sh [COMMAND]

COMMANDS:

  backup    - Backup previous dotfiles from your '${HOME}' directory.
  copy      - Copy dotfiles (v${VERSION}) to your '${HOME}' directory.
  download  - Download the latest dotfiles package (v${VERSION}.zip).
  install   - Run the full installation process.
  unpack    - Unpack Dotfiles (v${VERSION}.zip) package.
  help      - Show the help menu.

EOF
}

# shellcheck disable=SC2292
if [ "$1" = "backup" ]; then
  echo "${BIRed}❭${NC} Backing up.${NC}"
  backup
elif [ "$1" = "copy" ]; then
  echo "${BIRed}❭${NC} Copying dotfiles.${NC}"
  copy
elif [ "$1" = "download" ]; then
  echo "${BIRed}❭${NC} Downloading ${BIGreen}Dotfiles v${VERSION}${NC}."
  download
elif [ "$1" = "help" ]; then
  help
elif [ "$1" = "install" ]; then
  echo "${BIRed}❭${NC} Installing ${BIGreen}Dotfiles v${VERSION}${NC}."
  install
elif [ "$1" = "unpack" ]; then
  echo "${BIRed}❭${NC} Unpacking ${BIGreen}Dotfiles v${VERSION}${NC}."
  unpack
else
  help
fi
