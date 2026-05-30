function ls --description 'List contents of directory'
    if command -v eza >/dev/null 2>&1
        eza --sort Name --icons --group-directories-first $argv
    else
        command ls $argv
    end
end
