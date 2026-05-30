function ll --wraps=ls --description 'List contents of directory in long format'
    if command -v eza >/dev/null 2>&1
        eza -alF --sort Name --icons --group-directories-first $argv
    else
        ls -lA $argv
    end
end
