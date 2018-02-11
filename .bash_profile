#!/bin/bash -l

# set INPUTRC (so that .inputrc is respected)
INPUTRC=~/.inputrc
export INPUTRC

# Set language flags
LANG=en_GB.UTF-8
export LANG 

# Set architecture flags
ARCHFLAGS="-arch x86_64"
export ARCHFLAGS

# Ensure user-installed binaries take precedence
LIBCURL_CFLAGS=-L$(brew --prefix)/opt/curl/lib
export LIBCURL_CFLAGS

LIBCURL_LIBS=-I$(brew --prefix)/opt/curl/include
export LIBCURL_LIBS

HOMEBREW_CASK_OPTS="--appdir=/Applications"
export HOMEBREW_CASK_OPTS

MAVEN_OPTS="-Xms512m -Xmx512m"
export MAVEN_OPTS

# GH_TOKEN="YOUR GH_TOKEN"
# export GH_TOKEN

SSL_CERT_FILE=~/cacert.pem
export SSL_CERT_FILE

# AWS_ACCESS_KEY_ID=<Your requested AWS access ID>
# export AWS_ACCESS_KEY_ID

# AWS_SECRET_ACCESS_KEY=<Your requested secret access key>
# export AWS_SECRET_ACCESS_KEY

# Load .bashrc if it exists
# shellcheck disable=SC1090
test -f "$HOME/.bashrc" && source "$HOME/.bashrc"

# Change prompt

# Root prompt (RED)
SUDO_PS1="$(tput setaf 1)[\\d \\t] @ $(tput setaf 7)\\h(💀 \\u): $"
export SUDO_PS1

# Normal prompt (WHITE)
PS1="$(tput setaf 7)[\\d \\t] @ \\h(👽 \\u): $"
export PS1

# Add Visual Studio Code (code)
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $"*" ;}

# PATH=$PATH:'/Applications/Visual Studio Code.app/Contents/Resources/app/bin'
# export PATH

##### Set Default Editor #####
EDITOR=code
export EDITOR

##### auto-correct directory spelling errors #####
shopt -s cdspell

# extended pattern matching features enabled
shopt -s extglob

# make bash append rather than overwrite the history on disk
shopt -s histappend

# Multilines together
shopt -s cmdhist

# perform hostname completion when a word containing a @ is being completed
shopt -s hostcomplete

# allow a word beginning with # to cause that word and all remaining characters on that line to be ignored
shopt -s interactive_comments

# bash will not attempt to search the PATH for possible completions when completion is attempted on an empty line
shopt -s no_empty_cmd_completion

# case insensitive matching when performing pathname expansion
shopt -s nocaseglob

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

export BLOCKSIZE=10k

# Ignore whitespace and duplicates. Erase duplicates.
export HISTCONTROL=erasedups

# Sets the size to "unlimited"
export HISTFILESIZE
export HISTSIZE
export HISTTIMEFORMAT="[%F %T] "

## Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:exit:ls:history:date:* --help:jrnl *"

# Set the location of your HISTFILE
export HISTFILE=$HOME/.bash_history

# GOLANG configurations
# go
GOROOT=$(brew --prefix)/opt/go/libexec
export GOROOT

export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin

# Force prompt to write history after every command.
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

set meta-flag on
set input-meta on
set output-meta on
set convert-meta off

# Generic Aliases
alias kp="ps auxwww"
alias locale='locale -a | grep UTF-8'
alias ls='ls -FGlAhp'
alias l='ls -FGlAhp'
alias la='ls -lisa'
alias ll='ls -lisa'
alias lr='ls -R | grep ":$" | sed -e '\''s/:$//'\'' -e '\''s/[^-][^\/]*\//--/g'\'' -e '\''s/^/   /'\'' -e '\''s/-/|/'\'' | less'
alias h='history'
alias r='reload'
alias du="du -h"
alias grep="grep --color"
alias mate='open -a "Visual Studio Code"'
alias edit='open -a "Visual Studio Code"'
alias e='open -a "Visual Studio Code"'
alias xcode='open -a xcode'
alias preview="open -a Preview"
alias mkdir='mkdir -pv'
alias checkperms='sudo /usr/libexec/repair_packages --verify --standard-pkgs --volume /'
alias repairperms='sudo /usr/libexec/repair_packages --repair --standard-pkgs --volume /'
mcd() { mkdir -p "$1" && cd "$1" || exit; }      # mcd:      Makes new Dir and jumps inside
trash() { command mv "$@" ~/.Trash; }    # trash:    Moves a file to the MacOS trash
ql() { qlmanage -p "$*" >&/dev/null; }   # ql:       Opens any file in MacOS Quicklook Preview
alias DT='tee ~/Desktop/terminalOut.txt' # DT:       Pipe content to file on MacOS Desktop
alias c='clear'
alias path='echo -e ${PATH//:/\\n}' # path:         Echo all executable Paths

