#!/bin/zsh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#
# Description:  Mac OS X Dotfiles - Simply designed to fit your shell life.
#
# Sections:
#
#   1. Heroku aliases.
#      1.1 Heroku Access aliases.
#      1.2 Heroku Addons aliases.
#      1.3 Heroku Apps aliases.
#      1.4 Heroku Auth aliases.
#      1.5 Heroku Authorizations aliases.
#      1.6 Heroku Authorizations aliases.
#      1.7 Heroku Certs aliases.
#      1.8 Heroku ci aliases.
#      1.9 Heroku config aliases.
#
#   2. Heroku Container aliases.
#      2.1 Heroku Domains aliases.
#      2.2 Heroku Drains aliases.
#      2.3 Heroku Dyno aliases.
#      2.4 Heroku Features aliases.
#      2.5 Heroku Git aliases.
#      2.6 Heroku Keys aliases.
#      2.7 Heroku Maintenance aliases.
#      2.8 Heroku Members aliases.
#      2.9 Heroku pg aliases.
#
#   3. Heroku Pipelines aliases.
#      3.1 Heroku ps aliases.
#      3.2 Heroku redis aliases.
#      3.3 Heroku Spaces aliases.
#      3.4 Heroku Webhooks aliases.
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#



##  ----------------------------------------------------------------------------
##  1. Heroku Core aliases
##  ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  1.1 Heroku Access aliases.
##  ----------------------------------------------------------------------------


# h: Heroku CLI command shortcut.
alias h='heroku'

# ha: Add new users to your app.
alias ha='heroku access:add'

# hau: Update existing collaborators on an team app.
alias hau='heroku access:update'

# hh: Display help for heroku.
alias hh='heroku help'

# hip: List trusted IP ranges for a space.
alias hip='heroku trusted-ips --space "$@"'

# hipa: Add one range to the list of trusted IP ranges.
alias hipa='heroku trusted-ips:add --space "$@"'

# hipr: Remove a range from the list of trusted IP ranges.
alias hipr='heroku trusted-ips:remove --space "$@"'

# hj: Add yourself to a team app.
alias hj='heroku join'

# hl: List all the commands.
alias hl='heroku commands'

# hla: List who has access to an app.
alias hla='heroku access'

# hlg: Display recent log output.
alias hlg='heroku logs'

# hn: Display notifications.
alias hn='heroku notifications'

# ho: List the teams that you are a member of.
alias ho='heroku orgs'

# hoo: Open the team interface in a browser.
alias hoo='heroku orgs:open'

# hp: Open a psql shell to the database.
alias hp='heroku psql'      

# hq: Remove yourself from a team app.
alias hq='heroku leave'

# hr: Remove users from a team app.
alias hr='heroku access:remove'

# hrg: List available regions for deployment.
alias hrg='heroku regions'

# hs: Display current status of the Heroku platform.
alias hs='heroku status'

# ht: List the teams that you are a member of.
alias ht='heroku teams'

# hu: Update the heroku CLI. 
alias hu='heroku update' 

# hulk: Unlock an app so any team member can join.
alias hulk='heroku unlock'

# hw: Show which plugin a command is in.
alias hw='heroku which'


##  ----------------------------------------------------------------------------
##  1.2 Heroku Add-ons aliases
##  ----------------------------------------------------------------------------


# Attach an existing add-on resource to an app.
alias hada='heroku addons:attach'

# Create a new add-on resource.
alias hadc='heroku addons:create'

# Detach an existing add-on resource from an app.
alias hadd='heroku addons:detach'

# Open an add-on's Dev Center documentation in your browser.
alias haddoc='heroku addons:docs'

# Change add-on plan.
alias haddown='heroku addons:downgrade'

# Show detailed add-on resource and attachment information.
alias hadi='heroku addons:info'

# Permanently destroy an add-on resource.
alias hadk='heroku addons:destroy'

# Lists your add-ons and attachments.
alias hadl='heroku addons'

