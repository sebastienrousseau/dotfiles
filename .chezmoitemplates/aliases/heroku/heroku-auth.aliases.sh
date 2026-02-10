# shellcheck shell=bash
# Heroku Auth & Authorizations aliases
[[ -n "${_HEROKU_AUTH_LOADED:-}" ]] && return 0
_HEROKU_AUTH_LOADED=1

# Auth 2fa aliases
# hk2fa: Display the current logged in user.
alias hk2fa='heroku auth:whoami'

# hk2fad: Disables 2fa on account.
alias hk2fad='heroku auth:2fa:disable'

# hk2fain: Login with your Heroku credentials.
alias hk2fain='heroku auth:login'

# hk2faout: Clears local login credentials and invalidates API session
alias hk2faout='heroku auth:logout'

# hk2fas: Check 2fa status.
alias hk2fas='heroku auth:2fa'

# hk2fat: Outputs current CLI authentication token.
alias hk2fat='heroku auth:token'

# Authorizations aliases
# hkauc: Create a new OAuth authorization.
alias hkauc='heroku authorizations:create'

# hkaui: Show an existing OAuth authorization.
alias hkaui='heroku authorizations:info'

# hkaul: List OAuth authorizations.
alias hkaul='heroku authorizations'

# hkaur: Revoke OAuth authorization.
alias hkaur='heroku authorizations:revoke'

# hkauro: Updates an OAuth authorization token.
alias hkauro='heroku authorizations:rotate'

# hkauu: Updates an OAuth authorization.
alias hkauu='heroku authorizations:update'
