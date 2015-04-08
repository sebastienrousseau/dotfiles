# Set language flags
export LANG=en_GB.UTF-8

# Set architecture flags
export ARCHFLAGS="-arch x86_64"

# Ensure user-installed binaries take precedence
export PATH=/usr/local/bin:$PATH

# To connect the Docker client to the Docker daemon
export DOCKER_TLS_VERIFY=1
export DOCKER_HOST=tcp://192.168.59.103:2376
export DOCKER_CERT_PATH=/Users/seb/.boot2docker/certs/boot2docker-vm

# Load .bashrc if it exists
test -f ~/.bashrc && source ~/.bashrc

# Change prompt
  # Root prompt (RED)
  export SUDO_PS1="$(tput setaf 1)[\d \t] \w @ $(tput setaf 7)\h(🔴 \u): $"

  # Normal prompt (WHITE)
  export PS1="$(tput setaf 7)[\d \t] \w @ \h(👤 \u): $"

# Set Default Editor
export EDITOR='atom'

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

export BLOCKSIZE=1k

set meta-flag on
set input-meta on
set output-meta on
set convert-meta off

# Generic Aliases
alias locale='locale -a | grep UTF-8'
alias ls='ls -Gp'
alias l='ls -Gp'
alias la='ls -lisa'
alias ll='ls -lisa'
alias lr='ls -R | grep ":$" | sed -e '\''s/:$//'\'' -e '\''s/[^-][^\/]*\//--/g'\'' -e '\''s/^/   /'\'' -e '\''s/-/|/'\'' | less'
alias h='history'
alias r='reload'
alias du="du -h"
alias grep="grep --color"
alias mate="open -a 'Atom'"
alias edit="open -a 'Atom'"
alias e="open -a 'Atom'"
alias preview="open -a Preview"
alias mkdir='mkdir -pv'
mcd () { mkdir -p "$1" && cd "$1"; }        # mcd:      Makes new Dir and jumps inside
trash () { command mv "$@" ~/.Trash ; }     # trash:    Moves a file to the MacOS trash
ql () { qlmanage -p "$*" >& /dev/null; }    # ql:       Opens any file in MacOS Quicklook Preview
alias DT='tee ~/Desktop/terminalOut.txt'    # DT:       Pipe content to file on MacOS Desktop
alias c='clear'
cd() { builtin cd "$@"; ll; }
alias ~="cd ~"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias path='echo -e ${PATH//:/\\n}'
alias showoptions='shopt'
alias opencurrent='open -a Finder ./'
alias zap='rm -i' #remove file with warning

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
alias ione-ios-4s="ionic emulate ios --target="iPhone-4s""
alias ione-ios-5="ionic emulate ios --target="iPhone-5""
alias ione-ios-5s="ionic emulate ios --target="iPhone-5s""
alias ione-ios-6="ionic emulate ios --target="iPhone-6""
alias ione-ios-6-Plus="ionic emulate ios --target="iPhone-6-Plus""
alias ione-ios-iPad-2="ionic emulate ios --target="iPad-2""
alias ione-ios-iPad-Retina="ionic emulate ios --target="iPad-Retina""
alias ione-ios-iPad-Air="ionic emulate ios --target="iPad-Air""


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

alias rmdir='rm –rf'
alias dir="ls -R | grep ":" | sed -e 's/://' -e 's/[^-][^\/]*\//--/g' -e 's/^/ /' -e 's/-/|/'"
alias flush='sudo dscacheutil -flushcache'

# Get OS X Software Updates, update Homebrew itself, and upgrade installed Homebrew packages
alias update="sudo softwareupdate -i -a; brew update; brew upgrade"

# Speed-up Terminal load time by clearing system logs
alias speedup="sudo rm -rf /private/var/log/asl/*"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; speedup"


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
alias ipinfo='/Users/seb/Bin/gt-ipinfo.sh'

#   ttop:  Recommended 'top' invocation to minimize resources
#   ------------------------------------------------------------
#       Taken from this macosxhints article
#       http://www.macosxhints.com/article.php?story=20060816123853639
#   ------------------------------------------------------------
alias ttop="top -R -F -s 10 -o rsize"

#   my_ps: List processes owned by my user:
#   ------------------------------------------------------------
my_ps() { ps $@ -u $USER -o pid,%cpu,%mem,start,time,bsdtime,command ; }

#   ---------------------------
#   6.  NETWORKING
#   ---------------------------