# Open an add-on's dashboard in your browser.
alias hado='heroku addons:open'

# List all available plans for an add-on services.
alias hadp='heroku addons:plans'

# Rename an add-on.
alias hadr='heroku addons:rename'

# List all available add-on services.
alias hads='heroku addons:services'

# Change add-on plan.
alias hadu='heroku addons:upgrade '

# Show provisioning status of the add-ons on the app.
alias hadw='heroku addons:wait'



##  ----------------------------------------------------------------------------
##  1.3 Heroku Apps aliases
##  ----------------------------------------------------------------------------


# hapc: Creates a new app.
alias hapc='heroku apps:create'

# hape: View app errors.
alias hape='heroku apps:errors'

# hapfav: List favorites apps.
alias hapfav='heroku apps:favorites'

# hapfava: Favorites an app.
alias hapfava='heroku apps:favorites:add'

# hapunfav: Unfavorite an app.
alias hapunfav='heroku apps:favorites:remove'

# hapi: Show detailed app information.
alias hapi='heroku apps:info'

# hapj: Add yourself to a team app.
alias hapj='heroku apps:join'

# hapk: Permanently destroy an app.
alias hapk='heroku apps:destroy'

# hapl: List your apps.
alias hapl='heroku apps'

# haplk: Prevent team members from joining an app.
alias haplk='heroku apps:lock'

# hapo: Open the app in a web browser.
alias hapo='heroku apps:open'

# hapq: Remove yourself from a team app.
alias hapq='heroku apps:leave'

# hapr: Rename an app.
alias hapr='heroku apps:rename'

# haps: Show the list of available stacks.
alias haps='heroku apps:stacks'

# hapss: Set the stack of an app.
alias hapss='heroku apps:stacks:set'

# hapt: Transfer applications to another user or team.
alias hapt='heroku apps:transfer'

# hapulk: Unlock an app so any team member can join.
alias hapulk='heroku apps:unlock'


##  ----------------------------------------------------------------------------
##  1.4 Heroku Auth 2fa aliases
##  ----------------------------------------------------------------------------

# h2fa: Display the current logged in user.
alias h2fa='heroku auth:whoami'

# h2fad: Disables 2fa on account.
alias h2fad='heroku auth:2fa:disable'

# h2fain: Login with your Heroku credentials.
alias h2fain='heroku auth:login'

# h2faout: Clears local login credentials and invalidates API session.
alias h2faout='heroku auth:logout'

# h2fas: Check 2fa status.
alias h2fas='heroku auth:2fa'

# h2fat: Outputs current CLI authentication token.
alias h2fat='heroku auth:token'


##  ----------------------------------------------------------------------------
##  1.5 Heroku Authorizations aliases
##  ----------------------------------------------------------------------------

# hauc: Create a new OAuth authorization.
alias hauc='heroku authorizations:create'

# haui: Show an existing OAuth authorization.
alias haui='heroku authorizations:info' 

# haul: List OAuth authorizations. |
alias haul='heroku authorizations'

# haur: Revoke OAuth authorization. |
alias haur='heroku authorizations:revoke'

# hauro: Updates an OAuth authorization token. |
alias hauro='heroku authorizations:rotate'

# hauu: Updates an OAuth authorization.
alias hauu='heroku authorizations:update'


##  ----------------------------------------------------------------------------
##  1.6 Heroku Build packs aliases
##  ----------------------------------------------------------------------------

# hbpac: Display autocomplete installation instructions.
alias hbpac='heroku autocomplete'

# hbpad: Add new app build-pack, inserting into list of build-packs if necessary.
alias hbpad='heroku buildpacks:add'

# hbpcl: Clear all build-packs set on the app.
alias hbpcl='heroku buildpacks:clear'

# hbpi: Fetch info about a build-pack.
alias hbpi='heroku buildpacks:info'

# hbpl: Display the build-packs for an app.
alias hbpl='heroku buildpacks'

