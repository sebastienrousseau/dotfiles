# Les alias de base

## ℹ️ Les alias en mode interactif

Les alias en mode interactif sont des raccourcis pour des commandes. Ils sont
définis dans le fichier `interactive.aliases.sh` et sont disponibles dans tous
les terminaux.

| Alias | Commande | Description |
|---|---|---|
| cp | `cp -vi`  | Pour copier un fichier en mode interactif. |
| ln | `ln -vi`  | Pour créer un lien symbolique en mode interactif. |
| mv | `mv -vi`  | Pour déplacer un fichier en mode interactif. |
| rm | `rm -vi`  | Pour supprimer un fichier en mode interactif. |
| zap | `rm -vi` | Pour supprimer un fichier en mode interactif. |

## 🧭 Les alias de navigation

| Alias | Commande | Description |
|---|---|---|
| --    | `cd -` | Permet de revenir au répertoire précédent |
| ..    | `cd ..` | Permet de revenir au répertoire parent |
| ...   | `cd ../..` | Permet de revenir au répertoire parent du parent |
| ....  | `cd ../../..` | Permet de revenir au répertoire parent du parent du parent |
| ..... | `cd ../../../..` | Permet de revenir au répertoire parent du parent du parent du parent |
| ~     | `cd ${HOME}` | Pour aller dans le répertoire personnel. |
| app   | `cd ${HOME}/Applications; ls` | Shortcut to go to the Applications directory.
| cod   | `cd ${HOME}/Code; ls` | Shortcut to go to the Code directory and list its contents.
| des   | `cd ${HOME}/Desktop; ls` | Shortcut to go to the Desktop directory and list its contents.
| doc   | `cd ${HOME}/Documents; ls` | Shortcut to go to the Documents directory and list its contents.
| dot   | `cd ${HOME}/.dotfiles; ls` | Shortcut to go to the dotfiles directory.
| dow   | `cd ${HOME}/Downloads; ls` | Shortcut to go to the Downloads directory and list its contents.
| hom   | `cd ${HOME}/; ls` | Shortcut to go to home directory and list its contents.
| mus   | `cd ${HOME}/Music; ls` | Shortcut to go to the Music directory and list its contents.
| pic   | `cd ${HOME}/Pictures; ls` | Shortcut to go to the Pictures directory and list its contents.
| vid   | `cd ${HOME}/Videos; ls` | Shortcut to go to the Videos directory and list its contents.

## 📂 Les alias de parcours de répertoire

| Alias | Commande | Description |
|---|---|---|
| bashrc       | `${=EDITOR} $HOME/.bashrc` | Ouvre le fichier de configuration bashrc |
| bash_profile | `${=EDITOR} $HOME/.bash_profile` | Ouvre le fichier de configuration bash_profile |
| gitconfig    | `${=EDITOR} $HOME/.gitconfig` | Ouvre le fichier de configuration gitconfig |
| gitignore    | `${=EDITOR} $HOME/.gitignore` | Ouvre le fichier de configuration gitignore |
| zshrc        | `${=EDITOR} $HOME/.zshrc` | Ouvre le fichier de configuration zshrc |

## 📦 Les alias de gestion de permissions

| Alias | Commande | Description |
|---|---|---|
| 000 | `chmod -R 000` | (chmod a-rwx) Pour interdire tous les accès. |
| 400 | `chmod -R 400` | (chmod a-rw) Pour interdire l'accès en écriture. |
| 444 | `chmod -R 444` | (chmod a-r) Pour interdire l'accès en écriture et en exécution. |
| 600 | `chmod -R 600` | (chmod a+rwx,u-x,g-rwx,o-rwx) Pour interdire l'accès en exécution. |
| 644 | `chmod -R 644` | (chmod a+rwx,u-x,g-wx,o-wx) Pour interdire l'accès en écriture et en exécution. |
| 666 | `chmod -R 666` | (chmod a+rwx,u-x,g-x,o-x) Pour interdire l'accès en exécution. |
| 755 | `chmod -R 755` | (chmod a+rwx,g-w,o-w) Pour interdire l'accès en écriture. |
| 764 | `chmod -R 764` | (chmod a+rwx,g-x,o-wx) Pour interdire l'accès en écriture et en exécution. |
| 777 | `chmod -R 777` | (chmod a+rwx) Pour autoriser tous les accès. |
| chgrp | `chgrp -v` | Pour changer le groupe d'un fichier en mode verbeux. |
| chgrpr | `chgrp -Rv` | Pour changer le groupe d'un répertoire en mode verbeux. |
| chgrpu | `chgrp -Rv ${USER}` | Pour changer le groupe d'un répertoire pour l'utilisateur courant. |
| chmod | `chmod -v` | Pour changer les permissions d'un fichier en mode verbeux. |
| chmodr | `chmod -Rv` | Pour changer les permissions d'un répertoire en mode verbeux. |
| chmodu | `chmod -Rv u+rwX` | Pour changer les permissions d'un répertoire pour l'utilisateur courant. |
| chown | `chown -v` | Pour changer le propriétaire d'un fichier en mode verbeux. |
| chownr | `chown -Rv` | Pour changer le propriétaire d'un répertoire en mode verbeux. |
| chownu | `chown -Rv ${USER}` | Pour changer le propriétaire d'un répertoire pour l'utilisateur courant. |

