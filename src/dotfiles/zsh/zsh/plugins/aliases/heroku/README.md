# Dotfiles aliases

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

This aliases.zsh file creates helpful shortcut aliases for many commonly used commands.

## Table of Contents.

- [Dotfiles aliases](#dotfiles-aliases)
  - [Table of Contents.](#table-of-contents)
    - [1. Heroku Core aliases.](#1-heroku-core-aliases)
      - [1.1 Heroku Access aliases.](#11-heroku-access-aliases)
      - [1.2 Heroku Add-ons aliases.](#12-heroku-add-ons-aliases)
      - [1.3 Heroku Apps aliases.](#13-heroku-apps-aliases)
      - [1.4 Heroku Auth 2fa aliases.](#14-heroku-auth-2fa-aliases)
      - [1.5 Heroku Authorizations aliases.](#15-heroku-authorizations-aliases)
      - [1.6 Heroku Build packs aliases.](#16-heroku-build-packs-aliases)
      - [1.7 Heroku Certs aliases.](#17-heroku-certs-aliases)
      - [1.8 Heroku ci aliases.](#18-heroku-ci-aliases)
      - [1.9 Heroku config aliases.](#19-heroku-config-aliases)
    - [2. Heroku Configuration aliases.](#2-heroku-configuration-aliases)
      - [2.1 Heroku Container aliases.](#21-heroku-container-aliases)
      - [2.2 Heroku Domains aliases.](#22-heroku-domains-aliases)
      - [2.3 Heroku Drains aliases.](#23-heroku-drains-aliases)
      - [2.4 Heroku Dyno aliases.](#24-heroku-dyno-aliases)
      - [2.5 Heroku Features aliases.](#25-heroku-features-aliases)
      - [2.6 Heroku Git aliases.](#26-heroku-git-aliases)
      - [2.7 Heroku Keys aliases.](#27-heroku-keys-aliases)
      - [2.9 Heroku Labs aliases.](#29-heroku-labs-aliases)
    - [3. Heroku Advanced aliases.](#3-heroku-advanced-aliases)
      - [3.1 Heroku Local aliases.](#31-heroku-local-aliases)
      - [3.2 Heroku Maintenance aliases.](#32-heroku-maintenance-aliases)
      - [3.3 Heroku Members aliases.](#33-heroku-members-aliases)
      - [3.4 Heroku Postgres aliases.](#34-heroku-postgres-aliases)
      - [3.5 Heroku Pipelines aliases.](#35-heroku-pipelines-aliases)
      - [3.6 Heroku Plugins aliases.](#36-heroku-plugins-aliases)
      - [3.7 Heroku `ps` aliases.](#37-heroku-ps-aliases)
      - [3.8 Heroku redis aliases.](#38-heroku-redis-aliases)
      - [3.9 Heroku Releases aliases.](#39-heroku-releases-aliases)
      - [3.10.1 Heroku Spaces aliases.](#3101-heroku-spaces-aliases)
      - [3.10.2 Heroku Run aliases.](#3102-heroku-run-aliases)
      - [3.10.4 Heroku Sessions aliases.](#3104-heroku-sessions-aliases)
      - [3.10.5 Heroku Spaces aliases.](#3105-heroku-spaces-aliases)
      - [3.10.6 Heroku Webhooks aliases.](#3106-heroku-webhooks-aliases)

### 1. Heroku Core aliases.

#### 1.1 Heroku Access aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| h     | `heroku`                | Heroku CLI command shortcut.               |
| h:a   | `heroku access:add`     | Add new users to your app.                 |
| h:au   | `heroku access:update`  | Update existing collaborators on an team app. |
| h:h   | `heroku help`           | Display help for heroku.                   |
| h:ip | `heroku trusted-ips` | list trusted IP ranges for a space. |
| h:ipa | `heroku trusted-ips:add` | Add one range to the list of trusted IP ranges. |
| h:ipr | `heroku trusted-ips:remove` | Remove a range from the list of trusted IP ranges. |
| h:j   | `heroku join`           | Add yourself to a team app.                |
| h:l   | `heroku commands`       | List all the commands.                     |
| h:la  | `heroku access`         | List who has access to an app.             |
| h:lg  | `heroku logs`           | Display recent log output.                 |
| h:n   | `heroku notifications`  | Display notifications.                     |
| h:o   | `heroku orgs`           | List the teams that you are a member of.   |
| h:oo  | `heroku orgs:open`      | Open the team interface in a browser.      |
| h:p   | `heroku psql`           | Open a psql shell to the database.         |
| h:q   | `heroku leave`          | Remove yourself from a team app.           |
| h:r   | `heroku access:remove`  | Remove users from a team app.              |
| h:rg  | `heroku regions`        | List available regions for deployment.            |
| h:s | `heroku status`           | Display current status of the Heroku platform. |
| h:t | `heroku teams`            | List the teams that you are a member of. |
| h:u | `heroku update`           | Update the heroku CLI. |
| h:ulk | `heroku unlock`         | Unlock an app so any team member can join. |
| h:w | `heroku which`            | Show which plugin a command is in. |

#### 1.2 Heroku Add-ons aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| had:a | `heroku addons:attach` | Attach an existing add-on resource to an app.|
| had:c | `heroku addons:create` | Create a new add-on resource.                |
| had:d | `heroku addons:detach` | Detach an existing add-on resource from an app. |
| had:doc | `heroku addons:docs` | Open an add-on's Dev Center documentation in your browser. |
| had:down | `heroku addons:downgrade` | Change add-on plan. |
| had:i | `heroku addons:info` | Show detailed add-on resource and attachment information. |
| had:k | `heroku addons:destroy` | Permanently destroy an add-on resource.     |
| had:l  | `heroku addons` | Lists your add-ons and attachments.                 |
| had:o | `heroku addons:open` | Open an add-on's dashboard in your browser. |
| had:p | `heroku addons:plans` | List all available plans for an add-on services. |
| had:r | `heroku addons:rename` | Rename an add-on. |
| had:s | `heroku addons:services` | List all available add-on services. |
| had:u | `heroku addons:upgrade ` | Change add-on plan. |
| had:w | `heroku addons:wait` | Show provisioning status of the add-ons on the app. |

#### 1.3 Heroku Apps aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hap:c | `heroku apps:create` | Creates a new app. |
| hap:e | `heroku apps:errors` | View app errors. |
| hap:f | `heroku apps:favorites` | List favorites apps. |
| hap:fa | `heroku apps:favorites:add` | Favorites an app. |
| hap:fr | `heroku apps:favorites:remove` | Unfavorite an app. |
| hap:i | `heroku apps:info` | Show detailed app information. |
| hap:j | `heroku apps:join` | Add yourself to a team app. |
| hap:k | `heroku apps:destroy` | Permanently destroy an app. |
| hap:l | `heroku apps` | List your apps. |
| hap:lck | `heroku apps:lock` | Prevent team members from joining an app. |
| hap:o | `heroku apps:open` | Open the app in a web browser. |
| hap:q | `heroku apps:leave` | Remove yourself from a team app. |
| hap:r | `heroku apps:rename` | Rename an app. |
| hap:s | `heroku apps:stacks` | Show the list of available stacks. |
| hap:ss | `heroku apps:stacks:set` | Set the stack of an app. |
| hap:t | `heroku apps:transfer` | Transfer applications to another user or team. |
| hap:ulck | `heroku apps:unlock` | unlock an app so any team member can join. |

#### 1.4 Heroku Auth 2fa aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| h2fa:?| `heroku auth:whoami` | Display the current logged in user. |
| h2fa:d | `heroku auth:2fa:disable` | Disables 2fa on account. |
| h2fa:in | `heroku auth:login` | Login with your Heroku credentials. |
| h2fa:out | `heroku auth:logout` | Clears local login credentials and invalidates API session. |
| h2fa:s | `heroku auth:2fa` | Check 2fa status. |
| h2fa:t | `heroku auth:token` | Outputs current CLI authentication token. |

#### 1.5 Heroku Authorizations aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hauthz:c | `heroku authorizations:create` | Create a new OAuth authorization. |
| hauthz:i | `heroku authorizations:info` | Show an existing OAuth authorization. |
| hauthz:l | `heroku authorizations` | List OAuth authorizations. |
| hauthz:r | `heroku authorizations:revoke` | Revoke OAuth authorization. |
| hauthz:ro | `heroku authorizations:rotate` | Updates an OAuth authorization token. |
| hauthz:u | `heroku authorizations:update` | Updates an OAuth authorization. |

#### 1.6 Heroku Build packs aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hbps:ac | `heroku autocomplete` | Display autocomplete installation instructions. |
| hbps:add | `heroku buildpacks:add` | Add new app build-pack, inserting into list of build-packs if necessary. |
| hbps:cl | `heroku buildpacks:clear` | Clear all build-packs set on the app. |
| hbps:i | `heroku buildpacks:info` | Fetch info about a build-pack. |
| hbps:l | `heroku buildpacks` | Display the build-packs for an app. |
| hbps:r | `heroku buildpacks:remove` | Remove a build-pack set on the app. |
| hbps:s | `heroku buildpacks:search` | Search for build-packs. |
| hbps:v | `heroku buildpacks:versions` | List versions of a build-pack. |

#### 1.7 Heroku Certs aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hc:a | `heroku certs:auto` | Show ACM status for an app. |
| hc:ad | `heroku certs:add` | Add an SSL certificate to an app. |
| hc:ae | `heroku certs:auto:enable` | Enable ACM status for an app. |
| hc:ak | `heroku certs:auto:disable` | Disable ACM for an app. |
| hc:ar | `heroku certs:auto:refresh` | Refresh ACM for an app. |
| hc:c | `heroku certs:chain` | Print an ordered & complete chain for a certificate. |
| hc:g | `heroku certs:generate` | Generate a key and a CSR or self-signed certificate. |
| hc:i | `heroku certs:info` | Show certificate information for an SSL certificate. |
| hc:k | `heroku certs:key` | Print the correct key for the given certificate. |
| hc:l | `heroku certs` | List SSL certificates for an app. |
| hc:r | `heroku certs:remove` | Remove an SSL certificate from an app. |
| hc:u | `heroku certs:update` | Update an SSL certificate on an app. |

#### 1.8 Heroku ci aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hci:cg | `heroku ci:config:get` | Get a CI config var. |
| hci:cs | `heroku ci:config:set` | Set CI config vars. |
| hci:cu | `heroku ci:config:unset` | Unset CI config vars. |
| hci:cv | ` ci:config` | Display CI config vars. |
| hci:d | `heroku ci:debug` | Opens an interactive test debugging session with the contents of the current directory. |
| hci:e | `heroku ci:last` | Looks for the most recent run and returns the output of that run. |
| hci:i | `heroku ci:info` | Show the status of a specific test run. |
| hci:l | `heroku ci` | Display the most recent CI runs for the given pipeline. |
| hci:m | `heroku ci:migrate-manifest` | `app-ci.json` is deprecated. Run this command to migrate to app.json with an environments key. |
| hci:o | `heroku ci:open` | Open the Dashboard version of Heroku CI. |
| hci:r | `heroku ci:run` | Run tests against current directory. |
| hci:r2 | `heroku ci:rerun` | Rerun tests against current directory. |

#### 1.9 Heroku config aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hcl:c | `heroku clients:create` | Create a new OAuth client. |
| hcl:i | `heroku clients:info` | Show details of an oauth client. |
| hcl:k | `heroku clients:destroy` | Delete client by ID. |
| hcl:l | `heroku clients` | List your OAuth clients. |
| hcl:s | `heroku clients:rotate` | Rotate OAuth client secret. |
| hcl:u | `heroku clients:update` | Update OAuth client. |

### 2. Heroku Configuration aliases.
| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hcf:e | `heroku config:edit` | Interactively edit config vars. |
| hcf:g | `heroku config:get` | Display a single config value for an app. |
| hcf:s | `heroku config:set` | Set one or more config vars. |
| hcf:u | `heroku config:unset` | Unset one or more config vars. |
| hcf:v | `heroku config` | Display the config vars for an app. |

#### 2.1 Heroku Container aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hct | `heroku container` | Use containers to build and deploy Heroku apps. |
| hct:in | `heroku container:login` | Log in to Heroku Container Registry. |
| hct:out | `heroku container:logout` | Log out from Heroku Container Registry. |
| hct:pull | `heroku container:pull` | Pulls an image from an app's process type. |
| hct:push | `heroku container:push` | Builds, then pushes Docker images to deploy your Heroku app. |
| hct:release | `heroku container:release` | Releases previously pushed Docker images to your Heroku app. |
| hct:rm | `heroku container:rm` | Remove the process type from your app. |
| hct:run | `heroku container:run` | Builds, then runs the docker image locally. |

#### 2.2 Heroku Domains aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hdo | `heroku domains` | List domains for an app. |
| hdo:a | `heroku domains:add` | Add a domain to an app. |
| hdo:c | `heroku domains:clear` | Remove all domains from an app. |
| hdo:i | `heroku domains:info` | Show detailed information for a domain on an app. |
| hdo:r | `heroku domains:remove` | Remove a domain from an app. |
| hdo:u | `heroku domains:update` | Update a domain to use a different SSL certificate on an app. |
| hdo:w | `heroku domains:wait` | Wait for domain to be active for an app. |

#### 2.3 Heroku Drains aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hdr   | `heroku drains` | Display the log drains of an app. |
| hdr:a | `heroku drains:add` | Adds a log drain to an app. |
| hdr:r | `heroku drains:remove` | Removes a log drain from an app. |

#### 2.4 Heroku Dyno aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hdy:k | `heroku dyno:kill` | Stop app dyno. |
| hdy:rz | `heroku dyno:resize` | Manage dyno sizes. |
| hdy:rs | `heroku dyno:restart` | Restart app dynos. |
| hdy:sc | `heroku dyno:scale` | Scale dyno quantity up or down. |
| hdy:st | `heroku dyno:stop` | Stop app dyno. |

#### 2.5 Heroku Features aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hfeat | `heroku features` | List available app features. |
| hfeat:d | `heroku features:disable` | Disables an app feature. |
| hfeat:e | `heroku features:enable` | Enables an app feature. |
| hfeat:i | `heroku features:info` | Display information about a feature. |

#### 2.6 Heroku Git aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hgit:c | `heroku git:clone` | Clones a heroku app to your local machine at DIRECTORY (defaults to app name). |
| hgit:r | `heroku git:remote` | Adds a git remote to an app repo. |

#### 2.7 Heroku Keys aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hk | `heroku keys` | Display your SSH keys. |
| hk:a | `heroku keys:add` | Add an SSH key for a user. |
| hk:cl | `heroku keys:clear` | Remove all SSH keys for current user. |
| hk:r | `heroku keys:remove` | Remove an SSH key from the user. |

#### 2.9 Heroku Labs aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hlab | `heroku labs` | List experimental features. |
| hlab:d | `heroku labs:disable` | Disables an experimental feature. |
| hlab:e | `heroku labs:enable` | Enables an experimental feature. |
| hlab:i | `heroku labs:info` | Show feature info. |

### 3. Heroku Advanced aliases.

#### 3.1 Heroku Local aliases.
| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hloc | `heroku local` | Run heroku app locally. |
| hloc:r | `heroku local:run` | Run a one-off command. |
| hloc:v | `heroku local:version` | Display node-foreman version. |
| hloc:lck | `heroku lock` | Prevent team members from joining an app. |

#### 3.2 Heroku Maintenance aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hmt | `heroku maintenance` | display the current maintenance status of app. |
| hmt:off | `heroku maintenance:off` | take the app out of maintenance mode. |
| hmt:on | `heroku maintenance:on` | put the app into maintenance mode. |

#### 3.3 Heroku Members aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hmb   | `heroku members` | list members of a team. |
| hmb:a | `heroku members:add` | adds a user to a team. |
| hmb:r | `heroku members:remove` | removes a user from a team. |
| hmb:s | `heroku members:set` | sets a members role in a team. |

#### 3.4 Heroku Postgres aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hpg | `heroku pg` | Show database information. |
| hpg:b | `heroku pg:bloat` | Show table and index bloat in your database ordered by most wasteful. |
| hpg:bck | `heroku pg:backups` | List database backups. |
| hpg:bck:cc | `heroku pg:backups:cancel` | Cancel an in-progress backup or restore (default newest). |
| hpg:bck:cp | `heroku pg:backups:capture` | Capture a new backup. |
| hpg:bck:dl | `heroku pg:backups:delete` | Delete a backup. |
| hpg:bck:dn | `heroku pg:backups:download` | Downloads database backup. |
| hpg:bck:i | `heroku pg:backups:info` | Get information about a specific backup. |
| hpg:bck:rst | `heroku pg:backups:restore` | Restore a backup (default latest) to a database. |
| hpg:bck:sch | `heroku pg:backups:schedule` | Schedule daily backups for given database. |
| hpg:bck:schs | `heroku pg:backups:schedules` | List backup schedule. |
| hpg:bck:url | `heroku pg:backups:url` | Get secret but publicly accessible URL of a backup. |
| hpg:bck:usch | `heroku pg:backups:unschedule` | Stop daily backups. |
| hpg:blk | `heroku pg:blocking` | Display queries holding locks other queries are waiting to be released. |
| hpg:c | `heroku pg:copy` | Copy all data from source db to target. |
| hpg:cnp:a | `heroku pg:connection-pooling:attach` | Add an attachment to a database using connection pooling. |
| hpg:cr | `heroku pg:credentials` | Show information on credentials in the database. |
| hpg:cr:c | `heroku pg:credentials:create` | Create credential within database. |
| hpg:cr:d | `heroku pg:credentials:destroy` | Destroy credential within database. |
| hpg:cr:r | `heroku pg:credentials:rotate` | Rotate the database credentials. |
| hpg:cr:rd | `heroku pg:credentials:repair-default` | Repair the permissions of the default credential within database. |
| hpg:cr:url | `heroku pg:credentials:url` | Show information on a database credential. |
| hpg:dg | `heroku pg:diagnose` | Run or view diagnostics report. |
| hpg:i | `heroku pg:info` | Show database information. |
| hpg:k | `heroku pg:kill` | Kill a query. |
| hpg:ka | `heroku pg:killall` | Terminates all connections for all credentials. |
| hpg:lks | `heroku pg:locks` | Display queries with active locks. |
| hpg:lnk | `heroku pg:links` | Lists all databases and information on link. |
| hpg:lnk:c | `heroku pg:links:create` | Create a link between data stores. |
| hpg:lnk:d | `heroku pg:links:destroy` | Destroys a link between data stores. |
| hpg:mt | `heroku pg:maintenance` | Show current maintenance information. |
| hpg:mt:r | `heroku pg:maintenance:run` | Start maintenance. |
| hpg:mt:w | `heroku pg:maintenance:window` | Set weekly maintenance window. |
| hpg:o | `heroku pg:outliers` | Show 10 queries that have longest execution time in aggregate. |
| hpg:p | `heroku pg:promote` | Sets DATABASE as your DATABASE_URL. |
| hpg:ps | `heroku pg:ps` | View active queries with execution time. |
| hpg:psql | `heroku pg:psql` | Open a psql shell to the database. |
| hpg:pull | `heroku pg:pull` | Pull Heroku database into local or remote database. |
| hpg:push | `heroku pg:push` | Push local or remote into Heroku database. |
| hpg:reset | `heroku pg:reset` | Delete all data in DATABASE. |
| hpg:set | `heroku pg:settings` | Show your current database settings. |
| hpg:set:llw    | `heroku pg:settings:log-lock-waits` | Controls whether a log message is produced when a session waits longer than the deadlock_timeout to acquire a lock. deadlock_timeout is se... . |
| hpg:set:lmds | `heroku pg:settings:log-min-duration-statement` | The duration of each completed statement will be logged if the statement completes after the time specified by VALUE. |
| hpg:set:log-statement | `heroku pg:settings:log-statement` | `log_statement` controls which SQL statements are logged. |
| hpg:up | `heroku pg:upgrade` | Unfollow a database and upgrade it to the latest stable PostgreSQL version. |
| hpg:vs | `heroku pg:vacuum-stats` | Show dead rows and whether an automatic vacuum is expected to be triggered. |
| hpg:ww | `heroku pg:wait` | Blocks until database is available. |
| pg:uf | `heroku pg:unfollow` | Stop a replica from following and make it a writeable database. |

#### 3.5 Heroku Pipelines aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hpipe | `heroku pipelines` | List pipelines you have access to. |
| hpipe:a | `heroku pipelines:add` | Add this app to a pipeline. |
| hpipe:c | `heroku pipelines:create` | Create a new pipeline. |
| hpipe:ct | `heroku pipelines:connect` | Connect a github repo to an existing pipeline. |
| hpipe:diff | `heroku pipelines:diff` | Compares the latest release of this app to its downstream app(s). |
| hpipe:i | `heroku pipelines:info` | Show list of apps in a pipeline. |
| hpipe:k | `heroku pipelines:destroy` | Destroy a pipeline. |
| hpipe:o | `heroku pipelines:open` | Open a pipeline in dashboard. |
| hpipe:p | `heroku pipelines:promote` | Promote the latest release of this app to its downstream app(s). |
| hpipe:r | `heroku pipelines:remove` | Remove this app from its pipeline. |
| hpipe:rn | `heroku pipelines:rename` | Rename a pipeline. |
| hpipe:s | `heroku pipelines:setup` | Bootstrap a new pipeline with common settings and create a production and staging app (requires a fully formed app.json in the repo). |
| hpipe:tt | `heroku pipelines:transfer` | Transfer ownership of a pipeline. |
| hpipe:u | `heroku pipelines:update` | Update the app's stage in a pipeline. |

#### 3.6 Heroku Plugins aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hplugs | `heroku plugins` | List installed plugins. |
| hplugs:i | `heroku plugins:install` | Installs a plugin into the CLI. |
| hplugs:lk | `heroku plugins:link` | Links a plugin into the CLI for development. |
| hplugs:ui | `heroku plugins:uninstall` | Removes a plugin from the CLI. |
| hplugs:u | `heroku plugins:update` | Update installed plugins. |

#### 3.7 Heroku `ps` aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hps     | `heroku ps` | List dynos for an app. |
| hps:ad  | `heroku ps:autoscale:disable` | Disable web dyno autoscaling. |
| hps:ae  | `heroku ps:autoscale:enable ` | Enable web dyno autoscaling. |
| hps:c   | `heroku ps:copy` | Copy a file from a dyno to the local filesystem. |
| hps:e   | `heroku ps:exec` | Create an SSH session to a dyno. |
| hps:f   | `heroku ps:forward` | Forward traffic on a local port to a dyno. |
| hps:k   | `heroku ps:kill` | Stop app dyno. |
| hps:r   | `heroku ps:restart` | Restart app dynos. |
| hps:rs  | `heroku ps:resize` | Manage dyno sizes. |
| hps:s   | `heroku ps:stop` | Stop app dyno. |
| hps:sc  | `heroku ps:scale` | Scale dyno quantity up or down. |
| hps:sck | `heroku ps:socks` | Launch a SOCKS proxy into a dyno. |
| hps:t   | `heroku ps:type` | Manage dyno sizes. |
| hps:w   | `heroku ps:wait` | Wait for all dynos to be running latest version after a release. |

#### 3.8 Heroku redis aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hred | `heroku redis` | Gets information about redis. |
| hred:cli | `heroku redis:cli` | Opens a redis prompt. |
| hred:cr | `heroku redis:credentials` | Display credentials information. |
| hred:i | `heroku redis:info` | Gets information about redis. |
| hred:kn | `heroku redis:keyspace-notifications` | Set the keyspace notifications configuration. |
| hred:mm | `heroku redis:maxmemory` | Set the key eviction policy. |
| hred:mt | `heroku redis:maintenance` | Manage maintenance windows. |
| hred:p | `heroku redis:promote` | Sets DATABASE as your REDIS_URL. |
| hred:sr | `heroku redis:stats-reset` | Reset all stats covered by RESETSTAT (https://redis.io/commands/config-resetstat). |
| hred:t | `heroku redis:timeout` | Set the number of seconds to wait before killing idle connections. |
| hred:w | `heroku redis:wait` | Wait for Redis instance to be available. |

#### 3.9 Heroku Releases aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hrel | `heroku releases` | Display the releases for an app. |
| hrel:i | `heroku releases:info` | View detailed information for a release. |
| hrel:o | `heroku releases:output` | View the release command output. |
| hrel:r | `heroku releases:rollback` | Rollback to a previous release. |

#### 3.10.1 Heroku Spaces aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hrva:d | `heroku reviewapps:disable` | Disable review apps and/or settings on an existing pipeline. |
| hrva:e | `heroku reviewapps:enable` | Enable review apps and/or settings on an existing pipeline. |

#### 3.10.2 Heroku Run aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hrun | `heroku run` | Run a one-off process inside a heroku dyno. |
| hrun:d | `heroku run:detached` | Run a detached dyno, where output is sent to your logs. |

#### 3.10.4 Heroku Sessions aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hsessions | `heroku sessions` | List your OAuth sessions. |
| hsessions:d | `heroku sessions:destroy` | Delete (logout) OAuth session by ID. |

#### 3.10.5 Heroku Spaces aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hsp     | `heroku spaces` | List available spaces. |
| hsp:c   | `heroku spaces:create` | Create a new space. |
| hsp:d   | `heroku spaces:destroy` | Destroy a space. |
| hsp:i   | `heroku spaces:info` | Show info about a space. |
| hsp:pi  | `heroku spaces:peering:info` | Display the information necessary to initiate a peering connection. |
| hsp:p   | `heroku spaces:peerings` | List peering connections for a space. |
| hsp:pa  | `heroku spaces:peerings:accept ` | Accepts a pending peering request for a private space. |
| hsp:pd  | `heroku spaces:peerings:destroy` | Destroys an active peering connection in a private space. |
| hsp:ps  | `heroku spaces:ps` | List dynos for a space. |
| hsp:r   | `heroku spaces:rename` | Renames a space. |
| hsp:t   | `heroku spaces:topology` | Show space topology. |
| hsp:t   | `heroku spaces:transfer` | Transfer a space to another team. |
| hsp:v   | `heroku spaces:vpn:config` | Display the configuration information for VPN. |
| hsp:v   | `heroku spaces:vpn:connect` | Create VPN. |
| hsp:v   | `heroku spaces:vpn:connections` | List the VPN Connections for a space. |
| hsp:v   | `heroku spaces:vpn:destroy` | Destroys VPN in a private space. |
| hsp:v   | `heroku spaces:vpn:info` | Display the information for VPN. |
| hsp:v   | `heroku spaces:vpn:update` | Update VPN. |
| hsp:v   | `heroku spaces:vpn:wait` | Wait for VPN Connection to be created. |
| hsp:w   | `heroku spaces:wait` | Wait for a space to be created. |

#### 3.10.6 Heroku Webhooks aliases.

| Alias     | Command             | Description                                |
|-----------|---------------------|--------------------------------------------|
| hwh  | `heroku webhooks` | list webhooks on an app. |
| hwh:a| `heroku webhooks:add` | add a webhook to an app. |
| hwh:dv| `heroku webhooks:deliveries` | list webhook deliveries on an app. |
| hwh:dvi| `heroku webhooks:deliveries:info` | info for a webhook event on an app. |
| hwh:ev| `heroku webhooks:events` | list webhook events on an app. |
| hwh:evi| `heroku webhooks:events:info` | info for a webhook event on an app. |
| hwh:i| `heroku webhooks:info` | info for a webhook on an app. |
| hwh:r| `heroku webhooks:remove` | removes a webhook from an app. |
| hwh:u| `heroku webhooks:update` | updates a webhook in an app. |
