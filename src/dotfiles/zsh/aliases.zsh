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
#	1.  Allow aliases to be with sudo
#  	2.  Generic aliases
#  	3.  Quicker navigation
#  	4.  Jekyll
#  	7.  Emulate iOS using different Apple devices
#  	9.  App engine commands
#  	10. Add an 'alert' alias for long running commands.
#  	11. Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
#  	12. Shorter commands for `Homebrew`.
#  	13. Speed-up Terminal load time by clearing system logs
#  	14. Empty the Trash on all mounted volumes and the main HDD
#  	15. Open the device simulators
#  	16. Recursively delete .DS_Store files
#  	17. Hidden Files
#  	18. Clean up LaunchServices to remove duplicates in the 'Open With' menu
#  	19. Run a screen saver on the Desktop
#  	20. Things for Subversion
#  	21. Application launchers
#  	22. Recommended 'top' invocation to minimize resources
#  	23. Networking
#  	24. Limit Ping to 5 ECHO_REQUEST packets
#  	25. Wget with resume
#  	26. Searching
#  	27. Find memory hogs
#  	28. Find CPU hogs
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#


# Detect which `ls` flavour is in use
if ls --color > /dev/null 2>&1; then # GNU `ls`
	colorflag='--color'
  export colorflag
	export LS_COLORS='no=00:fi=00:di=01;31:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:'
else # macOS `ls`
	colorflag='-G'
  export colorflag
	export CLICOLOR=1
	export LSCOLORS='GxFxCxDxBxegedabagaced'
fi


#  ---------------------------------------------------------------------------
#  	1.  Allow aliases to be with sudo
#       Please refer to http://www.shellperson.net/using-sudo-with-an-alias/
#  ---------------------------------------------------------------------------

# Common
alias sudo='sudo '
alias reload='reset'
alias zshrc='${=EDITOR} ${ZDOTDIR:-$HOME}/.zshrc' # Quick access to the .zshrc file

# Purging Xcode DerivedData
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'


#  ---------------------------------------------------------------------------
#  	2.  Generic aliases
#  ---------------------------------------------------------------------------
alias c="clear && printf '\e[3J'"
alias cp='cp -i'
alias dt='tee ~/Desktop/terminalOut.txt' # dt: Pipe content to file on MacOS Desktop
alias du='du -h'
alias dud='du -d 1 -h'
alias duf='du -sh *'
alias ff='find . -type f -name'
alias flush='sudo dscacheutil -flushcache'
alias grep='grep --color'
alias h='history'
alias kp='ps auxwww'
alias locale='locale -a | grep UTF-8'
alias makedir='mkdir -pv'
alias mv='mv -i'
alias numFiles='echo $(ls -1 | wc -l)' # numFiles: Function to count of non-hidden files in current dir
alias p='ps -f'
alias p='pwd'
alias path='echo -e ${PATH//:/\\n}'
alias q='exit'
alias r='reload'
alias removedir=rmdir
alias repair_permissions='diskutil repairPermissions /'
alias repair_volume='diskutil repairvolume /'
alias rm='rm -i'
alias rmdir='rm –rf'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '
alias shutdown="shutdown -h now"
alias sortnr='sort -n -r'
alias t='tail -f'
alias top='htop'
alias verify_permissions='diskutil verifyPermissions /'
alias verify_volume='diskutil verifyvolume /'



