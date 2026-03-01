function silent-run --description 'Submit a command to pueue and forget about it'
    if test -z "$argv"
        echo "Usage: silent-run <command>"
        return 1
    end
    pueue add -- $argv
end
