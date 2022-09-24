#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

set -e

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for items in ./installer/*.sh; do
  # shellcheck source=/dev/null
  . "$items"
done

## 🅷🅴🅻🅿 🅼🅴🅽🆄
helpMenuDotfiles() {
  echo ""
  echo "${ICyan}┌──────────────────────────────────────┐${Reset}"
  echo "${ICyan}│                                      │${Reset}"
  echo "${ICyan}│          ${IWhite}DotFiles (v0.2.450)${Reset}         ${ICyan}│${Reset}"
  echo "${ICyan}│                                      │${Reset}"
  echo "${ICyan}└──────────────────────────────────────┘${Reset}"
  echo
  echo "${IGreen}[INFO] Available options:${Reset}"
  echo "
  ${ICyan}[0]${Reset} ${IWhite}Exit menu.${Reset}
  ${ICyan}[1]${Reset} ${IWhite}Backup an existing Dotfiles folder${Reset}
  ${ICyan}[2]${Reset} ${IWhite}Download the latest Dotfiles release${Reset}
  ${ICyan}[3]${Reset} ${IWhite}Recover a previous Dotfiles folder${Reset}
  ${ICyan}[4]${Reset} ${IWhite}Generate the Dotfiles documentation locally${Reset}"
  echo
  echo "${IGreen}[INFO]${Reset}  ${IWhite}Please choose an option and press [ENTER]:${Reset}"
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
  *) echo "${IRed}[ERROR]${Reset} ${IWhite}Wrong option.${Reset}" ;;
  esac
}

## 🅵🆄🅽🅲🆃🅸🅾🅽🆂
# shellcheck source=/dev/null
. ./installer/functions.sh

helpMenuDotfiles
