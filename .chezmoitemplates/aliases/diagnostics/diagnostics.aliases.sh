#!/usr/bin/env bash
# Diagnostics & Self-Healing Aliases

# Health Check
alias dotdoc='bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh'
alias dot-doctor='dotdoc'

# Detailed Doctor (with debug info)
alias dotdoc-full='bash $HOME/.dotfiles/scripts/diagnostics/doctor.sh && echo "\n--- Path Info ---" && echo $PATH | tr ":" "\n"'

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
  alias ca='chezmoi apply'
  alias ce='chezmoi edit'
  cdot() {
    cd "$(chezmoi source-path)" || return 1
  }
fi
