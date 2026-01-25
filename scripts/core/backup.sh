#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.473) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set Dotfiles variables.
DF_DOTFILESDIR="${HOME}/.dotfiles"   # Location of dotfiles.
DF_TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Timestamp for backup directory
DF_BACKUPDIR="${HOME}/.dotfiles_backup" # Base backup directory
DF="dotfiles"                         # Directory name for dotfiles backup

# ANSI color codes - defined here instead of relying on external file
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

## 🅱🅰🅲🅺🆄🅿 - Backup existing files.
backup() {
  echo ""
  echo -e "${RED}❭${NC} Starting Backup Procedure."
  echo ""

  # Create base backup directory if it doesn't exist
  if [[ -d "${DF_BACKUPDIR}" ]]; then
    echo -e "${RED}  ✘${NC} Backup directory already exists."
  else
    echo -e "${GREEN}  ✔${NC} Creating backup directory '${GREEN}${DF_BACKUPDIR}${NC}'..."
    if ! mkdir -p "${DF_BACKUPDIR}"; then
      echo -e "${RED}  ✘${NC} Failed to create backup directory. Exiting."
      return 1
    fi
  fi

  # Create timestamped backup directory
  CURRENT_BACKUP_DIR="${DF_BACKUPDIR}/${DF_TIMESTAMP}"
  if ! mkdir -p "${CURRENT_BACKUP_DIR}"; then
    echo -e "${RED}  ✘${NC} Failed to create timestamped backup directory. Exiting."
    return 1
  fi

  # Backup existing Dotfiles directory.
  if [[ -d "${HOME}"/.dotfiles ]]; then
    echo -e "${GREEN}  ✔${NC} Backing up previous Dotfiles installation to '${GREEN}${CURRENT_BACKUP_DIR}/${DF}${NC}'..."
    if ! mkdir -p "${CURRENT_BACKUP_DIR}/${DF}"; then
      echo -e "${RED}  ✘${NC} Failed to create dotfiles backup directory. Skipping dotfiles backup."
    else
      # Use rsync instead of mv to preserve original until we know the backup succeeded
      if ! rsync -a "${DF_DOTFILESDIR}/" "${CURRENT_BACKUP_DIR}/${DF}/"; then
        echo -e "${RED}  ✘${NC} Failed to backup dotfiles directory."
      fi
    fi
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
  .gemrc
  .gitattributes
  .gitconfig
  .gitignore
  .gitmessage
  .inputrc
  .nanorc
  .npmrc
  .path
  .profile
  .tmux.conf
  .vimrc
  .wgetrc
  .yarnrc
  .zshenv
  .zshrc
  .zprofile
  cacert.pem
  "

  # Create dotfiles directory in the backup location
  mkdir -p "${CURRENT_BACKUP_DIR}/files"

  # Track if we've successfully backed up any files
  BACKUP_COUNT=0

  for file in ${FILES}; do
    if [[ -f "${HOME}/${file}" ]]; then
      echo -e "${GREEN}  ✔${NC} Backing up '${YELLOW}${file}${NC}'"
      if cp -f "${HOME}/${file}" "${CURRENT_BACKUP_DIR}/files/${file}"; then
        ((BACKUP_COUNT++))
      else
        echo -e "${RED}  ✘${NC} Failed to backup '${YELLOW}${file}${NC}'"
      fi
    fi
  done

  if [[ ${BACKUP_COUNT} -gt 0 ]]; then
    echo -e "${GREEN}  ✔${NC} ${BACKUP_COUNT} files have been backed up to '${CYAN}${CURRENT_BACKUP_DIR}/files${NC}'"
  else
    echo -e "${YELLOW}  ⚠${NC} No files were backed up."
  fi

  echo ""
  echo -e "${GREEN}❭${NC} Backup procedure completed."
  echo ""
}

# Process command line arguments
case "$1" in
  backup)
    backup
    ;;
  help|--help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  backup    Backup dotfiles and configuration files"
    echo "  help      Display this help message"
    echo ""
    ;;
  "")
    echo "No command specified. Use '$0 help' for usage information."
    ;;
  *)
    echo "Unknown command: $1"
    echo "Use '$0 help' for usage information."
    ;;
esac