# Quicker navigation
alias ~="cd ~"
alias ..='cd ../'                # Go back 1 directory level
alias ...='cd ../../'            # Go back 2 directory levels
alias .3='cd ../../../'          # Go back 3 directory levels
alias .4='cd ../../../../'       # Go back 4 directory levels
alias .5='cd ../../../../../'    # Go back 5 directory levels
alias .6='cd ../../../../../../' # Go back 6 directory levels
alias path='echo -e ${PATH//:/\\n}'
alias showoptions='shopt'
alias opencurrent='open -a Finder ./'
alias zap='rm -i' #remove file with warning
alias repos='cd ~/Dropbox\ \(REEDIA\)$HOME/Repositories/'

# make less always work with colored input
alias less="less -R"

# Jekyll
alias site-dev='JEKYLL_ENV=dev bundle exec jekyll serve --watch --trace'
alias site-production='JEKYLL_ENV=production bundle exec jekyll serve --watch --trace'

# Heroku commands
alias hcp='heroku console --remote production'
alias hcs='heroku console --remote staging'
alias hlp='heroku logs -t --remote production'
alias hls='heroku logs -t --remote staging'

# Ionic commands
alias ionup='npm update -g cordova ionic'
alias ions="ionic serve"
alias ionios="ionic emulate ios"
alias ionandroid="ionic emulate android"
alias ioniosrun="ionic run ios"
alias ionandroidrun="ionic run android"
alias ionicons="open http://ionicons.com/"
alias ionpa-ios="ionic platform add ios"
alias ionpa-android="ionic platform add android"
alias ionpr-ios="ionic platform remove ios"
alias ionpr-android="ionic platform remove android"
alias ionb="ionic build"
alias ionbios="ionic build ios"
alias ionbandroid="ionic build android"
alias ionosreset="ionpr-ios | ionpa-ios | ionbios"
alias iondroidreset="ionpr-android | ionpa-android | ionbandroid"

# Emulate iOS using different Apple devices
alias ione-ios-4s="ionic emulate ios --target='iPhone-4s'"
alias ione-ios-5="ionic emulate ios --target='iPhone-5'"
alias ione-ios-5s="ionic emulate ios --target='iPhone-5s'"
alias ione-ios-6="ionic emulate ios --target='iPhone-6'"
alias ione-ios-6-Plus="ionic emulate ios --target='iPhone-6-Plus'"
alias ione-ios-iPad-2="ionic emulate ios --target='iPad-2'"
alias ione-ios-iPad-Retina="ionic emulate ios --target='iPad-Retina'"
alias ione-ios-iPad-Air="ionic emulate ios --target='iPad-Air'"

##### git #####
# Git SCM Cheats
alias g=git
alias gi='git init'
alias gs='clear && git status'
alias ga='git add'
alias gad='git add .'
alias gaa='git add --all'
alias gau='git add --update'
alias gc='echo "for commiting use \"gcm\" & for checkout use \"gco\" this command is just for CLONING! - با تشکر" && git clone'
alias gcm='git commit -m '
alias gce='git commit -a'
alias gcam='git commit --amend -m'
alias gl='git log'
alias glg='git log --oneline --graph --all --decorate'
alias glgc='clear && git log --oneline --graph --all --decorate'
alias gls='git log --pretty=format: --name-only --diff-filter=A | sort '
alias glp='git log --pretty=oneline'
alias glps='git log --pretty=oneline --stat'
alias gl1d='git log --since=1.day.ago'
alias gl7d='git log --since=7.days.ago'
alias gl1w='git log --since=1.week.ago'
alias gd='git diff'
alias gds='git diff --staged'
alias gdh='git diff HEAD'
alias gdh1='git diff HEAD^'
alias gdh2='git diff HEAD^^'
alias gdh5='git diff HEAD~5'
alias grh='git reset HEAD'          #unstage some files
alias gco='git checkout'            #undo to last commit
alias grsh='git reset --soft HEAD^' #role back to stage!
alias grhh='git reset --hard HEAD^' #role back fully to last commit! //be careful
alias gra='git remote add'
alias grao='git remote add origin'
alias grs='git remote -v'
alias gp='git push'
alias gpo='git push -u origin'
alias gpom='git push -u origin master'
alias gpt='git push --tags'
alias gbs='git branch -a'
alias gb='git branch' #git branch test 07aeec9 --> to make a branch on an old commit!
alias gbr='git branch -r'
alias gbd='git branch -d'
alias grso='git remote show origin'
alias gm='git merge'
alias grm='git rm'
alias grmc='git rm --cached'
alias gt='git tag'
alias gts='git tag'
alias gta='git tag -a'
alias gbl='git blame --date short'
alias gcl='git config --list'
alias gitremoveallmergedbranches='git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

