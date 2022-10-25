
## 👽 System aliases

### System tools aliases

| Alias | Command | Description |
|---|---|---|
| htop | `sudo htop` | Append sudo to htop (interactive process viewer) command. |
| ifconfig | `sudo ifconfig` | Append sudo to ifconfig (configure network interface parameters) command. |
| iotop | `sudo iotop` | Append sudo to iotop (display top disk I/O events by process) command. |
| iptables | `sudo iptables` | Append sudo to iptables (Append sudo to iptables (Administration tool for packet filtering) command. |
| purge | `rm -rf ~/library/Developer/Xcode/DerivedData/*` | Purging Xcode DerivedData. |
| reload | `reset` | Reset and initialize the Terminal screen. |
| sudo | `sudo` | Allows a system administrator to delegate authority to give certain users (or groups of users) the ability to run some (or all) commands as root or another user while providing an audit trail of the commands and their arguments. |
| top | `htop` | Allows the user to interactively monitor the system's vital resources or server's processes in real time. |
| ttop | `top -F -s 10  rsize` | Recommended 'top' invocation to minimize resources. |
| zshrc | `${=EDITOR} $HOME/.zshrc` | Quick access to the `.zshrc` file. |

### System information aliases

| Alias | Command | Description |
|---|---|---|
| kp | `ps auxwww` | Getting full path of executables. The "auxwww" are options to the ps (process) command. The options mean display all process running that belong to you and to other users and provide information about who owns what process. The three "www"'s mean display the entire command line regardless of how long it is and wrap it in your window. |
| pid | `ps -f` | Display the uid, pid, parent pid, recent CPU usage, process start time, controlling tty, elapsed CPU usage, and the associated command. |
| ping | `ping -c 5` | Limit Ping to 5 ECHO_REQUEST packets. |
| ports | `netstat -tulan` | Display ports |
| pscpu | `ps aux | sort -nr -k 3 | head -3` | Getting top 3 CPU eating processes. |
| pscpu10 | `ps aux | sort -nr -k 3 | head -10` | Getting top 10 CPU eating processes. |
| psmem | `ps aux | sort -nr -k 4 | head -3` | Getting top 3 memory eating processes. |
| psmem10 | `ps aux | sort -nr -k 4 | head -10` | Getting top 10 memory eating processes. |

## ℹ️ Interactive mode aliases

### Interactive mode aliases

| Alias | Command | Description |
|---|---|---|
| cp | `cp -i` | Copy files with warning. |
| ln | `ln -i` | Make links with warning. |
| mv | `mv -i` | Move files with warning. |
| rm | `rm -i` | Remove file with warning.|
| zap | `rm -i` | Remove file with warning.|

## 🧬 Generic aliases

| Alias | Command | Description |
|---|---|---|
| c | `clear && printf '\e[3J'` | Clear screen shortcut. |
| cls | `clear && printf '\e[3J` | Clear screen command. |
| countf | `echo $(ls -1 | wc -l)` | Count of non-hidden files in current dir. |
| dt | `tee $HOME/terminal-$(date +%F).txt` | Pipe content to file in the $HOME directory. |
| du | `du -h` | File size human readable output sorted by size. |
| dud | `du -d 1 -h` | File size human readable output sorted by depth. |
| duf | `du -sh *` | File size human readable output sorted. |
| egz | `tar -xvzf` | Extract a whole directory (including subdirectories). |
| flush | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | Flush the directory service cache and restart the multi-cast DNS daemon. |
| gz | `tar -zcvf` | Compress a whole directory (including subdirectories). |
| h | `history` | Lists all recently used commands. |
| hs | `history | grep` | Use grep to search the command history. |
| hsi | `history | grep -i` | Use grep to do a case-insensitive search of the command history. |
| locale | `locale -a | grep UTF-8` | Check UTF-8 locale. |
| mkdir | `mkdir -pv` | Create the directory and all parent directories, verbose mode. |
| p | `pwd` | Shortcut for `pwd` which returns working directory name. |
| path | `echo  ${PATH//:/\\n}` | Display the $PATH variable on newlines. |
| q | `exit` | Shortcut for the `exit` command. |
| r | `reload` | Shortcut for the `reload` command. |
| reboot | `sudo shutdown -r now` | Restart immediately. |
| reload | `. ~/.zshrc` | Reload the Z shell. |
| rp | `diskutil repairPermissions /` | Repair macOS Permissions. |
| rv | `diskutil repairvolume /` | diskutil repairvolume / |
| rmdir | `rm –rf` | Remove directory. |
| shutdown | `sudo shutdown -h now` | Shutdown immediately. |
| sort | `LC_ALL=C sort` | Fix sorting order |
| sortnr | `sort -n -r` | Sort in a descending order according to numerical value. |
| t | `tail -f` | Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time. |
| vp | `diskutil verifyPermissions /` | Verify macOS Permissions |
| vv | `diskutil verifyvolume /` | Verify macOS Volume |

## 🔎 Finding aliases

| Alias | Command | Description |
|---|---|---|
| egrep | `egrep --color`             | Searches that can handle extended regular expressions (EREs). |
| fd | `find . -type d -name`      | Find a directory with a given name. |
| ff | `find . -type f -name`      | Find a file with a given name. |
| fgrep | `fgrep --color`             | Searches that can only handle fixed patterns. |
| grep | `grep --color`              | Searches for a query string. |
| hgrep | `history | grep`            | Searches for a word in the list of previously used commands. |
| sgrep | `grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS}` | Useful for searching within files. |

## 🗂 List directory aliases

| Alias | Command | Description |
|---|---|---|
| l | `ls -lFh` | Size, show type, human readable.                                                                                       |
| l1 | `ls -1`  | Display one file per line.                                                                                            |
| la | `ls -lAFh` | Long list, show almost all, show type, human readable.                                                                |
| lart | `ls -1Fcart` | Force output to be one entry per line, last changed, includes directory entries whose names begin with a dot, reverse, sort by time modified. |
| last | `ls -t`  | Sorts all files by modification time, showing the last edited file first.                                             |
| lc | `ls -ltcr` | Sort by/show change time,most recent last.                                                                            |
| ld | `ls -ld` | Display directory information.                                                                                        |
| ldot | `ls -ld .*` | Display only dot files.                                                                                               |
| lf | `ls -lf` | Visual Classification of Files With Special Characters.                                                               |
| lh | `ls -lh` | Display file size in human readable format.                                                                           |
| li | `ls -i`  | Display File Inode Number.                                                                                            |
| lk | `ls -lSr` | Sort by size, biggest last.                                                                                           |
| ll | `ls -lghFG | sort -n -td -k2`  | Long list.                                                                                      |
| ln | `ls -n`  | Display File UID and GID.                                                                                             |
| lq | `ls -q`  | Hide Control Characters.                                                                                              |
| lr | `ls -tRFh` | Display Files Recursively sorted by date, recursive, show type, human readable.                                       |
| lrt | `ls -1Fcrt` | Order Files Based on Last Modified Time (In Reverse Order).                                                           |
| lS | `ls -1FSsh` | Order Files Based on Last Modified Time and size.                                                                     |
| lsd | `ls -l | grep "^d"` | Display only directories.                                                                                     |
| lt | `ls -ltFh` | Display Files long list, sorted by date, show type, human readable.                                                   |
| ltr | `ls -ltr` | Sort by date, most recent last.                                                                                       |
| lu | `ls -ltur` | Sort by/show access time,most recent last.                                                                            |
| lx | `ls -lXB` | Sort by extension.                                                                                                    |

## 🚈 Networking aliases

| Alias | Command | Description |
|---|---|---|
| ipInfo0 | `ipconfig getpacket en0` | Get info on connections for en0. |
| ipInfo1 | `ipconfig getpacket en1` | Get info on connections for en1. |
| lsock | `sudo /usr/sbin/lsof -i -P` | Display open sockets. |
| lsockTCP | `sudo /usr/sbin/lsof -nP | grep TCP` | Display only open TCP sockets. |
| lsockUDP | `sudo /usr/sbin/lsof -nP | grep UDP` | Display only open UDP sockets. |
| lsof | `lsof -i` | Show all open TCP/IP sockets. |
| mic | `sudo lsof -i | grep LISTEN` | Listening to all connections. |
| op | `sudo lsof -i -P` | List of open ports. |
| wip | `dig +short myip.opendns.com @resolver1.opendns.com` | Public facing IP Address. |

## 🧭 Navigation aliases

| Alias | Command | Description |
|---|---|---|
| ~ | `cd ~` | Change to $HOME directory. |
| cd. | `cd -P .` | Show true (physical) path instead of symbolic links in the path. |
| cd/ | `cd /; ls` | Change to / root directory and show the directory content. |
| gitRoot | `cd "$(git rev-parse --show-toplevel)"` | Change to Git Root directory. |
| . | `cd ..; ls` | Move back to one level and show the directory content. |
| .. | `cd ../..; ls` | Move back to two levels and show the directory content. |
| ... | `cd ../../..; ls` | Move back to three levels and show the directory content. |
| .... | `cd ../../../..; ls` | Move back to four levels and show the directory content. |
| ..... | `cd ../../../../..; ls` | Move back to five levels and show the directory content. |
| cd . | `cd .; ls` | Move back to one level and show the directory content. |
| cd .. | `cd ..; ls` | Move back to two levels and show the directory content. |
| cd ... | `cd ...; ls` | Move back to three levels and show the directory content. |
| cd .... | `cd ....; ls` | Move back to four levels and show the directory content. |
| cd ..... | `cd .....; ls` | Move back to five levels and show the directory content. |
| - | `cd -; ls` | Navigate to the previous one level directory (or back) and show the directory content. |
| -- | `cd -2; ls` | Navigate to the previous two levels directory (or back) and show the directory content. |
| --- | `cd -3; ls` | Navigate to the previous three levels directory (or back) and show the directory content. |
| ---- | `cd -4; ls` | Navigate to the previous four levels directory (or back) and show the directory content. |
| ----- | `cd -5; ls` | Navigate to the previous five levels directory (or back) and show the directory content. |
| 1 | `cd -; ls` | Navigate to the previous one level directory (or back) and show the directory content. |
| 2 | `cd -2; ls` | Navigate to the previous two levels directory (or back) and show the directory content. |
| 3 | `cd -3; ls` | Navigate to the previous three levels directory (or back) and show the directory content. |
| 4 | `cd -4; ls` | Navigate to the previous four levels directory (or back) and show the directory content. |
| 5 | `cd -5; ls` | Navigate to the previous five levels directory (or back) and show the directory content. |
| 1. | `cd ..; ls` | Move back to one level and show the directory content. |
| 2. | `cd ../..; ls` | Move back to two levels and show the directory content. |
| 3. | `cd ../../..; ls` | Move back to three levels and show the directory content. |
| 4. | `cd ../../../..; ls` | Move back to four levels and show the directory content. |
| 5. | `cd ../../../../..; ls` | Move back to five levels and show the directory content. |
| cd 1. | `cd ..; ls` | Move back to one level and show the directory content. |
| cd 2. | `cd ../..; ls` | Move back to two levels and show the directory content. |
| cd 3. | `cd ../../..; ls` | Move back to three levels and show the directory content. |
| cd 4. | `cd ../../../..; ls` | Move back to four levels and show the directory content. |
| cd 5. | `cd ../../../../..; ls` | Move back to five levels and show the directory content. |
| less | `less -R` | Make less always work with colored input. |
| openDir | `open -a Finder ./` | Open any folder from macOS Terminal. |
| path | `echo "$PATH" | tr ":" "\n" | nl` | Display or print $PATH variable. |
| so | `setopt` | Lists the active options. |
| uso | `unsetopt` | Lists the inactive options. |

## 📂 Path aliases

| Alias | Command | Description |
|---|---|---|
| .bash_profile | `cd ~/.bash_profile` | Change to .bash_profile directory. |
| .bashrc | `cd ~/.bashrc` | Change to .bashrc directory. |
| .gitconfig | `cd ~/.gitconfig` | Change to .gitconfig directory. |
| .gitignore | `cd ~/.gitignore` | Change to .gitignore directory. |

## 📝 Process aliases

| Alias | Command | Description |
|---|---|---|
| kill9 | `kill -9` | Kill a process. |
| killall | `killall` | Kill a process. |
| ps | `ps -ef` | List all processes. |
| psa | `ps aux` | List all processes. |
| psax | `ps ax` | List all processes. |
| psaux | `ps aux` | List all processes. |
| psauxw | `ps auxw` | List all processes. |
| psauxww | `ps auxww` | List all processes. |

## 🌐 Global aliases

These aliases are expanded in any position in the command line, meaning you can use them even at the
end of the command you've typed. Examples:

Quickly pipe to less:

```zsh
$ ls -l /var/log L
# will run
$ ls -l /var/log | less
```

Silences stderr output:

```zsh
$ find . -type f NE
# will run
$ find . -type f 2>/dev/null
```

| Alias | Command | Description |
|---|---|---|
| H | `\| head`              | Pipes output to head which outputs the first part of a file |
| T | `\| tail`              | Pipes output to tail which outputs the last part of a file |
| G | `\| grep`              | Pipes output to grep to search for some word           |
| L | `\| less`              | Pipes output to less, useful for paging                |
| M | `\| most`              | Pipes output to more, useful for paging                |
| LL | `2>&1 \| less`         | Writes stderr to stdout and passes it to less          |
| CA | `2>&1 \| cat -A`       | Writes stderr to stdout and passes it to cat           |
| NE | `2 > /dev/null`        | Silences stderr                     |
| NUL | `> /dev/null 2>&1`     | Silences both stdout and stderr     |
| P | `2>&1\| pygmentize -l pytb` | Writes stderr to stdout and passes it to pygmentize    |

## File extension aliases

These are special aliases that are triggered when a file name is passed as the command. For example,
if the pdf file extension is aliased to `acroread` (a popular Linux pdf reader), when running `file.pdf`
that file will be open with `acroread`.

### Reading Docs

| Alias | Command | Description |
|---|---|---|
| pdf | `acroread` | Opens up a document using acroread |
| ps | `gv`   | Opens up a .ps file using gv   |
| dvi | `xdvi` | Opens up a .dvi file using xdvi |
| chm | `xchm` | Opens up a .chm file using xchm |
| djvu | `djview` | Opens up a .djvu file using djview |

### Listing files inside a packed file

| Alias | Command | Description |
|---|---|---|
| zip | `unzip -l` | Lists files inside a .zip file |
| rar | `unrar l` | Lists files inside a .rar file |
| tar | `tar tf` | Lists files inside a .tar file |
| tar.gz | `echo` | Lists files inside a .tar.gz file |
| ace | `unace l` | Lists files inside a .ace file |
