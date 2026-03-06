# shellcheck shell=bash
# Heroku PS aliases
[[ -n "${_HEROKU_PS_LOADED:-}" ]] && return 0
_HEROKU_PS_LOADED=1

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

# hkpsw: Wait for all dynos to be running latest version after a release.
alias hkpsw='heroku ps:wait'
