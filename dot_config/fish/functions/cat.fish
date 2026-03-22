function cat --description 'Print file contents with bat fallback'
    if command -v bat >/dev/null 2>&1
        bat $argv
    else if command -v batcat >/dev/null 2>&1
        batcat $argv
    else
        command cat $argv
    end
end
