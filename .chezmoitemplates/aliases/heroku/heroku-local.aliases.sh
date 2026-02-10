# shellcheck shell=bash
# Heroku Local & Maintenance & Members aliases
[[ -n "${_HEROKU_LOCAL_LOADED:-}" ]] && return 0
_HEROKU_LOCAL_LOADED=1

# Local aliases
# hkloc: Run heroku app locally.
alias hkloc='heroku local'

# hklocr: Run a one-off command.
alias hklocr='heroku local:run'

# hklocv: Display node-foreman version.
alias hklocv='heroku local:version'

# hkloclk: Prevent team members from joining an app.
alias hkloclk='heroku lock'

# Maintenance aliases
# hkmt: Display the current maintenance status of app.
alias hkmt='heroku maintenance'

# hkmtoff: Take the app out of maintenance mode.
alias hkmtoff='heroku maintenance:off'

# hkmton: Put the app into maintenance mode.
alias hkmton='heroku maintenance:on'

# Members aliases
# hkmb: List members of a team.
alias hkmb='heroku members'

# hkmba: Adds a user to a team.
alias hkmba='heroku members:add'

# hkmbr: Removes a user from a team.
alias hkmbr='heroku members:remove'

# hkmbs: Sets a members role in a team.
alias hkmbs='heroku members:set'