# hbpr: Remove a build-pack set on the app.
alias hbpr='heroku buildpacks:remove'

# hbps: Search for build-packs.
alias hbps='heroku buildpacks:search'

# hbpv: List versions of a build-pack. |
alias hbpv='heroku buildpacks:versions'


##  ----------------------------------------------------------------------------
##  1.7 Heroku Certs aliases
##  ----------------------------------------------------------------------------

# hca: Show ACM status for an app.
alias hca='heroku certs:auto'

# hcad: Add an SSL certificate to an app.
alias hcad='heroku certs:add'

# hcae: Enable ACM status for an app.
alias hcae='heroku certs:auto:enable'

# hcak: Disable ACM for an app.
alias hcak='heroku certs:auto:disable'

# hcar: Refresh ACM for an app.
alias hcar='heroku certs:auto:refresh'

# hcc: Print an ordered & complete chain for a certificate.
alias hcc='heroku certs:chain'

# hcg: Generate a key and a CSR or self-signed certificate.
alias hcg='heroku certs:generate'

# hci: Show certificate information for an SSL certificate.
alias hci='heroku certs:info'

# hck: Print the correct key for the given certificate.
alias hck='heroku certs:key'

# hcl: List SSL certificates for an app.
alias hcl='heroku certs'

# hcr: Remove an SSL certificate from an app.
alias hcr='heroku certs:remove'

# hcu: Update an SSL certificate on an app.
alias hcu='heroku certs:update'


##  ----------------------------------------------------------------------------
##  1.8 Heroku ci aliases
##  ----------------------------------------------------------------------------

# hcicg: Get a CI config var.
alias hcicg='heroku ci:config:get'

# hcics: Set CI config vars.
alias hcics='heroku ci:config:set'

# hcicu: Unset CI config vars.
alias hcicu='heroku ci:config:unset'

# hcicv: Display CI config vars.
alias hcicv=' ci:config'

# hcid: Opens an interactive test debugging session with the contents of the current directory.
alias hcid='heroku ci:debug'

# hcie: Looks for the most recent run and returns the output of that run.
alias hcie='heroku ci:last'

# hcii: Show the status of a specific test run.
alias hcii='heroku ci:info'

# hcil: Display the most recent CI runs for the given pipeline.
alias hcil='heroku ci'

# hcim: 'app-ci.json' is deprecated. Run this command to migrate to app.json with an environments key.
alias hcim='heroku ci:migrate-manifest'

# hcio: Open the Dashboard version of Heroku CI.
alias hcio='heroku ci:open'

# hcir: Run tests against current directory.
alias hcir='heroku ci:run'

# hcir2: Rerun tests against current directory.
alias hcir2='heroku ci:rerun'


##  ----------------------------------------------------------------------------
##  1.9 Heroku config aliases
##  ----------------------------------------------------------------------------

# hclc: Create a new OAuth client.
alias hclc='heroku clients:create'

# hcli: Show details of an oauth client.
alias hcli='heroku clients:info'

# hclk: Delete client by ID.
alias hclk='heroku clients:destroy'

# hcll: List your OAuth clients.
alias hcll='heroku clients'

# hcls: Rotate OAuth client secret.
alias hcls='heroku clients:rotate'

# hclu: Update OAuth client. |
alias hclu='heroku clients:update'


##  ----------------------------------------------------------------------------
##  2. Heroku Configuration aliases
##  ----------------------------------------------------------------------------

# hcfe: Interactively edit config vars.
alias hcfe='heroku config:edit'

# hcfg: Display a single config value for an app.
alias hcfg='heroku config:get'

# hcfs: Set one or more config vars.
alias hcfs='heroku config:set'

# hcfu: Unset one or more config vars.
alias hcfu='heroku config:unset'

# hcfv: Display the config vars for an app.
alias hcfv='heroku config'


##  ----------------------------------------------------------------------------
##  2.1 Heroku Container aliases
##  ----------------------------------------------------------------------------

