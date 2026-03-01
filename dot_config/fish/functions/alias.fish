# Overrides the default Fish alias command to provide a beautiful TUI listing
function alias --description 'List aliases with high-fidelity TUI (gum)'
    if not set -q argv[1]
        if command -v gum >/dev/null 2>&1
            # In Fish, 'alias' without args lists functions defined as aliases.
            # We filter those and format them for gum table.
            functions --alias | string replace -r '^alias (\S+) (.*)$' '$1,$2' | 
                gum table --columns "Alias,Command" --widths 15,60 
                --border rounded --border-foreground 212 --header-foreground 212
        else
            # Fallback to standard fish alias listing
            functions --alias
        end
    else
        # Standard alias creation
        builtin alias $argv
    end
end
