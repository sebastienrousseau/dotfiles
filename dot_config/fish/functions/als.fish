function als --description 'List aliases and scripts with high-fidelity TUI (gum)'
    # Find gum cmd
    set -l gum_cmd (command -v gum 2>/dev/null)
    if test -z "$gum_cmd"
        # Try to find gum in mise managed paths if not in PATH
        for f in $HOME/.local/share/mise/installs/aqua-charmbracelet-gum/*/gum*/gum
            if test -x "$f"
                set gum_cmd "$f"
                break
            end
        end
    end
    
    if test -n "$gum_cmd"
        set -l tab (printf "\t")
        
        begin
            # Get fish aliases
            alias | while read -l line
                # Format: alias name command
                set -l parts (string split -m 2 " " "$line")
                if test (count $parts) -ge 3
                    set -l name $parts[2]
                    set -l cmd_str $parts[3..-1]
                    # Join cmd parts and clean up leading/trailing quotes
                    set -l clean_cmd (string join " " $cmd_str | string replace -r "^'|'\$" "")
                    # Remove any internal tabs to keep 2 columns
                    set clean_cmd (string replace -a "$tab" " " "$clean_cmd")
                    printf "%s\t%s\n" "$name" "$clean_cmd"
                end
            end
            
            # Get universal scripts
            if test -d ~/.local/bin
                for f in ~/.local/bin/*
                    set -l fname (basename $f)
                    if string match -q "executable_*" "$fname"
                        set -l name (string replace "executable_" "" "$fname")
                        printf "%s\t%s\n" "$name" "Script in ~/.local/bin"
                    elif string match -q "up" "$fname"; or string match -q "extract" "$fname"; or string match -q "bm" "$fname"; or string match -q "cb" "$fname"; or string match -q "open" "$fname"; or string match -q "notify" "$fname"; or string match -q "win" "$fname"
                         printf "%s\t%s\n" "$fname" "Universal Script"
                    end
                end
            end
        end | while read -l line
            # Count elements when split by tab. Should be exactly 2.
            set -l split_line (string split "$tab" "$line")
            if test (count $split_line) -eq 2
                echo "$line"
            end
        end | "$gum_cmd" table --separator "$tab" --print --columns "Command,Source/Definition" --widths 15,60 \
            --border rounded --border.foreground 212 --header.foreground 212
    else
        alias
        if test -d ~/.local/bin
            ls ~/.local/bin
        end
    end
end
