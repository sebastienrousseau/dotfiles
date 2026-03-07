# shellcheck shell=bash
# Heroku Postgres aliases
[[ -n "${_HEROKU_POSTGRES_LOADED:-}" ]] && return 0
_HEROKU_POSTGRES_LOADED=1

# hkpg: Show database information.
alias hkpg='heroku pg'

# hkpgb: Show table and index bloat in your database ordered by most wasteful.
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

# hkpgblk: Display queries holding locks other queries are waiting to be released.
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

# hkpgcrrd: Repair the permissions of the default credential within database.
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

# hkpgo: Show 10 queries that have longest execution time in aggregate.
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

# hkpgset: Show your current database settings.
alias hkpgset='heroku pg:settings'

# hkpgsetllw: Controls log message production for lock waits.
alias hkpgsetllw='heroku pg:settings:log-lock-waits'

# hkpgsetlmds: Log duration for completed statements.
alias hkpgsetlmds='heroku pg:settings:log-min-duration-statement'

# hkpgsetlgs: Controls which SQL statements are logged.
alias hkpgsetlgs='heroku pg:settings:log-statement'

# hkpguf: Stop a replica from following and make it a writeable database.
alias hkpguf='heroku pg:unfollow'

# hkpgup: Unfollow a database and upgrade it to the latest stable PostgreSQL version.
alias hkpgup='heroku pg:upgrade'

# hkpgvs: Show dead rows and whether an automatic vacuum is expected to be triggered.
alias hkpgvs='heroku pg:vacuum-stats'

# hkpgww: Blocks until database is available.
alias hkpgww='heroku pg:wait'
