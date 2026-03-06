# shellcheck shell=bash
# Heroku Aliases - Main loader
# Loads all Heroku submodules when heroku CLI is available

if command -v heroku &>/dev/null; then
  # Source guard for main loader
  [[ -n "${_HEROKU_ALIASES_LOADED:-}" ]] && return 0
  _HEROKU_ALIASES_LOADED=1

  # Get the directory containing this script
  _HEROKU_ALIASES_DIR="${BASH_SOURCE[0]%/*}"

  # Core aliases
  # hk: Heroku CLI command shortcut.
  alias hkk='heroku'

  # hka: Add new users to your app.
  alias hka='heroku access:add'

  # hkau: Update existing collaborators on an team app.
  alias hkau='heroku access:update'

  # hkh: Display help for heroku.
  alias hkh='heroku help'

  # hkj: Add yourself to a team app.
  alias hkj='heroku join'

  # hkl: List all the commands.
  alias hkl='heroku commands'

  # hkla: List who has access to an app.
  alias hkla='heroku access'

  # hklg: Display recent log output.
  alias hklg='heroku logs'

  # hkn: Display notifications.
  alias hkn='heroku notifications'

  # hko: List the teams that you are a member of.
  alias hko='heroku orgs'

  # hkoo: Open the team interface in a browser.
  alias hkoo='heroku orgs:open'

  # hkp: Open a psql shell to the database.
  alias hkp='heroku psql'

  # hkq: Remove yourself from a team app.
  alias hkq='heroku leave'

  # hkr: Remove users from a team app.
  alias hkr='heroku access:remove'

  # hkrg: List available regions for deployment.
  alias hkrg='heroku regions'

  # hks: Display current status of the Heroku platform.
  alias hks='heroku status'

  # hkt: List the teams that you are a member of.
  alias hkt='heroku teams'

  # hku: Update the heroku CLI.
  alias hku='heroku update'

  # hkulk: Unlock an app so any team member can join.
  alias hkulk='heroku unlock'

  # hkw: Show which plugin a command is in.
  alias hkw='heroku which'

  # Load all submodules
  for _module in \
    heroku-addons \
    heroku-apps \
    heroku-auth \
    heroku-buildpacks \
    heroku-certs \
    heroku-ci \
    heroku-config \
    heroku-container \
    heroku-domains \
    heroku-infra \
    heroku-local \
    heroku-postgres \
    heroku-pipelines \
    heroku-ps \
    heroku-redis \
    heroku-spaces \
    heroku-webhooks; do
    # shellcheck source=/dev/null
    [[ -f "${_HEROKU_ALIASES_DIR}/${_module}.aliases.sh" ]] && source "${_HEROKU_ALIASES_DIR}/${_module}.aliases.sh"
  done

  unset _module _HEROKU_ALIASES_DIR
fi
