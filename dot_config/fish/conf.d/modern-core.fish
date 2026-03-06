# Unified History (Atuin) and Smart Directory Jumping (Zoxide)
# Works across all shells and platforms.

if not set -q DOTFILES_ARTIFACT_MODE
    set -gx DOTFILES_ARTIFACT_MODE 0
end

function _lazy_modern_core --on-event fish_prompt
    # Only run once
    functions -e _lazy_modern_core

    if test "$DOTFILES_ARTIFACT_MODE" = "0"
        if command -v atuin >/dev/null 2>&1
            atuin init fish | source
        end

        if command -v zoxide >/dev/null 2>&1
            zoxide init fish | source
            alias cd="z"
        end

        if command -v starship >/dev/null 2>&1
            starship init fish | source
        end
    end
end
