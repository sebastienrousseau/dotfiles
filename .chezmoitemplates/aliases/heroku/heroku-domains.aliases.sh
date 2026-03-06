# shellcheck shell=bash
# Heroku Domains & Drains & Dyno aliases
[[ -n "${_HEROKU_DOMAINS_LOADED:-}" ]] && return 0
_HEROKU_DOMAINS_LOADED=1

# Domains aliases
# hkdo: List domains for an app.
alias hkdo='heroku domains'

# hkdoa: Add a domain to an app.
alias hkdoa='heroku domains:add'

# hkdoc: Remove all domains from an app.
alias hkdoc='heroku domains:clear'

# hkdoi: Show detailed information for a domain on an app.
alias hkdoi='heroku domains:info'

# hkdor: Remove a domain from an app.
alias hkdor='heroku domains:remove'

# hkdou: Update a domain to use a different SSL certificate on an app.
alias hkdou='heroku domains:update'

# hkdow: Wait for domain to be active for an app.
alias hkdow='heroku domains:wait'

# Drains aliases
# hkdr: Display the log drains of an app.
alias hkdr='heroku drains'

# hkdra: Adds a log drain to an app.
alias hkdra='heroku drains:add'

# hkdrr: Removes a log drain from an app.
alias hkdrr='heroku drains:remove'

# Dyno aliases
# hkdyk: Stop app dyno.
alias hkdyk='heroku dyno:kill'

# hkdyrz: Manage dyno sizes.
alias hkdyrz='heroku dyno:resize'

# hkdyrs: Restart app dynos.
alias hkdyrs='heroku dyno:restart'

# hkdysc: Scale dyno quantity up or down.
alias hkdysc='heroku dyno:scale'

# hkdyst: Stop app dyno.
alias hkdyst='heroku dyno:stop'
