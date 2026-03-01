function log_error --description 'Log error message'
    if set -q NO_COLOR; or not isatty 2
        set -l RED ""
        set -l NC ""
        printf "[ERROR] %s
" "$argv[1]" >&2
    else
        set -l RED (set_color red)
        set -l NC (set_color normal)
        printf "%s[ERROR]%s %s
" "$RED" "$NC" "$argv[1]" >&2
    end
end
