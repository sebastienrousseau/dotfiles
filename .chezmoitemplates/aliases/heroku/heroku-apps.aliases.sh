# shellcheck shell=bash
# Heroku Apps aliases
[[ -n "${_HEROKU_APPS_LOADED:-}" ]] && return 0
_HEROKU_APPS_LOADED=1

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
