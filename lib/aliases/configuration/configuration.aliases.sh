#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT
# Script: configuration.aliases.sh
# Version: 0.2.464
# Website: https://dotfiles.io

# 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂

# Alias to open the Apache configuration file in the default text editor
alias apconf='${=EDITOR} /etc/apache2/apache2.conf'

# Alias to open the Bash configuration file in the default text editor
alias bshrc='${=EDITOR} $HOME/.bashrc'

# Alias to open the Bash profile in the default text editor
alias bshp='${=EDITOR} $HOME/.bash_profile'

# Alias to open the Docker Compose file in the default text editor
alias dockcomp='${=EDITOR} docker-compose.yml'

# Alias to open the current directory in the default text editor
alias eddir='${=EDITOR} .'

# Alias to open the Git configuration file in the default text editor
alias gcfg='${=EDITOR} $HOME/.gitconfig'

# Alias to open the Git ignore file in the default text editor
alias gign='${=EDITOR} $HOME/.gitignore'

# Alias to open the hosts file in the default text editor
alias hosts='${=EDITOR} /etc/hosts'

# Alias to open the Nginx configuration file in the default text editor
alias ngconf='${=EDITOR} /etc/nginx/nginx.conf'

# Alias to open the SSH configuration file in the default text editor
alias sshconf='${=EDITOR} $HOME/.ssh/config'

# Alias to open the Zsh configuration file in the default text editor
alias zshrc='${=EDITOR} $HOME/.zshrc'

# Alias to open the Zsh profile in the default text editor
alias zshp='${=EDITOR} $HOME/.zsh_profile'
