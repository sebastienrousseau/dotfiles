function als --description 'Instant-Load High-Fidelity Command Explorer'
    set -l data_file "$HOME/.config/shell/als_data.txt"
    
    if not test -f "$data_file"
        echo "Error: Command data not found. Please run 'chezmoi apply'."
        return 1
    end

    # Find gum cmd robustly
    set -l gum_cmd (command -v gum 2>/dev/null)
    if test -z "$gum_cmd"
        for f in $HOME/.local/share/mise/installs/aqua-charmbracelet-gum/*/gum*/gum
            if test -x "$f"; set gum_cmd "$f"; break; end
        end
    end

    if test -z "$gum_cmd"
        echo "Error: 'gum' not found. Please ensure mise tools are installed."
        return 1
    end

    # Search Interface (Near-Instant)
    set -l selected ("$gum_cmd" filter --placeholder "Search categories, aliases, or descriptions..." \
        --indicator "󰁔" --indicator.foreground 212 \
        --match.foreground 212 --text.foreground 255 --height 20 < "$data_file")

    if test -n "$selected"
        # Extract metadata from hidden fields
        set -l parts (string split "|SEP|" "$selected")
        set -l final_cmd $parts[2]
        set -l final_name $parts[3]
        
        # Clean the display string for the detail view (remove ANSI and SEP)
        set -l clean_display (echo "$selected" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/|SEP|.*$//' | string trim)

        echo ""
        "$gum_cmd" style --foreground 212 --border rounded --border-foreground 212 --padding "1 2" \
            "󰄬 COMMAND INTELLIGENCE" \
            "  Identity: $final_name" \
            "  Exec:     $final_cmd" \
            "  Details:  $clean_display"
        
        echo "$final_cmd" | cb >/dev/null 2>&1
        "$gum_cmd" style --foreground 240 "  󱉊 Copied to clipboard"
    end
end
