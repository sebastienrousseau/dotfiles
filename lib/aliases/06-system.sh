#!/usr/bin/env bash

################################################################################
# Group 6: System & Platform-Specific Aliases
# System administration, security, and platform-specific tools
#
# Includes:
#   - sudo aliases
#   - System updates
#   - UUID generation
#   - Interactive commands
#   - GNU tool wrappers
#   - Subversion (SVN) commands
#   - macOS specific aliases
#   - Security command aliases (744 lines)
#
# Load Priority: LOW-MEDIUM (system/platform dependent)
# Expected Time: ~40-80ms
################################################################################

# Source all system alias files
for alias_file in \
    sudo/sudo.aliases.sh \
    update/update.aliases.sh \
    uuid/uuid.aliases.sh \
    interactive/interactive.aliases.sh \
    gnu/gnu.aliases.sh \
    subversion/subversion.aliases.sh \
    macOS/macOS.aliases.sh \
    security/security.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