alias gb="git branch"
alias gs='git status -sb'
alias ga="git add"
alias gc="git commit"
alias gl="git log"
alias glo="git log --pretty=oneline"
alias glu="git log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
alias gout="git checkout"
alias gt="git tag"
alias grs="git reset"
alias grv="git revert"
alias gm="git merge"
alias gpom="git push origin master"
alias gpum="git pull origin master"
alias gd="git diff"
alias gpo="git push origin"
alias gob="git checkout -b"
alias gcm='git checkout master'
alias gf='git fetch'
alias gp='git pull'
alias c='clear'
alias gb='git branch'
alias gl='git l'
alias gsu='git submodule update --recursive'
alias gd='git diff'
alias gnuke='git branch --merged | xargs git branch -d'
alias gl="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gll="git log --graph --full-history --all --color"

##### appengine #####
alias gaeauth='appcfg.py --oauth2'
alias gaeup='appcfg.py --oauth2 update .'
alias gaeupauth='appcfg.py --oauth2 -V dev update . && appcfg.py --oauth2 update . -V'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# See http://www.shellperson.net/using-sudo-with-an-alias/
alias sudo='sudo '
alias q='exit'

alias rmdir="rm –rf"
alias flush="sudo dscacheutil -flushcache"

# Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
alias update="sudo softwareupdate -i -a; brew cu --all; brew doctor; brew prune; clear;"

alias brewup='brew update; brew upgrade; brew prune; brew cleanup; brew doctor'

# Speed-up Terminal load time by clearing system logs
alias speedup="sudo rm -rf /private/var/log/asl/*"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; speedup"

# Open the device simulators
alias iphone="open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"

#   cleanupDS:  Recursively delete .DS_Store files
#   -------------------------------------------------------------------
alias cleanupDS="find . -type f -name '*.DS_Store' -ls -delete"

#   finderShowHidden:   Show hidden files in Finder
#   finderHideHidden:   Hide hidden files in Finder
#   -------------------------------------------------------------------
alias finderShowHidden='defaults write com.apple.finder ShowAllFiles TRUE'
alias finderHideHidden='defaults write com.apple.finder ShowAllFiles FALSE'

#   cleanupLS:  Clean up LaunchServices to remove duplicates in the "Open With" menu
#   -----------------------------------------------------------------------------------
alias cleanupLS="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"

#    screensaverDesktop: Run a screensaver on the Desktop
#   -----------------------------------------------------------------------------------
alias screensaverDesktop='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'

# things for subversion
alias sm='svn move'
alias sa='svn add'
alias sd='svn delete'
alias sr='svn rename'
alias sc='svn commit'
alias ss='svn status'

# application launchers
alias www='open -a /Applications/Safari.app'
alias preview='open -a /Applications/Preview.app'
alias sql='open -a /Applications/Sequel\ Pro.app'
alias css='open -a /Applications/CSSEdit.app'
alias ipinfo='$HOME/Bin/gt-ipinfo.sh'

#   ttop:  Recommended 'top' invocation to minimize resources
#   ------------------------------------------------------------
#       Taken from this macosxhints article
#       http://www.macosxhints.com/article.php?story=20060816123853639
#   ------------------------------------------------------------
alias ttop="top -R -F -s 10 -o rsize"

#   my_ps: List processes owned by my user:
#   ------------------------------------------------------------
my_ps() { ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command; }

#   ---------------------------
#   6.  NETWORKING
#   ---------------------------

