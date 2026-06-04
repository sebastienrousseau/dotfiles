function goto --description 'cd to a directory and list its contents'
    if test "$argv[1]" = --help
        echo "goto: cd to a directory and list its contents"
        echo "Usage: goto [directory]"
        return 0
    end
    if test -z "$argv[1]"
        echo "[ERROR] No directory provided. Use 'goto --help' for usage." >&2
        return 1
    end
    if test -d "$argv[1]"
        cd "$argv[1]"; or return
        ls
    else
        echo "[ERROR] '$argv[1]' is not a valid directory." >&2
        return 1
    end
end