## :alien: Les alias système

| Alias | Commande | Description |
|---|---|---|
| htop | `sudo htop` | Ajoute sudo à la commande `htop` (pour visualiser les processus en cours) |
| ifconfig | `sudo ifconfig` | Ajoute sudo à la commande ifconfig (pour visualiser les interfaces réseau) |
| iotop | `sudo iotop` | Ajoute sudo à la commande `iotop` (pour visualiser les processus en cours) |
| iptables | `sudo iptables` | Ajoute sudo à la commande `iptables` (pour visualiser les règles de filtrage) |
| purge | `rm -rf ~/library/Developer/Xcode/DerivedData/*` | Supprime les fichiers temporaires Xcode |
| reload | `reset` | Recharge le terminal |
| sudo | `sudo` | Pour exécuter une commande en tant qu'administrateur |
| top | `htop` | Pour visualiser les processus en cours |
| top | alias top='sudo btop' | Allows the user to interactively monitor the system's vital resources or server's processes in real time. |
| ttop | `top -F -s 10  rsize` | Pour visualiser les processus en cours |

| l. | alias 'l.'="ls -dlhF .*| grep -v '^d'" | List hidden files. |

| bye | alias bye='quit' | Shortcut for the `exit` command. |
| c | alias c="clear" | Clear screen shortcut. |

