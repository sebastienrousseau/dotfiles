#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
# https://dotfiles.io
#
# Description: Installer of the symbolic links (Symlinks) for the Z shell (Zsh)
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC2002 # Don't warn about UUOC
# shellcheck disable=SC3000
# shellcheck disable=SC4000
# shellcheck disable=SC1091

# shellcheck source=/dev/null
. ./installer/colors.sh

# shellcheck source=/dev/null
. ./installer/variables.sh

pid () {
  eval "${1}=$(sh -c 'echo ${PPID}')"
}

# error () {
#   _error_pid
#   _error_pid pid
#   echo "❌ [${Red}ERROR${Reset}:${Blue}${pid}${Reset}] ${Green}$(date +%F)${Reset}: ${Blue}${progName}${Reset}: ${Blue}${1}${Reset}: Exited with status ${code}.${Reset}"
#   logs
#   echo [ERROR:"${pid}"] "$(date +%F)": "${progName}": "${1}": Exited with status "${code}".
#   exit "${code}"
# }

logs () {
  script_log="errors-$(date +%F).log"
  exec 1>>"$script_log"
}