# hct: Use containers to build and deploy Heroku apps.
alias hct='heroku container'

# hctin: Log in to Heroku Container Registry.
alias hctin='heroku container:login'

# hctout: Log out from Heroku Container Registry.
alias hctout='heroku container:logout'

# hctpull: Pulls an image from an app's process type.
alias hctpull='heroku container:pull'

# hctpush: Builds, then pushes Docker images to deploy your Heroku app.
alias hctpush='heroku container:push'

# hctrelease: Releases previously pushed Docker images to your Heroku app.
alias hctrelease='heroku container:release'

# hctrm: Remove the process type from your app.
alias hctrm='heroku container:rm'

# hctrun: Builds, then runs the docker image locally.
alias hctrun='heroku container:run'


##  ----------------------------------------------------------------------------
##  2.2 Heroku Domains aliases
##  ----------------------------------------------------------------------------

# hdo: List domains for an app.
alias hdo='heroku domains'

# hdoa: Add a domain to an app.
alias hdoa='heroku domains:add'

# hdoc: Remove all domains from an app.
alias hdoc='heroku domains:clear'

# hdoi: Show detailed information for a domain on an app.
alias hdoi='heroku domains:info'

# hdor: Remove a domain from an app.
alias hdor='heroku domains:remove'

# hdou: Update a domain to use a different SSL certificate on an app.
alias hdou='heroku domains:update'

# hdow: Wait for domain to be active for an app.
alias hdow='heroku domains:wait'


##  ----------------------------------------------------------------------------
##  2.3 Heroku Drains aliases
##  ----------------------------------------------------------------------------

# hdr: Display the log drains of an app.
alias hdr='heroku drains'

# hdra: Adds a log drain to an app.
alias hdra='heroku drains:add'

# hdrr: Removes a log drain from an app.
alias hdrr='heroku drains:remove'


##  ----------------------------------------------------------------------------
##  2.4 Heroku Dyno aliases
##  ----------------------------------------------------------------------------

# hdyk: Stop app dyno.
alias hdyk='heroku dyno:kill'

# hdyrz: Manage dyno sizes.
alias hdyrz='heroku dyno:resize'

# hdyrs: Restart app dynos.
alias hdyrs='heroku dyno:restart'

# hdysc: Scale dyno quantity up or down.
alias hdysc='heroku dyno:scale'

# hdyst: Stop app dyno.
alias hdyst='heroku dyno:stop'


##  ----------------------------------------------------------------------------
##  2.5 Heroku Features aliases
##  ----------------------------------------------------------------------------

# hfeat: List available app features.
alias hfeat='heroku features'

# hfeatd: Disables an app feature.
alias hfeatd='heroku features:disable'

# hfeate: Enables an app feature.
alias hfeate='heroku features:enable'

# hfeati: Display information about a feature.
alias hfeati='heroku features:info'


##  ----------------------------------------------------------------------------
##  2.6 Heroku Git aliases
##  ----------------------------------------------------------------------------

# Clones a heroku app to your local machine at DIRECTORY (defaults to app name).
alias hgitc='heroku git:clone'

# Adds a git remote to an app repo.
alias hgitr='heroku git:remote'


##  ----------------------------------------------------------------------------
##  2.7 Heroku Keys aliases
##  ----------------------------------------------------------------------------

# Display your SSH keys.
alias hk='heroku keys'

# Add an SSH key for a user.
alias hka='heroku keys:add'

# Remove all SSH keys for current user.
alias hkcl='heroku keys:clear'

# Remove an SSH key from the user.
alias hkr='heroku keys:remove'

##  ----------------------------------------------------------------------------
##  2.8 Heroku Labs aliases
##  ----------------------------------------------------------------------------

# hlab: List experimental features.
alias hlab='heroku labs'

# hlabd: Disables an experimental feature.
alias hlabd='heroku labs:disable'

# hlabe: Enables an experimental feature.
alias hlabe='heroku labs:enable'

