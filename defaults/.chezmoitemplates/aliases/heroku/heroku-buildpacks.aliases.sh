# shellcheck shell=bash
# Heroku Buildpacks aliases
[[ -n "${_HEROKU_BUILDPACKS_LOADED:-}" ]] && return 0
_HEROKU_BUILDPACKS_LOADED=1

# hkbpac: Display autocomplete installation instructions.
alias hkbpac='heroku autocomplete'

# hkbpad: Add new app build-pack, inserting into list of build-packs if necessary.
alias hkbpad='heroku buildpacks:add'

# hkbpcl: Clear all build-packs set on the app.
alias hkbpcl='heroku buildpacks:clear'

# hkbpi: Fetch info about a build-pack.
alias hkbpi='heroku buildpacks:info'

# hkbpl: Display the build-packs for an app.
alias hkbpl='heroku buildpacks'

# hkbpr: Remove a build-pack set on the app.
alias hkbpr='heroku buildpacks:remove'

# hkbps: Search for build-packs.
alias hkbps='heroku buildpacks:search'

# hkbpv: List versions of a build-pack.
alias hkbpv='heroku buildpacks:versions'
