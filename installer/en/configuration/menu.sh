#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452)

set -e

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for items in ./installer/*.sh; do
  # shellcheck source=/dev/null
  . "$items"
done

## 🅷🅴🅻🅿 🅼🅴🅽🆄
helpMenuDotfiles() {
  echo ""
  echo "┌──────────────────────────────────────┐"
  echo "│                                      │"
  echo "│          DotFiles (v0.2.452)         |"
  echo "│                                      │"
  echo "└──────────────────────────────────────┘"
  echo
  echo "[INFO] Available options:"
  echo "
  [0] Exit menu.
  [1] Backup an existing Dotfiles folder.
  [2] Download the latest Dotfiles release.
  [3] Recover a previous Dotfiles folder.
  [4] Generate the Dotfiles documentation locally."
  echo
  echo "[INFO] Please choose an option and press [ENTER]:"
  read -r a
  case $a in
  0) exit 0 ;;
  1)
    backupDotfiles
    helpMenuDotfiles
    ;;
  2)
    downloadDotfiles
    helpMenuDotfiles
    ;;
  3)
    recoverDotfiles
    helpMenuDotfiles
    ;;
  4)
    documentDotfiles
    helpMenuDotfiles
    ;;
  *) echo "[ERROR] Wrong option." ;;
  esac
}

## 🅵🆄🅽🅲🆃🅸🅾🅽🆂
# shellcheck source=/dev/null
. ./installer/functions.sh

helpMenuDotfiles
