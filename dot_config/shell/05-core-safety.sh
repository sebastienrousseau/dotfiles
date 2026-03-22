#!/usr/bin/env bash

# 05-safety.sh: Core Safety Settings
# Part of the "Core Layer"

# Set sane defaults for safety, though be careful with -e in interactive shell
# Use 'set -o pipefail' to catch pipeline errors if supported
if [[ -n "$BASH_VERSION" ]] || [[ -n "$ZSH_VERSION" ]]; then
    set -o pipefail 2>/dev/null || true
fi

# Prevent file overwrite with redirection (force use of >|)
set -o noclobber

# Strict destructive-operation confirmation helper.
# Enabled when DOTFILES_ALIAS_STRICT_MODE=1.
dot_confirm_destructive() {
    local action="${1:-destructive operation}"
    local log_file="${DOTFILES_DESTRUCTIVE_LOG:-$HOME/.dotfiles_destruction.log}"
    local ts

    if [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" != "1" ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        if [[ "${DOTFILES_FORCE_DESTRUCTIVE:-0}" == "1" ]]; then
            ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
            printf "%s\tuser=%s\thost=%s\tpwd=%s\taction=%s\tmode=forced\n" \
                "$ts" "${USER:-unknown}" "${HOSTNAME:-unknown}" "${PWD:-unknown}" "$action" >> "$log_file" 2>/dev/null || true
            return 0
        fi
        echo "[STRICT] Refusing ${action} without TTY confirmation." >&2
        return 1
    fi

    echo "[STRICT] About to run: ${action}" >&2
    read -r -p "Type YES to continue: " confirm
    if [[ "$confirm" == "YES" ]]; then
        ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date)"
        printf "%s\tuser=%s\thost=%s\tpwd=%s\taction=%s\tmode=confirmed\n" \
            "$ts" "${USER:-unknown}" "${HOSTNAME:-unknown}" "${PWD:-unknown}" "$action" >> "$log_file" 2>/dev/null || true
        return 0
    fi
    return 1
}
