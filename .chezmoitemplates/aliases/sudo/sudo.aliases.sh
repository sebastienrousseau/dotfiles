# shellcheck shell=bash
# 🆂🆄🅳🅾 🅰🅻🅸🅰🆂🅴🆂

# Execute a command as the superuser.
alias root='s'

# Execute a command as the superuser.
alias s='sudo -i'

# Execute a command as the superuser.
if [[ "${DOTFILES_ENABLE_SU_ALIAS:-0}" == "1" ]]; then
  alias su='sudo su'
fi

# Risky command shadowing aliases are opt-in.
if [[ "${DOTFILES_ENABLE_SUDO_ALIAS:-0}" == "1" ]]; then
  alias sudo='s'
fi
