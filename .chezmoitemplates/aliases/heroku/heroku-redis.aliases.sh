# shellcheck shell=bash
# Heroku Redis & Releases aliases
[[ -n "${_HEROKU_REDIS_LOADED:-}" ]] && return 0
_HEROKU_REDIS_LOADED=1

# Redis aliases
# hkred: Gets information about redis.
alias hkred='heroku redis'

# hkredcli: Opens a redis prompt.
alias hkredcli='heroku redis:cli'

# hkredcr: Display credentials information.
alias hkredcr='heroku redis:credentials'

# hkredi: Gets information about redis.
alias hkredi='heroku redis:info'

# hkredkn: Set the keyspace notifications configuration.
alias hkredkn='heroku redis:keyspace-notifications'

# hkredmm: Set the key eviction policy.
alias hkredmm='heroku redis:maxmemory'

# hkredmt: Manage maintenance windows.
alias hkredmt='heroku redis:maintenance'

# hkredp: Sets DATABASE as your REDIS_URL.
alias hkredp='heroku redis:promote'

# hkredsr: Reset all stats covered by RESETSTAT.
alias hkredsr='heroku redis:stats-reset'

# hkredt: Set the number of seconds to wait before killing idle connections.
alias hkredt='heroku redis:timeout'

# hkredw: Wait for Redis instance to be available.
alias hkredw='heroku redis:wait'

# Releases aliases
# hkrel: Display the releases for an app.
alias hkrel='heroku releases'

# hkreli: View detailed information for a release.
alias hkreli='heroku releases:info'

# hkrelo: View the release command output.
alias hkrelo='heroku releases:output'

# hkrelr: Rollback to a previous release.
alias hkrelr='heroku releases:rollback'

# Review Apps aliases
# hkrvae: Enable review apps and/or settings on an existing pipeline.
alias hkrvae='heroku reviewapps:enable'

# hkrvad: Disable review apps and/or settings on an existing pipeline.
alias hkrvad='heroku reviewapps:disable'

# Run aliases
# hkrun: Run a one-off process inside a heroku dyno.
alias hkrun='heroku run'

# hkrund: Run a detached dyno, where output is sent to your logs.
alias hkrund='heroku run:detached'

# Sessions aliases
# hksessions: List your OAuth sessions.
alias hksessions='heroku sessions'

# hksessionsd: Delete (logout) OAuth session by ID.
alias hksessionsd='heroku sessions:destroy'
