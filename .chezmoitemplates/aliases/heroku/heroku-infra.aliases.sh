# shellcheck shell=bash
# Heroku Infrastructure aliases (Features, Git, Keys, Labs)
[[ -n "${_HEROKU_INFRA_LOADED:-}" ]] && return 0
_HEROKU_INFRA_LOADED=1

# Features aliases
# hkfeat: List available app features.
alias hkfeat='heroku features'

# hkfeatd: Disables an app feature.
alias hkfeatd='heroku features:disable'

# hkfeate: Enables an app feature.
alias hkfeate='heroku features:enable'

# hkfeati: Display information about a feature.
alias hkfeati='heroku features:info'

# Git aliases
# Clones a heroku app to your local machine at DIRECTORY (defaults to app name).
alias hkgitc='heroku git:clone'

# Adds a git remote to an app repo.
alias hkgitr='heroku git:remote'

# Keys aliases
# Display your SSH keys.
alias hkk='heroku keys'

# Add an SSH key for a user.
alias hkka='heroku keys:add'

# Remove all SSH keys for current user.
alias hkkcl='heroku keys:clear'

# Remove an SSH key from the user.
alias hkkr='heroku keys:remove'

# Labs aliases
# hklab: List experimental features.
alias hklab='heroku labs'

# hklabd: Disables an experimental feature.
alias hklabd='heroku labs:disable'

# hklabe: Enables an experimental feature.
alias hklabe='heroku labs:enable'

# hklabi: Show feature info.
alias hklabi='heroku labs:info'
