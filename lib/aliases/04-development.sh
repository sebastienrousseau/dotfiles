#!/usr/bin/env bash

################################################################################
# Group 4: Development Aliases
# Language and framework specific tools
#
# Includes:
#   - Python commands
#   - npm/Node.js
#   - pnpm package manager
#   - Rust/cargo
#   - Docker commands
#
# Load Priority: MEDIUM (project specific)
# Expected Time: ~20-30ms
# Note: Can be lazy-loaded for faster startup if not needed
################################################################################

# Source all development alias files
for alias_file in \
    python/python.aliases.sh \
    npm/npm.aliases.sh \
    pnpm/pnpm.aliases.sh \
    rust/rust.aliases.sh \
    docker/docker.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
