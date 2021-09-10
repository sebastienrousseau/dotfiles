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
# Sections:
#
#   1. System detection utility.
#      1.1 Detect which `ls` flavor is in use.
#      1.2 Aliases for the GNU coreutils (Core GNU utilities) programs.
#      1.3 Detect which `ls` flavor is in use.
#
#   2. System tools and system information aliases.
#      2.1 System tools aliases.
#      2.2 Checking that the aliases are already installed.
#
#   3. Common shell aliases.
#      3.1 Generic aliases.
#      3.2 Finding (find and grep).
#      3.3 List directory aliases commands (ls).
#      3.4 Networking aliases.
#      3.5 Quicker navigation aliases.
#      3.6 Jekyll Aliases. 
#
#   4. sssNetworking aliases.
#   ) Quicker navigation
#   ) Jekyll
#   ) Heroku's commands
#   ) Ionic commands
#   ) Emulate iOS using different Apple devices
#   ) Git SCM Cheats
#   ) App engine commands
#   ) Add an 'alert' alias for long running commands.
#   ) Get OS X Software Updates, update and upgrade Homebrew packages
#   ) Shorter commands for `Homebrew`.
#   ) Speed-up Terminal load time by clearing system logs
#   ) Empty the Trash on all mounted volumes and the main HDD
#   ) Open the device simulators
#   ) Recursively delete .DS_Store files
#   ) Hidden Files
#   ) Clean up LaunchServices to remove duplicates in the 'Open With' menu
#   ) Run a screen saver on the Desktop
#   ) Things for Subversion
#   ) Application launchers
#   ) Recommended 'top' invocation to minimize resources
#   ) Networking
#   ) Limit Ping to 5 ECHO_REQUEST packets
#   ) Wget with resume
#   ) Searching
#   ) Find memory hogs
#   ) Find CPU hogs
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


