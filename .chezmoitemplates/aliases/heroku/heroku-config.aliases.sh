# shellcheck shell=bash
# Heroku Config & Clients aliases
[[ -n "${_HEROKU_CONFIG_LOADED:-}" ]] && return 0
_HEROKU_CONFIG_LOADED=1

# Clients aliases
# hkclc: Create a new OAuth client.
alias hkclc='heroku clients:create'

# hkcli: Show details of an oauth client.
alias hkcli='heroku clients:info'

# hkclk: Delete client by ID.
alias hkclk='heroku clients:destroy'

# hkcll: List your OAuth clients.
alias hkcll='heroku clients'

# hkcls: Rotate OAuth client secret.
alias hkcls='heroku clients:rotate'

# hkclu: Update OAuth client.
alias hkclu='heroku clients:update'

# Configuration aliases
# hkcfe: Interactively edit config vars.
alias hkcfe='heroku config:edit'

# hkcfg: Display a single config value for an app.
alias hkcfg='heroku config:get'

# hkcfs: Set one or more config vars.
alias hkcfs='heroku config:set'

# hkcfu: Unset one or more config vars.
alias hkcfu='heroku config:unset'

# hkcfv: Display the config vars for an app.
alias hkcfv='heroku config'
