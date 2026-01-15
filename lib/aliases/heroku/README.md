<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🅷🅴🆁🅾🅺🆄 🅰🅻🅸🅰🆂🅴🆂

This is a collection of aliases for the
[Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli).

### 1. Heroku Core aliases

#### 1.1 Heroku Access aliases

- `hkk` Heroku CLI command shortcut.
- `hka` Add new users to your app.
- `hkau` Update existing collaborators on an team app.
- `hkh` Display help for heroku.
- `hkj` Add yourself to a team app.
- `hkl` List all the commands.
- `hkla` List who has access to an app.
- `hklg` Display recent log output.
- `hkn` Display notifications.
- `hko` List the teams that you are a member of.
- `hkoo` Open the team interface in a browser.
- `hkp` Open a psql shell to the database.
- `hkq` Remove yourself from a team app.
- `hkr` Remove users from a team app.
- `hkrg` List available regions for deployment.
- `hks` Display current status of the Heroku platform.
- `hkt` List the teams that you are a member of.
- `hku` Update the heroku CLI.
- `hkulk` Unlock an app so any team member can join.
- `hkw` Show which plugin a command is in

#### 1.2 Heroku Add-ons aliases

- `hkada` Attach an existing add-on resource to an app
- `hkadc` Create a new add-on resource
- `hkadd` Detach an existing add-on resource from an app
- `hkaddoc` Open an add-on's Dev Center documentation in your browser
- `hkaddown` Change add-on plan
- `hkadi` Show detailed add-on resource and attachment information
- `hkadk` Permanently destroy an add-on resource
- `hkadl` Lists your add-ons and attachments
- `hkado` Open an add-on's dashboard in your browser
- `hkadp` List all available plans for an add-on services
- `hkadr` Rename an add-on
- `hkads` List all available add-on services
- `hkadu` Change add-on plan
- `hkadw` Show provisioning status of the add-ons on the app

#### 1.3 Heroku Apps aliases

- `hkapc` Creates a new app
- `hkape` View app errors
- `hkapfav` List favorites apps
- `hkapfava` Favorites an app
- `hkapunfav` Unfavorite an app
- `hkapi` Show detailed app information
- `hkapj` Add yourself to a team app
- `hkapk` Permanently destroy an app
- `hkapl` List your apps
- `hkaplk` Prevent team members from joining an app
- `hkapo` Open the app in a web browser
- `hkapq` Remove yourself from a team app
- `hkapr` Rename an app
- `hkaps` Show the list of available stacks
- `hkapss` Set the stack of an app
- `hkapt` Transfer applications to another user or team
- `hkapulk` Unlock an app so any team member can join

#### 1.4 Heroku Auth 2fa aliases

- `hk2fa` Display the current logged in user
- `hk2fad` Disables 2fa on account
- `hk2fain` Login with your Heroku credentials
- `hk2faout` Clears local login credentials and invalidates API session
- `hk2fas` Check 2fa status
- `hk2fat` Outputs current CLI authentication token

#### 1.5 Heroku Authorizations aliases

- `hkauc` Create a new OAuth authorization
- `hkaui` Show an existing OAuth authorization
- `hkaul` List OAuth authorizations.
- `hkaur` Revoke OAuth authorization.
- `hkauro` Updates an OAuth authorization token.
- `hkauu` Updates an OAuth authorization

#### 1.6 Heroku Build packs aliases

- `hkbpac` Display autocomplete installation instructions
- `hkbpad` Add new app build-pack, inserting into list of build-packs if
  necessary
- `hkbpcl` Clear all build-packs set on the app
- `hkbpi` Fetch info about a build-pack
- `hkbpl` Display the build-packs for an app
- `hkbpr` Remove a build-pack set on the app
- `hkbps` Search for build-packs
- `hkbpv` List versions of a build-pack.

#### 1.7 Heroku Certs aliases

