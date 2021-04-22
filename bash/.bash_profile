#!/bin/bash -l

#  ---------------------------------------------------------------------------
#
#  ______      _  ______ _ _           
#  |  _  \    | | |  ___(_) |          
#  | | | |___ | |_| |_   _| | ___  ___ 
#  | | | / _ \| __|  _| | | |/ _ \/ __|
#  | |/ / (_) | |_| |   | | |  __/\__ \
#  |___/ \___/ \__\_|   |_|_|\___||___/
#                                                                            
#  Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#  																			
#  Sections:																
#  																			
#  	1.  Configurations
#  	2.  Change prompt
#  	3.  Bash shell shopt options
#  	4.  Exports
#  	5.  History Options
#  	6.  GOLANG configurations
#  	7.  System Operations & Information
#  	8.  Paths Management
#  	9.  Reminders & Notes
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
#   1. Configurations
#  ---------------------------------------------------------------------------

# set INPUTRC (so that .inputrc is respected)
INPUTRC=~/.inputrc
export INPUTRC

# set HOSTNAME
export HOSTNAME=$(hostname -f)

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


#  ---------------------------------------------------------------------------
#   2. Change prompt
#  ---------------------------------------------------------------------------

# Root prompt (😈)
SUDO_PS1="\[root@$(hostname -s) 😈: $ "
export SUDO_PS1

# Normal prompt (👽)
PS1="$(hostname -s) 👽: $ "
export PS1


#  ---------------------------------------------------------------------------
#   3. Bash shell shopt options
#  ---------------------------------------------------------------------------

# Auto-correct directory spelling errors
shopt -s cdspell

# Extended pattern matching features enabled
shopt -s extglob

# Make bash append rather than overwrite the history on disk
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


#  ---------------------------------------------------------------------------
#   4. Exports
#  ---------------------------------------------------------------------------

# Add Visual Studio Code (code)
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $"*" ;}

# Set Default Editor
EDITOR=code
export EDITOR

# Default block size for ls, df, du
export BLOCKSIZE=10k


#  ---------------------------------------------------------------------------
#   5. History Options
#  ---------------------------------------------------------------------------

# Sets the size to "unlimited"
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups:ignorespace

# Ignore whitespace and duplicates. Erase duplicates.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}erasedups
export HISTFILESIZE=1000000000
export HISTSIZE=1000000
export HISTTIMEFORMAT="[%F %T] "

## Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:exit:ls:history:date:* --help:jrnl *"

# Set the location of your HISTFILE
export HISTFILE=$HOME/.bash_history


#  ---------------------------------------------------------------------------
#   6. GOLANG configurations
#  ---------------------------------------------------------------------------

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




#  ---------------------------------------------------------------------------
#   8. Paths Management
#  ---------------------------------------------------------------------------

# The next line updates PATH for the Google Cloud SDK.
# source $HOME/google-cloud-sdk/path.bash.inc
# shellcheck disable=SC1090
if [ -f "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc ]; then 
	source "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc
fi

# The next line enables bash completion for gcloud.
# source $HOME/google-cloud-sdk/completion.bash.inc
# shellcheck disable=SC1090
if [ -f "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc ]; then 
	source "$(brew --prefix)"/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc
fi

# Setting JAVA environments
JAVA_HOME='/Library/Java/JavaVirtualMachines/jdk-9.0.4.jdk/Contents/Home'
export JAVA_HOME

ANT_HOME="$(brew --prefix)/Cellar/ant/1.10.1/libexec/"
export ANT_HOME

MAVEN_HOME="$(brew --prefix)/Cellar/maven/3.5.2/libexec"
export MAVEN_HOME

M2=$MAVEN_HOME/bin
export M2

GIT_EDITOR="atom"
export GIT_EDITOR

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

PATH="/usr/local/opt/imagemagick@6/bin:$PATH"
export PATH

#  ---------------------------------------------------------------------------
#   9. Reminders & Notes
#  ---------------------------------------------------------------------------

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

# Setting PATH for Python 2.7
# The original version is saved in .bash_profile.pysave
#PATH="/opt/local/Library/Frameworks/Python.framework/Versions/3.6/bin/python2.7/bin:${PATH}"
#export PATH
#export PATH="$(brew --prefix)/opt/curl/bin:$PATH"
# shellcheck disable=SC1090
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# Perl notes
# By default non-brewed cpan modules are installed to the Cellar. If you wish
# for your modules to persist across updates we recommend using `local::lib`.
# You can set that up like this:
#   PERL_MM_OPT="INSTALL_BASE=$HOME/perl5" cpan local::lib
#   echo 'eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib=$HOME/perl5)"' >> ~/.bash_profile

# Init jenv
if which jenv > /dev/null; then eval "$(jenv init -)"; fi