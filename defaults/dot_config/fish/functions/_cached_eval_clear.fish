# _cached_eval_clear — Remove cache files written by _cached_eval.
# Safe: only removes *-init.fish and *-init.bin in $XDG_CACHE_HOME/fish.

function _cached_eval_clear --description 'Clear caches written by _cached_eval'
    set -l cache_dir (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")/fish
    if not test -d "$cache_dir"
        printf 'Cleared 0 cached eval file(s) from %s\n' "$cache_dir"
        return 0
    end
    set -l count 0
    for f in $cache_dir/*-init.fish $cache_dir/*-init.bin
        if test -f "$f"
            rm -f -- "$f"; and set count (math $count + 1)
        end
    end
    printf 'Cleared %d cached eval file(s) from %s\n' $count "$cache_dir"
end
