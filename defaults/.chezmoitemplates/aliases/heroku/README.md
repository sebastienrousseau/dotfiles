# Heroku Aliases

Manage Heroku CLI aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `heroku-addons.aliases.sh`, `heroku-apps.aliases.sh`, `heroku-auth.aliases.sh`, `heroku-buildpacks.aliases.sh`, `heroku-certs.aliases.sh`, `heroku-ci.aliases.sh`, `heroku-config.aliases.sh`, `heroku-container.aliases.sh`, `heroku-domains.aliases.sh`, `heroku-infra.aliases.sh`, `heroku-local.aliases.sh`, `heroku-pipelines.aliases.sh`, `heroku-postgres.aliases.sh`, `heroku-ps.aliases.sh`, `heroku-redis.aliases.sh`, `heroku-spaces.aliases.sh`, `heroku-webhooks.aliases.sh` and `heroku.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name.

## Aliases

### `heroku-addons.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkada` | `heroku addons:attach` | Attach an existing add-on resource to an app. |
| `hkadc` | `heroku addons:create` | Create a new add-on resource. |
| `hkadd` | `heroku addons:detach` | Detach an existing add-on resource from an app. |
| `hkaddoc` | `heroku addons:docs` | Open an add-on's Dev Center documentation in your browser. |
| `hkaddown` | `heroku addons:downgrade` | Change add-on plan. |
| `hkadi` | `heroku addons:info` | Show detailed add-on resource and attachment information. |
| `hkadk` | `heroku addons:destroy` | Permanently destroy an add-on resource. |
| `hkadl` | `heroku addons` | Lists your add-ons and attachments. |
| `hkado` | `heroku addons:open` | Open an add-on's dashboard in your browser. |
| `hkadp` | `heroku addons:plans` | List all available plans for an add-on services. |
| `hkadr` | `heroku addons:rename` | Rename an add-on. |
| `hkads` | `heroku addons:services` | List all available add-on services. |
| `hkadu` | `heroku addons:upgrade <add-on> <plan>` | Change add-on plan. |
| `hkadw` | `heroku addons:wait` | Show provisioning status of the add-ons on the app. |

### `heroku-apps.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkapc` | `heroku apps:create` | Creates a new app. |
| `hkape` | `heroku apps:errors` | View app errors. |
| `hkapfav` | `heroku apps:favorites` | List favorites apps. |
| `hkapfava` | `heroku apps:favorites:add` | Favorites an app. |
| `hkapunfav` | `heroku apps:favorites:remove` | Unfavorite an app. |
| `hkapi` | `heroku apps:info` | Show detailed app information. |
| `hkapj` | `heroku apps:join` | Add yourself to a team app. |
| `hkapk` | `heroku apps:destroy` | Permanently destroy an app. |
| `hkapl` | `heroku apps` | List your apps. |
| `hkaplk` | `heroku apps:lock` | Prevent team members from joining an app. |
| `hkapo` | `heroku apps:open` | Open the app in a web browser. |
| `hkapq` | `heroku apps:leave` | Remove yourself from a team app. |
| `hkapr` | `heroku apps:rename` | Rename an app. |
| `hkaps` | `heroku apps:stacks` | Show the list of available stacks. |
| `hkapss` | `heroku apps:stacks:set` | Set the stack of an app. |
| `hkapt` | `heroku apps:transfer` | Transfer applications to another user or team. |
| `hkapulk` | `heroku apps:unlock` | Unlock an app so any team member can join. |

### `heroku-auth.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hk2fa` | `heroku auth:whoami` | Display the current logged in user. |
| `hk2fad` | `heroku auth:2fa:disable` | Disables 2fa on account. |
| `hk2fain` | `heroku auth:login` | Login with your Heroku credentials. |
| `hk2faout` | `heroku auth:logout` | Clears local login credentials and invalidates API session. |
| `hk2fas` | `heroku auth:2fa` | Check 2fa status. |
| `hk2fat` | `heroku auth:token` | Outputs current CLI authentication token. |
| `hkauc` | `heroku authorizations:create` | Create a new OAuth authorization. |
| `hkaui` | `heroku authorizations:info` | Show an existing OAuth authorization. |
| `hkaul` | `heroku authorizations` | List OAuth authorizations. |
| `hkaur` | `heroku authorizations:revoke` | Revoke OAuth authorization. |
| `hkauro` | `heroku authorizations:rotate` | Updates an OAuth authorization token. |
| `hkauu` | `heroku authorizations:update` | Updates an OAuth authorization. |

### `heroku-buildpacks.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkbpac` | `heroku autocomplete` | Display autocomplete installation instructions. |
| `hkbpad` | `heroku buildpacks:add` | Add new app build-pack, inserting into list of build-packs if necessary. |
| `hkbpcl` | `heroku buildpacks:clear` | Clear all build-packs set on the app. |
| `hkbpi` | `heroku buildpacks:info` | Fetch info about a build-pack. |
| `hkbpl` | `heroku buildpacks` | Display the build-packs for an app. |
| `hkbpr` | `heroku buildpacks:remove` | Remove a build-pack set on the app. |
| `hkbps` | `heroku buildpacks:search` | Search for build-packs. |
| `hkbpv` | `heroku buildpacks:versions` | List versions of a build-pack. |

### `heroku-certs.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkca` | `heroku certs:auto` | Show ACM status for an app. |
| `hkcad` | `heroku certs:add` | Add an SSL certificate to an app. |
| `hkcae` | `heroku certs:auto:enable` | Enable ACM status for an app. |
| `hkcak` | `heroku certs:auto:disable` | Disable ACM for an app. |
| `hkcar` | `heroku certs:auto:refresh` | Refresh ACM for an app. |
| `hkcc` | `heroku certs:chain` | Print an ordered & complete chain for a certificate. |
| `hkcg` | `heroku certs:generate` | Generate a key and a CSR or self-signed certificate. |
| `hkci` | `heroku certs:info` | Show certificate information for an SSL certificate. |
| `hkck` | `heroku certs:key` | Print the correct key for the given certificate. |
| `hkcl` | `heroku certs` | List SSL certificates for an app. |
| `hkcr` | `heroku certs:remove` | Remove an SSL certificate from an app. |
| `hkcu` | `heroku certs:update` | Update an SSL certificate on an app. |

### `heroku-ci.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkcicg` | `heroku ci:config:get` | Get a CI config var. |
| `hkcics` | `heroku ci:config:set` | Set CI config vars. |
| `hkcicu` | `heroku ci:config:unset` | Unset CI config vars. |
| `hkcicv` | `heroku ci:config` | Display CI config vars. |
| `hkcid` | `heroku ci:debug` | Opens an interactive test debugging session with the contents of the current directory. |
| `hkcie` | `heroku ci:last` | Looks for the most recent run and returns the output of that run. |
| `hkcii` | `heroku ci:info` | Show the status of a specific test run. |
| `hkcil` | `heroku ci` | Display the most recent CI runs for the given pipeline. |
| `hkcim` | `heroku ci:migrate-manifest` | 'app-ci.json' is deprecated. Run this command to migrate to app.json with an environments key. |
| `hkcio` | `heroku ci:open` | Open the Dashboard version of Heroku CI. |
| `hkcir` | `heroku ci:run` | Run tests against current directory. |
| `hkcir2` | `heroku ci:rerun` | Rerun tests against current directory. |

### `heroku-config.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkclc` | `heroku clients:create` | Create a new OAuth client. |
| `hkcli` | `heroku clients:info` | Show details of an oauth client. |
| `hkclk` | `heroku clients:destroy` | Delete client by ID. |
| `hkcll` | `heroku clients` | List your OAuth clients. |
| `hkcls` | `heroku clients:rotate` | Rotate OAuth client secret. |
| `hkclu` | `heroku clients:update` | Update OAuth client. |
| `hkcfe` | `heroku config:edit` | Interactively edit config vars. |
| `hkcfg` | `heroku config:get` | Display a single config value for an app. |
| `hkcfs` | `heroku config:set` | Set one or more config vars. |
| `hkcfu` | `heroku config:unset` | Unset one or more config vars. |
| `hkcfv` | `heroku config` | Display the config vars for an app. |

### `heroku-container.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkct` | `heroku container` | Use containers to build and deploy Heroku apps. |
| `hkctin` | `heroku container:login` | Log in to Heroku Container Registry. |
| `hkctout` | `heroku container:logout` | Log out from Heroku Container Registry. |
| `hkctpull` | `heroku container:pull` | Pulls an image from an app's process type. |
| `hkctpush` | `heroku container:push` | Builds, then pushes Docker images to deploy your Heroku app. |
| `hkctrelease` | `heroku container:release` | Releases previously pushed Docker images to your Heroku app. |
| `hkctrm` | `heroku container:rm` | Remove the process type from your app. |
| `hkctrun` | `heroku container:run` | Builds, then runs the docker image locally. |

### `heroku-domains.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkdo` | `heroku domains` | List domains for an app. |
| `hkdoa` | `heroku domains:add` | Add a domain to an app. |
| `hkdoc` | `heroku domains:clear` | Remove all domains from an app. |
| `hkdoi` | `heroku domains:info` | Show detailed information for a domain on an app. |
| `hkdor` | `heroku domains:remove` | Remove a domain from an app. |
| `hkdou` | `heroku domains:update` | Update a domain to use a different SSL certificate on an app. |
| `hkdow` | `heroku domains:wait` | Wait for domain to be active for an app. |
| `hkdr` | `heroku drains` | Display the log drains of an app. |
| `hkdra` | `heroku drains:add` | Adds a log drain to an app. |
| `hkdrr` | `heroku drains:remove` | Removes a log drain from an app. |
| `hkdyk` | `heroku dyno:kill` | Stop app dyno. |
| `hkdyrz` | `heroku dyno:resize` | Manage dyno sizes. |
| `hkdyrs` | `heroku dyno:restart` | Restart app dynos. |
| `hkdysc` | `heroku dyno:scale` | Scale dyno quantity up or down. |
| `hkdyst` | `heroku dyno:stop` | Stop app dyno. |

### `heroku-infra.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkfeat` | `heroku features` | List available app features. |
| `hkfeatd` | `heroku features:disable` | Disables an app feature. |
| `hkfeate` | `heroku features:enable` | Enables an app feature. |
| `hkfeati` | `heroku features:info` | Display information about a feature. |
| `hkgitc` | `heroku git:clone` | Clones a heroku app to your local machine at DIRECTORY (defaults to app name). |
| `hkgitr` | `heroku git:remote` | Adds a git remote to an app repo. |
| `hkk` | `heroku keys` | Display your SSH keys. Replaced by `hkk='heroku'` from `heroku.aliases.sh`, which loads after the other heroku files. |
| `hkka` | `heroku keys:add` | Add an SSH key for a user. |
| `hkkcl` | `heroku keys:clear` | Remove all SSH keys for current user. |
| `hkkr` | `heroku keys:remove` | Remove an SSH key from the user. |
| `hklab` | `heroku labs` | List experimental features. |
| `hklabd` | `heroku labs:disable` | Disables an experimental feature. |
| `hklabe` | `heroku labs:enable` | Enables an experimental feature. |
| `hklabi` | `heroku labs:info` | Show feature info. |

### `heroku-local.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkloc` | `heroku local` | Run heroku app locally. |
| `hklocr` | `heroku local:run` | Run a one-off command. |
| `hklocv` | `heroku local:version` | Display node-foreman version. |
| `hkloclk` | `heroku lock` | Prevent team members from joining an app. |
| `hkmt` | `heroku maintenance` | Display the current maintenance status of app. |
| `hkmtoff` | `heroku maintenance:off` | Take the app out of maintenance mode. |
| `hkmton` | `heroku maintenance:on` | Put the app into maintenance mode. |
| `hkmb` | `heroku members` | List members of a team. |
| `hkmba` | `heroku members:add` | Adds a user to a team. |
| `hkmbr` | `heroku members:remove` | Removes a user from a team. |
| `hkmbs` | `heroku members:set` | Sets a members role in a team. |

### `heroku-pipelines.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkpipe` | `heroku pipelines` | List pipelines you have access to. |
| `hkpipea` | `heroku pipelines:add` | Add this app to a pipeline. |
| `hkpipec` | `heroku pipelines:create` | Create a new pipeline. |
| `hkpipect` | `heroku pipelines:connect` | Connect a github repo to an existing pipeline. |
| `hkpipediff` | `heroku pipelines:diff` | Compares the latest release of this app to its downstream app(s). |
| `hkpipei` | `heroku pipelines:info` | Show list of apps in a pipeline. |
| `hkpipek` | `heroku pipelines:destroy` | Destroy a pipeline. |
| `hkpipeo` | `heroku pipelines:open` | Open a pipeline in dashboard. |
| `hkpipep` | `heroku pipelines:promote` | Promote the latest release of this app to its downstream app(s). |
| `hkpiper` | `heroku pipelines:remove` | Remove this app from its pipeline. |
| `hkpipern` | `heroku pipelines:rename` | Rename a pipeline. |
| `hkpipes` | `heroku pipelines:setup` | Bootstrap a new pipeline with common settings. |
| `hkpipett` | `heroku pipelines:transfer` | Transfer ownership of a pipeline. |
| `hkpipeu` | `heroku pipelines:update` | Update the app's stage in a pipeline. |
| `hkplugs` | `heroku plugins` | List installed plugins. |
| `hkplugsi` | `heroku plugins:install` | Installs a plugin into the CLI. |
| `hkplugslk` | `heroku plugins:link` | Links a plugin into the CLI for development. |
| `hkplugsui` | `heroku plugins:uninstall` | Removes a plugin from the CLI. |
| `hkplugsu` | `heroku plugins:update` | Update installed plugins. |

### `heroku-postgres.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkpg` | `heroku pg` | Show database information. |
| `hkpgb` | `heroku pg:bloat` | Show table and index bloat in your database ordered by most wasteful. |
| `hkpgbk` | `heroku pg:backups` | List database backups. |
| `hkpgbkcl` | `heroku pg:backups:cancel` | Cancel an in-progress backup or restore (default newest). |
| `hkpgbkc` | `heroku pg:backups:capture` | Capture a new backup. |
| `hkpgbkdl` | `heroku pg:backups:delete` | Delete a backup. |
| `hkpgbkdw` | `heroku pg:backups:download` | Downloads database backup. |
| `hkpgbki` | `heroku pg:backups:info` | Get information about a specific backup. |
| `hkpgbkr` | `heroku pg:backups:restore` | Restore a backup (default latest) to a database. |
| `hkpgbks` | `heroku pg:backups:schedule` | Schedule daily backups for given database. |
| `hkpgbksh` | `heroku pg:backups:schedules` | List backup schedule. |
| `hkpgbkurl` | `heroku pg:backups:url` | Get secret but publicly accessible URL of a backup. |
| `hkpgbkk` | `heroku pg:backups:unschedule` | Stop daily backups. |
| `hkpgblk` | `heroku pg:blocking` | Display queries holding locks other queries are waiting to be released. |
| `hkpgc` | `heroku pg:copy` | Copy all data from source db to target. |
| `hkpgcpa` | `heroku pg:connection-pooling:attach` | Add an attachment to a database using connection pooling. |
| `hkpgcr` | `heroku pg:credentials` | Show information on credentials in the database. |
| `hkpgcrc` | `heroku pg:credentials:create` | Create credential within database. |
| `hkpgcrd` | `heroku pg:credentials:destroy` | Destroy credential within database. |
| `hkpgcrr` | `heroku pg:credentials:rotate` | Rotate the database credentials. |
| `hkpgcrrd` | `heroku pg:credentials:repair-default` | Repair the permissions of the default credential within database. |
| `hkpgcrurl` | `heroku pg:credentials:url` | Show information on a database credential. |
| `hkpgdg` | `heroku pg:diagnose` | Run or view diagnostics report. |
| `hkpgi` | `heroku pg:info` | Show database information. |
| `hkpgk` | `heroku pg:kill` | Kill a query. |
| `hkpgka` | `heroku pg:killall` | Terminates all connections for all credentials. |
| `hkpglks` | `heroku pg:locks` | Display queries with active locks. |
| `hkpglnk` | `heroku pg:links` | Lists all databases and information on link. |
| `hkpglnkc` | `heroku pg:links:create` | Create a link between data stores. |
| `hkpglnkd` | `heroku pg:links:destroy` | Destroys a link between data stores. |
| `hkpgmt` | `heroku pg:maintenance` | Show current maintenance information. |
| `hkpgmtr` | `heroku pg:maintenance:run` | Start maintenance. |
| `hkpgmtw` | `heroku pg:maintenance:window` | Set weekly maintenance window. |
| `hkpgo` | `heroku pg:outliers` | Show 10 queries that have longest execution time in aggregate. |
| `hkpgp` | `heroku pg:promote` | Sets DATABASE as your DATABASE_URL. |
| `hkpgps` | `heroku pg:ps` | View active queries with execution time. |
| `hkpgpsql` | `heroku pg:psql` | Open a psql shell to the database. |
| `hkpgpull` | `heroku pg:pull` | Pull Heroku database into local or remote database. |
| `hkpgpush` | `heroku pg:push` | Push local or remote into Heroku database. |
| `hkpgreset` | `heroku pg:reset` | Delete all data in DATABASE. |
| `hkpgset` | `heroku pg:settings` | Show your current database settings. |
| `hkpgsetllw` | `heroku pg:settings:log-lock-waits` | Controls log message production for lock waits. |
| `hkpgsetlmds` | `heroku pg:settings:log-min-duration-statement` | Log duration for completed statements. |
| `hkpgsetlgs` | `heroku pg:settings:log-statement` | Controls which SQL statements are logged. |
| `hkpguf` | `heroku pg:unfollow` | Stop a replica from following and make it a writeable database. |
| `hkpgup` | `heroku pg:upgrade` | Unfollow a database and upgrade it to the latest stable PostgreSQL version. |
| `hkpgvs` | `heroku pg:vacuum-stats` | Show dead rows and whether an automatic vacuum is expected to be triggered. |
| `hkpgww` | `heroku pg:wait` | Blocks until database is available. |

### `heroku-ps.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkpsad` | `heroku ps:autoscale:disable` | Disable web dyno autoscaling. |
| `hkps` | `heroku ps` | List dynos for an app. |
| `hkpsae` | `heroku ps:autoscale:enable <options>` | Enable web dyno autoscaling. |
| `hkpsc` | `heroku ps:copy` | Copy a file from a dyno to the local filesystem. |
| `hkpse` | `heroku ps:exec` | Create an SSH session to a dyno. |
| `hkpsf` | `heroku ps:forward` | Forward traffic on a local port to a dyno. |
| `hkpsk` | `heroku ps:kill` | Stop app dyno. |
| `hkpsr` | `heroku ps:restart` | Restart app dynos. |
| `hkpsrs` | `heroku ps:resize` | Manage dyno sizes. |
| `hkpss` | `heroku ps:stop` | Stop app dyno. |
| `hkpssc` | `heroku ps:scale` | Scale dyno quantity up or down. |
| `hkpssck` | `heroku ps:socks` | Launch a SOCKS proxy into a dyno. |
| `hkpst` | `heroku ps:type` | Manage dyno sizes. |
| `hkpsw` | `heroku ps:wait` | Wait for all dynos to be running latest version after a release. |

### `heroku-redis.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkred` | `heroku redis` | Gets information about redis. |
| `hkredcli` | `heroku redis:cli` | Opens a redis prompt. |
| `hkredcr` | `heroku redis:credentials` | Display credentials information. |
| `hkredi` | `heroku redis:info` | Gets information about redis. |
| `hkredkn` | `heroku redis:keyspace-notifications` | Set the keyspace notifications configuration. |
| `hkredmm` | `heroku redis:maxmemory` | Set the key eviction policy. |
| `hkredmt` | `heroku redis:maintenance` | Manage maintenance windows. |
| `hkredp` | `heroku redis:promote` | Sets DATABASE as your REDIS_URL. |
| `hkredsr` | `heroku redis:stats-reset` | Reset all stats covered by RESETSTAT. |
| `hkredt` | `heroku redis:timeout` | Set the number of seconds to wait before killing idle connections. |
| `hkredw` | `heroku redis:wait` | Wait for Redis instance to be available. |
| `hkrel` | `heroku releases` | Display the releases for an app. |
| `hkreli` | `heroku releases:info` | View detailed information for a release. |
| `hkrelo` | `heroku releases:output` | View the release command output. |
| `hkrelr` | `heroku releases:rollback` | Rollback to a previous release. |
| `hkrvae` | `heroku reviewapps:enable` | Enable review apps and/or settings on an existing pipeline. |
| `hkrvad` | `heroku reviewapps:disable` | Disable review apps and/or settings on an existing pipeline. |
| `hkrun` | `heroku run` | Run a one-off process inside a heroku dyno. |
| `hkrund` | `heroku run:detached` | Run a detached dyno, where output is sent to your logs. |
| `hksessions` | `heroku sessions` | List your OAuth sessions. |
| `hksessionsd` | `heroku sessions:destroy` | Delete (logout) OAuth session by ID. |

### `heroku-spaces.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hksp` | `heroku spaces` | List available spaces. |
| `hkspc` | `heroku spaces:create` | Create a new space. |
| `hkspd` | `heroku spaces:destroy` | Destroy a space. |
| `hkspi` | `heroku spaces:info` | Show info about a space. |
| `hksppi` | `heroku spaces:peering:info` | Display the information necessary to initiate a peering connection. |
| `hkspp` | `heroku spaces:peerings` | List peering connections for a space. |
| `hksppa` | `heroku spaces:peerings:accept` | Accepts a pending peering request for a private space. |
| `hksppd` | `heroku spaces:peerings:destroy` | Destroys an active peering connection in a private space. |
| `hkspps` | `heroku spaces:ps` | List dynos for a space. |
| `hkspr` | `heroku spaces:rename` | Renames a space. |
| `hksptop` | `heroku spaces:topology` | Show space topology. |
| `hkspt` | `heroku spaces:transfer` | Transfer a space to another team. |
| `hkspconf` | `heroku spaces:vpn:config` | Display the configuration information for VPN. |
| `hkspvc` | `heroku spaces:vpn:connect` | Create VPN. |
| `hkspvcs` | `heroku spaces:vpn:connections` | List the VPN Connections for a space. |
| `hkspvk` | `heroku spaces:vpn:destroy` | Destroys VPN in a private space. |
| `hkspvi` | `heroku spaces:vpn:info` | Display the information for VPN. |
| `hkspvu` | `heroku spaces:vpn:update` | Update VPN. |
| `hkspvw` | `heroku spaces:vpn:wait` | Wait for VPN Connection to be created. |
| `hkspw` | `heroku spaces:wait` | Wait for a space to be created. |

### `heroku-webhooks.aliases.sh`

| Name | Definition | Notes |
| --- | --- | --- |
| `hkwh` | `heroku webhooks` | List webhooks on an app. |
| `hkwha` | `heroku webhooks:add` | Add a webhook to an app. |
| `hkwhdv` | `heroku webhooks:deliveries` | List webhook deliveries on an app. |
| `hkwhdvi` | `heroku webhooks:deliveries:info` | Info for a webhook event on an app. |
| `hkwhev` | `heroku webhooks:events` | List webhook events on an app. |
| `hkwhevi` | `heroku webhooks:events:info` | Info for a webhook event on an app. |
| `hkwhi` | `heroku webhooks:info` | Info for a webhook on an app. |
| `hkwhr` | `heroku webhooks:remove` | Removes a webhook from an app. |
| `hkwhu` | `heroku webhooks:update` | Updates a webhook in an app. |

### `heroku.aliases.sh`

Every definition in this file exists only when `heroku` is on PATH.

| Name | Definition | Notes |
| --- | --- | --- |
| `hkk` | `heroku` | Heroku CLI shortcut. Replaces `hkk='heroku keys'` from `heroku-infra.aliases.sh`. |
| `hka` | `heroku access:add` | Add new users to your app. |
| `hkau` | `heroku access:update` | Update existing collaborators on an team app. |
| `hkh` | `heroku help` | Display help for heroku. |
| `hkj` | `heroku join` | Add yourself to a team app. |
| `hkl` | `heroku commands` | List all the commands. |
| `hkla` | `heroku access` | List who has access to an app. |
| `hklg` | `heroku logs` | Display recent log output. |
| `hkn` | `heroku notifications` | Display notifications. |
| `hko` | `heroku orgs` | List the teams that you are a member of. |
| `hkoo` | `heroku orgs:open` | Open the team interface in a browser. |
| `hkp` | `heroku psql` | Open a psql shell to the database. |
| `hkq` | `heroku leave` | Remove yourself from a team app. |
| `hkr` | `heroku access:remove` | Remove users from a team app. |
| `hkrg` | `heroku regions` | List available regions for deployment. |
| `hks` | `heroku status` | Display current status of the Heroku platform. |
| `hkt` | `heroku teams` | List the teams that you are a member of. |
| `hku` | `heroku update` | Update the heroku CLI. |
| `hkulk` | `heroku unlock` | Unlock an app so any team member can join. |
| `hkw` | `heroku which` | Show which plugin a command is in. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