| cgz | alias cgz='tar -zcvf' | Compress a whole directory (including subdirectories) to a tarball. |
| chmox | alias chmox='chmod +x' | Make a file executable. |
| cl | alias cl="clear" | Clear screen shortcut. |
| clear | alias clear="clear && printf '\e[3J'" | Clear screen shortcut. |
| clr | alias clr="clear" | Clear screen shortcut. |
| cls | alias cls="clear" | Clear screen shortcut. |
| cp | alias cp="cp -vi" | Copy files and directories. |
| cr | alias cr='cargo run' | Run cargo. |
| ct | alias ct="clear && tree ./" | Clear screen and list directory contents. |
| ctf | alias ctf='echo $(ls -1 | wc -l)' | Count the number of files in the current directory. |
| curl | alias curl='curl --compressed' | Use compression when transferring data. |
| da | alias da='date "+%Y-%m-%d %A %T %Z"' | Display the current date and time. |
| del | alias del="rm -rfv" | Remove a file or directory. |
| digg | alias digg="dig @8.8.8.8 +nocmd any +multiline +noall +answer" | Dig with Google's DNS. |
| dsp | alias dsp="sudo du -shc ." | Show the size of the current directory. |
| du | alias du='sudo du -h' | File size human readable output sorted by size. |
| duf | alias duf='sudo du -sh*' | File size human readable output sorted. |
| e | alias e='vim' | Edit current file. |
| edit | alias edit='vim' | Edit current file. |
| egz | alias egz='tar -xvzf' | Extract a whole directory (including subdirectories) |
| f | alias f='find . -name ' | Quickly search for file |
| fd | alias fd='find . -type d -name' | Quickly search for directory |
| ff | alias ff='find . -type f -name' | Quickly search for file |
| gz | alias gz='tar -zcvf' | Compress a whole directory (including subdirectories) to a tarball. |
| h | alias h='history' | Lists all recently used commands. |
| halt | alias halt="sudo /sbin/halt" | Shutdown the system. |
| ifconfig | alias ifconfig='sudo ifconfig' | Append sudo to ifconfig (configure network interface parameters) command. |
| ip | alias ip="ip4; ip6" | Get the public IPv4 and IPv6 addresses. |
| ip4 | alias ip4="dig +short myip.opendns.com @resolver1.opendns.com -4" | Get the public IPv4 address. |
| ip6 | alias ip6="dig -6 AAAA +short myip.opendns.com. @resolver1.opendns.com." | Get the public IPv6 address. |
| ipinfo | alias ipinfo='ipconfig getpacket en0' | Get network interface parameters for en0. |
| l | alias l='ls -lFh' | Size, show type, human readable. |
| l1 | alias l1='ls -1' | Display one file per line. |
| la | alias la='ls -Alh' | show hidden files on the command line. |
| labc | alias labc='ls -lap' | List all files in alphabetical order. |
| lc | alias lc='wc -l' | Count the number of lines in the file. |
| lct | alias lct='ls -lcrh' | sort by change time |
| ld | alias ld='ls -ltrh' | sort by date |
| ldir | alias ldir="ls -l | egrep '^d'" | directories only |
| ldot | alias ldot="l." | List hidden files. |
| left | alias left='ls -t -1' | List files by date, most recent last. |
| lf | alias lf="ls -l | egrep -v '^d'" | files only |
| lk | alias lk='ls -lSrh' | sort by size |
| ll | alias ll='ls -lAFh' | Long list, show almost all, show type, human readable. |
| lla | alias lla='ls -l -d $PWD/*' | List full path of all files in current directory. |
| lm | alias lm='ls -alh | more' | pipe through 'more' |
| ln | alias ln='ln -vi' | interactive symbolic link |
| locale | alias locale='locale -a | grep UTF-8' | List all available locales. |
| lp | alias lp='sudo lsof -i -T -n' | List all open ports. |
| lr | alias lr='ls -lRh' | recursive ls |
| ls | alias ls='ls --color' | Colorize the output. |
| lS | alias lS='ls -1FSsh'  | Order Files Based on Last Modified Time and size. |
| lt | alias lt="tree" | List contents of directories in a tree-like format. |
| lu | alias lu='ls -lurh' | sort by access time |
| lw | alias lw='ls -xAh' | wide listing format |
| lx | alias lx='ls | sort -k 1,1 -t .' | sort by extension |
| mate | alias mate='vim' | Edit current file. |
| mc | alias mc='make clean' | Make clean. |
| md | alias md='mkd' | Create the directory and all parent directories, verbose mode. |
| mi | alias mi='make install' | Make install. |
| mk | alias mk=make | Make. |
| mkbz2 | alias mkbz2='tar -cvjf' | Create a temporary tar ball compressed with bzip2. |
| mkcd | alias mkcd='mkdir -pv && cd' | Create the directory and all parent directories, verbose mode, then change to it. |
| mkd | alias mkd='mkdir -pv' | Create the directory and all parent directories, verbose mode. |
| mkdd | alias mkdd='mkdir -pv $(date +%Y%m%d)' | Create a directory with the current date. |
| mkgz | alias mkgz='tar -cvzf' | Create a temporary tar ball compressed with gzip. |
| mkh | alias mkh="make help" | Make help. |
| mkr | alias mkr="make run" | Make run. |
| mkt | alias mkt="make test" | Make test. |
| mktar | alias mktar='tar -cvf' | Create a temporary tarball. |
| mv | alias mv='mv -vi' | Move files interactively (ask before overwrite) and verbose. |
| mx | alias mx='chmod a+x' | Make executable. |
| nls | alias nls='sudo lsof -i -P | grep LISTEN' | Show only active network listeners. |
| now | alias now='date +"%T"' | Show the current time. |
| npmi | alias npmi='npm install ' | Install npm package. |
| npms | alias npms='npm start ' | Start npm package. |
| op | alias op='sudo lsof -i -P' | List of open ports. |
| p | alias p='pwd' | Shortcut for `pwd` which returns working directory name. |
| pa | alias pa="clear && pwd && echo '' && ls && echo ''" | Clear the screen, show the current directory, and list the files. |
| paa | alias paa="clear && pwd && echo '' && ls -a && echo ''" | Clear the screen, show the current directory, and list all files. |
| path | alias path='echo  ${PATH//:/\\n}' | Display the $PATH variable on newlines. |
| pid | alias pid='ps -f' | Display the uid, pid, parent pid, recent CPU usage, process start time, controlling tty, elapsed CPU usage, and the associated command. |
| ping | alias ping='ping -c 5' | Limit Ping to 5 ECHO_REQUEST packets. |
| please | alias please='sudo -' | Execute a command as the superuser. |
| pn | alias pn='pnpm' | Shortcut to pnpm. |
| ports | alias ports='netstat -tulan' | List all listening ports. |
| poweroff | alias poweroff="sudo /sbin/shutdown" | Poweroff the system. |
| pp | alias pp="clear && pwd" | Clear the screen and show the current directory. |
| ps | alias ps='ps auxwww' | Getting full path of executables. |
| pt | alias pt="clear && pwd && echo '' && tree ./ && echo ''" | Clear the screen and show the current directory and tree. |
| :q | alias ':q'='quit' | Permet de quitter le shell |
| q | alias q='quit' | Shortcut for the `exit` command. |
| qfind | alias qfind='find . -name ' | Quickly search for file. |
| quit | alias quit='exit' | Shortcut for the `exit` command. |
| r | alias r=reload | Reload the shell. |
| reboot | alias reboot="sudo /sbin/reboot" | Reboot the system. |
| reload | alias reload='exec $SHELL -l' | Reload the shell. |
| rm | alias rm='rm -vI' | Prompts for every file before removing. |
| rr | alias rr="rm -rf" | Remove directory and all its contents. |
| rs | alias rs='rsync -avz' | Rsync with verbose and progress. |
| s | alias s='sudo' | Execute a command as the superuser. |
| shutdown | alias shutdown='sudo shutdown -h now' | Shutdown the system. |
| spd | alias spd='sudo rm -rf /private/var/log/asl/*' | Remove all log files in /private/var/log/asl. |
| srv | alias srv='python3 -m http.server' | Start a simple HTTP server. |
| svi | alias svi='sudo vi' | Run vi in sudo mode. |
| t | alias t='tail -f' | Prints the last 10 lines of a text or log file, and then waits for new additions to the file to print it in real time. |

