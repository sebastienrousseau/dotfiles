function lr --wraps=ls --description 'List contents of directory recursively'
    if command -v eza >/dev/null 2>&1
        eza -alF --recurse --sort Name --icons --group-directories-first $argv
    else
        ls -lAR $argv
    end
end
