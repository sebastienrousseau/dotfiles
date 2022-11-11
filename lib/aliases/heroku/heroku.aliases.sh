#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

# 🅷🅴🆁🅾🅺🆄 🅰🅻🅸🅰🆂🅴🆂 - Heroku aliases.
if command -v 'heroku' >/dev/null; then
  alias hk='heroku'                                                 # hk: Heroku CLI command shortcut.
  alias hka='heroku access:add'                                     # hka: Add new users to your app.
  alias hkau='heroku access:update'                                 # hkau: Update existing collaborators on an team app.
  alias hkh='heroku help'                                           # hkh: Display help for heroku.
  alias hkj='heroku join'                                           # hkj: Add yourself to a team app.
  alias hkl='heroku commands'                                       # hkl: List all the commands.
  alias hkla='heroku access'                                        # hkla: List who has access to an app.
  alias hklg='heroku logs'                                          # hklg: Display recent log output.
  alias hkn='heroku notifications'                                  # hkn: Display notifications.
  alias hko='heroku orgs'                                           # hko: List the teams that you are a member of.
  alias hkoo='heroku orgs:open'                                     # hkoo: Open the team interface in a browser.
  alias hkp='heroku psql'                                           # hkp: Open a psql shell to the database.
  alias hkq='heroku leave'                                          # hkq: Remove yourself from a team app.
  alias hkr='heroku access:remove'                                  # hkr: Remove users from a team app.
  alias hkrg='heroku regions'                                       # hkrg: List available regions for deployment.
  alias hks='heroku status'                                         # hks: Display current status of the Heroku platform.
  alias hkt='heroku teams'                                          # hkt: List the teams that you are a member of.
  alias hku='heroku update'                                         # hku: Update the heroku CLI.
  alias hkulk='heroku unlock'                                       # hkulk: Unlock an app so any team member can join.
  alias hkw='heroku which'                                          # hkw: Show which plugin a command is in.
  alias hkada='heroku addons:attach'                                # Attach an existing add-on resource to an app.
  alias hkadc='heroku addons:create'                                # Create a new add-on resource.
  alias hkadd='heroku addons:detach'                                # Detach an existing add-on resource from an app.
  alias hkaddoc='heroku addons:docs'                                # Open an add-on's Dev Center documentation in your browser.
  alias hkaddown='heroku addons:downgrade'                          # Change add-on plan.
  alias hkadi='heroku addons:info'                                  # Show detailed add-on resource and attachment information.
  alias hkadk='heroku addons:destroy'                               # Permanently destroy an add-on resource.
  alias hkadl='heroku addons'                                       # Lists your add-ons and attachments.
  alias hkado='heroku addons:open'                                  # Open an add-on's dashboard in your browser.
  alias hkadp='heroku addons:plans'                                 # List all available plans for an add-on services.
  alias hkadr='heroku addons:rename'                                # Rename an add-on.
  alias hkads='heroku addons:services'                              # List all available add-on services.
  alias hkadu='heroku addons:upgrade'                               # Change add-on plan.
  alias hkadw='heroku addons:wait'                                  # Show provisioning status of the add-ons on the app.
  alias hkapc='heroku apps:create'                                  # hkapc: Creates a new app.
  alias hkape='heroku apps:errors'                                  # hkape: View app errors.
  alias hkapfav='heroku apps:favorites'                             # hkapfav: List favorites apps.
  alias hkapfava='heroku apps:favorites:add'                        # hkapfava: Favorites an app.
  alias hkapunfav='heroku apps:favorites:remove'                    # hkapunfav: Unfavorite an app.
  alias hkapi='heroku apps:info'                                    # hkapi: Show detailed app information.
  alias hkapj='heroku apps:join'                                    # hkapj: Add yourself to a team app.
  alias hkapk='heroku apps:destroy'                                 # hkapk: Permanently destroy an app.
  alias hkapl='heroku apps'                                         # hkapl: List your apps.
  alias hkaplk='heroku apps:lock'                                   # hkaplk: Prevent team members from joining an app.
  alias hkapo='heroku apps:open'                                    # hkapo: Open the app in a web browser.
  alias hkapq='heroku apps:leave'                                   # hkapq: Remove yourself from a team app.
  alias hkapr='heroku apps:rename'                                  # hkapr: Rename an app.
  alias hkaps='heroku apps:stacks'                                  # hkaps: Show the list of available stacks.
  alias hkapss='heroku apps:stacks:set'                             # hkapss: Set the stack of an app.
  alias hkapt='heroku apps:transfer'                                # hkapt: Transfer applications to another user or team.
  alias hkapulk='heroku apps:unlock'                                # hkapulk: Unlock an app so any team member can join.
  alias hk2fa='heroku auth:whoami'                                  # hk2fa: Display the current logged in user.
  alias hk2fad='heroku auth:2fa:disable'                            # hk2fad: Disables 2fa on account.
  alias hk2fain='heroku auth:login'                                 # hk2fain: Login with your Heroku credentials.
  alias hk2faout='heroku auth:logout'                               # hk2faout: Clears local login credentials and invalidates API session.
  alias hk2fas='heroku auth:2fa'                                    # hk2fas: Check 2fa status.
  alias hk2fat='heroku auth:token'                                  # hk2fat: Outputs current CLI authentication token.
  alias hkauc='heroku authorizations:create'                        # hkauc: Create a new OAuth authorization.
  alias hkaui='heroku authorizations:info'                          # hkaui: Show an existing OAuth authorization.
  alias hkaul='heroku authorizations'                               # hkaul: List OAuth authorizations.
  alias hkaur='heroku authorizations:revoke'                        # hkaur: Revoke OAuth authorization.
  alias hkauro='heroku authorizations:rotate'                       # hkauro: Updates an OAuth authorization token.
  alias hkauu='heroku authorizations:update'                        # hkauu: Updates an OAuth authorization.
  alias hkbpac='heroku autocomplete'                                # hkbpac: Display autocomplete installation instructions.
  alias hkbpad='heroku buildpacks:add'                              # hkbpad: Add new app build-pack, inserting into list of build-packs if necessary.
  alias hkbpcl='heroku buildpacks:clear'                            # hkbpcl: Clear all build-packs set on the app.
  alias hkbpi='heroku buildpacks:info'                              # hkbpi: Fetch info about a build-pack.
  alias hkbpl='heroku buildpacks'                                   # hkbpl: Display the build-packs for an app.
  alias hkbpr='heroku buildpacks:remove'                            # hkbpr: Remove a build-pack set on the app.
  alias hkbps='heroku buildpacks:search'                            # hkbps: Search for build-packs.
  alias hkbpv='heroku buildpacks:versions'                          # hkbpv: List versions of a build-pack.
  alias hkca='heroku certs:auto'                                    # hkca: Show ACM status for an app.
  alias hkcad='heroku certs:add'                                    # hkcad: Add an SSL certificate to an app.
  alias hkcae='heroku certs:auto:enable'                            # hkcae: Enable ACM status for an app.
  alias hkcak='heroku certs:auto:disable'                           # hkcak: Disable ACM for an app.
  alias hkcar='heroku certs:auto:refresh'                           # hkcar: Refresh ACM for an app.
  alias hkcc='heroku certs:chain'                                   # hkcc: Print an ordered & complete chain for a certificate.
  alias hkcg='heroku certs:generate'                                # hkcg: Generate a key and a CSR or self-signed certificate.
  alias hkci='heroku certs:info'                                    # hkci: Show certificate information for an SSL certificate.
  alias hkck='heroku certs:key'                                     # hkck: Print the correct key for the given certificate.
  alias hkcl='heroku certs'                                         # hkcl: List SSL certificates for an app.
  alias hkcr='heroku certs:remove'                                  # hkcr: Remove an SSL certificate from an app.
  alias hkcu='heroku certs:update'                                  # hkcu: Update an SSL certificate on an app.
  alias hkcicg='heroku ci:config:get'                               # hkcicg: Get a CI config var.
  alias hkcics='heroku ci:config:set'                               # hkcics: Set CI config vars.
  alias hkcicu='heroku ci:config:unset'                             # hkcicu: Unset CI config vars.
  alias hkcicv=' ci:config'                                         # hkcicv: Display CI config vars.
  alias hkcid='heroku ci:debug'                                     # hkcid: Opens an interactive test debugging session with the contents of the current directory.
  alias hkcie='heroku ci:last'                                      # hkcie: Looks for the most recent run and returns the output of that run.
  alias hkcii='heroku ci:info'                                      # hkcii: Show the status of a specific test run.
  alias hkcil='heroku ci'                                           # hkcil: Display the most recent CI runs for the given pipeline.
  alias hkcim='heroku ci:migrate-manifest'                          # hkcim: 'app-ci.json' is deprecated. Run this command to migrate to app.json with an environments key.
  alias hkcio='heroku ci:open'                                      # hkcio: Open the Dashboard version of Heroku CI.
  alias hkcir='heroku ci:run'                                       # hkcir: Run tests against current directory.
  alias hkcir2='heroku ci:rerun'                                    # hkcir2: Rerun tests against current directory.
  alias hkclc='heroku clients:create'                               # hkclc: Create a new OAuth client.
  alias hkcli='heroku clients:info'                                 # hkcli: Show details of an oauth client.
  alias hkclk='heroku clients:destroy'                              # hkclk: Delete client by ID.
  alias hkcll='heroku clients'                                      # hkcll: List your OAuth clients.
  alias hkcls='heroku clients:rotate'                               # hkcls: Rotate OAuth client secret.
  alias hkclu='heroku clients:update'                               # hkclu: Update OAuth client.
  alias hkcfe='heroku config:edit'                                  # hkcfe: Interactively edit config vars.
  alias hkcfg='heroku config:get'                                   # hkcfg: Display a single config value for an app.
  alias hkcfs='heroku config:set'                                   # hkcfs: Set one or more config vars.
  alias hkcfu='heroku config:unset'                                 # hkcfu: Unset one or more config vars.
  alias hkcfv='heroku config'                                       # hkcfv: Display the config vars for an app.
  alias hkct='heroku container'                                     # hkct: Use containers to build and deploy Heroku apps.
  alias hkctin='heroku container:login'                             # hkctin: Log in to Heroku Container Registry.
  alias hkctout='heroku container:logout'                           # hkctout: Log out from Heroku Container Registry.
  alias hkctpull='heroku container:pull'                            # hkctpull: Pulls an image from an app's process type.
  alias hkctpush='heroku container:push'                            # hkctpush: Builds, then pushes Docker images to deploy your Heroku app.
  alias hkctrelease='heroku container:release'                      # hkctrelease: Releases previously pushed Docker images to your Heroku app.
  alias hkctrm='heroku container:rm'                                # hkctrm: Remove the process type from your app.
  alias hkctrun='heroku container:run'                              # hkctrun: Builds, then runs the docker image locally.
  alias hkdo='heroku domains'                                       # hkdo: List domains for an app.
  alias hkdoa='heroku domains:add'                                  # hkdoa: Add a domain to an app.
  alias hkdoc='heroku domains:clear'                                # hkdoc: Remove all domains from an app.
  alias hkdoi='heroku domains:info'                                 # hkdoi: Show detailed information for a domain on an app.
  alias hkdor='heroku domains:remove'                               # hkdor: Remove a domain from an app.
  alias hkdou='heroku domains:update'                               # hkdou: Update a domain to use a different SSL certificate on an app.
  alias hkdow='heroku domains:wait'                                 # hkdow: Wait for domain to be active for an app.
  alias hkdr='heroku drains'                                        # hkdr: Display the log drains of an app.
  alias hkdra='heroku drains:add'                                   # hkdra: Adds a log drain to an app.
  alias hkdrr='heroku drains:remove'                                # hkdrr: Removes a log drain from an app.
  alias hkdyk='heroku dyno:kill'                                    # hkdyk: Kill a dyno.
  alias hkdyrz='heroku dyno:resize'                                 # hkdyrz: Manage dyno sizes.
  alias hkdyrs='heroku dyno:restart'                                # hkdyrs: Restart app dynos.
  alias hkdysc='heroku dyno:scale'                                  # hkdysc: Scale dyno quantity up or down.
  alias hkdyst='heroku dyno:stop'                                   # hkdyst: Stop app dyno.
  alias hkfeat='heroku features'                                    # hkfeat: List available app features.
  alias hkfeatd='heroku features:disable'                           # hkfeatd: Disables an app feature.
  alias hkfeate='heroku features:enable'                            # hkfeate: Enables an app feature.
  alias hkfeati='heroku features:info'                              # hkfeati: Display information about a feature.
  alias hkgitc='heroku git:clone'                                   # Clones a heroku app to your local machine at DIRECTORY (defaults to app name).
  alias hkgitr='heroku git:remote'                                  # Adds a git remote to an app repo.
  alias hkk='heroku keys'                                           # Display your SSH keys.
  alias hkka='heroku keys:add'                                      # Add an SSH key for a user.
  alias hkkcl='heroku keys:clear'                                   # Remove all SSH keys for current user.
  alias hkkr='heroku keys:remove'                                   # Remove an SSH key from the user.
  alias hklab='heroku labs'                                         # hklab: List experimental features.
  alias hklabd='heroku labs:disable'                                # hklabd: Disables an experimental feature.
  alias hklabe='heroku labs:enable'                                 # hklabe: Enables an experimental feature.
  alias hklabi='heroku labs:info'                                   # hklabi: Show feature info.
  alias hkloc='heroku local'                                        # hkloc: Run heroku app locally.
  alias hklocr='heroku local:run'                                   # hklocr: Run a one-off command.
  alias hklocv='heroku local:version'                               # hklocv: Display node-foreman version.
  alias hkloclk='heroku lock'                                       # hkloclk: Prevent team members from joining an app.
  alias hkmt='heroku maintenance'                                   # hkmt: Display the current maintenance status of app.
  alias hkmtoff='heroku maintenance:off'                            # hkmtoff: Take the app out of maintenance mode.
  alias hkmton='heroku maintenance:on'                              # hkmton: Put the app into maintenance mode.
  alias hkmb='heroku members'                                       # hkmb: List members of a team.
  alias hkmba='heroku members:add'                                  # hkmba: Adds a user to a team.
  alias hkmbr='heroku members:remove'                               # hkmbr: Removes a user from a team.
  alias hkmbs='heroku members:set'                                  # hkmbs: Sets a members role in a team.
  alias hkpg='heroku pg'                                            # hkpg: Show database information.
  alias hkpgb='heroku pg:bloat'                                     # hkpgb: Show table and index bloat in your database ordered by most wasteful.
  alias hkpgbk='heroku pg:backups'                                  # hkpgbk: List database backups.
  alias hkpgbkcl='heroku pg:backups:cancel'                         # hkpgbkcl: Cancel an in-progress backup or restore (default newest).
  alias hkpgbkc='heroku pg:backups:capture'                         # hkpgbkc: Capture a new backup.
  alias hkpgbkdl='heroku pg:backups:delete'                         # hkpgbkdl: Delete a backup.
  alias hkpgbkdw='heroku pg:backups:download'                       # hkpgbkdw: Downloads database backup.
  alias hkpgbki='heroku pg:backups:info'                            # hkpgbki: Get information about a specific backup.
  alias hkpgbkr='heroku pg:backups:restore'                         # hkpgbkr: Restore a backup (default latest) to a database.
  alias hkpgbks='heroku pg:backups:schedule'                        # hkpgbks: Schedule daily backups for given database.
  alias hkpgbksh='heroku pg:backups:schedules'                      # hkpgbksh: List backup schedule.
  alias hkpgbkurl='heroku pg:backups:url'                           # hkpgbkurl: Get secret but publicly accessible URL of a backup.
  alias hkpgbkk='heroku pg:backups:unschedule'                      # hkpgbkk: Stop daily backups.
  alias hkpgblk='heroku pg:blocking'                                # hkpgblk: Display queries holding locks other queries are waiting to be released.
  alias hkpgc='heroku pg:copy'                                      # hkpgc: Copy all data from source db to target.
  alias hkpgcpa='heroku pg:connection-pooling:attach'               # hkpgcpa: Add an attachment to a database using connection pooling.
  alias hkpgcr='heroku pg:credentials'                              # hkpgcr: Show information on credentials in the database.
  alias hkpgcrc='heroku pg:credentials:create'                      # hkpgcrc: Create credential within database.
  alias hkpgcrd='heroku pg:credentials:destroy'                     # hkpgcrd: Destroy credential within database.
  alias hkpgcrr='heroku pg:credentials:rotate'                      # hkpgcrr: Rotate the database credentials.
  alias hkpgcrrd='heroku pg:credentials:repair-default'             # hkpgcrrd: Repair the permissions of the default credential within database.
  alias hkpgcrurl='heroku pg:credentials:url'                       # hkpgcrurl: Show information on a database credential.
  alias hkpgdg='heroku pg:diagnose'                                 # hkpgdg: Run or view diagnostics report.
  alias hkpgi='heroku pg:info'                                      # hkpgi: Show database information.
  alias hkpgk='heroku pg:kill'                                      # hkpgk: Kill a query.
  alias hkpgka='heroku pg:killall'                                  # hkpgka: Terminates all connections for all credentials.
  alias hkpglks='heroku pg:locks'                                   # hkpglks: Display queries with active locks.
  alias hkpglnk='heroku pg:links'                                   # hkpglnk: Lists all databases and information on link.
  alias hkpglnkc='heroku pg:links:create'                           # hkpglnkc: Create a link between data stores.
  alias hkpglnkd='heroku pg:links:destroy'                          # hkpglnkd: Destroys a link between data stores.
  alias hkpgmt='heroku pg:maintenance'                              # hkpgmt: Show current maintenance information.
  alias hkpgmtr='heroku pg:maintenance:run'                         # hkpgmtr: Start maintenance.
  alias hkpgmtw='heroku pg:maintenance:window'                      # hkpgmtw: Set weekly maintenance window.
  alias hkpgo='heroku pg:outliers'                                  # hkpgo: Show 10 queries that have longest execution time in aggregate.
  alias hkpgp='heroku pg:promote'                                   # hkpgp: Sets DATABASE as your DATABASE_URL.
  alias hkpgps='heroku pg:ps'                                       # hkpgps: View active queries with execution time.
  alias hkpgpsql='heroku pg:psql'                                   # hkpgpsql: Open a psql shell to the database.
  alias hkpgpull='heroku pg:pull'                                   # hkpgpull: Pull Heroku database into local or remote database.
  alias hkpgpush='heroku pg:push'                                   # hkpgpush: Push local or remote into Heroku database.
  alias hkpgreset='heroku pg:reset'                                 # hkpgreset: Delete all data in DATABASE.
  alias hkpgset='heroku pg:settings'                                # hkpgreset: Show your current database settings.
  alias hkpgsetllw='heroku pg:settings:log-lock-waits'              # hkpgsetllw: Controls whether a log message is produced when a session waits longer than the deadlock_timeout to acquire a lock.
  alias hkpgsetlmds='heroku pg:settings:log-min-duration-statement' # hkpgsetlmds: The duration of each completed statement will be logged if the statement completes after the time specified by VALUE.
  alias hkpgsetlgs='heroku pg:settings:log-statement'               # hkpgsetlgs: 'log_statement' controls which SQL statements are logged.
  alias hkpguf='heroku pg:unfollow'                                 # hkpguf: Stop a replica from following and make it a writeable database.
  alias hkpgup='heroku pg:upgrade'                                  # hkpgup: Unfollow a database and upgrade it to the latest stable PostgreSQL version.
  alias hkpgvs='heroku pg:vacuum-stats'                             # hkpgvs: Show dead rows and whether an automatic vacuum is expected to be triggered.
  alias hkpgww='heroku pg:wait'                                     # hkpgww: Blocks until database is available.
  alias hkpipe='heroku pipelines'                                   # List pipelines you have access to.
  alias hkpipea='heroku pipelines:add'                              # Add this app to a pipeline.
  alias hkpipec='heroku pipelines:create'                           # Create a new pipeline.
  alias hkpipect='heroku pipelines:connect'                         # Connect a github repo to an existing pipeline.
  alias hkpipediff='heroku pipelines:diff'                          # Compares the latest release of this app to its downstream app(s).
  alias hkpipei='heroku pipelines:info'                             # Show list of apps in a pipeline.
  alias hkpipek='heroku pipelines:destroy'                          # Destroy a pipeline.
  alias hkpipeo='heroku pipelines:open'                             # Open a pipeline in dashboard.
  alias hkpipep='heroku pipelines:promote'                          # Promote the latest release of this app to its downstream app(s).
  alias hkpiper='heroku pipelines:remove'                           # Remove this app from its pipeline.
  alias hkpipern='heroku pipelines:rename'                          # Rename a pipeline.
  alias hkpipes='heroku pipelines:setup'                            # Bootstrap a new pipeline with common settings and create a production and staging app (requires a fully formed app.json in the repo).
  alias hkpipett='heroku pipelines:transfer'                        # Transfer ownership of a pipeline.
  alias hkpipeu='heroku pipelines:update'                           # Update the app's stage in a pipeline.
  alias hkplugs='heroku plugins'                                    # hkplugs: List installed plugins.
  alias hkplugsi='heroku plugins:install'                           # hkplugsi: Installs a plugin into the CLI.
  alias hkplugslk='heroku plugins:link'                             # hkplugslk: Links a plugin into the CLI for development.
  alias hkplugsui='heroku plugins:uninstall'                        # hkplugsui: Removes a plugin from the CLI.
  alias hkplugsu='heroku plugins:update'                            # hkplugsu: Update installed plugins.
  alias hkpsad='heroku ps:autoscale:disable'                        # hkpsad: Disable web dyno autoscaling.
  alias hkps='heroku ps'                                            # hkps: List dynos for an app.
  alias hkpsae='heroku ps:autoscale:enable'                         # hkpsae: Enable web dyno autoscaling.
  alias hkpsc='heroku ps:copy'                                      # hkpsc: Copy a file from a dyno to the local filesystem.
  alias hkpse='heroku ps:exec'                                      # hkpse: Create an SSH session to a dyno.
  alias hkpsf='heroku ps:forward'                                   # hkpsf: Forward traffic on a local port to a dyno.
  alias hkpsk='heroku ps:kill'                                      # hkpsk: Stop app dyno.
  alias hkpsr='heroku ps:restart'                                   # hkpsr: Restart app dynos.
  alias hkpsrs='heroku ps:resize'                                   # hkpsrs: Manage dyno sizes.
  alias hkpss='heroku ps:stop'                                      # hkpss: Stop app dyno.
  alias hkpssc='heroku ps:scale'                                    # hkpssc: Scale dyno quantity up or down.
  alias hkpssck='heroku ps:socks'                                   # hkpssck: Launch a SOCKS proxy into a dyno.
  alias hkpst='heroku ps:type'                                      # hkpst: Manage dyno sizes.
  alias hkpsw='heroku ps:wait'                                      # hkpsw: Wait for all dynos to be running latest version after a release.
  alias hkred='heroku redis'                                        # hkred: Gets information about redis.
  alias hkredcli='heroku redis:cli'                                 # hkredcli: Opens a redis prompt.
  alias hkredcr='heroku redis:credentials'                          # hkredcr: Display credentials information.
  alias hkredi='heroku redis:info'                                  # hkredi: Gets information about redis.
  alias hkredkn='heroku redis:keyspace-notifications'               # hkredkn: Set the keyspace notifications configuration.
  alias hkredmm='heroku redis:maxmemory'                            # hkredmm: Set the key eviction policy.
  alias hkredmt='heroku redis:maintenance'                          # hkredmt: Manage maintenance windows.
  alias hkredp='heroku redis:promote'                               # hkredp: Sets DATABASE as your REDIS_URL.
  alias hkredsr='heroku redis:stats-reset'                          # hkredsr: Reset all stats covered by RESETSTAT (<https://redis.io/commands/config-resetstat>).
  alias hkredt='heroku redis:timeout'                               # hkredt: Set the number of seconds to wait before killing idle connections.
  alias hkredw='heroku redis:wait'                                  # hkredw: Wait for Redis instance to be available.
  alias hkrel='heroku releases'                                     # hkrel: Display the releases for an app.
  alias hkreli='heroku releases:info'                               # hkreli: View detailed information for a release.
  alias hkrelo='heroku releases:output'                             # hkrelo: View the release command output.
  alias hkrelr='heroku releases:rollback'                           # hkrelr: Rollback to a previous release.
  alias hkrvae='heroku reviewapps:enable'                           # hkrvae: Enable review apps and/or settings on an existing pipeline.
  alias hkrvad='heroku reviewapps:disable'                          # hkrvad: Disable review apps and/or settings on an existing pipeline.
  alias hkrun='heroku run'                                          # hkrun: Run a one-off process inside a heroku dyno.
  alias hkrund='heroku run:detached'                                # hkrund: Run a detached dyno, where output is sent to your logs.
  alias hksessions='heroku sessions'                                # hksessions: List your OAuth sessions.
  alias hksessionsd='heroku sessions:destroy'                       # hksessionsd: Delete (logout) OAuth session by ID.
  alias hksp='heroku spaces'                                        # hksp: List available spaces.
  alias hkspc='heroku spaces:create'                                # hkspc: Create a new space.
  alias hkspd='heroku spaces:destroy'                               # hkspd: Destroy a space.
  alias hkspi='heroku spaces:info'                                  # hkspi: Show info about a space.
  alias hksppi='heroku spaces:peering:info'                         # hksppi: Display the information necessary to initiate a peering connection.
  alias hkspp='heroku spaces:peerings'                              # hkspp: List peering connections for a space.
  alias hksppa='heroku spaces:peerings:accept'                      # hksppa: Accepts a pending peering request for a private space.
  alias hksppd='heroku spaces:peerings:destroy'                     # hksppd: Destroys an active peering connection in a private space.
  alias hkspps='heroku spaces:ps'                                   # hkspps: List dynos for a space.
  alias hkspr='heroku spaces:rename'                                # hkspr: Renames a space.
  alias hksptop='heroku spaces:topology'                            # hksptop: Show space topology.
  alias hkspt='heroku spaces:transfer'                              # hkspt: Transfer a space to another team.
  alias hkspconf='heroku spaces:vpn:config'                         # hkspconf: Display the configuration information for VPN.
  alias hkspvc='heroku spaces:vpn:connect'                          # hkspvc: Create VPN.
  alias hkspvcs='heroku spaces:vpn:connections'                     # hkspvcs: List the VPN Connections for a space.
  alias hkspvk='heroku spaces:vpn:destroy'                          # hkspvk: Destroys VPN in a private space.
  alias hkspvi='heroku spaces:vpn:info'                             # hkspvi: Display the information for VPN.
  alias hkspvu='heroku spaces:vpn:update'                           # hkspvu: Update VPN.
  alias hkspvw='heroku spaces:vpn:wait'                             # hkspvw: Wait for VPN Connection to be created.
  alias hkspw='heroku spaces:wait'                                  # hkspw: Wait for a space to be created.
  alias hkwh='heroku webhooks'                                      # hkwh: List webhooks on an app.
  alias hkwha='heroku webhooks:add'                                 # hkwha: Add a webhook to an app.
  alias hkwhdv='heroku webhooks:deliveries'                         # hkwhdv: List webhook deliveries on an app.
  alias hkwhdvi='heroku webhooks:deliveries:info'                   # hkwhdvi: Info for a webhook event on an app.
  alias hkwhev='heroku webhooks:events'                             # hkwhev: List webhook events on an app.
  alias hkwhevi='heroku webhooks:events:info'                       # hkwhevi: Info for a webhook event on an app.
  alias hkwhi='heroku webhooks:info'                                # hkwhi: Info for a webhook on an app.
  alias hkwhr='heroku webhooks:remove'                              # hkwhr: Removes a webhook from an app.
  alias hkwhu='heroku webhooks:update'                              # hkwhu: Updates a webhook in an app.
fi