| trash | alias trash="rm -fr ~/.Trash" | Remove all files in the trash. |
| tree | alias tree='tree --dirsfirst' | Display a directory tree. |
| unbz2 | alias unbz2='tar -xvjf' | Extract a tarball compressed with bzip2. |
| undopush | alias undopush="git push -f origin HEAD^:master" | Undo the last push. |
| ungz | alias ungz='tar -xvzf' | Extract a tarball compressed with gzip. |
|untar  | alias untar='tar -xvf' | Extract a tarball. |
| usage | alias usage='du -ch | grep total' | Grabs the disk usage in the current directory. |
| v | alias v='vim' | Edit current file. |
| wget | alias wget='wget -c' | wget with resume. |
| wip | alias wip='dig +short myip.opendns.com @resolver1.opendns.com' | Get public IP address. |
| wk | alias wk='date +%V' | Show the current week number. |
| wth | alias wth='curl -s "wttr.in/?format=3"' | Get the weather. |
| x | alias x='quit' | Shortcut for the `exit` command. |

## :tv: Les alias d'information

| Alias | Commande | Description |
|---|---|---|
| kp | `ps auxwww` | Pour visualiser les processus en cours |
| pid | `ps -f` | Pour visualiser les processus en cours |
| ping | `ping -c 5` | Pour tester la connexion internet |
| ports | `netstat -tulan` | Pour visualiser les ports en cours d'utilisation |
| pscpu | `ps aux | sort -nr -k 3 | head -3` | Pour visualiser les trois processus les plus gourmands en CPU |
| pscpu10 | `ps aux | sort -nr -k 3 | head -10` | Pour visualiser les dix processus les plus gourmands en CPU |
| psmem | `ps aux | sort -nr -k 4 | head -3` | Pour visualiser les trois processus les plus gourmands en mémoire |
| psmem10 | `ps aux | sort -nr -k 4 | head -10` | Pour visualiser les dix processus les plus gourmands en mémoire |

## 🧬 Alias génériques

