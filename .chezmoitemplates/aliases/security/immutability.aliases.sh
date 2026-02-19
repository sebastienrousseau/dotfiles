# shellcheck shell=bash
# Immutability Aliases
# Wrappers for the lock-configs script.

script_path="${HOME}/.local/share/chezmoi/scripts/security/lock-configs.sh"

if [[ -f "$script_path" ]]; then
  # shellcheck disable=SC2139 # Intentional expansion at definition time
  alias lock-configs="bash $script_path lock"
  # shellcheck disable=SC2139
  alias unlock-configs="bash $script_path unlock"
  # shellcheck disable=SC2139
  alias check-locks="bash $script_path check"
fi
