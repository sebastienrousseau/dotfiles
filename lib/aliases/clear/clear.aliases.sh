#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: clear.aliases.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Enhances terminal interaction with aliases for clearing the screen,
# navigating directories, and displaying directory contents in an organized manner.
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Configurable paths
WORKSPACE_DIR="${HOME}/workspace"

# Validate directory existence
function validate_dir() {
    if [[ ! -d "$1" ]]; then
        echo "Directory $1 not found."
        return 1
    fi
    return 0
}

# Functions for aliases
function cd_workspace() {
    validate_dir "${WORKSPACE_DIR}" && cd "${WORKSPACE_DIR}" || return
}

function clear_screen() {
    clear
}

function clear_list_current() {
    clear && ls -a
}

function clear_pwd_list() {
    clear && pwd && echo '' && ls -a && echo ''
}

function clear_pwd_tree() {
    clear && pwd && echo '' && tree ./ && echo ''
}

function clear_history() {
    clear && history
}

function print_working_dir() {
    pwd
}

function clear_print_tree() {
    clear && tree
}

# 🅲🅻🅴🅰🆁 🅰🅻🅸🅰🆂🅴🆂

# Alias definitions
alias cdw='cd_workspace'
alias c='clear_screen'
alias clc='clear_list_current'
alias cpl='clear_pwd_list'
alias cplt='clear_pwd_tree'
alias clh='clear_history'
alias cl='clear_screen'
alias clp='print_working_dir'
alias clt='clear_print_tree'