# hlabi: Show feature info.
alias hlabi='heroku labs:info'

##  ----------------------------------------------------------------------------
##  3. Heroku Advanced aliases
##  ----------------------------------------------------------------------------

##  ----------------------------------------------------------------------------
##  3.1 Heroku Local aliases
##  ----------------------------------------------------------------------------

# hloc: Run heroku app locally.
alias hloc='heroku local'

# hlocr: Run a one-off command.
alias hlocr='heroku local:run'

# hlocv: Display node-foreman version.
alias hlocv='heroku local:version'

# hloclk: Prevent team members from joining an app.
alias hloclk='heroku lock'


##  ----------------------------------------------------------------------------
##  3.2 Heroku Maintenance aliases
##  ----------------------------------------------------------------------------

# hmt: Display the current maintenance status of app.
alias hmt='heroku maintenance'

# hmtoff: Take the app out of maintenance mode.
alias hmtoff='heroku maintenance:off'

# hmton: Put the app into maintenance mode.
alias hmton='heroku maintenance:on'


##  ----------------------------------------------------------------------------
##  3.3 Heroku Members aliases
##  ----------------------------------------------------------------------------

# hmb: List members of a team.
alias hmb='heroku members'

# hmba: Adds a user to a team.
alias hmba='heroku members:add'

# hmbr: Removes a user from a team.
alias hmbr='heroku members:remove'

# hmbs: Sets a members role in a team. |
alias hmbs='heroku members:set'



##  ----------------------------------------------------------------------------
##  3.4 Heroku Postgres aliases
##  ----------------------------------------------------------------------------

# hpg: Show database information.
alias hpg='heroku pg'

# hpgb: Show table and index bloat in your database ordered by most wasteful.
alias hpgb='heroku pg:bloat'

# hpgbk: List database backups.
alias hpgbk='heroku pg:backups'

# hpgbkcl: Cancel an in-progress backup or restore (default newest).
alias hpgbkcl='heroku pg:backups:cancel'

# hpgbkc: Capture a new backup.
alias hpgbkc='heroku pg:backups:capture'

# hpgbkdl: Delete a backup.
alias hpgbkdl='heroku pg:backups:delete'

# hpgbkdw: Downloads database backup.
alias hpgbkdw='heroku pg:backups:download'

# hpgbki: Get information about a specific backup.
alias hpgbki='heroku pg:backups:info'

# hpgbkr: Restore a backup (default latest) to a database.
alias hpgbkr='heroku pg:backups:restore'

# hpgbks: Schedule daily backups for given database.
alias hpgbks='heroku pg:backups:schedule'

# hpgbksh: List backup schedule.
alias hpgbksh='heroku pg:backups:schedules'

# hpgbkurl: Get secret but publicly accessible URL of a backup.
alias hpgbkurl='heroku pg:backups:url'

# hpgbkk: Stop daily backups.
alias hpgbkk='heroku pg:backups:unschedule'

# hpgblk: Display queries holding locks other queries are waiting to be released.
alias hpgblk='heroku pg:blocking'

# hpgc: Copy all data from source db to target.
alias hpgc='heroku pg:copy'

# hpgcpa: Add an attachment to a database using connection pooling.
alias hpgcpa='heroku pg:connection-pooling:attach'

# hpgcr: Show information on credentials in the database.
alias hpgcr='heroku pg:credentials'

# hpgcrc: Create credential within database.
alias hpgcrc='heroku pg:credentials:create'

# hpgcrd: Destroy credential within database.
alias hpgcrd='heroku pg:credentials:destroy'

# hpgcrr: Rotate the database credentials.
alias hpgcrr='heroku pg:credentials:rotate'

# hpgcrrd: Repair the permissions of the default credential within database.
alias hpgcrrd='heroku pg:credentials:repair-default'

# hpgcrurl: Show information on a database credential.
alias hpgcrurl='heroku pg:credentials:url'

