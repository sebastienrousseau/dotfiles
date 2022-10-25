# Dotfiles aliases

The `heroku.aliases.zsh` file creates helpful shortcut aliases for many commonly
[Heroku](https://www.heroku.com/) commands.

## Table of Contents

### 1. Heroku aliases

#### 1.1 Heroku Access aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| h | `heroku` | Heroku CLI command shortcut. |
| ha | `heroku access:add` | Add new users to your app. |
| hau | `heroku access:update`| Update existing collaborators on an team app. |
| hh | `heroku help` | Display help for heroku. |
| hj | `heroku join` | Add yourself to a team app. |
| hl | `heroku commands` | List all the commands. |
| hla | `heroku access` | List who has access to an app. |
| hlg | `heroku logs` | Display recent log output. |
| hn | `heroku notifications`| Display notifications. |
| ho | `heroku orgs` | List the teams that you are a member of.|
| hoo | `heroku orgs:open` | Open the team interface in a browser. |
| hp | `heroku psql` | Open a psql shell to the database. |
| hq | `heroku leave` | Remove yourself from a team app. |
| hr | `heroku access:remove`| Remove users from a team app. |
| hrg | `heroku regions` | List available regions for deployment. |
| hs | `heroku status` | Display current status of the Heroku platform. |
| ht | `heroku teams` | List the teams that you are a member of. |
| hu | `heroku update` | Update the heroku CLI. |
| hulk | `heroku unlock` | Unlock an app so any team member can join. |
| hw | `heroku which` | Show which plugin a command is in. |

#### 1.2 Heroku Add-ons aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hada | `heroku addons:attach` | Attach an existing add-on resource to an app. |
| hadc | `heroku addons:create` | Create a new add-on resource. |
| hadd | `heroku addons:detach` | Detach an existing add-on resource from an app. |
| haddoc | `heroku addons:docs` | Open an add-on's Dev Center documentation in your browser. |
| haddown | `heroku addons:downgrade`| Change add-on plan. |
| hadi | `heroku addons:info` | Show detailed add-on resource and attachment information. |
| hadk | `heroku addons:destroy` | Permanently destroy an add-on resource. |
| hadl | `heroku addons` | Lists your add-ons and attachments. |
| hado | `heroku addons:open` | Open an add-on's dashboard in your browser. |
| hadp | `heroku addons:plans` | List all available plans for an add-on services. |
| hadr | `heroku addons:rename` | Rename an add-on. |
| hads | `heroku addons:services` | List all available add-on services. |
| hadu | `heroku addons:upgrade` | Change add-on plan. |
| hadw | `heroku addons:wait` | Show provisioning status of the add-ons on the app. |

#### 1.3 Heroku Apps aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hapc | `heroku apps:create` | Creates a new app. |
| hape | `heroku apps:errors` | View app errors.|
| hapfav | `heroku apps:favorites` | List favorites apps. |
| hapfava | `heroku apps:favorites:add` | Favorites an app. |
| hapunfav| `heroku apps:favorites:remove`| Unfavorite an app. |
| hapi | `heroku apps:info` | Show detailed app information. |
| hapj | `heroku apps:join` | Add yourself to a team app. |
| hapk | `heroku apps:destroy` | Permanently destroy an app. |
| hapl | `heroku apps` | List your apps. |
| haplk | `heroku apps:lock` | Prevent team members from joining an app. |
| hapo | `heroku apps:open` | Open the app in a web browser. |
| hapq | `heroku apps:leave` | Remove yourself from a team app. |
| hapr | `heroku apps:rename` | Rename an app. |
| haps | `heroku apps:stacks` | Show the list of available stacks. |
| hapss | `heroku apps:stacks:set` | Set the stack of an app. |
| hapt | `heroku apps:transfer` | Transfer applications to another user or team. |
| hapulck | `heroku apps:unlock` | unlock an app so any team member can join. |

#### 1.4 Heroku Auth 2fa aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| h2fa | `heroku auth:whoami` | Display the current logged in user. |
| h2fad | `heroku auth:2fa:disable`| Disables 2fa on account. |
| h2fain | `heroku auth:login` | Login with your Heroku credentials. |
| h2faout | `heroku auth:logout` | Clears local login credentials and invalidates API session. |
| h2fas | `heroku auth:2fa` | Check 2fa status. |
| h2fat | `heroku auth:token` | Outputs current CLI authentication token. |

#### 1.5 Heroku Authorizations aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hauc | `heroku authorizations:create`| Create a new OAuth authorization. |
| haui | `heroku authorizations:info` | Show an existing OAuth authorization. |
| haul | `heroku authorizations` | List OAuth authorizations. |
| haur | `heroku authorizations:revoke` | Revoke OAuth authorization. |
| hauro| `heroku authorizations:rotate` | Updates an OAuth authorization token. |
| hauu | `heroku authorizations:update` | Updates an OAuth authorization. |

#### 1.6 Heroku Build packs aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hbpac | `heroku autocomplete` | Display autocomplete installation instructions. |
| hbpad | `heroku buildpacks:add` | Add new app build-pack, inserting into list of build-packs if necessary. |
| hbpcl | `heroku buildpacks:clear` | Clear all build-packs set on the app. |
| hbpi | `heroku buildpacks:info` | Fetch info about a build-pack. |
| hbpl | `heroku buildpacks` | Display the build-packs for an app. |
| hbpr | `heroku buildpacks:remove` | Remove a build-pack set on the app. |
| hbps | `heroku buildpacks:search` | Search for build-packs. |
| hbpv | `heroku buildpacks:versions`| List versions of a build-pack. |

#### 1.7 Heroku Certs aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hca | `heroku certs:auto` | Show ACM status for an app. |
| hcad | `heroku certs:add` | Add an SSL certificate to an app. |
| hcae | `heroku certs:auto:enable` | Enable ACM status for an app. |
| hcak | `heroku certs:auto:disable` | Disable ACM for an app. |
| hcar | `heroku certs:auto:refresh` | Refresh ACM for an app. |
| hcc | `heroku certs:chain` | Print an ordered & complete chain for a certificate. |
| hcg | `heroku certs:generate` | Generate a key and a CSR or self-signed certificate. |
| hci | `heroku certs:info` | Show certificate information for an SSL certificate. |
| hck | `heroku certs:key` | Print the correct key for the given certificate. |
| hcl | `heroku certs` | List SSL certificates for an app. |
| hcr | `heroku certs:remove` | Remove an SSL certificate from an app. |
| hcu | `heroku certs:update` | Update an SSL certificate on an app. |

#### 1.8 Heroku ci aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hcicg | `heroku ci:config:get` | Get a CI config var. |
| hcics | `heroku ci:config:set` | Set CI config vars. |
| hcicu | `heroku ci:config:unset` | Unset CI config vars. |
| hcicv | `ci:config` | Display CI config vars. |
| hcid | `heroku ci:debug` | Opens an interactive test debugging session with the contents of the current directory. |
| hcie | `heroku ci:last` | Looks for the most recent run and returns the output of that run. |
| hcii | `heroku ci:info` | Show the status of a specific test run. |
| hcil | `heroku ci` | Display the most recent CI runs for the given pipeline. |
| hcim | `heroku ci:migrate-manifest` | `app-ci.json` is deprecated. Run this command to migrate to app.json with an environments key. |
| hcio | `heroku ci:open` | Open the Dashboard version of Heroku CI. |
| hcir | `heroku ci:run` | Run tests against current directory. |
| hcir2 | `heroku ci:rerun` | Rerun tests against current directory. |

#### 1.9 Heroku config aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hclc | `heroku clients:create` | Create a new OAuth client. |
| hcli | `heroku clients:info` | Show details of an oauth client. |
| hclk | `heroku clients:destroy`| Delete client by ID. |
| hcll | `heroku clients` | List your OAuth clients. |
| hcls | `heroku clients:rotate` | Rotate OAuth client secret. |
| hclu | `heroku clients:update` | Update OAuth client. |

### 2. Heroku Configuration aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hcfe | `heroku config:edit` | Interactively edit config vars. |
| hcfg | `heroku config:get` | Display a single config value for an app. |
| hcfs | `heroku config:set` | Set one or more config vars. |
| hcfu | `heroku config:unset` | Unset one or more config vars. |
| hcfv | `heroku config` | Display the config vars for an app. |

#### 2.1 Heroku Container aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hct | `heroku container` | Use containers to build and deploy Heroku apps. |
| hctin | `heroku container:login` | Log in to Heroku Container Registry. |
| hctout | `heroku container:logout` | Log out from Heroku Container Registry. |
| hctpull | `heroku container:pull` | Pulls an image from an app's process type. |
| hctpush | `heroku container:push` | Builds, then pushes Docker images to deploy your Heroku app. |
| hctrelease | `heroku container:release`| Releases previously pushed Docker images to your Heroku app. |
| hctrm | `heroku container:rm` | Remove the process type from your app. |
| hctrun | `heroku container:run` | Builds, then runs the docker image locally. |

#### 2.2 Heroku Domains aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hdo | `heroku domains` | List domains for an app. |
| hdoa | `heroku domains:add` | Add a domain to an app. |
| hdoc | `heroku domains:clear` | Remove all domains from an app. |
| hdoi | `heroku domains:info` | Show detailed information for a domain on an app. |
| hdor | `heroku domains:remove` | Remove a domain from an app. |
| hdou | `heroku domains:update` | Update a domain to use a different SSL certificate on an app. |
| hdow | `heroku domains:wait` | Wait for domain to be active for an app. |

#### 2.3 Heroku Drains aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hdr | `heroku drains` | Display the log drains of an app. |
| hdra | `heroku drains:add` | Adds a log drain to an app. |
| hdrr | `heroku drains:remove` | Removes a log drain from an app. |

#### 2.4 Heroku Dyno aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hdyk | `heroku dyno:kill` | Stop app dyno. |
| hdyrz | `heroku dyno:resize` | Manage dyno sizes. |
| hdyrs | `heroku dyno:restart` | Restart app dynos. |
| hdysc | `heroku dyno:scale` | Scale dyno quantity up or down. |
| hdyst | `heroku dyno:stop` | Stop app dyno. |

#### 2.5 Heroku Features aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hfeat | `heroku features` | List available app features. |
| hfeatd | `heroku features:disable` | Disables an app feature. |
| hfeate | `heroku features:enable`  | Enables an app feature. |
| hfeati | `heroku features:info` | Display information about a feature. |

#### 2.6 Heroku Git aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hgitc | `heroku git:clone` | Clones a heroku app to your local machine at DIRECTORY (defaults to app name). |
| hgitr | `heroku git:remote` | Adds a git remote to an app repo. |

#### 2.7 Heroku Keys aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hk | `heroku keys` | Display your SSH keys. |
| hk:a | `heroku keys:add` | Add an SSH key for a user. |
| hk:cl | `heroku keys:clear` | Remove all SSH keys for current user. |
| hk:r | `heroku keys:remove`| Remove an SSH key from the user. |

#### 2.8 Heroku Labs aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hlab | `heroku labs` | List experimental features. |
| hlab:d | `heroku labs:disable`| Disables an experimental feature. |
| hlab:e | `heroku labs:enable` | Enables an experimental feature. |
| hlab:i | `heroku labs:info` | Show feature info. |

### 3. Heroku Advanced aliases

#### 3.1 Heroku Local aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hloc | `heroku local` | Run heroku app locally. |
| hlocr | `heroku local:run` | Run a one-off command. |
| hlocv | `heroku local:version`| Display node-foreman version. |
| hloclck | `heroku lock` | Prevent team members from joining an app. |

#### 3.2 Heroku Maintenance aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hmt | `heroku maintenance` | Display the current maintenance status of app. |
| hmtoff | `heroku maintenance:off` | take the app out of maintenance mode. |
| hmton | `heroku maintenance:on` | Put the app into maintenance mode. |

#### 3.3 Heroku Members aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hmb | `heroku members` | List members of a team. |
| hmba | `heroku members:add` | Adds a user to a team. |
| hmbr | `heroku members:remove` | Removes a user from a team. |
| hmbs | `heroku members:set` | Sets a members role in a team. |

#### 3.4 Heroku Postgres aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hpg | `heroku pg` | Show database information. |
| hpgb | `heroku pg:bloat`| Show table and index bloat in your database ordered by most wasteful. |
| hpgbk | `heroku pg:backups` | List database backups. |
| hpgbkcl | `heroku pg:backups:cancel` | Cancel an in-progress backup or restore (default newest). |
| hpgbkc | `heroku pg:backups:capture` | Capture a new backup. |
| hpgbkdl | `heroku pg:backups:delete` | Delete a backup. |
| hpgbkdw | `heroku pg:backups:download` | Downloads database backup. |
| hpgbki | `heroku pg:backups:info` | Get information about a specific backup. |
| hpgbkr | `heroku pg:backups:restore` | Restore a backup (default latest) to a database. |
| hpgbks | `heroku pg:backups:schedule` | Schedule daily backups for given database. |
| hpgbksh | `heroku pg:backups:schedules` | List backup schedule. |
| hpgbkurl | `heroku pg:backups:url` | Get secret but publicly accessible URL of a backup. |
| hpgbkk | `heroku pg:backups:unschedule` | Stop daily backups. |
| hpgblk | `heroku pg:blocking` | Display queries holding locks other queries are waiting to be released. |
| hpgc | `heroku pg:copy` | Copy all data from source db to target. |
| hpgcpa | `heroku pg:connection-pooling:attach` | Add an attachment to a database using connection pooling. |
| hpgcr | `heroku pg:credentials` | Show information on credentials in the database. |
| hpgcrc | `heroku pg:credentials:create` | Create credential within database. |
| hpgcrd | `heroku pg:credentials:destroy` | Destroy credential within database. |
| hpgcrr | `heroku pg:credentials:rotate` | Rotate the database credentials. |
| hpgcrrd | `heroku pg:credentials:repair-default` | Repair the permissions of the default credential within database. |
| hpgcrurl | `heroku pg:credentials:url` | Show information on a database credential. |
| hpgdg | `heroku pg:diagnose` | Run or view diagnostics report.|
| hpgi | `heroku pg:info` | Show database information. |
| hpgk | `heroku pg:kill` | Kill a query. |
| hpgka | `heroku pg:killall` | Terminates all connections for all credentials. |
| hpglks | `heroku pg:locks`| Display queries with active locks. |
| hpglnk | `heroku pg:links`| Lists all databases and information on link. |
| hpglnkc | `heroku pg:links:create` | Create a link between data stores. |
| hpglnkd | `heroku pg:links:destroy` | Destroys a link between data stores. |
| hpgmt | `heroku pg:maintenance` | Show current maintenance information. |
| hpgmtr | `heroku pg:maintenance:run` | Start maintenance. |
| hpgmtw | `heroku pg:maintenance:window` | Set weekly maintenance window. |
| hpgo | `heroku pg:outliers` | Show 10 queries that have longest execution time in aggregate.|
| hpgp | `heroku pg:promote` | Sets DATABASE as your DATABASE_URL. |
| hpgps | `heroku pg:ps` | View active queries with execution time. |
| hpgpsql | `heroku pg:psql` | Open a psql shell to the database.|
| hpgpull | `heroku pg:pull` | Pull Heroku database into local or remote database.|
| hpgpush | `heroku pg:push` | Push local or remote into Heroku database. |
| hpgreset | `heroku pg:reset`| Delete all data in DATABASE. |
| hpgset | `heroku pg:settings` | Show your current database settings. |
| hpgsetllw | `heroku pg:settings:log-lock-waits` | Controls whether a log message is produced when a session waits longer than the deadlock_timeout to acquire a lock.|
| hpgsetlmds | `heroku pg:settings:log-min-duration-statement` | The duration of each completed statement will be logged if the statement completes after the time specified by VALUE. |
| hpgsetlgs | `heroku pg:settings:log-statement` | `log_statement` controls which SQL statements are logged. |
| hpguf | `heroku pg:unfollow` | Stop a replica from following and make it a writeable database. |
| hpgup | `heroku pg:upgrade` | Unfollow a database and upgrade it to the latest stable PostgreSQL version. |
| hpgvs | `heroku pg:vacuum-stats` | Show dead rows and whether an automatic vacuum is expected to be triggered. |
| hpgww | `heroku pg:wait` | Blocks until database is available. |

#### 3.5 Heroku Pipelines aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hpipe | `heroku pipelines` | List pipelines you have access to. |
| hpipea | `heroku pipelines:add` | Add this app to a pipeline. |
| hpipec | `heroku pipelines:create` | Create a new pipeline. |
| hpipect | `heroku pipelines:connect` | Connect a github repo to an existing pipeline. |
| hpipediff | `heroku pipelines:diff` | Compares the latest release of this app to its downstream app(s). |
| hpipei | `heroku pipelines:info` | Show list of apps in a pipeline.|
| hpipek | `heroku pipelines:destroy` | Destroy a pipeline. |
| hpipeo | `heroku pipelines:open` | Open a pipeline in dashboard. |
| hpipep | `heroku pipelines:promote` | Promote the latest release of this app to its downstream app(s). |
| hpiper | `heroku pipelines:remove` | Remove this app from its pipeline. |
| hpipern | `heroku pipelines:rename` | Rename a pipeline. |
| hpipes | `heroku pipelines:setup` | Bootstrap a new pipeline with common settings and create a production and staging app (requires a fully formed app.json in the repo). |
| hpipett | `heroku pipelines:transfer`| Transfer ownership of a pipeline. |
| hpipeu | `heroku pipelines:update` | Update the app's stage in a pipeline. |

#### 3.6 Heroku Plugins aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hplugs | `heroku plugins` | List installed plugins. |
| hplugsi | `heroku plugins:install` | Installs a plugin into the CLI. |
| hplugslk | `heroku plugins:link` | Links a plugin into the CLI for development. |
| hplugsui | `heroku plugins:uninstall` | Removes a plugin from the CLI. |
| hplugsu | `heroku plugins:update` | Update installed plugins. |

#### 3.7 Heroku `ps` aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hps | `heroku ps` | List dynos for an app. |
| hpsad | `heroku ps:autoscale:disable` | Disable web dyno autoscaling. |
| hpsae | `heroku ps:autoscale:enable` | Enable web dyno autoscaling. |
| hpsc | `heroku ps:copy` | Copy a file from a dyno to the local filesystem. |
| hpse | `heroku ps:exec` | Create an SSH session to a dyno. |
| hpsf | `heroku ps:forward` | Forward traffic on a local port to a dyno. |
| hpsk | `heroku ps:kill` | Stop app dyno. |
| hpsr | `heroku ps:restart` | Restart app dynos. |
| hpsrs | `heroku ps:resize` | Manage dyno sizes. |
| hpss | `heroku ps:stop` | Stop app dyno. |
| hpssc | `heroku ps:scale` | Scale dyno quantity up or down. |
| hpssck | `heroku ps:socks` | Launch a SOCKS proxy into a dyno. |
| hpst | `heroku ps:type` | Manage dyno sizes. |
| hpsw | `heroku ps:wait` | Wait for all dynos to be running latest version after a release. |

#### 3.8 Heroku redis aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hred | `heroku redis` | Gets information about redis. |
| hredcli | `heroku redis:cli` | Opens a redis prompt. |
| hredcr | `heroku redis:credentials` | Display credentials information. |
| hredi | `heroku redis:info` | Gets information about redis. |
| hredkn | `heroku redis:keyspace-notifications` | Set the keyspace notifications configuration. |
| hredmm | `heroku redis:maxmemory` | Set the key eviction policy. |
| hredmt | `heroku redis:maintenance` | Manage maintenance windows. |
| hredp | `heroku redis:promote` | Sets DATABASE as your REDIS_URL. |
| hredsr | `heroku redis:stats-reset` | Reset all stats covered by RESETSTAT (<https://redis.io/commands/config-resetstat>). |
| hredt | `heroku redis:timeout` | Set the number of seconds to wait before killing idle connections. |
| hredw | `heroku redis:wait` | Wait for Redis instance to be available. |

#### 3.9 Heroku Releases aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hrel | `heroku releases` | Display the releases for an app.|
| hreli | `heroku releases:info` | View detailed information for a release. |
| hrelo | `heroku releases:output` | View the release command output. |
| hrelr | `heroku releases:rollback` | Rollback to a previous release. |

#### 3.10.1 Heroku Spaces aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hrvad | `heroku reviewapps:disable` | Disable review apps and/or settings on an existing pipeline. |
| hrvae | `heroku reviewapps:enable` | Enable review apps and/or settings on an existing pipeline. |

#### 3.10.2 Heroku Run aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hrun | `heroku run` | Run a one-off process inside a heroku dyno. |
| hrund | `heroku run:detached` | Run a detached dyno, where output is sent to your logs. |

#### 3.10.3 Heroku Sessions aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hsessions | `heroku sessions` | List your OAuth sessions. |
| hsessionsd | `heroku sessions:destroy` | Delete (logout) OAuth session by ID. |

#### 3.10.4 Heroku Spaces aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hsp | `heroku spaces` | List available spaces. |
| hspc | `heroku spaces:create` | Create a new space. |
| hspd | `heroku spaces:destroy`| Destroy a space. |
| hspi | `heroku spaces:info` | Show info about a space. |
| hsppi | `heroku spaces:peering:info` | Display the information necessary to initiate a peering connection. |
| hspp | `heroku spaces:peerings` | List peering connections for a space. |
| hsppa | `heroku spaces:peerings:accept` | Accepts a pending peering request for a private space. |
| hsppd | `heroku spaces:peerings:destroy` | Destroys an active peering connection in a private space. |
| hspps | `heroku spaces:ps` | List dynos for a space. |
| hspr | `heroku spaces:rename` | Renames a space. |
| hsptop | `heroku spaces:topology` | Show space topology. |
| hspt | `heroku spaces:transfer` | Transfer a space to another team. |
| hspconf | `heroku spaces:vpn:config` | Display the configuration information for VPN. |
| hspvc | `heroku spaces:vpn:connect` | Create VPN. |
| hspvcs | `heroku spaces:vpn:connections` | List the VPN Connections for a space. |
| hspvk | `heroku spaces:vpn:destroy` | Destroys VPN in a private space. |
| hspvi | `heroku spaces:vpn:info` | Display the information for VPN. |
| hspvu | `heroku spaces:vpn:update` | Update VPN. |
| hspvw | `heroku spaces:vpn:wait` | Wait for VPN Connection to be created. |
| hspw | `heroku spaces:wait` | Wait for a space to be created. |

#### 3.10.5 Heroku Webhooks aliases

| Alias | Command | Description |
| ----- | ----- | ----- |
| hwh | `heroku webhooks`| list webhooks on an app. |
| hwha | `heroku webhooks:add` | add a webhook to an app. |
| hwhdv | `heroku webhooks:deliveries` | list webhook deliveries on an app. |
| hwhdvi | `heroku webhooks:deliveries:info`| info for a webhook event on an app. |
| hwhev | `heroku webhooks:events` | list webhook events on an app. |
| hwhevi | `heroku webhooks:events:info` | info for a webhook event on an app. |
| hwhi | `heroku webhooks:info` | info for a webhook on an app. |
| hwhr | `heroku webhooks:remove` | removes a webhook from an app. |
| hwhu | `heroku webhooks:update` | updates a webhook in an app. |
