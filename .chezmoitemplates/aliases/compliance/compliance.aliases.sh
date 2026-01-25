#!/usr/bin/env bash
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

# Audit Trail: View chezmoi application logs
# (Assuming chezmoi logs are piped or we verify git history as the audit trail)
audit_fn() {
    echo " Configuration Audit Trail (Recent Changes)"
    echo "---------------------------------------------"
    if [[ -f "$HOME/.dotfiles_audit.log" ]]; then
        tail -n 20 "$HOME/.dotfiles_audit.log"
    else
        # Fallback to git log if custom audit log doesn't exist
        git -C "$HOME/.dotfiles" log --oneline -n 10 --format="%C(auto)%h %C(blue)%ad %C(reset)%s (%an)" --date=short
    fi
}

alias dot-audit=audit_fn