alias myip='curl -s checkip.dyndns.org | sed -e "s/.*Current IP Address: //" -e "s/<.*$//"'                    # myip:         Public facing IP Address
alias netCons='lsof -i'                             # netCons:      Show all open TCP/IP sockets
alias flushDNS='dscacheutil -flushcache'            # flushDNS:     Flush out the DNS Cache
alias lsock='sudo /usr/sbin/lsof -i -P'             # lsock:        Display open sockets
alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP'   # lsockU:       Display only open UDP sockets
alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP'   # lsockT:       Display only open TCP sockets
alias ipInfo0='ipconfig getpacket en0'              # ipInfo0:      Get info on connections for en0
alias ipInfo1='ipconfig getpacket en1'              # ipInfo1:      Get info on connections for en1
alias localip="ifconfig en0 inet | grep 'inet ' | awk ' { print $2 } '"
alias ips="ifconfig -a | perl -nle'/(\d+\.\d+\.\d+\.\d+)/ && print $1'"
alias openPorts='sudo lsof -i | grep LISTEN'        # openPorts:    All listening connections
alias showBlocked='sudo ipfw list'                  # showBlocked:  All ipfw rules inc/ blocked IPs


#   ii:  display useful host related informaton
#   -------------------------------------------------------------------
ii() {
  echo -e "\nYou are logged on ${RED}$HOST"
  echo -e "\nAdditionnal information:$NC " ; uname -a
  echo -e "\n${RED}Users logged on:$NC " ; w -h
  echo -e "\n${RED}Current date :$NC " ; date
  echo -e "\n${RED}Machine stats :$NC " ; uptime
  echo -e "\n${RED}Current network location :$NC " ; scselect
  echo -e "\n${RED}Public facing IP Address :$NC " ;myip
  echo -e "\n${RED}DNS Configuration:$NC " ; scutil --dns
  echo
}

#   httpDebug:  Download a web page and show info on what took time
#   -------------------------------------------------------------------
httpDebug () { /usr/bin/curl $@ -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\n" ; }


# List of open ports
alias op='sudo lsof -i -P'

#   -------------------------------
#   3.  FILE AND FOLDER MANAGEMENT
#   -------------------------------

zipf () { zip -r "$1".zip "$1" ; }          # zipf:         To create a ZIP archive of a folder
alias numFiles='echo $(ls -1 | wc -l)'      # numFiles:     Count of non-hidden files in current dir


# function to make 'rm' move files to the trash
function rm () {
  local path
  for path in "$@"; do
    # ignore any arguments
    if [[ "$path" = -* ]]; then :
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
function cd {
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

# Create a new directory and enter it
function md() {
  mkdir -p "$@" && cd "$@"
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
extract () {
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1     ;;
*.tar.gz)    tar xzf $1     ;;
*.bz2)       bunzip2 $1     ;;
*.rar)       unrar e $1     ;;
*.gz)        gunzip $1      ;;
*.tar)       tar xf $1      ;;
*.tbz2)      tar xjf $1     ;;
*.tgz)       tar xzf $1     ;;
*.zip)       unzip $1       ;;
*.Z)         uncompress $1  ;;
*.7z)        7z x $1        ;;
*)     echo "'$1' cannot be extracted via extract()" ;;
esac
else
 echo "'$1' is not a valid file"
fi
}


#   ---------------------------
#   4.  SEARCHING
#   ---------------------------

alias qfind="find . -name "                 # qfind:    Quickly search for file
ff () { /usr/bin/find . -name "$@" ; }      # ff:       Find file under the current directory
ffs () { /usr/bin/find . -name "$@"'*' ; }  # ffs:      Find file whose name starts with a given string
ffe () { /usr/bin/find . -name '*'"$@" ; }  # ffe:      Find file whose name ends with a given string


#   memHogsTop, memHogsPs:  Find memory hogs
#   -----------------------------------------------------
alias memHogsTop='top -l 1 -o rsize | head -20'
alias memHogsPs='ps wwaxm -o pid,stat,vsize,rss,time,command | head -10'


    #   cpuHogs:  Find CPU hogs
#   -----------------------------------------------------
alias cpu_hogs='ps wwaxr -o pid,stat,%cpu,time,command | head -10'



# The next line updates PATH for the Google Cloud SDK.
source '/Users/seb/google-cloud-sdk/path.bash.inc'

# The next line enables bash completion for gcloud.
source '/Users/seb/google-cloud-sdk/completion.bash.inc'

# Aliases
alias reload='. .bash_profile'

# Purging Xcode DerivedData
alias purge='rm -rf ~/library/Developer/Xcode/DerivedData/*'

alias brewupdate='brew update && brew upgrade'

# Paths
export PATH=$PATH:/Users/seb/Library/Android/sdk/platform-tools

# Setting JAVA environments
export JAVA_HOME='/Library/Java/JavaVirtualMachines/jdk1.8.0_31.jdk/Contents/Home'
export ANT_HOME='/usr/local/Cellar/ant/1.9.4/libexec/'
export MAVEN_HOME='/usr/local/Cellar/maven/3.2.5/libexec'
export GIT_EDITOR="atom"
export ANDROID_HOME='/Users/seb/Library/Android/sdk/'


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
