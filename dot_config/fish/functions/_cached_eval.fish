# _cached_eval — Cache tool init output with binary mtime invalidation
# Mirrors the bash/zsh _cached_eval pattern for Fish
#
# Usage: _cached_eval <tool_binary> <init_args...>
# Example: _cached_eval starship init fish
#          _cached_eval zoxide init fish
#
# Cache files stored in $XDG_CACHE_HOME/fish/ (or ~/.cache/fish/)
# Cache invalidated when binary mtime changes (e.g. after upgrade)

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

    set -l cache_dir (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")/fish
    set -l cache_file "$cache_dir/$tool_name-init.fish"
    set -l mtime_file "$cache_dir/$tool_name-init.mtime"

    mkdir -p "$cache_dir"

    # Check if cache is stale (binary newer than cache)
    set -l stale 0
    if not test -f "$cache_file"
        set stale 1
    else if not test -f "$mtime_file"
        set stale 1
    else if test "$tool_path" -nt "$cache_file"
        set stale 1
    end

    # Regenerate cache if stale
    if test "$stale" = 1
        set -l init_output (command $argv 2>/dev/null)
        # Reject suspicious patterns indicating malicious payloads
        if string match -rq 'curl\s.*\|\s*(ba)?sh|wget\s.*\|\s*(ba)?sh|nc\s+-e|/dev/tcp/|base64\s+-d\s*\|' -- "$init_output"
            echo "[WARN] Suspicious output from $tool_name init, skipping" >&2
            return 1
        end
        printf '%s\n' $init_output >"$cache_file"
        echo "$tool_path" >"$mtime_file"
    end

    # Source cached output
    if test -s "$cache_file"
        source "$cache_file"
    end
end
