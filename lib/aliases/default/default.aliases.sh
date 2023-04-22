#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅳🅴🅵🅰🆄🅻🆃 🅰🅻🅸🅰🆂🅴🆂
alias ':q'='quit'                              # q: Shortcut for the `exit` command.
alias bye='quit'                               # bye: Shortcut for the `exit` command.
alias ctf='echo $(ls -1 | wc -l)'              # ctf: Count the number of files in the current directory.
alias curl='curl --compressed'                 # curl: Use compression when transferring data.
alias da='date "+%Y-%m-%d %A %T %Z"'           # da: Display the current date and time.
alias h='history'                              # h: Lists all recently used commands.
alias halt="sudo /sbin/halt"                   # halt: Shutdown the system.
alias ifconfig='sudo ifconfig'                 # ifconfig: Append sudo to ifconfig (configure network interface parameters) command.
alias ipinfo='ipconfig getpacket en0'          # ipinfo: Get network interface parameters for en0.
alias moon='curl -s "wttr.in/?format=%m"'      # moon: Get the moon phase.
alias nls='sudo lsof -i -P | grep LISTEN'      # nls: Show only active network listeners.
alias now='date +"%T"'                         # now: Show the current time.
alias op='sudo lsof -i -P'                     # op: List of open ports.
alias p='pwd'                                  # p: Shortcut for `pwd` which returns working directory name.
alias path='echo  ${PATH//:/\\n}'              # path: Display the $PATH variable on newlines.
alias ping='ping -c 5'                         # ping: Limit Ping to 5 ECHO_REQUEST packets.
alias please='sudo -'                          # please: Execute a command as the superuser.
alias ports='netstat -tulan'                   # ports: List all listening ports.
alias poweroff="sudo /sbin/shutdown"           # poweroff: Poweroff the system.
alias q='quit'                                 # q: Shortcut for the `exit` command.
alias qfind='find . -name '                    # qfind: Quickly search for file.
alias quit='exit'                              # quit: Shortcut for the `exit` command.
alias r='reload'                               # r: Reload the shell.
alias reboot='sudo /sbin/reboot'               # reboot: Reboot the system.
alias reload='exec $SHELL -l'                  # reload: Reload the shell.
alias shutdown='sudo shutdown -h now'          # shutdown: Shutdown the system.
alias spd='sudo rm -rf /private/var/log/asl/*' # spd: Remove all log files in /private/var/log/asl.
alias srv='python3 -m http.server'             # srv: Start a simple HTTP server.
alias t='tail -f'                              # t: Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time.
alias top='sudo btop'                          # top: Allows the user to interactively monitor the system's vital resources or server's processes in real time.
alias tree='tree --dirsfirst'                  # tree: Display a directory tree.
alias wk='date +%V'                            # wk: Show the current week number.
alias wth='curl -s "wttr.in/?format=3"'        # wth: Get the weather.
alias x='quit'                                 # q: Shortcut for the `exit` command.