alias myip='curl -s checkip.dyndns.org | sed -e "s/.*Current IP Address: //" -e "s/<.*$//"' # myip:         Public facing IP Address
alias netCons='lsof -i'                                                                     # netCons:      Show all open TCP/IP sockets
alias flushDNS='sudo killall -HUP mDNSResponder'                                            # flushDNS:     Flush out the DNS Cache
alias lsock='sudo /usr/sbin/lsof -i -P'                                                     # lsock:        Display open sockets
alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP'                                           # lsockU:       Display only open UDP sockets
alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP'                                           # lsockT:       Display only open TCP sockets
alias ipInfo0='ipconfig getpacket en0'                                                      # ipInfo0:      Get info on connections for en0
alias ipInfo1='ipconfig getpacket en1'                                                      # ipInfo1:      Get info on connections for en1
alias openPorts='sudo lsof -i | grep LISTEN' # openPorts:    All listening connections
alias op='sudo lsof -i -P' # List of open ports


## Limit Ping to 5 ECHO_REQUEST packets
alias ping='ping -c 5'

## wget with resume
alias wget='wget -c'

#   ii:  display useful host related informaton
#   -------------------------------------------------------------------
ii() {
	echo -e "\\nYou are logged on ${RED}$HOST"
	echo -e "\\nAdditionnal information:$NC "
	uname -a
	echo -e "\\n${RED}Users logged on:$NC "
	w -h
	echo -e "\\n${RED}Current date :$NC "
	date
	echo -e "\\n${RED}Machine stats :$NC "
	uptime
	echo -e "\\n${RED}Current network location :$NC "
	scselect
	echo -e "\\n${RED}Public facing IP Address :$NC "
	myip
	echo -e "\\n${RED}DNS Configuration:$NC "
	scutil --dns
	echo
}

#   httpDebug:  Download a web page and show info on what took time
#   -------------------------------------------------------------------
httpDebug() { /usr/bin/curl "$@" -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\\n"; }

#   -------------------------------
#   3.  FILE AND FOLDER MANAGEMENT
#   -------------------------------

zipf() { zip -r "$1".zip "$1"; }       # zipf:         To create a ZIP archive of a folder
alias numFiles='echo $(ls -1 | wc -l)' # numFiles:     Count of non-hidden files in current dir

# function to make 'rm' move files to the trash
function rm() {
	local path
	for path in "$@"; do
		# ignore any arguments
		if [[ "$path" == -* ]]; then :
		else
			local dst=${path##*/}
			# append the time if necessary
			while [ -e ~/.Trash/"$dst" ]; do
				dst="$dst "$(date +%H-%M-%S)
			done
			mv "$path" ~/.Trash/"$dst"
		fi
	done
}

# function to Enable 'cd' into directory aliases
function cd() {
	if [ ${#1} == 0 ]; then
		builtin cd
	elif [ -d "${1}" ]; then
		builtin cd "${1}"
	elif [[ -f "${1}" || -L "${1}" ]]; then
		path=$(getTrueName "$1")
		builtin cd "$path"
	else
		builtin cd "${1}"
	fi
}

# combine mkdir and cd
mkcd() {
	mkdir "$1"
	cd "$1" || exit
}

# combine touch and osu
tosu() {
	touch "$1"
	osu "$1"
}

# Create a new directory and enter it
function md() {
	mkdir -p "$@" && cd "$@" || exit 
}

# Remove a direcory and its files
function rd() {
	rm -rf "$@"
}

# function to Logout from OS X via the Terminal
logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}

#   extract:  Extract most know archives with one command
#   ---------------------------------------------------------
extract() {
	if [ -f $1 ]; then
		case $1 in
		*.tar.bz2) tar xjf $1 ;;
		*.tar.gz) tar xzf $1 ;;
		*.bz2) bunzip2 $1 ;;
		*.rar) unrar e $1 ;;
		*.gz) gunzip $1 ;;
		*.tar) tar xf $1 ;;
		*.tbz2) tar xjf $1 ;;
		*.tgz) tar xzf $1 ;;
		*.zip) unzip $1 ;;
		*.Z) uncompress $1 ;;
		*.7z) 7z x $1 ;;
		*) echo "'$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

#   ---------------------------
#   4.  SEARCHING
#   ---------------------------

alias qfind="find . -name "              # qfind:    Quickly search for file

#   memHogsTop, memHogsPs:  Find memory hogs
#   -----------------------------------------------------
alias memHogsTop='top -l 1 -o rsize | head -20'
alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'

