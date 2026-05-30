function l --wraps=ls --description 'List contents of directory'
    if command -v eza >/dev/null 2>&1
        eza --sort Name --icons --group-directories-first $argv
    else
        ls $argv
    end
end
