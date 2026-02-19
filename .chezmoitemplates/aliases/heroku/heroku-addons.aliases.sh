# shellcheck shell=bash
# Heroku Add-ons aliases
[[ -n "${_HEROKU_ADDONS_LOADED:-}" ]] && return 0
_HEROKU_ADDONS_LOADED=1

# Attach an existing add-on resource to an app.
alias hkada='heroku addons:attach'

# Create a new add-on resource.
alias hkadc='heroku addons:create'

# Detach an existing add-on resource from an app.
alias hkadd='heroku addons:detach'

# Open an add-on's Dev Center documentation in your browser.
alias hkaddoc='heroku addons:docs'

# Change add-on plan.
alias hkaddown='heroku addons:downgrade'

# Show detailed add-on resource and attachment information.
alias hkadi='heroku addons:info'

# Permanently destroy an add-on resource.
alias hkadk='heroku addons:destroy'

# Lists your add-ons and attachments.
alias hkadl='heroku addons'

# Open an add-on's dashboard in your browser.
alias hkado='heroku addons:open'

# List all available plans for an add-on services.
alias hkadp='heroku addons:plans'

# Rename an add-on.
alias hkadr='heroku addons:rename'

# List all available add-on services.
alias hkads='heroku addons:services'

# Change add-on plan.
alias hkadu='heroku addons:upgrade '

# Show provisioning status of the add-ons on the app.
alias hkadw='heroku addons:wait'
