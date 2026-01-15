#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: configuration.aliases.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script containing aliases to open configuration files in default
# editor
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Set default text editor
EDITOR="${EDITOR:-vi}"

# Apache aliases
# ------------------------------------------------------------------------------

# Open Apache configuration file in default text editor
alias edit_apache_config='${EDITOR} /etc/apache2/apache2.conf'

# Bash aliases
# ------------------------------------------------------------------------------

# Open Bash configuration file in default text editor
alias edit_bashrc='${EDITOR} $HOME/.bashrc'

# Open Bash profile in default text editor
alias edit_bash_profile='${EDITOR} $HOME/.bash_profile'

# Docker aliases
# ------------------------------------------------------------------------------

# Open Docker Compose file in default text editor
alias edit_docker_compose='${EDITOR} docker-compose.yml'

# General aliases
# ------------------------------------------------------------------------------

# Open current directory in default text editor
alias edit_current_directory='${EDITOR} .'

# Git aliases
# ------------------------------------------------------------------------------

# Open Git configuration file in default text editor
alias edit_git_config='${EDITOR} $HOME/.gitconfig'

# Open Git ignore file in default text editor
alias edit_git_ignore='${EDITOR} $HOME/.gitignore'

# System config aliases
# ------------------------------------------------------------------------------

# Open hosts file in default text editor
alias edit_hosts='${EDITOR} /etc/hosts'

# Open Nginx configuration file in default text editor
alias edit_nginx_config='${EDITOR} /etc/nginx/nginx.conf'

# Open SSH configuration file in default text editor
alias edit_ssh_config='${EDITOR} $HOME/.ssh/config'

# Open Zsh configuration file in default text editor
alias edit_zshrc='${EDITOR} $HOME/.zshrc'

# Open Zsh profile in default text editor
alias edit_zsh_profile='${EDITOR} $HOME/.zsh_profile'