#   ----------------------------------------------------------------------------
#  	1.0 System detection utility
#   ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Detect which `ls` flavor is in use
##  ----------------------------------------------------------------------------
# 
#     if ls --color > /dev/null 2>&1; then # GNU `ls`
#         colorflag='--color'
#     export colorflag
#         export LS_COLORS='no=00:fi=00:di=01;31:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
#     else # macOS `ls`
#         colorflag='-G'
#     export colorflag
#         export CLICOLOR=1
#         export LSCOLORS='GxFxCxDxBxegedabagaced'
#     fi
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  1.2 Aliases for the GNU coreutils (Core GNU utilities) programs
# ##  ----------------------------------------------------------------------------
# 
# # Only applying these aliases on macOS.
# if [ "$(uname -s)" == "Darwin" ]; then
# 
#     # Install command: `brew install findutils`
#     #  Switch dircolors by gnu dircolors.
#     if [ "$(type -P gdircolors)" ]; then
#         alias dircolors="gdircolors"
#     fi
# 
#     #  Switch find by gnu find.
#     if [ "$(type -P gfind)" ]; then
#         alias find="gfind"
#     fi
# 
#     #  Switch grep by gnu grep.
#     if [ "$(type -P ggrep)" ]; then
#         alias grep="ggrep"
#     fi
# 
#     #  Switch readlink by gnu readlink.
#     if [ "$(type -P greadlink)" ]; then
#         alias readlink="greadlink"
#     fi
# 
#     #  Switch sed by gnu sed.
#     if [ "$(type -P gsed)" ]; then
#         alias sed="gsed"
#     fi
# 
#     #  Switch sort by gnu sort.
#     if [ "$(type -P gsort)" ]; then
#         alias sort="gsort"
#     fi
# fi
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  1.3 Checking that the aliases are already installed
# ##  ----------------------------------------------------------------------------
# 
# #alias alias='alias | sort -nk 10'
# 
# 
# 
# #   ----------------------------------------------------------------------------
# #   2. System tools and system information aliases.
# #   ----------------------------------------------------------------------------
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  2.1 System tools aliases.
# ##  ----------------------------------------------------------------------------
# 
# # htop: Append sudo to htop (interactive process viewer) command.
# alias htop='sudo htop'
# 
# # ifconfig: Append sudo to ifconfig (configure network interface parameters) command.
# alias ifconfig='sudo ifconfig'
# 
# # iotop: Append sudo to iotop (display top disk I/O events by process) command.
# alias iotop='sudo iotop'
# 
# # iptables: Append sudo to iptables (Administration tool for packet filtering) command.
# alias iptables='sudo iptables'
# 
# # purge: Purging Xcode DerivedData.
# alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'
# 
# # reload: Reset and initialize the Terminal screen.
# alias reload='reset'
# 
# # sudo: Allows a system administrator to delegate authority to give certain users
# # (or groups of users) the ability to run some (or all) commands as root or another 
# # user while providing an audit trail of the commands and their arguments.
# alias sudo='sudo '
# 
# # top: Allows the user to interactively monitor the system's vital resources or 
# # server's processes in real time.
# alias top='htop'
# 
# # ttop: Recommended 'top' invocation to minimize resources
# alias ttop='top -F -s 10  rsize'
# 
# # Quick access to the .zshrc file.
# alias zshrc='${=EDITOR} $HOME/.zshrc'
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  2.2 System information aliases
# ##  ----------------------------------------------------------------------------
# 
# # Getting full path of executables. The "auxwww" are options to the ps (process)
# # command. The options mean display all process running that belong to you and 
# # to other users and provide information about who owns what process. 
# # The three "www"'s mean display the entire command line regardless of how long 
# # it is and wrap it in your window.
# alias kp='ps auxwww'
# 
# # Display the uid, pid, parent pid, recent CPU usage, process start time, 
# # controlling tty, elapsed CPU usage, and the associated command.
# alias pid='ps -f'
# 
# # Limit Ping to 5 ECHO_REQUEST packets.
# alias ping='ping -c 5'
# 
# # Display ports
# alias ports='netstat -tulan'
# 
# # Getting top 3 CPU eating processes
# alias pscpu='ps aux | sort -nr -k 3 | head -3'
# 
# # Getting top 10 CPU eating processes
# alias pscpu10='ps aux | sort -nr -k 3 | head -10'
# 
# # Getting top 3 memory eating processes
# alias psmem='ps aux | sort -nr -k 4 | head -3'
# 
# # Getting top 10 memory eating processes
# alias psmem10='ps aux | sort -nr -k 4 | head -10'
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  2.3 Interactive mode commands
# ##  ----------------------------------------------------------------------------
# 
# ## Interactive mode aliases.
# 
# # cp: Copy files with warning
# alias cp='cp -i'
# 
# # ln: Make links with warning
# alias ln='ln -i'
# 
# # mv: Move files with warning
# alias mv='mv -i'
# 
# # rm: Remove file with warning
# alias rm='rm -i'
# 
# # zap: Remove file with warning
# alias zap='rm -i'
# 
# 
# #   ----------------------------------------------------------------------------
# #   3. Common shell aliases.
# #   ----------------------------------------------------------------------------
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  3.1 Generic aliases.
# ##  ----------------------------------------------------------------------------
# 
# # c: Clear screen shortcut.
# alias c="clear && printf '\e[3J'"
# 
# # cls: Clear screen command.
# alias cls="clear && printf '\e[3J'"
# 
# # countf: Count of non-hidden files in current dir.
# alias countf='echo $(ls -1 | wc -l)' 
# 
# # dt: Pipe content to file in the $HOME directory.
# alias dt='tee $HOME/terminal-$(date +%F).txt'
# 
# # du: File size human readable output sorted by size.
# alias du='du -h'
# 
# # dud: File size human readable output sorted by depth.
# alias dud='du -d 1 -h'
# 
# # duf: File size human readable output sorted.
# alias duf='du -sh *'
# 
# # egz: Extract a whole directory (including subdirectories) 
# alias egz='tar -xvzf'
# 
# # flush: Flush the directory service cache and restart the multicast DNS daemon.
# alias flush='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
# 
# # h: Lists all recently used commands.
# alias h='history'
# 
# # hs: Use grep to search the command history.
# alias hs='history | grep'
# 
# # hsi: Use grep to do a case-insensitive search of the command history.
# alias hsi='history | grep -i'
# 
# # gz: Compress a whole directory (including subdirectories) 
# alias gz='tar -zcvf'
# 
# # locale: Check UTF-8 locale.
# alias locale='locale -a | grep UTF-8'
# 
# # mkdir: Create the directory and all parent directories, verbose mode.
# alias mkdir='mkdir -pv'
# 
# # p: Shortcut for `pwd` which returns working directory name.
# alias p='pwd'
# 
# # path: Display the $PATH variable on newlines.
# alias path='echo -e ${PATH//:/\\n}'
# 
# # q: Shortcut for the `exit` command.
# alias q='exit'
# 
# # r: Shortcut for the `reload` command.
# alias r='reload'
# 
# # reboot: Restart immediately.
# alias reboot="sudo shutdown -r now"
# 
# # reload: Reload the Z shell.
# alias reload=". ~/.zshrc"
# 
# # rp: Repair macOS Permissions.
# alias rp='diskutil repairPermissions /'
# 
# # rv: Repair macOS Volume.
# alias rv='diskutil repairvolume /'
# 
# # rmdir: Remove directory.
# alias rmdir='rm –rf'
# 
# # shutdown: Shutdown immediately.
# alias shutdown="sudo shutdown -h now"
# 
# # sort: Fix sorting order
# alias sort='LC_ALL=C sort'
# 
# # sortnr: Sort in a descending order according to numerical value.
# alias sortnr='sort -n -r'
# 
# # t: Prints the last 10 lines of a text or log file, and then waits for new 
# # additions to the file to print it in real time. 
# alias t='tail -f'
# 
# # vp: Verify macOS Permissions 
# alias vp='diskutil verifyPermissions /'
# 
# # vv: Verify macOS Volume 
# alias vv='diskutil verifyvolume /'
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  3.2 Finding (find and grep)
# ##  ----------------------------------------------------------------------------
# 
# # egrep: Searches that can handle extended regular expressions (EREs)
# alias egrep='egrep --color'
# 
# # fd: Find a directory with a given name
# alias fd='find . -type d -name'
# 
# # ff: Find a file with a given name
# alias ff='find . -type f -name'
# 
# # fgrep: Searches that can only handle fixed patterns
# alias fgrep='fgrep --color'
# 
# # grep: Searches for a query string
# alias grep='grep --color'
# 
# # hgrep: Searches for a word in the list of previously used commands.
# alias hgrep='history | grep'
# 
# # sgrep: Useful for searching within files
# alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  3.3 List directory aliases commands (ls)
# ##  ----------------------------------------------------------------------------
# 
# # l: Size, show type, human readable.
# alias l='ls -lFh'
# 
# # l1: Display one file per line.
# alias l1='ls -1'
# 
# # la: Long list, show almost all, show type, human readable.
# alias la='ls -lAFh'
# 
# # lart: Force output to be one entry per line, last changed, 
# # includes directory entries whose names begin with a dot, reverse, sort by time 
# # modified.
# alias lart='ls -1Fcart'
# 
# # last: Sorts all files by modification time, showing the last edited file first.
# alias last='ls -t'
# 
# # lc: Sort by/show change time,most recent last.
# alias lc='ls -ltcr'
# 
# # ld: Display directory information.
# alias ld='ls -ld'
# 
# # ldot: Display only dot files.
# alias ldot='ls -ld .*'
# 
# # lf: Visual Classification of Files With Special Characters.
# alias lf='ls -lf'
# 
# # lh: Display file size in human readable format.
# alias lh='ls -lh'
# 
# # li: Display File Inode Number. 
# alias li='ls -i'
# 
# # lk: Sort by size, biggest last.
# alias lk='ls -lSr'
# 
# # ll: Long list
# alias ll='ls -lghFG | sort -n -td -k2'  
# 
# # ln: Display File UID and GID. 
# alias ln='ls -n'
# 
# # lq: Hide Control Characters.
# alias lq='ls -q'
# 
# # lr: Display Files Recursively sorted by date,recursive, show type, human readable.
# alias lr='ls -tRFh'
# 
# # lrt: Order Files Based on Last Modified Time (In Reverse Order).
# alias lrt='ls -1Fcrt'
# 
# # lS: Order Files Based on Last Modified Time and size.
# alias lS='ls -1FSsh'
# 
# # lsd: Display only directories.
# alias lsd='ls -l | grep "^d"'
# 
# # lt: Display Files long list, sorted by date, show type, human readable.
# alias lt='ls -ltFh'
# 
# # ltr: Sort by date, most recent last.
# alias ltr='ls -ltr'
# 
# # lu: Sort by/show access time,most recent last.        
# alias lu='ls -ltur'
# 
# # lx: Sort by extension.
# alias lx='ls -lXB'
# 
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  3.4 Networking aliases
# ##  ----------------------------------------------------------------------------
# 
# 
# # ipInfo0: Get info on connections for en0.
# alias ipInfo0='ipconfig getpacket en0'
# 
# # ipInfo1: Get info on connections for en1.
# alias ipInfo1='ipconfig getpacket en1'
# 
# # lsock: Display open sockets.
# alias lsock='sudo /usr/sbin/lsof -i -P'
# 
# # lsockTCP: Display only open TCP sockets.
# alias lsockTCP='sudo /usr/sbin/lsof -nP | grep TCP'
# 
# # lsockUDP: Display only open UDP sockets.
# alias lsockUDP='sudo /usr/sbin/lsof -nP | grep UDP'
# 
# # lsof: Show all open TCP/IP sockets.
# alias lsof='lsof -i'
# 
# # mic: Listening to all connections.
# alias mic='sudo lsof -i | grep LISTEN'
# 
# # op: List of open ports.
# alias op='sudo lsof -i -P'
# 
# # wip: Public facing IP Address.
# alias wip='dig +short myip.opendns.com @resolver1.opendns.com'
# 
# 
# 
# 
# ##  ----------------------------------------------------------------------------
# ##  3.5 Quicker navigation aliases.
# ##  ----------------------------------------------------------------------------
# 
# # ~: Change to $HOME directory.
# alias ~="cd ~"
# 
# # cd.: Show true (physical) path instead of symbolic links in the path.
# alias cd.="cd -P ."
# 
# # cd/: Change to / root directory and show the directory content. 
# alias cd/='cd /; ls'
# 
# # gitRoot: Change to Git Root directory.
# alias gitRoot='cd "$(git rev-parse --show-toplevel)"'
# 
# # .: Move back to one level and show the directory content. 
# alias .='cd ..; ls'
# 
# # ..: Move back to two levels and show the directory content. 
# alias ..='cd ../..; ls'
# 
# # ...: Move back to three levels and show the directory content. 
# alias ...='cd ../../..; ls'
# 
# # ....: Move back to four levels and show the directory content. 
# alias ....='cd ../../../..; ls'
# 
# # .....: Move back to five levels and show the directory content. 
# alias .....='cd ../../../../..; ls'
# 
# # cd .: Move back to one level and show the directory content. 
# alias cd .='cd ..; ls'
# 
# # cd ..: Move back to two levels and show the directory content. 
# alias cd ..='cd ../..; ls'
# 
# # cd ...: Move back to three levels and show the directory content. 
# alias cd ...='cd ../../..; ls'
# 
# # cd ....: Move back to four levels and show the directory content. 
# alias cd ....='cd ../../../..; ls'
# 
# # cd .....: Move back to five levels and show the directory content. 
# alias cd .....='cd ../../../../..; ls'
# 
# # -: Navigate to the previous one level directory (or back) and show the directory content. 
# alias -='cd -; ls'
# 
# # --: Navigate to the previous two levels directory (or back) and show the directory content. 
# alias --='cd -2; ls'
# 
# # ---: Navigate to the previous three levels directory (or back) and show the directory content. 
# alias ---='cd -3; ls'
# 
# # ----: Navigate to the previous four levels directory (or back) and show the directory content. 
# alias ----='cd -4; ls'
# 
# # -----: Navigate to the previous five levels directory (or back) and show the directory content. 
# alias -----='cd -5; ls'
# 
# # 1: Navigate to the previous one level directory (or back) and show the directory content. 
# alias 1='cd -; ls'
# 
# # 2: Navigate to the previous two levels directory (or back) and show the directory content.
# alias 2='cd -2; ls'
# 
# # 3: Navigate to the previous three levels directory (or back) and show the directory content.
# alias 3='cd -3; ls'
# 
# # 4: Navigate to the previous four levels directory (or back) and show the directory content.
# alias 4='cd -4; ls'
# 
# # 5: Navigate to the previous five levels directory (or back) and show the directory content.
# alias 5='cd -5; ls'
# 
# # 1.: Move back to one level and show the directory content. 
# alias 1.='cd ..; ls'
# 
# # 2.: Move back to two levels and show the directory content. 
# alias 2.='cd ../..; ls'
# 
# # 3.: Move back to three levels and show the directory content. 
# alias 3.='cd ../../..; ls'
# 
# # 4.: Move back to four levels and show the directory content. 
# alias 4.='cd ../../../..; ls'
# 
# # 5.: Move back to five levels and show the directory content.
# alias 5.='cd ../../../../..; ls'
# 
# # cd 1.: Move back to one level and show the directory content.
# alias cd 1.='cd ..; ls'
# 
# # cd 2.: Move back to two levels and show the directory content.
# alias cd 2.='cd ../..; ls'
# 
# # cd 3.: Move back to three levels and show the directory content.
# alias cd 3.='cd ../../..; ls'
# 
# # cd 4.: Move back to four levels and show the directory content. 
# alias cd 4.='cd ../../../..; ls'
# 
# # cd 5.: Move back to five levels and show the directory content.
# alias cd 5.='cd ../../../../..; ls'
# 
# # less: Make less always work with colored input.
# alias less='less -R'
# 
# # openDir: Open any folder from macOS Terminal.
# alias openDir='open -a Finder ./'
# 
# # path: Display or print $PATH variable.
# alias path='echo "$PATH" | tr ":" "\n" | nl'
# 
# # so: Lists the active options.
# alias so='setopt'
# 
# # uso: Lists the inactive options.
# alias uso='unsetopt'
# 
# 
# 
# #  ---------------------------------------------------------------------------
# #  	11.  Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
# #  ---------------------------------------------------------------------------
# 
# # Get macOS Software Updates, and update installed Ruby gems, Homebrew, npm, and their installed packages
# 
# alias update='sudo softwareupdate -i -a; brew cu --all; brew doctor; brew update; brew upgrade; brew cask cleanup; brew prune; brew cleanup; mas upgrade; npm install npm -g; npm update -g; sudo gem update --system; sudo gem update; sudo gem cleanup'
# 
# #  ---------------------------------------------------------------------------
# #  	12.  Shorter commands for `Homebrew`.
# #  ---------------------------------------------------------------------------
# 
# alias brewd='brew doctor'
# alias brewi='brew install'
# alias brews='brew search'
# alias brewu='brew uninstall'
# alias brewupdate='brew update && brew upgrade && brew cleanup && brew doctor'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	13.  Speed-up Terminal load time by clearing system logs
# #  ---------------------------------------------------------------------------
# 
# alias speedup='sudo rm -rf /private/var/log/asl/*'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	14.  Empty the Trash on all mounted volumes and the main HDD
# # Also, clear Apple’s System Logs to improve shell startup speed
# #  ---------------------------------------------------------------------------
# 
# alias emptytrash='rm -rf ~/.Trash/*'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	15.  Open the device simulators
# #  ---------------------------------------------------------------------------
# 
# alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	16.  cleanupDS: Recursively delete .DS_Store files
# #  ---------------------------------------------------------------------------
# 
# alias cleanupDS='find . -type f -name ''*.DS_Store'' -ls -delete'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	17.  Hidden Files  
# #   finderShowHidden:   Show hidden files in Finder
# #   finderHideHidden:   Hide hidden files in Finder
# #  ---------------------------------------------------------------------------
# 
# alias finderHideHidden='defaults write com.apple.finder ShowAllFiles FALSE'
# alias finderShowHidden='defaults write com.apple.finder ShowAllFiles TRUE'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	18.  cleanupLS:  Clean up LaunchServices to remove duplicates in the 'Open With' menu
# #  ---------------------------------------------------------------------------
# 
# alias cleanupLS='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	19.  screensaverDesktop: Run a screensaver on the Desktop
# #  ---------------------------------------------------------------------------
# 
# alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	20.  Subversion
# #  ---------------------------------------------------------------------------
# 
# alias sa='svn add'
# alias sc='svn commit'
# alias sd='svn delete'
# alias sm='svn move'
# alias sr='svn rename'
# alias ss='svn status'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	21.  Application launchers
# #  ---------------------------------------------------------------------------
# 
# alias css='open -a /Applications/CSSEdit.app'
# alias e='open -a "Visual Studio Code"'
# alias edit='open -a "Visual Studio Code"'
# alias ipinfo='$HOME/Bin/gt-ipinfo.sh'
# alias mate='open -a "Visual Studio Code"'
# alias preview='open -a /System/Applications/Preview.app'
# alias sql='open -a /Applications/Sequel\ Pro.app'
# alias www='open -a /Applications/Safari.app'
# alias xcode='open -a xcode'
# 
# 
# 
# 
# 
# 
# #  ---------------------------------------------------------------------------
# #  	25.  wget with resume
# #  ---------------------------------------------------------------------------
# 
# alias wget='wget -c'
# 
# 
# #  ---------------------------------------------------------------------------
# #  	26.  Searching
# #  ---------------------------------------------------------------------------
# 
# alias qfind='find . -name '              # qfind:    Quickly search for file
# 
# 
# #  ---------------------------------------------------------------------------
# #  	27.  memHogsTop, memHogsPs:  Find memory hogs
# #  ---------------------------------------------------------------------------
# 
# alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'
# alias memHogsTop='top -l 1 -o rsize | head -20'
# 
# #  ---------------------------------------------------------------------------
# #  	28.  cpuHogs:  Find CPU hogs
# #  ---------------------------------------------------------------------------
# 
# alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'
# 