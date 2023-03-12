#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets Default Aliases
# License: MIT
# Script: default.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# 🅳🅴🅵🅰🆄🅻🆃 🅰🅻🅸🅰🆂🅴🆂

## Directory aliases

alias ctf='echo $(ls -1 | wc -l)' # ctf: Count the number of files in the current directory.
alias p='pwd'                     # p: Print working directory.

## Exit aliases

alias bye='quit'  # bye: Exit the shell.
alias q='quit'    # q: Exit the shell.
alias quit='exit' # quit: Exit the shell.

## Misc aliases

alias h='history'                              # h: Display command history.
alias ipinfo='ipconfig getpacket en0'          # ipinfo: Get network interface parameters for en0.
alias path='echo ${PATH//:/\n}'                # path: Display the $PATH variable on newlines.
alias please='sudo -s'                         # please: Run command as superuser.
alias spd='sudo rm -rf /private/var/log/asl/*' # spd: Remove all log files in /private/var/log/asl/.
alias srv='python3 -m http.server'             # srv: Start a simple HTTP server.
alias t='tail -f'                              # t: Print last 10 lines of a file in real time.
alias x='quit'                                 # x: Exit the shell.

## Package manager aliases

alias apt-get='sudo apt-get'   # apt-get: Append sudo to apt-get command.
alias aptitude='sudo aptitude' # aptitude: Run command as superuser.
alias pacman='sudo pacman'     # pacman: Run command as superuser.
alias yum='sudo yum'           # yum: Run command as superuser.

## System aliases

alias da='date "+%Y-%m-%d %A %T %Z"'      # da: Display the current date and time.
alias moon='curl -s "wttr.in/?format=%m"' # moon: Get the moon phase.
alias nls='sudo lsof -i -P | grep LISTEN' # nls: Show only active network listeners.
alias now='date +"%T"'                    # now: Show the current time.
alias op='sudo lsof -i -P'                # op: List of open ports.
alias ping='ping -c 5'                    # ping: Limit Ping to 5 ECHO_REQUEST packets.
alias ports='sudo lsof -i -P'             # ports: List all listening ports.
alias top='sudo htop'                     # top: Display the top processes.
alias tree='tree --dirsfirst'             # tree: Display the directory tree.
alias wth='curl -s "wttr.in/?format=3"'   # wth: Get the weather.
alias wk='date +%V'                       # wk: Display the current week number.

## System control aliases

alias halt='sudo shutdown -h now'     # halt: Halt the system.
alias poweroff="sudo /sbin/shutdown"  # poweroff: Power off the system.
alias reboot='sudo shutdown -r now'   # reboot: Reboot the system.
alias shutdown='sudo shutdown -h now' # shutdown: Shut down the system.

## Terminal control aliases

alias reload='exec $SHELL -l' # reload: Reload the shell.
alias r='reload'              # r: Reload the shell.