| Alias | Commande | Description |
|---|---|---|
| c | `clear && printf '\e[3J'` | Pour nettoyer le terminal |
| cls | `clear && printf '\e[3J` | Pour nettoyer le terminal |
| countf | `echo $(ls -1 | wc -l)` | Pour compter le nombre de fichiers dans le répertoire courant |
| dt | `tee $HOME/terminal-$(date +%F).txt` | Pour sauvegarder le terminal dans un fichier texte |
| du | `du -h` | Pour afficher la taille des fichiers et dossiers |
| dud | `du -d 1 -h` | Pour afficher la taille des fichiers et dossiers du répertoire courant |
| duf | `du -sh *` | Pour afficher la taille des fichiers et dossiers du répertoire courant |
| egz | `tar -xvzf` | Pour décompresser un fichier .tar.gz |
| flush | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` | Pour vider le cache DNS |
| gz | `tar -zcvf` | Pour compresser un fichier |
| h | `history` | Pour afficher l'historique des commandes |
| hs | `history | grep` | Pour rechercher une commande dans l'historique |
| hsi | `history | grep -i` | Pour rechercher une commande dans l'historique (insensible à la casse) |
| locale | `locale -a | grep UTF-8` | Pour afficher les locales disponibles |
| mkdir | `mkdir -pv` | Pour créer un répertoire |
| p | `pwd` | Pour afficher le répertoire courant |
| path | `echo  ${PATH//:/\\n}` | Pour afficher le chemin des exécutables |
| q | `exit` | Pour quitter le terminal |
| r | `reload` | Pour recharger le terminal |
| reboot | `sudo shutdown -r now` | Pour redémarrer le système |
| reload | `. ~/.zshrc` | Pour recharger le fichier de configuration zshrc |
| rp | `diskutil repairPermissions /` | Pour réparer les permissions du disque |
| rv | `diskutil repairvolume /` | Pour réparer le disque |
| rmdir | `rm –rf` | Pour supprimer un répertoire |
| shutdown | `sudo shutdown -h now` | Pour éteindre le système |
| sort | `LC_ALL=C sort` | Pour trier les fichiers |
| sortnr | `sort -n -r` | Pour trier les fichiers par ordre décroissant |
| t | `tail -f` | Pour afficher les dernières lignes d'un fichier |
| vp | `diskutil verifyPermissions /` | Pour vérifier les permissions du disque |
| vv | `diskutil verifyvolume /` | Pour vérifier le disque |

## 🔎 Alias de recherche

| Alias | Commande | Description |
|---|---|---|
| egrep | `egrep --color` | Pour rechercher un texte dans un fichier |
| fd | `find . -type d -name` | Pour rechercher un répertoire |
| ff | `find . -type f -name` | Pour rechercher un fichier |
| fgrep | `fgrep --color` | Pour rechercher un texte dans un fichier |
| grep | `grep --color` | Pour rechercher un texte dans un fichier |
| hgrep | `history | grep` | Pour rechercher une commande dans l'historique |
| sgrep | `grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS}` | Pour rechercher un texte dans un fichier |

## 🗂 Alias de gestion de fichiers

| Alias | Commande | Description |
|---|---|---|
| l | `ls -lFh` | Lister les fichiers par taille, type et avec un format lisible par l’homme. |
| l1 | `ls -1`  | Afficher un fichier par ligne. |
| la | `ls -lAFh` | Liste longue, montrer presque tout, montrer le type, lisible par l'homme. |
| lart | `ls -1Fcart` | Force la sortie à être une entrée par ligne, dernière modification, inclut les entrées de répertoire dont le nom commence par un point, inverse, tri par heure de modification. |
| last | `ls -t`  | Trie tous les fichiers par temps de modification, en affichant d'abord le dernier fichier édité. |
| lc | `ls -ltcr` | Affiche les fichiers par date de modification, en ordre décroissant. |
| ld | `ls -ld` | Affiche les informations détaillées d'un répertoire. |
| ldot | `ls -ld .*` | Affiche les fichiers cachés. |
| lf | `ls -lf` | Affiche les fichiers avec caractères spéciaux. |
| lh | `ls -lh` |Lister les fichiers avec un format lisible par l’homme. |
| li | `ls -i`  | Afficher le numéro d’inode du fichier ou du répertoire. |
| lk | `ls -lSr` | Trier les fichiers/répertoires par taille inverse. |
| ll | `ls -lghFG | sort -n -td -k2`  | Affiche les fichiers par taille, type, format lisible par l'homme, tri par date. |
| ln | `ls -n`  | Afficher les fichiers avec leur numéro de nœud. |
| lq | `ls -q`  | Masque les caractères spéciaux. |
| lr | `ls -tRFh` | Liste les fichiers par date de modification, récursivement, format lisible par l'homme. |
| lrt | `ls -1Fcrt` | Force la sortie à être une entrée par ligne, dernière modification, inclut les entrées de répertoire dont le nom commence par un point, tri par heure de modification. |
| lS | `ls -1FSsh` | Force la sortie à être une entrée par ligne, tri par taille, format lisible par l'homme. |
| lsd | `ls -l | grep "^d"` | Affiche les répertoires. |
| lt | `ls -ltFh` | Liste les fichiers par date de modification, format lisible par l'homme. |
| ltr | `ls -ltr` | Ordre de sortie inversé |
| lu | `ls -ltur` | Affiche les fichiers par date de modification, en ordre inverse. |
| lx | `ls -lXB` | Trie les fichiers par extension. |

## 🚈 Networking aliases

| Alias | Command | Description |
|---|---|---|
| ipInfo0 | `ipconfig getpacket en0` | Pour afficher les informations réseau de l'interface Ethernet |
| ipInfo1 | `ipconfig getpacket en1` | Pour afficher les informations réseau de l'interface Wi-Fi |
| lsock | `sudo /usr/sbin/lsof -i -P` | Pour afficher les connexions réseau |
| lsockTCP | `sudo /usr/sbin/lsof -nP | grep TCP` | Pour afficher les connexions TCP |
| lsockUDP | `sudo /usr/sbin/lsof -nP | grep UDP` | Pour afficher les connexions UDP |
| lsof | `lsof -i` | Pour afficher les connexions réseau |
| mic | `sudo lsof -i | grep LISTEN` | Pour afficher les connexions réseau |
| op | `sudo lsof -i -P` | Écoute les ports ouverts |
| wip | `dig +short myip.opendns.com @resolver1.opendns.com` | Pour afficher l'adresse IP publique |

## 🧭 Navigation aliases

| Alias | Commande | Description |
|---|---|---|
| ~ | `cd ~` | Pour se déplacer dans le répertoire personnel |
| cd. | `cd -P .` | Montrer le chemin absolu du répertoire courant |
| cd/ | `cd /; ls` | Pour se déplacer dans le répertoire racine |
| gitRoot | `cd "$(git rev-parse --show-toplevel)"` | Pour se déplacer dans le répertoire racine du dépôt Git |
| . | `cd ..; ls` | Pour se déplacer dans le répertoire parent |
| .. | `cd ../..; ls` | Pour se déplacer dans le répertoire parent du répertoire parent |
| ... | `cd ../../..; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent |
| .... | `cd ../../../..; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent du répertoire parent |
| ..... | `cd ../../../../..; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent du répertoire parent du répertoire parent |
| cd . | `cd .; ls` | Pour se déplacer dans le répertoire courant |
| cd .. | `cd ..; ls` | Pour se déplacer dans le répertoire parent du répertoire parent |
| cd ... | `cd ...; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent |
| cd .... | `cd ....; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent du répertoire parent |
| cd ..... | `cd .....; ls` | Pour se déplacer dans le répertoire parent du répertoire parent du répertoire parent du répertoire parent du répertoire parent |
| - | `cd -; ls` | Naviguer vers le répertoire précédent et afficher son contenu |
| -- | `cd -2; ls` | Naviguer vers le répertoire précédent du répertoire précédent et afficher son contenu |
| --- | `cd -3; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| ---- | `cd -4; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| ----- | `cd -5; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| 1 | `cd -; ls` | Naviguer vers le répertoire précédent et afficher son contenu |
| 2 | `cd -2; ls` | Naviguer vers le répertoire précédent du répertoire précédent et afficher son contenu |
| 3 | `cd -3; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| 4 | `cd -4; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| 5 | `cd -5; ls` | Naviguer vers le répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent du répertoire précédent et afficher son contenu |
| 1. | `cd ..; ls` | Pour se déplacer dans le répertoire parent et afficher son contenu |
| 2. | `cd ../..; ls` | Naviguer vers le répertoire parent du répertoire parent et afficher son contenu |
| 3. | `cd ../../..; ls` | Naviguer vers le répertoire parent du répertoire parent du répertoire parent et afficher son contenu |
| 4. | `cd ../../../..; ls` | Move back to four levels and show the directory content. |
| 5. | `cd ../../../../..; ls` | Move back to five levels and show the directory content. |
| cd 1. | `cd ..; ls` | Move back to one level and show the directory content. |
| cd 2. | `cd ../..; ls` | Move back to two levels and show the directory content. |
| cd 3. | `cd ../../..; ls` | Move back to three levels and show the directory content. |
| cd 4. | `cd ../../../..; ls` | Move back to four levels and show the directory content. |
| cd 5. | `cd ../../../../..; ls` | Move back to five levels and show the directory content. |
| less | `less -R` | Pour afficher le contenu d'un fichier avec des couleurs |
| openDir | `open -a Finder ./` | Ouvrir le répertoire courant dans le Finder |
| path | `echo "$PATH" | tr ":" "\n" | nl` | Afficher le contenu de la variable d'environnement PATH avec des numéros de ligne |
| so | `setopt` | Afficher les options actives de zsh |
| uso | `unsetopt` | Liste les options inactives de zsh |

## 📂 Path aliases

| Alias | Commande | Description |
|---|---|---|
| .bash_profile | `cd ~/.bash_profile` | Change to .bash_profile directory. |
| .bashrc | `cd ~/.bashrc` | Change to .bashrc directory. |
| .gitconfig | `cd ~/.gitconfig` | Change to .gitconfig directory. |
| .gitignore | `cd ~/.gitignore` | Change to .gitignore directory. |

## 📝 Process aliases

| Alias | Commande | Description |
|---|---|---|
| kill9 | `kill -9` | Terminer un processus avec le signal 9 |
| killall | `killall` | Terminer tous les processus |
| ps | `ps -ef` | Liste tous les processus |
| psa | `ps aux` | Liste tous les processus |
| psax | `ps ax` | Liste tous les processus |
| psaux | `ps aux` | Liste tous les processus |
| psauxw | `ps auxw` | Liste tous les processus |
| psauxww | `ps auxww` | Liste tous les processus |

## 🌐 Les alias globaux

Ces alias sont conçus pour être utilisés dans n'importe quel répertoire, ce qui
signifie que vous pouvez les utiliser même à la fin de la commande que vous avez
tapée.

la fin de la commande que vous avez tapée. Exemples :

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
| H | `\| head`              | Tuyau vers la commande head qui affiche la première partie du fichier |
| T | `\| tail`              | Tuyau vers la commande tail qui affiche la dernière partie du fichier |
| G | `\| grep`              | Tuyau vers la commande grep qui filtre le texte |
| L | `\| less`              | Tuyau vers la commande less, pratique pour la pagination |
| M | `\| most`              | Tuyau vers la commande most, pratique pour la pagination |
| LL | `2>&1 \| less`        | Écriture de la sortie standard et de la sortie d'erreur dans la commande less |
| CA | `2>&1 \| cat -A`      | Écriture de la sortie standard et de la sortie d'erreur dans la commande cat avec l'option -A |
| NE | `2 > /dev/null`       | Redirige la sortie d'erreur vers /dev/null |
| NUL | `> /dev/null 2>&1`   | Redirige la sortie standard et la sortie d'erreur vers /dev/null |
| P | `2>&1\| pygmentize -l pytb` | Écriture de la sortie standard et de la sortie d'erreur dans la commande pygmentize avec l'option -l pytb |

## File extension aliases

These are special aliases that are triggered when a file name is passed as the command. For example,
if the pdf file extension is aliased to `acroread` (a popular Linux pdf reader), when running `file.pdf`
that file will be open with `acroread`.

## Reading Docs

| Alias | Commande | Description |
|---|---|---|
| pdf | `acroread` | Opens up a document using acroread |
| ps | `gv`   | Opens up a .ps file using gv   |
| dvi | `xdvi` | Opens up a .dvi file using xdvi |
| chm | `xchm` | Opens up a .chm file using xchm |
| djvu | `djview` | Opens up a .djvu file using djview |

## Listing files inside a packed file

| Alias | Commande | Description |
|---|---|---|
| zip | `unzip -l` | Lists files inside a .zip file |
| rar | `unrar l` | Lists files inside a .rar file |
| tar | `tar tf` | Lists files inside a .tar file |
| tar.gz | `echo` | Lists files inside a .tar.gz file |
| ace | `unace l` | Lists files inside a .ace file |
