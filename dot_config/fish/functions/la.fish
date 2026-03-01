function la --wraps=ls --description 'List contents of directory including hidden files'
    if command -v eza >/dev/null 2>&1
        eza -a --sort Name --icons --group-directories-first $argv
    else
        ls -a $argv
    end
end
