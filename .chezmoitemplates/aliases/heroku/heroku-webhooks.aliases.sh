# shellcheck shell=bash
# Heroku Webhooks aliases
[[ -n "${_HEROKU_WEBHOOKS_LOADED:-}" ]] && return 0
_HEROKU_WEBHOOKS_LOADED=1

# hkwh: List webhooks on an app.
alias hkwh='heroku webhooks'

# hkwha: Add a webhook to an app.
alias hkwha='heroku webhooks:add'

# hkwhdv: List webhook deliveries on an app.
alias hkwhdv='heroku webhooks:deliveries'

# hkwhdvi: Info for a webhook event on an app.
alias hkwhdvi='heroku webhooks:deliveries:info'

# hkwhev: List webhook events on an app.
alias hkwhev='heroku webhooks:events'

# hkwhevi: Info for a webhook event on an app.
alias hkwhevi='heroku webhooks:events:info'

# hkwhi: Info for a webhook on an app.
alias hkwhi='heroku webhooks:info'

# hkwhr: Removes a webhook from an app.
alias hkwhr='heroku webhooks:remove'

# hkwhu: Updates a webhook in an app.
alias hkwhu='heroku webhooks:update'
