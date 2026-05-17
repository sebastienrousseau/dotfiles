function lra --wraps=ls --description 'List contents of directory recursively including hidden files'
    if command -v eza >/dev/null 2>&1
        eza -alF --recurse --all --sort Name --icons --group-directories-first $argv
    else
        ls -lAR $argv
    end
end
