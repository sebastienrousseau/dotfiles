# Unified History (Atuin) and Smart Directory Jumping (Zoxide)
# Works across all shells and platforms.

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
