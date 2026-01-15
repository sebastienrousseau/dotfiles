#!/usr/bin/env bash

################################################################################
# Group 5: Cloud & Deployment Aliases
# Cloud platforms and deployment tools
#
# Includes:
#   - Heroku platform (1053 lines, rarely used daily)
#   - Google Cloud (335 lines, project specific)
#
# Load Priority: LOW (project/environment specific, candidates for lazy loading)
# Expected Time: ~100-150ms
# Recommendation: Lazy-load this group for faster startup
#
# To use: Just type any heroku or gcloud command and it will auto-load
################################################################################

# Source all cloud alias files
for alias_file in \
    heroku/heroku.aliases.sh \
    gcloud/gcloud.aliases.sh; do
    
    if [[ -f "${DOTFILES}/aliases/$alias_file" ]]; then
        source "${DOTFILES}/aliases/$alias_file" 2>/dev/null || true
    fi
done
