#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)
#
# 🅰🅻🅸🅰🆂🅴🆂
unalias -a                                  # Remove all previous environment defined aliases.
alias _='sudo -'                            # sudo: Execute a command as the superuser.
alias -- -='cd -'                             # -: Shortcut to go to previous directory.
alias .....='cd ../../../..'                # .....: Shortcut to go to great-great-grandparent directory.
alias ....='cd ../../..'                    # ....: Shortcut to go to great-grandparent directory.
alias ...='cd ../..'                        # ...: Shortcut to go to grandparent directory.
alias ..='cd ..'                            # ..: Shortcut to go to parent directory.
alias ':q'='quit'                           # q: Shortcut for the `exit` command.
alias '~'='cd ~'                            # ~: Shortcut to go to home directory.
alias 'l.'="ls -dlhF .* | grep -v '^d'"     # l.: List hidden files.
alias 000='chmod -R 000'                    # 000: Make all files and directories read-only.
alias 644='chmod -R 644'                    # 644: Make all files and directories readable and writable.
alias 666='chmod -R 666'                    # 666: Make all files and directories readable and writable.
alias 755='chmod -R 755'                    # 755: Make all files and directories readable and writable.
alias 777='chmod -R 777'                    # 777: Make all files and directories readable and writable.
alias bye='quit'                            # q: Shortcut for the `exit` command.
alias c="clear"                             # c: Clear screen shortcut.
alias cde="cd ~/Code; ls"                   # cde: Shortcut to go to the Code directory and list its contents.
alias cgz='tar -zcvf'                       # cgz: Compress a whole directory (including subdirectories) to a tarball.
alias chmox='chmod +x'                      # chmox: Make a file executable.
alias cl="clear"                            # c: Clear screen shortcut.
alias clear="clear && printf '\e[3J'"       # c: Clear screen shortcut.
alias clr="clear"                           # c: Clear screen shortcut.
alias cr='cargo run'                        # cr: Run cargo.
alias ctf='echo $(ls -1 | wc -l)'           # ctf: Count the number of files in the current directory.
alias curl='curl --compressed'              # curl: Use compression when transferring data.
alias da='date "+%Y-%m-%d %A %T %Z"'        # da: Display the current date and time.
alias digg="dig @8.8.8.8 +nocmd any +multiline +noall +answer"           # digg: Dig with Google's DNS.
alias dn="cd ~/Downloads; ls"               # dn: Shortcut to go to the Downloads directory and list its contents.
alias dot='cd $DOTFILES'                    # dot: Shortcut to go to the dotfiles directory.
alias ds="cd ~/Documents; ls"               # ds: Shortcut to go to the Documents directory and list its contents.
alias dsp="sudo du -shc ."                  # dsp: Show the size of the current directory.
alias dt="cd ~/Desktop; ls"                 # dt: Shortcut to go to the Desktop directory and list its contents.
alias du='sudo du -h'                       # du: File size human readable output sorted by size.
alias duf='sudo du -sh *'                   # duf: File size human readable output sorted.
alias e='vim'                               # e, edit, mate: Edit current file.
alias edit='vim'                            # e, edit, mate: Edit current file.
alias egz='tar -xvzf'                       # egz: Extract a whole directory (including subdirectories)
alias f='find . -name '                     # f: Quickly search for file
alias fd='find . -type d -name'             # fd: Quickly search for directory
alias ff='find . -type f -name'             # ff: Quickly search for file
alias g='git'                               # g: Shortcut to git.
alias ga='git add '                         # ga: Shortcut to git add.
alias gb='git branch '                      # gb: Shortcut to git branch.
alias gc='git commit -m '                   # gc: Shortcut to git commit.
alias gcb="git checkout -b "                # gcb: Create a new branch and switch to it.
alias gcl='git clone '                      # gcl: Shortcut to git clone.
alias gco='git checkout '                   # gco: Shortcut to git checkout.
alias gd='git diff '                        # gd: Shortcut to git diff.
alias gf='git fetch '                       # gf: Shortcut to git fetch.
alias gl='git log '                         # gl: Shortcut to git log.
alias gmv='git mv'                          # gmv: Move or rename a file, a directory, or a symlink.
alias gph="git push"                        # gp: Push local commits to remote.
alias gpl="git pull"                        # gl: Update and merge remote changes.
alias gr='git remote '                      # gr: Shortcut to git remote.
alias grm='git remove'                      # grm: Remove files from the working tree and from the index.
alias grt='cd "$(git rev-parse --show-toplevel)"'                        # gr: Change to Git Root directory.
alias gst='git status '                     # gst: Shortcut to git status.
alias gsta='git stash save '                # gsta: Shortcut to git stash save.
alias gz='tar -zcvf'                        # gz: Compress a whole directory (including subdirectories) to a tarball.
alias h='history'                           # h: Lists all recently used commands.
alias halt="sudo /sbin/halt"                # halt: Shutdown the system.
alias ifconfig='sudo ifconfig'              # ifconfig: Append sudo to ifconfig (configure network interface parameters) command.
alias ip="ip4; ip6"                         # ip: Get the public IPv4 and IPv6 addresses.
alias ip4="dig +short myip.opendns.com @resolver1.opendns.com -4"        # ip4: Get the public IPv4 address.
alias ip6="dig -6 AAAA +short myip.opendns.com. @resolver1.opendns.com." # ip6: Get the public IPv6 address.
alias ipinfo='ipconfig getpacket en0'                                    # ipInfo0: Get network interface parameters for en0.
alias l='ls -lFh'                            # l: Size, show type, human readable.
alias l1='ls -1'                             # l1: Display one file per line.
alias la='ls -Alh'                           # la: show hidden files on the command line.
alias labc='ls -lap'                         # labc: List all files in alphabetical order.
alias lc='wc -l'                             # lc: Count the number of lines in the file.
alias lct='ls -lcrh'                         # lc: sort by change time
alias ldir="ls -l | egrep '^d'"              # directories only
alias ldot="l."                              # l.: List hidden files.
alias left='ls -t -1'                        # left: List files by date, most recent last.
alias lf="ls -l | egrep -v '^d'"             # files only
alias lk='ls -lSrh'                          # lk: sort by size
alias ll='ls -lAFh'                          # ll: Long list, show almost all, show type, human readable.
alias lla='ls -l -d $PWD/*'                  # lla: List full path of all files in current directory.
alias lm='ls -alh |more'                     # lm: pipe through 'more'
alias ln='ln -i'                             # ln: interactive symbolic link
alias locale='locale -a | grep UTF-8'        # locale: List all available locales.
alias lp='sudo lsof -i -T -n'                # lp: List all open ports.
alias lr='ls -lRh'                           # lr: recursive ls
alias ls='ls --color'                        # ls: Colorize the output.
alias lS='ls -1FSsh'                         # lS: Order Files Based on Last Modified Time and size.
alias lt='ls -ltrh'                          # lt: sort by date
alias lu='ls -lurh'                          # lu: sort by access time
alias lw='ls -xAh'                           # wide listing format
alias lx='ls | sort -k 1,1 -t .'             # lx: sort by extension
alias mate='vim'                             # e, edit, mate: Edit current file.
alias mc='make clean'                        # mc: Make clean.
alias md='mkd'                               # mkd: Create the directory and all parent directories, verbose mode.
alias mi='make install'                      # mi: Make install.
alias mk=make                                # mk: Make.
alias mkbz2='tar -cvjf'                      # mkbz2: Create a temporary tar ball compressed with bzip2.
alias mkd='mkdir -pv'                        # mkd: Create the directory and all parent directories, verbose mode.
alias mkcd='mkdir -pv && cd'                 # mkcd: Create the directory and all parent directories, verbose mode, then change to it.
alias mkdd='mkdir -pv $(date +%Y%m%d)'       # mkdd: Create a directory with the current date.
alias mkgz='tar -cvzf'                       # mkgz: Create a temporary tar ball compressed with gzip.
alias mkh="make help"                        # mkh: Make help.
alias mkr="make run"                         # mkr: Make run.
alias mkt="make test"                        # mkt: Make test.
alias mktar='tar -cvf'                       # mktar: Create a temporary tarball.
alias mv='mv -vi'                            # mv: Move files interactively (ask before overwrite) and verbose.
alias mx='chmod a+x'                         # mx: Make executable.
alias nls='sudo lsof -i -P | grep LISTEN'    # nls: Show only active network listeners.
alias now='date +"%T"'                       # now: Show the current time.
alias npmi='npm install '                    # npmi: Install npm package.
alias npms='npm start '                      # npms: Start npm package.
alias op='sudo lsof -i -P'                   # op: List of open ports.
alias p='pwd'                                # p: Shortcut for `pwd` which returns working directory name.
alias path='echo -e ${PATH//:/\\n}'          # path: Display the $PATH variable on newlines.
alias pid='ps -f'                            # pid: Display the uid, pid, parent pid, recent CPU usage, process start time, controlling tty, elapsed CPU usage, and the associated command.
alias ping='ping -c 5'                       # ping: Limit Ping to 5 ECHO_REQUEST packets.
alias please='sudo -'                        # sudo: Execute a command as the superuser.
alias pn='pnpm'                              # pn: Shortcut to pnpm.
alias ports='netstat -tulan'                 # ports: List all listening ports.
alias poweroff="sudo /sbin/shutdown"         # poweroff: Poweroff the system.
alias ps='ps auxwww'                         # kp: Getting full path of executables.
alias q='quit'                               # q: Shortcut for the `exit` command.
alias qfind='find . -name '                  # qfind: Quickly search for file.
alias quit='exit'                            # q: Shortcut for the `exit` command.
alias r=reload                               # r: Reload the shell.
alias reboot="sudo /sbin/reboot"             # reboot: Reboot the system.
alias reload='exec $SHELL -l'                # reload: Reload the shell.
alias rm='rm -I'                             # rm: Prompts for every file before removing.
alias rr="rm -rf"                            # rr: Remove directory and all its contents.
alias shutdown='sudo shutdown -h now'        # shutdown: Shutdown the system.
alias spd='sudo rm -rf /private/var/log/asl/*'                 # spd: Remove all log files in /private/var/log/asl.
alias srv='python3 -m http.server'           # srv: Start a simple HTTP server.
alias svi='sudo vi'                          # svi: Run vi in sudo mode.
alias t='tail -f'                            # t: Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time.
alias top='sudo btop'                        # top: Allows the user to interactively monitor the system's vital resources or server's processes in real time.
alias trash="rm -fr ~/.Trash"                # trash: Remove all files in the trash.
alias tree='tree -CAhF --dirsfirst'          # tree: Display a directory tree.
alias unbz2='tar -xvjf'                      # unbz2: Extract a tarball compressed with bzip2.
alias undopush="git push -f origin HEAD^:master"               # undopush: Undo the last push.
alias ungz='tar -xvzf'                       # ungz: Extract a tarball compressed with gzip.
alias untar='tar -xvf'                       # untar: Extract a tarball.
alias usage='du -ch | grep total'            # usage: Grabs the disk usage in the current directory.
alias v='vim $(f)'                           # v: Edit a file.
alias v='vim'                                # e, edit, mate: Edit current file.
alias vs="code ./"                           # vs: Open VS Code.
alias wget='wget -c'                         # wget: wget with resume.
alias wip='dig +short myip.opendns.com @resolver1.opendns.com' # wip: Get public IP address.
alias wk='date +%V'                          # wk: Show the current week number.
alias wth='curl https://wttr.in'             # wth: Get the weather.
alias x='quit'                               # q: Shortcut for the `exit` command.

if [ "$(uname)" = "Darwin" ]; then
    alias upd='
        sudo softwareupdate -i -a;
        pnpm i;
        pnpm update;
        # brew cu --all;
        # brew doctor;
        # brew update;
        # brew upgrade;
        # brew cleanup;
        mas upgrade;
        npm install npm -g;
        npm update -g;
        sudo gem update --system;
        sudo gem update;
        sudo gem cleanup;
        npm update ncu;
        npm audit fix;
        ncu -g;'
elif [ "$(uname)" = "Linux" ]; then
    alias open="xdg-open >/dev/null 2>&1" # open: Open a file or URL in the user's preferred application.
    alias pbcopy='xsel --clipboard --input'      # pbcopy: Copy to clipboard.
    alias pbpaste='xsel --clipboard --output'    # pbpaste: Paste from clipboard.
    alias upd='
        sudo apt update;
        sudo apt upgrade -y;
        pnpm i;
        pnpm update;
        npm install npm -g;
        npm update -g;
        sudo gem update --system;
        sudo gem update;
        sudo gem cleanup;
        npm update ncu;
        npm audit fix;
        ncu -g;'
fi