# alias python='$(brew --prefix)/bin/python2'
# alias python2='$(brew --prefix)/bin/python2'
# alias python3='$(brew --prefix)/bin/python3'
#   cpuHogs:  Find CPU hogs
#   -----------------------------------------------------
alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'

# The next line updates PATH for the Google Cloud SDK.
# source $HOME/google-cloud-sdk/path.bash.inc
# shellcheck disable=SC1090
source "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc

# The next line enables bash completion for gcloud.
# source $HOME/google-cloud-sdk/completion.bash.inc
# shellcheck disable=SC1090
source "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc

# Aliases
alias reload='. .bash_profile'

# Purging Xcode DerivedData
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'

alias brewupdate='brew update && brew upgrade && brew cleanup && brew prune && brew doctor'

# Setting JAVA environments
JAVA_HOME='/Library/Java/JavaVirtualMachines/jdk-9.0.4.jdk/Contents/Home'
export JAVA_HOME

ANT_HOME="$(brew --prefix)/Cellar/ant/1.10.1/libexec/"
export ANT_HOME

MAVEN_HOME="$(brew --prefix)/Cellar/maven/3.5.2/libexec"
export MAVEN_HOME

export M2=$MAVEN_HOME/bin

export GIT_EDITOR="atom"

ANDROID_HOME="$HOME/Library/Android/sdk/"
export ANDROID_HOME

PATH=$ANDROID_HOME/tools:$PATH
export PATH

PATH=$ANDROID_HOME/platform-tools:$PATH
export PATH

PATH="$(brew --prefix)/opt/python/libexec/bin:$PATH"
export PATH

PATH="$(brew --prefix)/sbin:$PATH"
export PATH

#   ---------------------------------------
#   9.  REMINDERS & NOTES
#   ---------------------------------------

#   remove_disk: spin down unneeded disk
#   ---------------------------------------
#   diskutil eject /dev/disk1s3

#   to change the password on an encrypted disk image:
#   ---------------------------------------
#   hdiutil chpass /path/to/the/diskimage

#   to mount a read-only disk image as read-write:
#   ---------------------------------------
#   hdiutil attach example.dmg -shadow /tmp/example.shadow -noverify

#   mounting a removable drive (of type msdos or hfs)
#   ---------------------------------------
#   mkdir /Volumes/Foo
#   ls /dev/disk*   to find out the device to use in the mount command)
#   mount -t msdos /dev/disk1s1 /Volumes/Foo
#   mount -t hfs /dev/disk1s1 /Volumes/Foo

#   to create a file of a given size: /usr/sbin/mkfile or /usr/bin/hdiutil
#   ---------------------------------------
#   e.g.: mkfile 10m 10MB.dat
#   e.g.: hdiutil create -size 10m 10MB.dmg
#   the above create files that are almost all zeros - if random bytes are desired
#   then use: ~/Dev/Perl/randBytes 1048576 > 10MB.dat
# shellcheck disable=SC1090
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"      # Load the default .profile
# shellcheck disable=SC1090
[[ -s "$HOME/.dnx/dnvm/dnvm.sh" ]] && . "$HOME/.dnx/dnvm/dnvm.sh" # Load dnvm
# shellcheck disable=SC1090
source "$HOME/.bashrc"

# The next line updates PATH for the Google Cloud SDK.
# shellcheck disable=SC1090
if [ -f "$HOME/exec -l /bin/bash/google-cloud-sdk/path.bash.inc" ]; then source "$HOME/exec -l /bin/bash/google-cloud-sdk/path.bash.inc"; fi

# The next line enables shell command completion for gcloud.
# shellcheck disable=SC1090
if [ -f "$HOME/exec -l /bin/bash/google-cloud-sdk/completion.bash.inc" ]; then source "$HOME/exec -l /bin/bash/google-cloud-sdk/completion.bash.inc"; fi

##
# Your previous $HOME/.bash_profile file was backed up as $HOME/.bash_profile.macports-saved_2017-12-16_at_10:13:37
##

# MacPorts Installer addition on 2017-12-16_at_10:13:37: adding an appropriate PATH variable for use with MacPorts.
#export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.

# Setting PATH for Python 2.7
# The original version is saved in .bash_profile.pysave
#PATH="/opt/local/Library/Frameworks/Python.framework/Versions/3.6/bin/python2.7/bin:${PATH}"
#export PATH
#export PATH="$(brew --prefix)/opt/curl/bin:$PATH"
# shellcheck disable=SC1090
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
