function dot --description 'dotfiles manager'
    if test "$argv[1]" = "load"
        # Since fish doesn't have the same "lazy loading" mechanism as this zsh setup
        # we'll just indicate that we're ready.
        # But we'll still call the real dot if it exists.
        if test "$argv[2]" = "--status"
            echo "ready"
            return 0
        end
    end

    if test -x "$HOME/.local/bin/dot"
        "$HOME/.local/bin/dot" $argv
    else
        echo "dot command not found at $HOME/.local/bin/dot" >&2
        return 1
    end
end
