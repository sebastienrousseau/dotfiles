function lt --wraps=ls --description 'List contents of directory in tree format'
    if command -v eza >/dev/null 2>&1
        eza -aT --sort Name --icons --group-directories-first $argv
    else
        ls -R $argv
    end
end
