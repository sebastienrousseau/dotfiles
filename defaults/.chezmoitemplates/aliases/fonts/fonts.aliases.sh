# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Font Management Aliases

# List installed fonts (if fc-list available)
alias list-fonts='fc-list : family | sort | uniq'
