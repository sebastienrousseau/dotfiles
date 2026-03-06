# shellcheck shell=bash
# Heroku CI aliases
[[ -n "${_HEROKU_CI_LOADED:-}" ]] && return 0
_HEROKU_CI_LOADED=1

# hkcicg: Get a CI config var.
alias hkcicg='heroku ci:config:get'

# hkcics: Set CI config vars.
alias hkcics='heroku ci:config:set'

# hkcicu: Unset CI config vars.
alias hkcicu='heroku ci:config:unset'

# hkcicv: Display CI config vars.
alias hkcicv='heroku ci:config'

# hkcid: Opens an interactive test debugging session with the contents of the current directory.
alias hkcid='heroku ci:debug'

# hkcie: Looks for the most recent run and returns the output of that run.
alias hkcie='heroku ci:last'

# hkcii: Show the status of a specific test run.
alias hkcii='heroku ci:info'

# hkcil: Display the most recent CI runs for the given pipeline.
alias hkcil='heroku ci'

# hkcim: 'app-ci.json' is deprecated. Run this command to migrate to app.json with an environments key.
alias hkcim='heroku ci:migrate-manifest'

# hkcio: Open the Dashboard version of Heroku CI.
alias hkcio='heroku ci:open'

# hkcir: Run tests against current directory.
alias hkcir='heroku ci:run'

# hkcir2: Rerun tests against current directory.
alias hkcir2='heroku ci:rerun'
