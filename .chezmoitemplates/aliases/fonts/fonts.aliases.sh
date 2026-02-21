#!/usr/bin/env bash
# Font Management Aliases

# List installed fonts (if fc-list available)
alias list-fonts='fc-list : family | sort | uniq'
