# shellcheck shell=bash
# Heroku Container aliases
[[ -n "${_HEROKU_CONTAINER_LOADED:-}" ]] && return 0
_HEROKU_CONTAINER_LOADED=1

# hkct: Use containers to build and deploy Heroku apps.
alias hkct='heroku container'

# hkctin: Log in to Heroku Container Registry.
alias hkctin='heroku container:login'

# hkctout: Log out from Heroku Container Registry.
alias hkctout='heroku container:logout'

# hkctpull: Pulls an image from an app's process type.
alias hkctpull='heroku container:pull'

# hkctpush: Builds, then pushes Docker images to deploy your Heroku app.
alias hkctpush='heroku container:push'

# hkctrelease: Releases previously pushed Docker images to your Heroku app.
alias hkctrelease='heroku container:release'

# hkctrm: Remove the process type from your app.
alias hkctrm='heroku container:rm'

# hkctrun: Builds, then runs the docker image locally.
alias hkctrun='heroku container:run'
