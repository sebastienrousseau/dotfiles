function log_info --description 'Log info message'
    if set -q NO_COLOR; or not isatty 1
        set -l BLUE ""
        set -l NC ""
        printf "[INFO] %s
" "$argv[1]"
    else
        set -l BLUE (set_color blue)
        set -l NC (set_color normal)
        printf "%s[INFO]%s %s
" "$BLUE" "$NC" "$argv[1]"
    end
end
