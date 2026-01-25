#!/usr/bin/env bash
# Linux tuning (opt-in)

set -euo pipefail

if [[ "${DOTFILES_TUNING:-0}" != "1" ]]; then
  echo "Tuning is disabled. Re-run with DOTFILES_TUNING=1 to apply."
  exit 0
fi

if [[ "${DOTFILES_PROFILE:-}" != "laptop" && "${DOTFILES_PROFILE:-}" != "desktop" && "${DOTFILES_PROFILE:-}" != "server" ]]; then
  echo "DOTFILES_PROFILE is not set to a known profile. Aborting."
  exit 1
fi

echo "Applying Linux tuning..."

# NOTE: sysctl changes require sudo/root.
if command -v sudo >/dev/null; then
  sudo sysctl -w fs.inotify.max_user_watches=524288
  sudo sysctl -w vm.swappiness=10
else
  echo "sudo not available; skipping sysctl tuning."
fi

echo "Linux tuning complete."
