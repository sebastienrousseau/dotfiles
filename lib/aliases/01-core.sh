#!/usr/bin/env bash

################################################################################
# Group 1: Core Aliases
# Essential aliases for navigation, file management, and basic commands
#
# Includes:
#   - Directory navigation (cd)
#   - File/directory management (mkdir, chmod, clear)
#   - Listing variations
#
# Load Priority: HIGH (always loaded)
# Expected Time: ~10-20ms
################################################################################

# Source all core alias files
for alias_file in \
    cd/cd.aliases.sh \
    chmod/chmod.aliases.sh \
    mkdir/mkdir.aliases.sh \
    clear/clear.aliases.sh \
    list/list.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
