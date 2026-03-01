function lta --wraps=ls --description 'List contents of directory in tree format including hidden files'
    if command -v eza >/dev/null 2>&1
        eza -aT --all --sort Name --icons --group-directories-first $argv
    else
        ls -aR $argv
    end
end