# hpgdg: Run or view diagnostics report.
alias hpgdg='heroku pg:diagnose'

# hpgi: Show database information.
alias hpgi='heroku pg:info'

# hpgk: Kill a query.
alias hpgk='heroku pg:kill'

# hpgka: Terminates all connections for all credentials.
alias hpgka='heroku pg:killall'

# hpglks: Display queries with active locks.
alias hpglks='heroku pg:locks'

# hpglnk: Lists all databases and information on link.
alias hpglnk='heroku pg:links'

# hpglnkc: Create a link between data stores.
alias hpglnkc='heroku pg:links:create'

# hpglnkd: Destroys a link between data stores.
alias hpglnkd='heroku pg:links:destroy'

# hpgmt: Show current maintenance information.
alias hpgmt='heroku pg:maintenance'

# hpgmtr: Start maintenance.
alias hpgmtr='heroku pg:maintenance:run'

# hpgmtw: Set weekly maintenance window.
alias hpgmtw='heroku pg:maintenance:window'

# hpgo: Show 10 queries that have longest execution time in aggregate.
alias hpgo='heroku pg:outliers'

# hpgp: Sets DATABASE as your DATABASE_URL.
alias hpgp='heroku pg:promote'

# hpgps: View active queries with execution time.
alias hpgps='heroku pg:ps'

# hpgpsql: Open a psql shell to the database.
alias hpgpsql='heroku pg:psql'

# hpgpull: Pull Heroku database into local or remote database.
alias hpgpull='heroku pg:pull'

# hpgpush: Push local or remote into Heroku database.
alias hpgpush='heroku pg:push'

# hpgreset: Delete all data in DATABASE.
alias hpgreset='heroku pg:reset'

# hpgreset: Show your current database settings.
alias hpgset='heroku pg:settings'

# hpgsetllw: Controls whether a log message is produced when a session waits longer than the deadlock_timeout to acquire a lock. deadlock_timeout is se... .
alias hpgsetllw='heroku pg:settings:log-lock-waits'

# hpgsetlmds: The duration of each completed statement will be logged if the statement completes after the time specified by VALUE.
alias hpgsetlmds='heroku pg:settings:log-min-duration-statement'

# hpgsetlgs: 'log_statement' controls which SQL statements are logged.
alias hpgsetlgs='heroku pg:settings:log-statement'

# hpguf: Stop a replica from following and make it a writeable database.
alias hpguf='heroku pg:unfollow'

# hpgup: Unfollow a database and upgrade it to the latest stable PostgreSQL version.
alias hpgup='heroku pg:upgrade'

# hpgvs: Show dead rows and whether an automatic vacuum is expected to be triggered.
alias hpgvs='heroku pg:vacuum-stats'

# hpgww: Blocks until database is available.
alias hpgww='heroku pg:wait'


##  ----------------------------------------------------------------------------
##  3.5 Heroku Pipelines aliases
##  ----------------------------------------------------------------------------

# List pipelines you have access to.
alias hpipe='heroku pipelines'

# Add this app to a pipeline.
alias hpipea='heroku pipelines:add'

# Create a new pipeline.
alias hpipec='heroku pipelines:create'

# Connect a github repo to an existing pipeline.
alias hpipect='heroku pipelines:connect'

# Compares the latest release of this app to its downstream app(s).
alias hpipediff='heroku pipelines:diff'

# Show list of apps in a pipeline.
alias hpipei='heroku pipelines:info'

# Destroy a pipeline.
alias hpipek='heroku pipelines:destroy'

# Open a pipeline in dashboard.
alias hpipeo='heroku pipelines:open'

# Promote the latest release of this app to its downstream app(s).
alias hpipep='heroku pipelines:promote'

# Remove this app from its pipeline.
alias hpiper='heroku pipelines:remove'

# Rename a pipeline.
alias hpipern='heroku pipelines:rename'

