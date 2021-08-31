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
#  	7.  Emulate iOS using different Apple devices
#  	9.  App engine commands
#  	10. Add an 'alert' alias for long running commands.
#  	11. Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
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
