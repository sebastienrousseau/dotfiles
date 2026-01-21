#!/usr/bin/env bash
# Diagnostics & Self-Healing Aliases

# Health Check
alias doc='bash $HOME/.local/share/chezmoi/scripts/doctor.sh'
alias dot-doctor='doc'

# Drift Detection
alias drift='chezmoi verify'
alias dot-drift='drift'

# Auto-Repair (Sync)
alias heal='chezmoi apply --verbose'
alias dot-heal='heal'

# Detailed Doctor (with debug info)
alias doc-full='bash $HOME/.local/share/chezmoi/scripts/doctor.sh && echo "\n--- Path Info ---" && echo $PATH | tr ":" "\n"'
