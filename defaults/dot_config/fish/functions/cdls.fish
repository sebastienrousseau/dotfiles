function cdls --description 'cd to a directory and list its contents'
    if test "$argv[1]" = --help
        echo "cdls: cd to a directory and list its contents"
        echo "Usage: cdls [directory]"
        return 0
    end
    cd $argv; and ls
end
