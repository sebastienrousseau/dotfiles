# shellcheck shell=bash
# Heroku Certs aliases
[[ -n "${_HEROKU_CERTS_LOADED:-}" ]] && return 0
_HEROKU_CERTS_LOADED=1

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
