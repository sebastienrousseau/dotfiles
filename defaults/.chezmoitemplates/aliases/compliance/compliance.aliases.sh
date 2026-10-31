# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Compliance & Privacy Aliases

# Privacy Mode: Disables telemetry for common CLI tools
privacy_mode_fn() {
  export DOTNET_CLI_TELEMETRY_OPTOUT=1
  export HOMEBREW_NO_ANALYTICS=1
  export AZURE_CORE_COLLECT_TELEMETRY=0
  export FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT=1
  export SAM_CLI_TELEMETRY=0
  export STRIPE_TELEMETRY_OPTOUT=1
  export GATSBY_TELEMETRY_DISABLED=1
  export NEXT_TELEMETRY_DISABLED=1

  echo " Privacy Mode Enabled: Telemetry disabled for active session."
  echo "   (Dotnet, Homebrew, Azure, Stripe, Gatsby, Next.js)"
}

alias privacy-mode=privacy_mode_fn

# Audit Trail: the dot CLI's own log (lib/dot/log.sh), else git history
audit_fn() {
  local log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/dot.log"
  echo " Configuration Audit Trail (Recent Changes)"
  echo "---------------------------------------------"
  if [[ -f "$log" ]]; then
    tail -n 20 "$log"
  else
    # Fallback to git log when dot has not logged anything yet
    git -C "${DOTFILES_DIR:-$HOME/.dotfiles}" log --oneline -n 10 --format="%C(auto)%h %C(blue)%ad %C(reset)%s (%an)" --date=short
  fi
}

alias dot-audit=audit_fn
