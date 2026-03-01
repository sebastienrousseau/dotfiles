function als --description 'List aliases and scripts with high-fidelity TUI (gum)'
    if command -v gum >/dev/null 2>&1
        # Get fish aliases and format with | as separator
        set -l aliases (alias | string replace -r '^alias (\S+) (.*)$' '$1|$2')
        
        # Get our universal scripts in ~/.local/bin
        set -l scripts ""
        if test -d ~/.local/bin
            for f in ~/.local/bin/*
                set -l fname (basename $f)
                if string match -q "executable_*" "$fname"
                    set -l name (string replace "executable_" "" "$fname")
                    set scripts "$scripts$name|Script in ~/.local/bin\n"
                else if string match -q "up" "$fname"; or string match -q "extract" "$fname"; or string match -q "bm" "$fname"; or string match -q "cb" "$fname"; or string match -q "open" "$fname"; or string match -q "notify" "$fname"
                     set scripts "$scripts$fname|Universal Script\n"
                end
            end
        end

        set -l combined (echo -e "$aliases\n$scripts" | string trim)
        
        if test -n "$combined"
            echo "$combined" | gum table --separator "|" --columns "Command,Source/Definition" --widths 15,60 \
                --border rounded --border.foreground 212 --header.foreground 212
        else
            echo "No aliases or scripts found."
        end
    else
        alias
        ls ~/.local/bin
    end
end
