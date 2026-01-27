#!/usr/bin/env bash
# Immutability Aliases
# Wrappers for the lock-configs script.

script_path="${HOME}/.local/share/chezmoi/scripts/security/lock-configs.sh"

if [[ -f "$script_path" ]]; then
  alias lock-configs="bash $script_path lock"
  alias unlock-configs="bash $script_path unlock"
  alias check-locks="bash $script_path check" # Script needs to handle check or default triggers it
fi
