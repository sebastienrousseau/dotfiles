#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅳🅴🅵🅰🆄🅻🆃 🅰🅻🅸🅰🆂🅴🆂
alias ':q'='quit'                                                                           # q: Shortcut for the `exit` command.
alias bye='quit'                                                                            # q: Shortcut for the `exit` command.
alias ctf='echo $(ls -1 | wc -l)'                                                           # ctf: Count the number of files in the current directory.
alias curl='curl --compressed'                                                              # curl: Use compression when transferring data.
alias da='date "+%Y-%m-%d %A %T %Z"'                                                        # da: Display the current date and time.
alias del="rm -rfv"                                                                         # del: Remove a file or directory.
alias digg="dig @8.8.8.8 +nocmd any +multiline +noall +answer"                              # digg: Dig with Google's DNS.
alias h='history'                                                                           # h: Lists all recently used commands.
alias halt="sudo /sbin/halt"                                                                # halt: Shutdown the system.
alias ifconfig='sudo ifconfig'                                                              # ifconfig: Append sudo to ifconfig (configure network interface parameters) command.
alias ipinfo='ipconfig getpacket en0'                                                       # ipInfo0: Get network interface parameters for en0.
alias moon='curl -s "wttr.in/?format=%m"'                                                   # moon: Get the moon phase.
alias nls='sudo lsof -i -P | grep LISTEN'                                                   # nls: Show only active network listeners.
alias now='date +"%T"'                                                                      # now: Show the current time.
alias op='sudo lsof -i -P'                                                                  # op: List of open ports.
alias p='pwd'                                                                               # p: Shortcut for `pwd` which returns working directory name.
alias pa="clear && pwd && echo '' && ls && echo ''"                                         # pa: Clear the screen, show the current directory, and list the files.
alias paa="clear && pwd && echo '' && ls -a && echo ''"                                     # paa: Clear the screen, show the current directory, and list all files.
alias path='echo  ${PATH//:/\\n}'                                                           # path: Display the $PATH variable on newlines.
alias pid='ps -f'                                                                           # pid: Display the uid, pid, parent pid, recent CPU usage, process start time, controlling tty, elapsed CPU usage, and the associated command.
alias ping='ping -c 5'                                                                      # ping: Limit Ping to 5 ECHO_REQUEST packets.
alias please='sudo -'                                                                       # sudo: Execute a command as the superuser.
alias ports='netstat -tulan'                                                                # ports: List all listening ports.
alias poweroff="sudo /sbin/shutdown"                                                        # poweroff: Poweroff the system.
alias pp="clear && pwd"                                                                     # pp: Clear the screen and show the current directory.
alias ps='ps auxwww'                                                                        # kp: Getting full path of executables.
alias pt="clear && pwd && echo '' && tree ./ && echo ''"                                    # pt: Clear the screen and show the current directory and tree.
alias q='quit'                                                                              # q: Shortcut for the `exit` command.
alias qfind='find . -name '                                                                 # qfind: Quickly search for file.
alias quit='exit'                                                                           # q: Shortcut for the `exit` command.
alias r=reload                                                                              # r: Reload the shell.
alias reboot="sudo /sbin/reboot"                                                            # reboot: Reboot the system.
alias reload='exec $SHELL -l'                                                               # reload: Reload the shell.
alias rr="rm -rf"                                                                           # rr: Remove directory and all its contents.
alias rs='rsync -avz'                                                                       # rs: Rsync with verbose and progress.
alias shutdown='sudo shutdown -h now'                                                       # shutdown: Shutdown the system.
alias spd='sudo rm -rf /private/var/log/asl/*'                                              # spd: Remove all log files in /private/var/log/asl.
alias srv='python3 -m http.server'                                                          # srv: Start a simple HTTP server.
alias svi='sudo nano'                                                                       # svi: Run vi in sudo mode.
alias t='tail -f'                                                                           # t: Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time.
alias top='sudo btop'                                                                       # top: Allows the user to interactively monitor the system's vital resources or server's processes in real time.
alias trash='rm -fr ${HOME}/.Trash'                                                         # trash: Remove all files in the trash.
alias tree='tree --dirsfirst'                                                               # tree: Display a directory tree.
alias undopush="git push -f origin HEAD^:master"                                            # undopush: Undo the last push.
alias usage='du -ch | grep total'                                                           # usage: Grabs the disk usage in the current directory.
alias uuid="uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]'  | pbcopy && pbpaste && echo" # uuid: Generate a UUID and copy it to the clipboard.
alias wget='wget -c'                                                                        # wget: wget with resume.
alias wip='dig +short myip.opendns.com @resolver1.opendns.com'                              # wip: Get public IP address.
alias wk='date +%V'                                                                         # wk: Show the current week number.
alias wth='curl -s "wttr.in/?format=3"'                                                     # wth: Get the weather.
alias x='quit'                                                                              # q: Shortcut for the `exit` command.

if [[ "$(uname || true)" = "Darwin" ]]; then
  alias upd='
        sudo softwareupdate -i -a;
        pnpm up;
        rustup update stable;
        if [[ "$(command -v brew cu)" ]]; then
            brew cu -ayi;
        else
            brew tap buo/cask-upgrade;
        fi;
        brew doctor;
        brew update;
        brew upgrade;
        brew cleanup;
        mas upgrade;
        sudo gem update;
        sudo gem cleanup;
    '
elif [[ "$(uname || true)" = "Linux" ]]; then
  alias open="xdg-open >/dev/null 2>&1"     # open: Open a file or URL in the user's preferred application.
  alias pbcopy='xsel --clipboard --input'   # pbcopy: Copy to clipboard.
  alias pbpaste='xsel --clipboard --output' # pbpaste: Paste from clipboard.
  alias upd='
        sudo apt update;
        sudo apt upgrade -y;
        pnpm up;
        rustup update stable;
        sudo gem update;
        sudo gem cleanup;
    '
fi
