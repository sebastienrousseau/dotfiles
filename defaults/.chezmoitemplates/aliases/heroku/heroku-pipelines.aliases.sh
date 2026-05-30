# shellcheck shell=bash
# Heroku Pipelines aliases
[[ -n "${_HEROKU_PIPELINES_LOADED:-}" ]] && return 0
_HEROKU_PIPELINES_LOADED=1

# List pipelines you have access to.
alias hkpipe='heroku pipelines'

# Add this app to a pipeline.
alias hkpipea='heroku pipelines:add'

# Create a new pipeline.
alias hkpipec='heroku pipelines:create'

# Connect a github repo to an existing pipeline.
alias hkpipect='heroku pipelines:connect'

# Compares the latest release of this app to its downstream app(s).
alias hkpipediff='heroku pipelines:diff'

# Show list of apps in a pipeline.
alias hkpipei='heroku pipelines:info'

# Destroy a pipeline.
alias hkpipek='heroku pipelines:destroy'

# Open a pipeline in dashboard.
alias hkpipeo='heroku pipelines:open'

# Promote the latest release of this app to its downstream app(s).
alias hkpipep='heroku pipelines:promote'

# Remove this app from its pipeline.
alias hkpiper='heroku pipelines:remove'

# Rename a pipeline.
alias hkpipern='heroku pipelines:rename'

# Bootstrap a new pipeline with common settings.
alias hkpipes='heroku pipelines:setup'

# Transfer ownership of a pipeline.
alias hkpipett='heroku pipelines:transfer'

# Update the app's stage in a pipeline.
alias hkpipeu='heroku pipelines:update'

# Plugins aliases
# hkplugs: List installed plugins.
alias hkplugs='heroku plugins'

# hkplugsi: Installs a plugin into the CLI.
alias hkplugsi='heroku plugins:install'

# hkplugslk: Links a plugin into the CLI for development.
alias hkplugslk='heroku plugins:link'

# hkplugsui: Removes a plugin from the CLI.
alias hkplugsui='heroku plugins:uninstall'

# hkplugsu: Update installed plugins.
alias hkplugsu='heroku plugins:update'
