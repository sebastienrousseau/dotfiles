# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# 🆂🆄🅳🅾 🅰🅻🅸🅰🆂🅴🆂

# Canonical superuser shell alias.
alias sudoi='sudo -i'

# Quick sudo prefix (matches user habit).
alias _='sudo '

# Optional short alias; disabled by default to avoid collisions with other
# command families (e.g. svn `s*` mnemonics).
if [[ "${DOTFILES_ENABLE_SHORT_SUDO:-0}" == "1" ]]; then
  alias s='sudoi'
fi

# Execute a command as the superuser.
if [[ "${DOTFILES_ENABLE_SU_ALIAS:-0}" == "1" ]]; then
  alias su='sudo su'
fi

# Risky command shadowing aliases are opt-in.
if [[ "${DOTFILES_ENABLE_SUDO_ALIAS:-0}" == "1" ]]; then
  alias sudo='sudoi'
fi