- `hkca` Show ACM status for an app
- `hkcad` Add an SSL certificate to an app
- `hkcae` Enable ACM status for an app
- `hkcak` Disable ACM for an app
- `hkcar` Refresh ACM for an app
- `hkcc` Print an ordered & complete chain for a certificate
- `hkcg` Generate a key and a CSR or self-signed certificate
- `hkci` Show certificate information for an SSL certificate
- `hkck` Print the correct key for the given certificate
- `hkcl` List SSL certificates for an app
- `hkcr` Remove an SSL certificate from an app
- `hkcu` Update an SSL certificate on an app

#### 1.8 Heroku ci aliases

- `hkcicg` Get a CI config var
- `hkcics` Set CI config vars
- `hkcicu` Unset CI config vars
- `hkcicv`  Display CI config vars
- `hkcid` Opens an interactive test debugging session with the contents
  of the current directory
- `hkcie` Looks for the most recent run and returns the output of that
  run
- `hkcii` Show the status of a specific test run
- `hkcil` Display the most recent CI runs for the given pipeline
- `hkcim` 'app-ci.json' is deprecated. Run this command to migrate to
  app.json with an environments key
- `hkcio` Open the Dashboard version of Heroku CI
- `hkcir` Run tests against current directory
- `hkcir2` Rerun tests against current directory

#### 1.9 Heroku config aliases

- `hkclc` Create a new OAuth client
- `hkcli` Show details of an oauth client
- `hkclk` Delete client by ID
- `hkcll` List your OAuth clients
- `hkcls` Rotate OAuth client secret
- `hkclu` Update OAuth client.

### 2. Heroku Configuration aliases

- `hkcfe` Interactively edit config vars
- `hkcfg` Display a single config value for an app
- `hkcfs` Set one or more config vars
- `hkcfu` Unset one or more config vars
- `hkcfv` Display the config vars for an app

#### 2.1 Heroku Container aliases

- `hkct` Use containers to build and deploy Heroku apps
- `hkctin` Log in to Heroku Container Registry
- `hkctout` Log out from Heroku Container Registry
- `hkctpull` Pulls an image from an app's process type
- `hkctpush` Builds, then pushes Docker images to deploy your Heroku app
- `hkctrelease` Releases previously pushed Docker images to your Heroku
  app
- `hkctrm` Remove the process type from your app
- `hkctrun` Builds, then runs the docker image locally

#### 2.2 Heroku Domains aliases

- `hkdo` List domains for an app
- `hkdoa` Add a domain to an app
- `hkdoc` Remove all domains from an app
- `hkdoi` Show detailed information for a domain on an app
- `hkdor` Remove a domain from an app
- `hkdou` Update a domain to use a different SSL certificate on an app
- `hkdow` Wait for domain to be active for an app

#### 2.3 Heroku Drains aliases

- `hkdr` Display the log drains of an app
- `hkdra` Adds a log drain to an app
- `hkdrr` Removes a log drain from an app

#### 2.4 Heroku Dyno aliases

- `hkdyk` Stop app dyno
- `hkdyrz` Manage dyno sizes
- `hkdyrs` Restart app dynos
- `hkdysc` Scale dyno quantity up or down
- `hkdyst` Stop app dyno

#### 2.5 Heroku Features aliases

- `hkfeat` List available app features
- `hkfeatd` Disables an app feature
- `hkfeate` Enables an app feature
- `hkfeati` Display information about a feature

#### 2.6 Heroku Git aliases

- `hkgitc` Clones a heroku app to your local machine at DIRECTORY
  (defaults to app name)
- `hkgitr` Adds a git remote to an app repo

#### 2.7 Heroku Keys aliases

- `hkk` Display your SSH keys
- `hkka` Add an SSH key for a user
- `hkkcl` Remove all SSH keys for current user
- `hkkr` Remove an SSH key from the user

#### 2.8 Heroku Labs aliases

- `hklab` List experimental features
- `hklabd` Disables an experimental feature
- `hklabe` Enables an experimental feature
- `hklabi` Show feature info

### 3. Heroku Advanced aliases

#### 3.1 Heroku Local aliases

- `hkloc` Run heroku app locally
- `hklocr` Run a one-off command
- `hklocv` Display node-foreman version
- `hkloclk` Prevent team members from joining an app

