# _cached_eval — Cache tool init output with binary mtime invalidation
# Mirrors the bash/zsh _cached_eval pattern for Fish
#
# Usage: _cached_eval <tool_binary> <init_args...>
# Example: _cached_eval starship init fish
#          _cached_eval zoxide init fish
#
# Cache files stored in $XDG_CACHE_HOME/fish/ (or ~/.cache/fish/)
# Cache invalidated when binary mtime, realpath, or any file-path arg changes
# (e.g. after upgrade or PATH-shadow swap).
#
# Set EVALCACHE_DISABLE=true to bypass cache read AND write (debug aid).

function _cached_eval --description 'Cache and source tool init output'
    set -l tool_name $argv[1]
    if test -z "$tool_name"
        echo "_cached_eval: usage: _cached_eval <tool> <init args...>" >&2
        return 1
    end

    # Resolve binary path
    set -l tool_path (command -v $tool_name 2>/dev/null)
    if test -z "$tool_path"
        return 1
    end

    # Debug bypass: skip cache read AND write entirely.
    if test "$EVALCACHE_DISABLE" = true
        command $argv 2>/dev/null | source
        return $status
    end

    set -l cache_dir (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")/fish
    set -l cache_file "$cache_dir/$tool_name-init.fish"
    set -l pin_file "$cache_dir/$tool_name-init.bin"

    mkdir -p "$cache_dir"

    set -l real_bin (realpath -- "$tool_path" 2>/dev/null; or echo "$tool_path")

    # Cache valid when: present non-empty, binary not newer, recorded realpath
    # still matches, and no file-path argument modified since cache write.
    set -l stale 0
    if not test -s "$cache_file"
        set stale 1
    else if test "$tool_path" -nt "$cache_file"
        set stale 1
    else if test -f "$pin_file"
        set -l pinned (cat "$pin_file" 2>/dev/null)
        if test -n "$pinned"; and test "$pinned" != "$real_bin"
            set stale 1
        end
    end
    if test "$stale" = 0
        for arg in $argv[2..]
            if test -f "$arg"; and test "$arg" -nt "$cache_file"
                set stale 1
                break
            end
        end
    end

    # Regenerate cache if stale
    if test "$stale" = 1
        set -l init_output (command $argv 2>/dev/null)
        set -l rc $status
        if test "$rc" -ne 0
            echo "[WARN] $tool_name init exited $rc; not caching" >&2
            return $rc
        end
        # Reject suspicious patterns indicating malicious payloads
        if string match -rq 'curl\s.*\|\s*(ba)?sh|wget\s.*\|\s*(ba)?sh|nc\s+-e|/dev/tcp/|base64\s+-d\s*\|' -- "$init_output"
            echo "[WARN] Suspicious output from $tool_name init, skipping" >&2
            return 1
        end
        set -l tmp_cache "$cache_file.tmp.$fish_pid"
        printf '%s\n' $init_output >"$tmp_cache"
        mv "$tmp_cache" "$cache_file"  # atomic rename
        set -l tmp_pin "$pin_file.tmp.$fish_pid"
        printf '%s\n' "$real_bin" >"$tmp_pin"
        mv "$tmp_pin" "$pin_file"
    end

    # Source cached output
    if test -s "$cache_file"
        source "$cache_file"
    end
end
