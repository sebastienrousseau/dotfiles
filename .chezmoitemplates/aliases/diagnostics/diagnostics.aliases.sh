#!/usr/bin/env bash
# Diagnostics & Self-Healing Aliases

# Health Check
alias doc='bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh'
alias dot-doctor='doc'

# Detailed Doctor (with debug info)
alias doc-full='bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh && echo "\n--- Path Info ---" && echo $PATH | tr ":" "\n"'

if command -v chezmoi &>/dev/null; then
  # Drift Detection
  alias drift='chezmoi verify'
  alias dot-drift='drift'

  # Auto-Repair (Sync)
  alias heal='chezmoi apply --verbose'
  alias dot-heal='heal'

  # Chezmoi workflow helpers
  alias capply='dot apply'
  alias cupdate='dot update'
  alias cdiff='dot diff'
  alias crem='dot remove'
  alias cdrift='dot drift'
fi
