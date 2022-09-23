#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

clone() {
  cd ~ &&
    mkdir -v .dotfiles/ &&
    cd .dotfiles/ &&
    git clone "$remoteurl" . &&
    cd ~/.dotfiles/ || exit
}

help() {
  echo \
    "Dotfiles (v0.2.450) - Simply designed to fit your shell life.

Usage: dotfiles.sh [OPTION] [COMMAND]

Options
  -v, --verbose        get verbose output
  -h, --help           show this message

Commands
  clone                clones the dotfiles repository
  install              install the dotfiles"

}

# Script itself
set -e
NAME=sebastienrousseau
WEBSITE=github.com
remoteurl=https://${NAME}@${WEBSITE}/${NAME}/dotfiles.git
#sshurl=git@${WEBSITE}:${NAME}/dotfiles.git
action=print_help  # Default action

while [ $# -gt 0 ]; do
	case $1 in
		clone)
			action=clone
			shift;;
		install)
			action=installs
			shift;;
		-v | --verbose)
			verbose
			shift;;
		-h | --help | *)
			action=help
			shift;;
	esac
done

eval "$action"