# ls commands
alias l='ls -lFh'     			# Size, show type, human readable
alias l1='ls -1' 				# Display one file per line
alias la='ls -lAFh'   			# Long list, show almost all, show type, human readable
alias lart='ls -1Fcart'			# Force output to be one entry per line, last changed, includes directory entries whose names begin with a dot, reverse, sort by time modified
alias last='ls -t' 				# Sorts all files by modification time, showing the last edited file first.
alias ld='ls -ld' 				# Display directory information
alias ldot='ls -ld .*'			# Display only dot files
alias lf='ls -lf' 				# Visual Classification of Files With Special Characters
alias lh='ls -lh' 				# Display file size in human readable format
alias li='ls -i' 				# Display File Inode Number 
alias ll='ls -l'      			# Long list
alias ln='ls -n' 				# Display File UID and GID 
alias lq='ls -q' 				# Hide Control Characters
alias lr='ls -tRFh'   			# Display Files Recursively sorted by date,recursive, show type, human readable
alias lrt='ls -1Fcrt'			# Order Files Based on Last Modified Time (In Reverse Order)
alias lS='ls -1FSsh'			# Order Files Based on Last Modified Time and size
alias lsd='ls -l | grep "^d"'	# Display only directories
alias lt='ls -ltFh'   			# Display Files long list, sorted by date, show type, human readable







#  ---------------------------------------------------------------------------
#  	3.  Quicker navigation
#  ---------------------------------------------------------------------------
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias cd.='cd $(readlink -f .)'     # go to real dir (i.e. if current dir is linked)
alias less='less -R'                # Make less always work with coloured input
alias opendir='open -a Finder ./'
alias path='echo "$PATH" | tr ":" "\n" | nl'
alias so='shopt'
alias zap='rm -i'                   # Remove file with warning
alias ~='cd ~'


#  ---------------------------------------------------------------------------
#  	7.  Emulate iOS using different Apple devices
#  ---------------------------------------------------------------------------

alias ione-ios-4s='ionic emulate ios --target='iPhone-4s''
alias ione-ios-5='ionic emulate ios --target='iPhone-5''
alias ione-ios-5s='ionic emulate ios --target='iPhone-5s''
alias ione-ios-6-Plus='ionic emulate ios --target='iPhone-6-Plus''
alias ione-ios-6='ionic emulate ios --target='iPhone-6''
alias ione-ios-iPad-2='ionic emulate ios --target='iPad-2''
alias ione-ios-iPad-Air='ionic emulate ios --target='iPad-Air''
alias ione-ios-iPad-Retina='ionic emulate ios --target='iPad-Retina''


#  ---------------------------------------------------------------------------
#  	10.  Add an 'alert' alias for long running commands.  Use like so: sleep 10; alert
#  ---------------------------------------------------------------------------

#alias alert='notify-send --urgency=low -i ''$([ $? = 0 ] && echo terminal || echo error)'' ''$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')'''


#  ---------------------------------------------------------------------------
#  	11.  Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
#  ---------------------------------------------------------------------------

# Get macOS Software Updates, and update installed Ruby gems, Homebrew, npm, and their installed packages

alias update='sudo softwareupdate -i -a; brew cu --all; brew doctor; brew update; brew upgrade; brew cask cleanup; brew prune; brew cleanup; mas upgrade; npm install npm -g; npm update -g; sudo gem update --system; sudo gem update; sudo gem cleanup'

#  ---------------------------------------------------------------------------
#  	12.  Shorter commands for `Homebrew`.
#  ---------------------------------------------------------------------------

alias brewd='brew doctor'
alias brewi='brew install'
alias brews='brew search'
alias brewu='brew uninstall'
alias brewupdate='brew update && brew upgrade && brew cleanup && brew doctor'


#  ---------------------------------------------------------------------------
#  	13.  Speed-up Terminal load time by clearing system logs
#  ---------------------------------------------------------------------------

alias speedup='sudo rm -rf /private/var/log/asl/*'


#  ---------------------------------------------------------------------------
#  	14.  Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
#  ---------------------------------------------------------------------------

alias emptytrash='rm -rf ~/.Trash/*'


#  ---------------------------------------------------------------------------
#  	15.  Open the device simulators
#  ---------------------------------------------------------------------------

alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'


#  ---------------------------------------------------------------------------
#  	16.  cleanupDS: Recursively delete .DS_Store files
#  ---------------------------------------------------------------------------

alias cleanupDS='find . -type f -name ''*.DS_Store'' -ls -delete'