#### 3.2 Heroku Maintenance aliases

- `hkmt` Display the current maintenance status of app
- `hkmtoff` Take the app out of maintenance mode
- `hkmton` Put the app into maintenance mode

#### 3.3 Heroku Members aliases

- `hkmb` List members of a team
- `hkmba` Adds a user to a team
- `hkmbr` Removes a user from a team
- `hkmbs` Sets a members role in a team.

#### 3.4 Heroku Postgres aliases

- `hkpg` Show database information
- `hkpgb` Show table and index bloat in your database ordered by most
  wasteful
- `hkpgbk` List database backups
- `hkpgbkcl` Cancel an in-progress backup or restore (default newest)
- `hkpgbkc` Capture a new backup
- `hkpgbkdl` Delete a backup
- `hkpgbkdw` Downloads database backup
- `hkpgbki` Get information about a specific backup
- `hkpgbkr` Restore a backup (default latest) to a database
- `hkpgbks` Schedule daily backups for given database
- `hkpgbksh` List backup schedule
- `hkpgbkurl` Get secret but publicly accessible URL of a backup
- `hkpgbkk` Stop daily backups
- `hkpgblk` Display queries holding locks other queries are waiting to
  be released
- `hkpgc` Copy all data from source db to target
- `hkpgcpa` Add an attachment to a database using connection pooling
- `hkpgcr` Show information on credentials in the database
- `hkpgcrc` Create credential within database
- `hkpgcrd` Destroy credential within database
- `hkpgcrr` Rotate the database credentials
- `hkpgcrrd` Repair the permissions of the default credential within
  database
- `hkpgcrurl` Show information on a database credential
- `hkpgdg` Run or view diagnostics report
- `hkpgi` Show database information
- `hkpgk` Kill a query
- `hkpgka` Terminates all connections for all credentials
- `hkpglks` Display queries with active locks
- `hkpglnk` Lists all databases and information on link
- `hkpglnkc` Create a link between data stores
- `hkpglnkd` Destroys a link between data stores
- `hkpgmt` heroku pg:maintenance'
- `hkpgmtr` Start maintenance
- `hkpgmtw` Set weekly maintenance window
- `hkpgo` Show 10 queries that have longest execution time in aggregate
- `hkpgp` Sets DATABASE as your DATABASE_URL
- `hkpgps` View active queries with execution time
- `hkpgpsql` Open a psql shell to the database
- `hkpgpull` Pull Heroku database into local or remote database
- `hkpgpush` Push local or remote into Heroku database
- `hkpgreset` Delete all data in DATABASE
- `hkpgset` Show your current database settings
- `hkpgsetllw` Controls whether a log message is produced when a session
  waits longer than the deadlock_timeout to acquire a lock.
- `hkpgsetlmds` The duration of each completed statement will be logged
  if the statement completes after the time specified by VALUE
- `hkpgsetlgs` 'log_statement' controls which SQL statements are logged
- `hkpguf` Stop a replica from following and make it a writeable
  database
- `hkpgup` Unfollow a database and upgrade it to the latest stable
  PostgreSQL version
- `hkpgvs` Show dead rows and whether an automatic vacuum is expected
  to be triggered
- `hkpgww` Blocks until database is available

#### 3.5 Heroku Pipelines aliases

- `hkpipe` List pipelines you have access to
- `hkpipea` Add this app to a pipeline
- `hkpipec` Create a new pipeline
- `hkpipect` Connect a github repo to an existing pipeline
- `hkpipediff` Compares the latest release of this app to its downstream
  app(s)
- `hkpipei` Show list of apps in a pipeline
- `hkpipek` Destroy a pipeline
- `hkpipeo` Open a pipeline in dashboard
- `hkpipep` Promote the latest release of this app to its downstream
  app(s)
- `hkpiper` heroku pipelines:remove'Remove this app from its pipeline
- `hkpipern` Rename a pipeline
- `hkpipes` Bootstrap a new pipeline with common settings and create a
  production and staging app (requires a fully formed app.json in the
  repo)
