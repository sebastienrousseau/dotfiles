#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

# 🅷🅴🆁🅾🅺🆄 🅰🅻🅸🅰🆂🅴🆂 - Heroku aliases.
if command -v heroku &>/dev/null; then
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
  ##  ------------------------------------------------------------------
  ##  1. Heroku Core aliases
  ##  ------------------------------------------------------------------

  ##  ------------------------------------------------------------------
  ##  1.1 Heroku Access aliases.
  ##  ------------------------------------------------------------------

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

  ##  ------------------------------------------------------------------
  ##  1.2 Heroku Add-ons aliases
  ##  ------------------------------------------------------------------

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

  ##  ------------------------------------------------------------------
  ##  1.3 Heroku Apps aliases
  ##  ------------------------------------------------------------------

  # hkapc: Creates a new app.
  alias hkapc='heroku apps:create'

  # hkape: View app errors.
  alias hkape='heroku apps:errors'

  # hkapfav: List favorites apps.
  alias hkapfav='heroku apps:favorites'

  # hkapfava: Favorites an app.
  alias hkapfava='heroku apps:favorites:add'

  # hkapunfav: Unfavorite an app.
  alias hkapunfav='heroku apps:favorites:remove'

  # hkapi: Show detailed app information.
  alias hkapi='heroku apps:info'

  # hkapj: Add yourself to a team app.
  alias hkapj='heroku apps:join'

  # hkapk: Permanently destroy an app.
  alias hkapk='heroku apps:destroy'

  # hkapl: List your apps.
  alias hkapl='heroku apps'

  # hkaplk: Prevent team members from joining an app.
  alias hkaplk='heroku apps:lock'

  # hkapo: Open the app in a web browser.
  alias hkapo='heroku apps:open'

  # hkapq: Remove yourself from a team app.
  alias hkapq='heroku apps:leave'

  # hkapr: Rename an app.
  alias hkapr='heroku apps:rename'

  # hkaps: Show the list of available stacks.
  alias hkaps='heroku apps:stacks'

  # hkapss: Set the stack of an app.
  alias hkapss='heroku apps:stacks:set'

  # hkapt: Transfer applications to another user or team.
  alias hkapt='heroku apps:transfer'

  # hkapulk: Unlock an app so any team member can join.
  alias hkapulk='heroku apps:unlock'

  ##  ------------------------------------------------------------------
  ##  1.4 Heroku Auth 2fa aliases
  ##  ------------------------------------------------------------------

  # hk2fa: Display the current logged in user.
  alias hk2fa='heroku auth:whoami'

  # hk2fad: Disables 2fa on account.
  alias hk2fad='heroku auth:2fa:disable'

  # hk2fain: Login with your Heroku credentials.
  alias hk2fain='heroku auth:login'

  # hk2faout: Clears local login credentials and invalidates API session
  alias hk2faout='heroku auth:logout'

  # hk2fas: Check 2fa status.
  alias hk2fas='heroku auth:2fa'

  # hk2fat: Outputs current CLI authentication token.
  alias hk2fat='heroku auth:token'

  ##  ------------------------------------------------------------------
  ##  1.5 Heroku Authorizations aliases
  ##  ------------------------------------------------------------------

  # hkauc: Create a new OAuth authorization.
  alias hkauc='heroku authorizations:create'

  # hkaui: Show an existing OAuth authorization.
  alias hkaui='heroku authorizations:info'

  # hkaul: List OAuth authorizations.
  alias hkaul='heroku authorizations'

  # hkaur: Revoke OAuth authorization.
  alias hkaur='heroku authorizations:revoke'

  # hkauro: Updates an OAuth authorization token.
  alias hkauro='heroku authorizations:rotate'

  # hkauu: Updates an OAuth authorization.
  alias hkauu='heroku authorizations:update'

  ##  ------------------------------------------------------------------
  ##  1.6 Heroku Build packs aliases
  ##  ------------------------------------------------------------------

  # hkbpac: Display autocomplete installation instructions.
  alias hkbpac='heroku autocomplete'

  # hkbpad: Add new app build-pack, inserting into list of build-packs
  # if necessary.
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

  ##  ------------------------------------------------------------------
  ##  1.7 Heroku Certs aliases
  ##  ------------------------------------------------------------------

  # hkca: Show ACM status for an app.
  alias hkca='heroku certs:auto'

  # hkcad: Add an SSL certificate to an app.
  alias hkcad='heroku certs:add'

  # hkcae: Enable ACM status for an app.
  alias hkcae='heroku certs:auto:enable'

  # hkcak: Disable ACM for an app.
  alias hkcak='heroku certs:auto:disable'

  # hkcar: Refresh ACM for an app.
  alias hkcar='heroku certs:auto:refresh'

  # hkcc: Print an ordered & complete chain for a certificate.
  alias hkcc='heroku certs:chain'

  # hkcg: Generate a key and a CSR or self-signed certificate.
  alias hkcg='heroku certs:generate'

  # hkci: Show certificate information for an SSL certificate.
  alias hkci='heroku certs:info'

  # hkck: Print the correct key for the given certificate.
  alias hkck='heroku certs:key'

  # hkcl: List SSL certificates for an app.
  alias hkcl='heroku certs'

  # hkcr: Remove an SSL certificate from an app.
  alias hkcr='heroku certs:remove'

  # hkcu: Update an SSL certificate on an app.
  alias hkcu='heroku certs:update'

  ##  ------------------------------------------------------------------
  ##  1.8 Heroku ci aliases
  ##  ------------------------------------------------------------------

  # hkcicg: Get a CI config var.
  alias hkcicg='heroku ci:config:get'

  # hkcics: Set CI config vars.
  alias hkcics='heroku ci:config:set'

  # hkcicu: Unset CI config vars.
  alias hkcicu='heroku ci:config:unset'

  # hkcicv: Display CI config vars.
  alias hkcicv=' ci:config'

  # hkcid: Opens an interactive test debugging session with the contents
  # of the current directory.
  alias hkcid='heroku ci:debug'

  # hkcie: Looks for the most recent run and returns the output of that
  # run.
  alias hkcie='heroku ci:last'

  # hkcii: Show the status of a specific test run.
  alias hkcii='heroku ci:info'

  # hkcil: Display the most recent CI runs for the given pipeline.
  alias hkcil='heroku ci'

  # hkcim: 'app-ci.json' is deprecated. Run this command to migrate to
  # app.json with an environments key.
  alias hkcim='heroku ci:migrate-manifest'

  # hkcio: Open the Dashboard version of Heroku CI.
  alias hkcio='heroku ci:open'

  # hkcir: Run tests against current directory.
  alias hkcir='heroku ci:run'

  # hkcir2: Rerun tests against current directory.
  alias hkcir2='heroku ci:rerun'

  ##  ------------------------------------------------------------------
  ##  1.9 Heroku config aliases
  ##  ------------------------------------------------------------------

  # hkclc: Create a new OAuth client.
  alias hkclc='heroku clients:create'

  # hkcli: Show details of an oauth client.
  alias hkcli='heroku clients:info'

  # hkclk: Delete client by ID.
  alias hkclk='heroku clients:destroy'

  # hkcll: List your OAuth clients.
  alias hkcll='heroku clients'

  # hkcls: Rotate OAuth client secret.
  alias hkcls='heroku clients:rotate'

  # hkclu: Update OAuth client.
  alias hkclu='heroku clients:update'

  ##  ------------------------------------------------------------------
  ##  2. Heroku Configuration aliases
  ##  ------------------------------------------------------------------

  # hkcfe: Interactively edit config vars.
  alias hkcfe='heroku config:edit'

  # hkcfg: Display a single config value for an app.
  alias hkcfg='heroku config:get'

  # hkcfs: Set one or more config vars.
  alias hkcfs='heroku config:set'

  # hkcfu: Unset one or more config vars.
  alias hkcfu='heroku config:unset'

  # hkcfv: Display the config vars for an app.
  alias hkcfv='heroku config'

  ##  ------------------------------------------------------------------
  ##  2.1 Heroku Container aliases
  ##  ------------------------------------------------------------------

  # hkct: Use containers to build and deploy Heroku apps.
  alias hkct='heroku container'

  # hkctin: Log in to Heroku Container Registry.
  alias hkctin='heroku container:login'

  # hkctout: Log out from Heroku Container Registry.
  alias hkctout='heroku container:logout'

  # hkctpull: Pulls an image from an app's process type.
  alias hkctpull='heroku container:pull'

  # hkctpush: Builds, then pushes Docker images to deploy your Heroku
  # app.
  alias hkctpush='heroku container:push'

  # hkctrelease: Releases previously pushed Docker images to your Heroku
  # app.
  alias hkctrelease='heroku container:release'

  # hkctrm: Remove the process type from your app.
  alias hkctrm='heroku container:rm'

  # hkctrun: Builds, then runs the docker image locally.
  alias hkctrun='heroku container:run'

  ##  ------------------------------------------------------------------
  ##  2.2 Heroku Domains aliases
  ##  ------------------------------------------------------------------

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

  ##  ------------------------------------------------------------------
  ##  2.3 Heroku Drains aliases
  ##  ------------------------------------------------------------------

  # hkdr: Display the log drains of an app.
  alias hkdr='heroku drains'

  # hkdra: Adds a log drain to an app.
  alias hkdra='heroku drains:add'

  # hkdrr: Removes a log drain from an app.
  alias hkdrr='heroku drains:remove'

  ##  ------------------------------------------------------------------
  ##  2.4 Heroku Dyno aliases
  ##  ------------------------------------------------------------------

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

  ##  ------------------------------------------------------------------
  ##  2.5 Heroku Features aliases
  ##  ------------------------------------------------------------------

  # hkfeat: List available app features.
  alias hkfeat='heroku features'

  # hkfeatd: Disables an app feature.
  alias hkfeatd='heroku features:disable'

  # hkfeate: Enables an app feature.
  alias hkfeate='heroku features:enable'

  # hkfeati: Display information about a feature.
  alias hkfeati='heroku features:info'

  ##  ------------------------------------------------------------------
  ##  2.6 Heroku Git aliases
  ##  ------------------------------------------------------------------

  # Clones a heroku app to your local machine at DIRECTORY
  # (defaults to app name).
  alias hkgitc='heroku git:clone'

  # Adds a git remote to an app repo.
  alias hkgitr='heroku git:remote'

  ##  ------------------------------------------------------------------
  ##  2.7 Heroku Keys aliases
  ##  ------------------------------------------------------------------

  # Display your SSH keys.
  alias hkk='heroku keys'

  # Add an SSH key for a user.
  alias hkka='heroku keys:add'

  # Remove all SSH keys for current user.
  alias hkkcl='heroku keys:clear'

  # Remove an SSH key from the user.
  alias hkkr='heroku keys:remove'

  ##  ------------------------------------------------------------------
  ##  2.8 Heroku Labs aliases
  ##  ------------------------------------------------------------------

  # hklab: List experimental features.
  alias hklab='heroku labs'

  # hklabd: Disables an experimental feature.
  alias hklabd='heroku labs:disable'

  # hklabe: Enables an experimental feature.
  alias hklabe='heroku labs:enable'

  # hklabi: Show feature info.
  alias hklabi='heroku labs:info'

  ##  ------------------------------------------------------------------
  ##  3. Heroku Advanced aliases
  ##  ------------------------------------------------------------------

  ##  ------------------------------------------------------------------
  ##  3.1 Heroku Local aliases
  ##  ------------------------------------------------------------------

  # hkloc: Run heroku app locally.
  alias hkloc='heroku local'

  # hklocr: Run a one-off command.
  alias hklocr='heroku local:run'

  # hklocv: Display node-foreman version.
  alias hklocv='heroku local:version'

  # hkloclk: Prevent team members from joining an app.
  alias hkloclk='heroku lock'

  ##  ------------------------------------------------------------------
  ##  3.2 Heroku Maintenance aliases
  ##  ------------------------------------------------------------------

  # hkmt: Display the current maintenance status of app.
  alias hkmt='heroku maintenance'

  # hkmtoff: Take the app out of maintenance mode.
  alias hkmtoff='heroku maintenance:off'

  # hkmton: Put the app into maintenance mode.
  alias hkmton='heroku maintenance:on'

  ##  ------------------------------------------------------------------
  ##  3.3 Heroku Members aliases
  ##  ------------------------------------------------------------------

  # hkmb: List members of a team.
  alias hkmb='heroku members'

  # hkmba: Adds a user to a team.
  alias hkmba='heroku members:add'

  # hkmbr: Removes a user from a team.
  alias hkmbr='heroku members:remove'

  # hkmbs: Sets a members role in a team.
  alias hkmbs='heroku members:set'

  ##  ------------------------------------------------------------------
  ##  3.4 Heroku Postgres aliases
  ##  ------------------------------------------------------------------

  # hkpg: Show database information.
  alias hkpg='heroku pg'

  # hkpgb: Show table and index bloat in your database ordered by most
  # wasteful.
  alias hkpgb='heroku pg:bloat'

  # hkpgbk: List database backups.
  alias hkpgbk='heroku pg:backups'

  # hkpgbkcl: Cancel an in-progress backup or restore (default newest).
  alias hkpgbkcl='heroku pg:backups:cancel'

  # hkpgbkc: Capture a new backup.
  alias hkpgbkc='heroku pg:backups:capture'

  # hkpgbkdl: Delete a backup.
  alias hkpgbkdl='heroku pg:backups:delete'

  # hkpgbkdw: Downloads database backup.
  alias hkpgbkdw='heroku pg:backups:download'

  # hkpgbki: Get information about a specific backup.
  alias hkpgbki='heroku pg:backups:info'

  # hkpgbkr: Restore a backup (default latest) to a database.
  alias hkpgbkr='heroku pg:backups:restore'

  # hkpgbks: Schedule daily backups for given database.
  alias hkpgbks='heroku pg:backups:schedule'

  # hkpgbksh: List backup schedule.
  alias hkpgbksh='heroku pg:backups:schedules'

  # hkpgbkurl: Get secret but publicly accessible URL of a backup.
  alias hkpgbkurl='heroku pg:backups:url'

  # hkpgbkk: Stop daily backups.
  alias hkpgbkk='heroku pg:backups:unschedule'

  # hkpgblk: Display queries holding locks other queries are waiting to
  # be released.
  alias hkpgblk='heroku pg:blocking'

  # hkpgc: Copy all data from source db to target.
  alias hkpgc='heroku pg:copy'

  # hkpgcpa: Add an attachment to a database using connection pooling.
  alias hkpgcpa='heroku pg:connection-pooling:attach'

  # hkpgcr: Show information on credentials in the database.
  alias hkpgcr='heroku pg:credentials'

  # hkpgcrc: Create credential within database.
  alias hkpgcrc='heroku pg:credentials:create'

  # hkpgcrd: Destroy credential within database.
  alias hkpgcrd='heroku pg:credentials:destroy'

  # hkpgcrr: Rotate the database credentials.
  alias hkpgcrr='heroku pg:credentials:rotate'

  # hkpgcrrd: Repair the permissions of the default credential within
  # database.
  alias hkpgcrrd='heroku pg:credentials:repair-default'

  # hkpgcrurl: Show information on a database credential.
  alias hkpgcrurl='heroku pg:credentials:url'

  # hkpgdg: Run or view diagnostics report.
  alias hkpgdg='heroku pg:diagnose'

  # hkpgi: Show database information.
  alias hkpgi='heroku pg:info'

  # hkpgk: Kill a query.
  alias hkpgk='heroku pg:kill'

  # hkpgka: Terminates all connections for all credentials.
  alias hkpgka='heroku pg:killall'

  # hkpglks: Display queries with active locks.
  alias hkpglks='heroku pg:locks'

  # hkpglnk: Lists all databases and information on link.
  alias hkpglnk='heroku pg:links'

  # hkpglnkc: Create a link between data stores.
  alias hkpglnkc='heroku pg:links:create'

  # hkpglnkd: Destroys a link between data stores.
  alias hkpglnkd='heroku pg:links:destroy'

  # hkpgmt: Show current maintenance information.
  alias hkpgmt='heroku pg:maintenance'

  # hkpgmtr: Start maintenance.
  alias hkpgmtr='heroku pg:maintenance:run'

  # hkpgmtw: Set weekly maintenance window.
  alias hkpgmtw='heroku pg:maintenance:window'

  # hkpgo: Show 10 queries that have longest execution time in
  # aggregate.
  alias hkpgo='heroku pg:outliers'

  # hkpgp: Sets DATABASE as your DATABASE_URL.
  alias hkpgp='heroku pg:promote'

  # hkpgps: View active queries with execution time.
  alias hkpgps='heroku pg:ps'

  # hkpgpsql: Open a psql shell to the database.
  alias hkpgpsql='heroku pg:psql'

  # hkpgpull: Pull Heroku database into local or remote database.
  alias hkpgpull='heroku pg:pull'

  # hkpgpush: Push local or remote into Heroku database.
  alias hkpgpush='heroku pg:push'

  # hkpgreset: Delete all data in DATABASE.
  alias hkpgreset='heroku pg:reset'

  # hkpgreset: Show your current database settings.
  alias hkpgset='heroku pg:settings'

  # hkpgsetllw: Controls whether a log message is produced when a
  # session waits longer than the deadlock_timeout to acquire a lock.
  alias hkpgsetllw='heroku pg:settings:log-lock-waits'

  # hkpgsetlmds: The duration of each completed statement will be logged
  # if the statement completes after the time specified by VALUE.
  alias hkpgsetlmds='heroku pg:settings:log-min-duration-statement'

  # hkpgsetlgs: 'log_statement' controls which SQL statements
  # are logged.
  alias hkpgsetlgs='heroku pg:settings:log-statement'

  # hkpguf: Stop a replica from following and make it a writeable
  # database.
  alias hkpguf='heroku pg:unfollow'

  # hkpgup: Unfollow a database and upgrade it to the latest stable
  # PostgreSQL version.
  alias hkpgup='heroku pg:upgrade'

  # hkpgvs: Show dead rows and whether an automatic vacuum is expected
  # to be triggered.
  alias hkpgvs='heroku pg:vacuum-stats'

  # hkpgww: Blocks until database is available.
  alias hkpgww='heroku pg:wait'

  ##  ------------------------------------------------------------------
  ##  3.5 Heroku Pipelines aliases
  ##  ------------------------------------------------------------------

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

  # Bootstrap a new pipeline with common settings and create a
  # production and staging app (requires a fully formed app.json in
  # the repo).
  alias hkpipes='heroku pipelines:setup'

  # Transfer ownership of a pipeline.
  alias hkpipett='heroku pipelines:transfer'

  # Update the app's stage in a pipeline.
  alias hkpipeu='heroku pipelines:update'

  ##  ------------------------------------------------------------------
  ##  3.6 Heroku Plugins aliases
  ##  ------------------------------------------------------------------

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

  ##  ------------------------------------------------------------------
  ##  3.7 Heroku 'ps' aliases
  ##  ------------------------------------------------------------------

  # hkpsad: Disable web dyno autoscaling.
  alias hkpsad='heroku ps:autoscale:disable'

  # hkps: List dynos for an app.
  alias hkps='heroku ps'

  # hkpsae: Enable web dyno autoscaling.
  alias hkpsae='heroku ps:autoscale:enable '

  # hkpsc: Copy a file from a dyno to the local filesystem.
  alias hkpsc='heroku ps:copy'

  # hkpse: Create an SSH session to a dyno.
  alias hkpse='heroku ps:exec'

  # hkpsf: Forward traffic on a local port to a dyno.
  alias hkpsf='heroku ps:forward'

  # hkpsk: Stop app dyno.
  alias hkpsk='heroku ps:kill'

  # hkpsr: Restart app dynos.
  alias hkpsr='heroku ps:restart'

  # hkpsrs: Manage dyno sizes.
  alias hkpsrs='heroku ps:resize'

  # hkpss: Stop app dyno.
  alias hkpss='heroku ps:stop'

  # hkpssc: Scale dyno quantity up or down.
  alias hkpssc='heroku ps:scale'

  # hkpssck: Launch a SOCKS proxy into a dyno.
  alias hkpssck='heroku ps:socks'

  # hkpst: Manage dyno sizes.
  alias hkpst='heroku ps:type'

  # hkpsw: Wait for all dynos to be running latest version after
  # a release.
  alias hkpsw='heroku ps:wait'

  ##  ------------------------------------------------------------------
  ##  3.8 Heroku redis aliases
  ##  ------------------------------------------------------------------

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

  # hkredsr: Reset all stats covered by RESETSTAT
  # (<https://redis.io/commands/config-resetstat>).
  alias hkredsr='heroku redis:stats-reset'

  # hkredt: Set the number of seconds to wait before killing idle
  # connections.
  alias hkredt='heroku redis:timeout'

  # hkredw: Wait for Redis instance to be available.
  alias hkredw='heroku redis:wait'

  ##  ------------------------------------------------------------------
  ##  3.9 Heroku Releases aliases
  ##  ------------------------------------------------------------------

  # hkrel: Display the releases for an app.
  alias hkrel='heroku releases'

  # hkreli: View detailed information for a release.
  alias hkreli='heroku releases:info'

  # hkrelo: View the release command output.
  alias hkrelo='heroku releases:output'

  # hkrelr: Rollback to a previous release.
  alias hkrelr='heroku releases:rollback'

  ##  ------------------------------------------------------------------
  ##  3.10.1 Heroku Spaces aliases
  ##  ------------------------------------------------------------------

  # hkrvae: Enable review apps and/or settings on an existing pipeline.
  alias hkrvae='heroku reviewapps:enable'

  # hkrvad: Disable review apps and/or settings on an existing pipeline.
  alias hkrvad='heroku reviewapps:disable'

  ##  ------------------------------------------------------------------
  ##  3.10.2 Heroku Run aliases
  ##  ------------------------------------------------------------------

  # hkrun: Run a one-off process inside a heroku dyno.
  alias hkrun='heroku run'

  # hkrund: Run a detached dyno, where output is sent to your logs.
  alias hkrund='heroku run:detached'

  ##  ------------------------------------------------------------------
  ##  3.10.3 Heroku Sessions aliases
  ##  ------------------------------------------------------------------

  # hksessions: List your OAuth sessions.
  alias hksessions='heroku sessions'

  # hksessionsd: Delete (logout) OAuth session by ID.
  alias hksessionsd='heroku sessions:destroy'

  ##  ------------------------------------------------------------------
  ##  3.10.4 Heroku Spaces aliases
  ##  ------------------------------------------------------------------

  # hksp: List available spaces.
  alias hksp='heroku spaces'

  # hkspc: Create a new space.
  alias hkspc='heroku spaces:create'

  # hkspd: Destroy a space.
  alias hkspd='heroku spaces:destroy'

  # hkspi: Show info about a space.
  alias hkspi='heroku spaces:info'

  # hksppi: Display the information necessary to initiate a peering
  # connection.
  alias hksppi='heroku spaces:peering:info'

  # hkspp: List peering connections for a space.
  alias hkspp='heroku spaces:peerings'

  # hksppa: Accepts a pending peering request for a private space.
  alias hksppa='heroku spaces:peerings:accept'

  # hksppd: Destroys an active peering connection in a private space.
  alias hksppd='heroku spaces:peerings:destroy'

  # hkspps: List dynos for a space.
  alias hkspps='heroku spaces:ps'

  # hkspr: Renames a space.
  alias hkspr='heroku spaces:rename'

  # hksptop: Show space topology.
  alias hksptop='heroku spaces:topology'

  # hkspt: Transfer a space to another team.
  alias hkspt='heroku spaces:transfer'

  # hkspconf: Display the configuration information for VPN.
  alias hkspconf='heroku spaces:vpn:config'

  # hkspvc: Create VPN.
  alias hkspvc='heroku spaces:vpn:connect'

  # hkspvcs: List the VPN Connections for a space.
  alias hkspvcs='heroku spaces:vpn:connections'

  # hkspvk: Destroys VPN in a private space.
  alias hkspvk='heroku spaces:vpn:destroy'

  # hkspvi: Display the information for VPN.
  alias hkspvi='heroku spaces:vpn:info'

  # hkspvu: Update VPN.
  alias hkspvu='heroku spaces:vpn:update'

  # hkspvw: Wait for VPN Connection to be created.
  alias hkspvw='heroku spaces:vpn:wait'

  # hkspw: Wait for a space to be created.
  alias hkspw='heroku spaces:wait'

  ##  ------------------------------------------------------------------
  ##  3.10.5 Heroku Webhooks aliases
  ##  ------------------------------------------------------------------

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
fi
