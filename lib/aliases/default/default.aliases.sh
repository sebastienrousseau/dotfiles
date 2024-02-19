#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT
# Script: default.aliases.sh
# Version: 0.2.468
# Website: https://dotfiles.io

# 🅳🅴🅵🅰🆄🅻🆃 🅰🅻🅸🅰🆂🅴🆂

## General aliases

# Shortcut for the `clear` command.
alias c="clear"

# Display the current date and time.
alias da='date "+%Y-%m-%d %A %T %Z"'

# Shortcut for `pwd` which returns working directory name.
alias p='pwd'

# Display the $PATH variable on newlines.
alias path='echo ${PATH//:/\\n}'

# Reload the shell.
alias r='reload'

# Prints the last 10 lines of a text or log file, and then waits for new
# additions to the file to print it in real time.
alias t='tail -f'

# wk: Show the current week number.
alias wk='date +%V'

## Exit/shutdown aliases

# Shortcut for the `exit` command.
alias ':q'='quit'

# Shortcut for the `exit` command.
alias bye='quit'

# Shortcut for the `exit` command.
alias q='quit'

# Shortcut for the `exit` command.
alias x='quit'

# Shortcut for the `exit` command.
alias quit='exit'

# Shutdown the system.
alias halt='sudo /sbin/halt'

# Poweroff the system.
alias poweroff='sudo /sbin/shutdown'

# Reboot the system.
alias reboot='sudo /sbin/reboot'

## Network aliases

# Append sudo to ifconfig (configure network interface parameters)
# command.
alias ifconfig='sudo ifconfig'

# Get network interface parameters for en0.
alias ipinfo='ipconfig getpacket en0'

# Show only active network listeners.
alias nls='sudo lsof -i -P | grep LISTEN'

# List of open ports.
alias op='sudo lsof -i -P'

# Limit Ping to 5 ECHO_REQUEST packets.
alias ping='ping -c 5'

# List all listening ports.
alias ports='netstat -tulan'

# Start a simple HTTP server.
alias srv='python3 -m http.server'

## System monitoring aliases

# Get the moon phase.
alias moon='curl -s "wttr.in/?format=%m"'

# Allows the user to interactively monitor the system's vital resources
# or server's processes in real time.
alias top='sudo btop'

# Remove all log files in /private/var/log/asl/.
alias spd='sudo rm -rf /private/var/log/asl/*'

## Utility aliases

# Count the number of files in the current directory.
alias ctf='echo $(ls -1 | wc -l)'

# Use compression when transferring data.
alias curl='curl --compressed'

# Quickly search for file.
alias qfind='find . -name '

# Reload the shell.
alias reload='exec $SHELL -l'

# Get the weather.
alias wth='curl -s "wttr.in/?format=3"'

# File system navigation aliases

# Clear the terminal screen and print the contents of the current
# directory.
alias clc='clear && ls -a'

# Clear the terminal screen and print
alias clp='pwd'