- `hkpipett` Transfer ownership of a pipeline
- `hkpipeu` Update the app's stage in a pipeline

#### 3.6 Heroku Plugins aliases

- `hkplugs` List installed plugins
- `hkplugsi` Installs a plugin into the CLI
- `hkplugslk` Links a plugin into the CLI for development
- `hkplugsui` Removes a plugin from the CLI
- `hkplugsu` Update installed plugins

#### 3.7 Heroku 'ps' aliases

- `hkpsad` Disable web dyno autoscaling
- `hkps` List dynos for an app
- `hkpsae` Enable web dyno autoscaling
- `hkpsc` Copy a file from a dyno to the local filesystem
- `hkpse` Create an SSH session to a dyno
- `hkpsf` Forward traffic on a local port to a dyno
- `hkpsk` Stop app dyno
- `hkpsr` Restart app dynos
- `hkpsrs` Manage dyno sizes
- `hkpss` Stop app dyno
- `hkpssc` Scale dyno quantity up or down
- `hkpssck` Launch a SOCKS proxy into a dyno
- `hkpst` Manage dyno sizes
- `hkpsw` Wait for all dynos to be running latest version after a
  release

#### 3.8 Heroku redis aliases

- `hkred` Gets information about redis
- `hkredcli` Opens a redis prompt
- `hkredcr` Display credentials information
- `hkredi` Gets information about redis
- `hkredkn` Set the keyspace notifications configuration
- `hkredmm` Set the key eviction policy
- `hkredmt` Manage maintenance windows
- `hkredp` Sets DATABASE as your REDIS_URL
- `hkredsr` Reset all stats covered by RESETSTAT
  (<https://redis.io/commands/config-resetstat>)
- `hkredt` Set the number of seconds to wait before killing idle
  connections
- `hkredw` Wait for Redis instance to be available

#### 3.9 Heroku Releases aliases

- `hkrel` Display the releases for an app
- `hkreli` View detailed information for a release
- `hkrelo` View the release command output
- `hkrelr` Rollback to a previous release

#### 3.10.1 Heroku Spaces aliases

- `hkrvae` Enable review apps and/or settings on an existing pipeline
- `hkrvad` Disable review apps and/or settings on an existing pipeline

#### 3.10.2 Heroku Run aliases

- `hkrun` Run a one-off process inside a heroku dyno
- `hkrund` Run a detached dyno, where output is sent to your logs

#### 3.10.3 Heroku Sessions aliases

- `hksessions` List your OAuth sessions
- `hksessionsd` Delete (logout) OAuth session by ID

#### 3.10.4 Heroku Spaces aliases

- `hksp` List available spaces
- `hkspc` Create a new space
- `hkspd` Destroy a space
- `hkspi` Show info about a space
- `hksppi` Display the information necessary to initiate a peering
  connection
- `hkspp` List peering connections for a space
- `hksppa` Accepts a pending peering request for a private space
- `hksppd` Destroys an active peering connection in a private space
- `hkspps` List dynos for a space
- `hkspr` Renames a space
- `hksptop` Show space topology
- `hkspt` Transfer a space to another team
- `hkspconf` Display the configuration information for VPN
- `hkspvc` Create VPN
- `hkspvcs` List the VPN Connections for a space
- `hkspvk` Destroys VPN in a private space
- `hkspvi` Display the information for VPN
- `hkspvu` Update VPN
- `hkspvw` Wait for VPN Connection to be created
- `hkspw` Wait for a space to be created

#### 3.10.5 Heroku Webhooks aliases

- `hkwh` List webhooks on an app
- `hkwha` Add a webhook to an app
- `hkwhdv` List webhook deliveries on an app
- `hkwhdvi` Info for a webhook event on an app
- `hkwhev` List webhook events on an app
- `hkwhevi` Info for a webhook event on an app
- `hkwhi` Info for a webhook on an app
- `hkwhr` Removes a webhook from an app
- `hkwhu` Updates a webhook in an app

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
