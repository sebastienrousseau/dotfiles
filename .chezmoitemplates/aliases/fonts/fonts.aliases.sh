#!/usr/bin/env bash
# Font Management Aliases

# Update font cache
alias update-fonts='if command -v fc-cache >/dev/null; then fc-cache -fv; else echo "fc-cache not found (is fontconfig installed?)"; fi'

# List installed fonts (if fc-list available)
alias list-fonts='fc-list : family | sort | uniq'