# Bootstrap a new pipeline with common settings and create a production and staging app (requires a fully formed app.json in the repo).
alias hpipes='heroku pipelines:setup'

# Transfer ownership of a pipeline.
alias hpipett='heroku pipelines:transfer'

# Update the app's stage in a pipeline.
alias hpipeu='heroku pipelines:update'
 

##  ----------------------------------------------------------------------------
##  3.6 Heroku Plugins aliases
##  ----------------------------------------------------------------------------

# hplugs: List installed plugins.
alias hplugs='heroku plugins'

# hplugsi: Installs a plugin into the CLI.
alias hplugsi='heroku plugins:install'

# hplugslk: Links a plugin into the CLI for development.
alias hplugslk='heroku plugins:link'

# hplugsui: Removes a plugin from the CLI.
alias hplugsui='heroku plugins:uninstall'

# hplugsu: Update installed plugins.
alias hplugsu='heroku plugins:update'


##  ----------------------------------------------------------------------------
##  3.7 Heroku 'ps' aliases
##  ----------------------------------------------------------------------------

# hpsad: Disable web dyno autoscaling.
alias hpsad='heroku ps:autoscale:disable'

# hps: List dynos for an app.
alias hps='heroku ps'

# hpsae: Enable web dyno autoscaling.
alias hpsae='heroku ps:autoscale:enable '

# hpsc: Copy a file from a dyno to the local filesystem.
alias hpsc='heroku ps:copy'

# hpse: Create an SSH session to a dyno.
alias hpse='heroku ps:exec'

# hpsf: Forward traffic on a local port to a dyno.
alias hpsf='heroku ps:forward'

# hpsk: Stop app dyno.
alias hpsk='heroku ps:kill'

# hpsr: Restart app dynos.
alias hpsr='heroku ps:restart'

# hpsrs: Manage dyno sizes.
alias hpsrs='heroku ps:resize'

# hpss: Stop app dyno.
alias hpss='heroku ps:stop'

# hpssc: Scale dyno quantity up or down.
alias hpssc='heroku ps:scale'

# hpssck: Launch a SOCKS proxy into a dyno.
alias hpssck='heroku ps:socks'

# hpst: Manage dyno sizes.
alias hpst='heroku ps:type'

# hpsw: Wait for all dynos to be running latest version after a release.
alias hpsw='heroku ps:wait'


##  ----------------------------------------------------------------------------
##  3.8 Heroku redis aliases
##  ----------------------------------------------------------------------------

# hred: Gets information about redis.
alias hred='heroku redis'

# hredcli: Opens a redis prompt.
alias hredcli='heroku redis:cli'

# hredcr: Display credentials information.
alias hredcr='heroku redis:credentials'

# hredi: Gets information about redis.
alias hredi='heroku redis:info'

# hredkn: Set the keyspace notifications configuration.
alias hredkn='heroku redis:keyspace-notifications'

# hredmm: Set the key eviction policy.
alias hredmm='heroku redis:maxmemory'

# hredmt: Manage maintenance windows.
alias hredmt='heroku redis:maintenance'

# hredp: Sets DATABASE as your REDIS_URL.
alias hredp='heroku redis:promote'

# hredsr: Reset all stats covered by RESETSTAT (<https://redis.io/commands/config-resetstat>).
alias hredsr='heroku redis:stats-reset'

# hredt: Set the number of seconds to wait before killing idle connections.
alias hredt='heroku redis:timeout'

# hredw: Wait for Redis instance to be available.
alias hredw='heroku redis:wait'


##  ----------------------------------------------------------------------------
##  3.9 Heroku Releases aliases
##  ----------------------------------------------------------------------------

# hrel: Display the releases for an app.
alias hrel='heroku releases'

# hreli: View detailed information for a release.
alias hreli='heroku releases:info'

# hrelo: View the release command output.
alias hrelo='heroku releases:output'

# hrelr: Rollback to a previous release.
alias hrelr='heroku releases:rollback'


