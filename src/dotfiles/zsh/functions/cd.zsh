#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#                                                                           
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


# cd: Function to Enable 'cd' into directory aliases

# cd: Function to Enable 'cd' into directory aliases
#function cd() {
#if [ ${#1} == 0 ]; then
#	builtin cd
#elif [ -d "${1}" ]; then
#	builtin cd "${1}"
#elif [[ -f "${1}" || -L "${1}" ]]; then
#	path=$(getTrueName "$1")
#	builtin cd "$path"
#else
#	builtin cd "${1}"
#fi
#}

function cd()
{
    function cdp()
    {
        if [ -d "$1" ]; then
            builtin cd "$1" && return 0
        else
            filered_array=($(cdlog_view | \grep -i "/${1}$"))
            for ((i=${#filered_array[*]}-1; i>=0; i--))
            do
                if [ "$PWD" = "${filered_array[i]}" ]; then
                    _cdhist_cd "${filered_array[0]}" && return 0
                fi
                _cdhist_cd "${filered_array[i]}" && return 0
            done
        fi
        return 1
    }

    [ -z "$1" ] && _cdhist_cd $HOME && return 0
    while (( $# > 0 ))
    do
        case "$1" in
            -*)
                if [[ "$1" =~ 'l' ]]; then
                    shift
                    cdp "$1" && return 0
                fi
                ;;
            *)
                cdp "$1" && break
                ;;
        esac
    done
}