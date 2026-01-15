#!/usr/bin/env bash

################################################################################
# Group 2: Productivity Aliases
# Development workflow and version control tools
#
# Includes:
#   - Git commands (544 lines)
#   - Configuration management
#   - Editor shortcuts
#   - Build system (make)
#   - Find variations
#   - File sync (rsync)
#
# Load Priority: HIGH (most developers use these daily)
# Expected Time: ~50-100ms
################################################################################

# Source all productivity alias files
for alias_file in \
    git/git.aliases.sh \
    configuration/configuration.aliases.sh \
    editor/editor.aliases.sh \
    make/make.aliases.sh \
    find/find.aliases.sh \
    rsync/rsync.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
