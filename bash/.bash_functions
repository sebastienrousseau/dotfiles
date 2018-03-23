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
#  	1. Addding and Removing Files and Folders
#  	2. Compression, Decompress and Archive Functions
#  	3. General Function (could be better sorted)
#  	4. Network and Debugging Function 
#  	5. Fun Functions
#
#  ---------------------------------------------------------------------------

#  ---------------------------------------------------------------------------
#   1. Addding and Removing Files and Folders
#  ---------------------------------------------------------------------------

# rm: Function to make 'rm' move files to the trash
rm() {
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

# cd: Function to Enable 'cd' into directory aliases
cd() {
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

# mkcd: Function to combine mkdir and cd
mkcd() {
	mkdir "$1"
	cd "$1" || exit
}

# md: Function to create a new directory and enter it
md() {
	mkdir -p "$@" && cd "$@" || exit 
}

# mcd: Function to makes new Dir and jumps inside
mcd() { 
	mkdir -p "$1" && cd "$1" || exit; 
}

# rd: Function to remove a direcory and its files
rd() {
	rm -rf "$@"
}

# trash: Function to moves a file to the MacOS trash
trash() { 
	command mv "$@" ~/.Trash; 
}

#  ---------------------------------------------------------------------------
#   2. Compression, Decompress and Archive Functions
#  ---------------------------------------------------------------------------

# zipf: Function to create a ZIP archive of a folder
zipf() { zip -r "$1".zip "$1"; }

# extract: Function to extract most know archives with one command
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

#  ---------------------------------------------------------------------------
#   3. General Function (could be better sorted)
#  ---------------------------------------------------------------------------

# numFiles: Function to count of non-hidden files in current dir
alias numFiles='echo $(ls -1 | wc -l)' 

# tree: Function to generates a tree view from the current directory
if [ ! -e /usr/local/bin/tree ]; then
	tree(){
		pwd
		ls -R | grep ":$" |   \
		sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /' -e 's/-/|/'
	}
fi

# sshKeyGen: Function to generates SSH key
sshKeyGen() {

	echo "What's the name of the Key (no spaced please) ? ";
	read -r name;

	echo "What's the email associated with it? ";
	read -r email;

	$(ssh-keygen -t rsa -f ~/.ssh/id_rsa_$name -C "$email");

	ssh-add ~/.ssh/id_rsa_$name;

	pbcopy < ~/.ssh/id_rsa_$name.pub;

	echo "SSH Key copied in your clipboard";

}

# filestolower: Function to rename all the files which contain uppercase letters to lowercase in the current folder
filestolower(){
  read -r -p "This will rename all the files and directories to lowercase in the current folder, continue? [y/n]: " letsdothis
  if [ "$letsdothis" = "y" ] || [ "$letsdothis" = "Y" ]; then
    for x in `ls`
      do
      skip=false
      if [ -d "$x" ]; then
	read -rp "'$x' is a folder, rename it? [y/n]: " renamedir
	if [ "$renamedir" = "n" ] || [ "$renamedir" = "N" ]; then
	  skip=true
	fi
      fi
      if [ "$skip" == "false" ]; then
        lc=$(echo "$x"  | tr ':A-Z:' ':a-z:')
        if [ "$lc" != "$x" ]; then
          echo "renaming $x -> $lc"
          mv "$x" "$lc"
        fi
      fi
    done
  fi
}

# aliasc: Function alias
aliasc() {
  alias | grep "^${1}=" | awk -F= '{ print $2 }' | sed "s/^'//" | sed "s/'$//"
}

# tosu: Function to combine touch and osu
tosu() {
	touch "$1"
	osu "$1"
}

# size: Function to check a file size
size() {
	stat -f '%z' "$1"
}

# logout: Function to logout from OS X via the Terminal
logout() {
	osascript -e 'tell application "System Events" to log out'
	builtin logout
}

# countdown: Function for countdown
countdown(){
   date1=$((`date +%s` + $1));
   while [ "$date1" -ne `date +%s` ]; do
     echo -ne "$(date -u --date @$((`date +%s` - $date1)) +%H:%M:%S)\r";
   done
}

# logout: Function for a stopwatch
stopwatch(){
  date1=`date +%s`;
   while true; do
    echo -ne "$(date -u --date @$((`date +%s` - $date1)) +%H:%M:%S)\r";
   done
}

# randompwd: Function to generates a strong random password of 20 characters
# https://www.gnu.org/software/sed/manual/html_node/Character-Classes-and-Bracket-Expressions.html
randompwd() {
	cat /dev/urandom | LC_CTYPE=C tr -dc [:alnum:],[:alpha:],[:punct:] | fold -w 256 | head -c 20 | sed -e 's/^0*//'
	echo
}

# ql: Function to open any file in MacOS Quicklook Preview
ql() { qlmanage -p "$*" >&/dev/null; }   

# my_ps: Function to list processes owned by an user
my_ps() { ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command; }

# ii: Function to display useful host related informaton
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

# Show hidden system and dotfile files
showhiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles YES
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

# Hide hidden system and dotfile files
hidehiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles NO
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

#  ---------------------------------------------------------------------------
#   4. Network and Debugging Functions
#  ---------------------------------------------------------------------------

## hammer a service with curl for a given number of times
## usage: curlhammer $url
curlhammer () {
  bot "about to hammer $1 with $2 curls ⇒";
  echo "curl -k -s -D - $1 -o /dev/null | grep 'HTTP/1.1' | sed 's/HTTP\/1.1 //'"
  for i in {1..$2}
  do
    curl -k -s -D - $1 -o /dev/null | grep 'HTTP/1.1' | sed 's/HTTP\/1.1 //'
  done
  bot "done"
}

## curlheader will return only a specific response header or all response headers for a given URL
## usage: curlheader $header $url
## usage: curlheader $url
curlheader() {
  if [[ -z "$2" ]]; then
    echo "curl -k -s -D - $1 -o /dev/null"
    curl -k -s -D - $1 -o /dev/null:
  else
    echo "curl -k -s -D - $2 -o /dev/null | grep $1:"
    curl -k -s -D - $2 -o /dev/null | grep $1:
  fi
}

## get the timings for a curl to a URL
## usage: curltime $url
curltime(){
  curl -w "   time_namelookup:  %{time_namelookup}\n\
      time_connect:  %{time_connect}\n\
   time_appconnect:  %{time_appconnect}\n\
  time_pretransfer:  %{time_pretransfer}\n\
     time_redirect:  %{time_redirect}\n\
time_starttransfer:  %{time_starttransfer}\n\
--------------------------\n\
        time_total:  %{time_total}\n" -o /dev/null -s "$1"
}

# httpDebug: Function to download a web page and show info on what took time
httpDebug() { /usr/bin/curl "$@" -o /dev/null -w "dns: %{time_namelookup} connect: %{time_connect} pretransfer: %{time_pretransfer} starttransfer: %{time_starttransfer} total: %{time_total}\\n"; }

#  ---------------------------------------------------------------------------
#   5. Fun Functions
#  ---------------------------------------------------------------------------

# matrix: Function to Enable Matrix Effect in the terminal
matrix() {
	echo -e "\\e[1;40m" ; clear ; while :; do echo $LINES $COLUMNS $(( $RANDOM % $COLUMNS)) $(( $RANDOM % 72 )) ;sleep 0.05; done|awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4; letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}' 
}
