# shellcheck shell=bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Immutability Aliases
# Wrappers for the lock-configs script.

# The source checkout ($DOTFILES_DIR, ~/.dotfiles by default), then the
# legacy chezmoi source location.
for script_path in "${DOTFILES_DIR:-$HOME/.dotfiles}/scripts/security/lock-configs.sh" \
  "${HOME}/.local/share/chezmoi/scripts/security/lock-configs.sh"; do
  [[ -f "$script_path" ]] && break
done

if [[ -f "$script_path" ]]; then
  # shellcheck disable=SC2139 # Intentional expansion at definition time
  alias lock-configs="bash $(printf %q "$script_path") lock"
  # shellcheck disable=SC2139
  alias unlock-configs="bash $(printf %q "$script_path") unlock"
  # shellcheck disable=SC2139
  alias check-locks="bash $(printf %q "$script_path") check"
fi
