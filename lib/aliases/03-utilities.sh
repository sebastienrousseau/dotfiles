#!/usr/bin/env bash

################################################################################
# Group 3: Utilities Aliases
# System administration and file operations
#
# Includes:
#   - Archive handling (tar, zip, extract)
#   - Disk space utilities
#   - Permission aliases
#   - Process listing
#   - Terminal multiplexer (tmux)
#   - DNS utilities (dig)
#   - Download utilities (wget)
#
# Load Priority: MEDIUM (frequently used but not daily for all)
# Expected Time: ~30-50ms
################################################################################

# Source all utility alias files
for alias_file in \
    archives/archives.aliases.sh \
    disk-usage/disk-usage.aliases.sh \
    permission/permission.aliases.sh \
    ps/ps.aliases.sh \
    tmux/tmux.aliases.sh \
    dig/dig.aliases.sh \
    wget/wget.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