#  ---------------------------------------------------------------------------
#  	17.  Hidden Files  
#   finderShowHidden:   Show hidden files in Finder
#   finderHideHidden:   Hide hidden files in Finder
#  ---------------------------------------------------------------------------

alias finderHideHidden='defaults write com.apple.finder ShowAllFiles FALSE'
alias finderShowHidden='defaults write com.apple.finder ShowAllFiles TRUE'


#  ---------------------------------------------------------------------------
#  	18.  cleanupLS:  Clean up LaunchServices to remove duplicates in the 'Open With' menu
#  ---------------------------------------------------------------------------

alias cleanupLS='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder'


#  ---------------------------------------------------------------------------
#  	19.  screensaverDesktop: Run a screensaver on the Desktop
#  ---------------------------------------------------------------------------

alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'


#  ---------------------------------------------------------------------------
#  	20.  Subversion
#  ---------------------------------------------------------------------------

alias sa='svn add'
alias sc='svn commit'
alias sd='svn delete'
alias sm='svn move'
alias sr='svn rename'
alias ss='svn status'


#  ---------------------------------------------------------------------------
#  	21.  Application launchers
#  ---------------------------------------------------------------------------

alias css='open -a /Applications/CSSEdit.app'
alias e='open -a "Visual Studio Code"'
alias edit='open -a "Visual Studio Code"'
alias ipinfo='$HOME/Bin/gt-ipinfo.sh'
alias mate='open -a "Visual Studio Code"'
alias preview='open -a /System/Applications/Preview.app'
alias sql='open -a /Applications/Sequel\ Pro.app'
alias www='open -a /Applications/Safari.app'
alias xcode='open -a xcode'




#  ---------------------------------------------------------------------------
#  	22.  ttop:  Recommended 'top' invocation to minimize resources
#  ---------------------------------------------------------------------------

alias ttop='top -R -F -s 10 -o rsize'


#  ---------------------------------------------------------------------------
#  	23.  Networking
#  ---------------------------------------------------------------------------

alias flushDNS='sudo killall -HUP mDNSResponder'                                                # flushDNS:     Flush out the DNS Cache
alias ipInfo0='ipconfig getpacket en0'                                                          # ipInfo0:      Get info on connections for en0
alias ipInfo1='ipconfig getpacket en1'                                                          # ipInfo1:      Get info on connections for en1
alias lsock='sudo /usr/sbin/lsof -i -P'                                                         # lsock:        Display open sockets
alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP'                                               # lsockT:       Display only open TCP sockets
alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP'                                               # lsockU:       Display only open UDP sockets
alias myip='curl -s checkip.dyndns.org | sed -e ''s/.*Current IP Address: //'' -e ''s/<.*$//''' # myip:         Public facing IP Address
alias netCons='lsof -i'                                                                         # netCons:      Show all open TCP/IP sockets
alias op='sudo lsof -i -P'                                                                      # op:           List of open ports
alias openPorts='sudo lsof -i | grep LISTEN'                                                    # openPorts:    All listening connections

#  ---------------------------------------------------------------------------
#  	24.  Limit Ping to 5 ECHO_REQUEST packets
#  ---------------------------------------------------------------------------

alias ping='ping -c 5'

#  ---------------------------------------------------------------------------
#  	25.  wget with resume
#  ---------------------------------------------------------------------------

alias wget='wget -c'


#  ---------------------------------------------------------------------------
#  	26.  Searching
#  ---------------------------------------------------------------------------

alias qfind='find . -name '              # qfind:    Quickly search for file


#  ---------------------------------------------------------------------------
#  	27.  memHogsTop, memHogsPs:  Find memory hogs
#  ---------------------------------------------------------------------------

alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'
alias memHogsTop='top -l 1 -o rsize | head -20'

#  ---------------------------------------------------------------------------
#  	28.  cpuHogs:  Find CPU hogs
#  ---------------------------------------------------------------------------

alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'