##  ----------------------------------------------------------------------------
##  3.10.1 Heroku Spaces aliases
##  ----------------------------------------------------------------------------

# hrvae: Enable review apps and/or settings on an existing pipeline.
alias hrvae='heroku reviewapps:enable'

# hrvad: Disable review apps and/or settings on an existing pipeline.
alias hrvad='heroku reviewapps:disable'


##  ----------------------------------------------------------------------------
##  3.10.2 Heroku Run aliases
##  ----------------------------------------------------------------------------

# hrun: Run a one-off process inside a heroku dyno.
alias hrun='heroku run'

# hrund: Run a detached dyno, where output is sent to your logs.
alias hrund='heroku run:detached'


##  ----------------------------------------------------------------------------
##  3.10.3 Heroku Sessions aliases
##  ----------------------------------------------------------------------------

# hsessions: List your OAuth sessions.
alias hsessions='heroku sessions'

# hsessionsd: Delete (logout) OAuth session by ID.
alias hsessionsd='heroku sessions:destroy'


##  ----------------------------------------------------------------------------
##  3.10.4 Heroku Spaces aliases
##  ----------------------------------------------------------------------------

# hsp: List available spaces.
alias hsp='heroku spaces'

# hspc: Create a new space.
alias hspc='heroku spaces:create'

# hspd: Destroy a space.
alias hspd='heroku spaces:destroy'

# hspi: Show info about a space.
alias hspi='heroku spaces:info'

# hsppi: Display the information necessary to initiate a peering connection.
alias hsppi='heroku spaces:peering:info'

# hspp: List peering connections for a space.
alias hspp='heroku spaces:peerings'

# hsppa: Accepts a pending peering request for a private space.
alias hsppa='heroku spaces:peerings:accept'

# hsppd: Destroys an active peering connection in a private space.
alias hsppd='heroku spaces:peerings:destroy'

# hspps: List dynos for a space.
alias hspps='heroku spaces:ps'

# hspr: Renames a space.
alias hspr='heroku spaces:rename'

# hsptop: Show space topology.
alias hsptop='heroku spaces:topology'

# hspt: Transfer a space to another team.
alias hspt='heroku spaces:transfer'

# hspconf: Display the configuration information for VPN.
alias hspconf='heroku spaces:vpn:config'

# hspvc: Create VPN.
alias hspvc='heroku spaces:vpn:connect'

# hspvcs: List the VPN Connections for a space.
alias hspvcs='heroku spaces:vpn:connections'

# hspvk: Destroys VPN in a private space.
alias hspvk='heroku spaces:vpn:destroy'

# hspvi: Display the information for VPN.
alias hspvi='heroku spaces:vpn:info'

# hspvu: Update VPN.
alias hspvu='heroku spaces:vpn:update'

# hspvw: Wait for VPN Connection to be created.
alias hspvw='heroku spaces:vpn:wait'

# hspw: Wait for a space to be created.
alias hspw='heroku spaces:wait'


##  ----------------------------------------------------------------------------
##  3.10.5 Heroku Webhooks aliases
##  ----------------------------------------------------------------------------

# hwh: List webhooks on an app.
alias hwh='heroku webhooks'

# hwha: Add a webhook to an app.
alias hwha='heroku webhooks:add'

# hwhdv: List webhook deliveries on an app.
alias hwhdv='heroku webhooks:deliveries'

# hwhdvi: Info for a webhook event on an app.
alias hwhdvi='heroku webhooks:deliveries:info'

# hwhev: List webhook events on an app.
alias hwhev='heroku webhooks:events'

# hwhevi: Info for a webhook event on an app.
alias hwhevi='heroku webhooks:events:info'

# hwhi: Info for a webhook on an app.
alias hwhi='heroku webhooks:info'

# hwhr: Removes a webhook from an app.
alias hwhr='heroku webhooks:remove'

# hwhu: Updates a webhook in an app.
alias hwhu='heroku webhooks:update'
