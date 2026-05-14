# _cached_eval — Cache tool init output with binary mtime invalidation.
# Mirrors the bash/zsh _cached_eval pattern for Fish.
#
# Usage: _cached_eval <tool_binary> <init_args...>
# Example: _cached_eval starship init fish
#          _cached_eval zoxide init fish
#
# Cache files stored in $XDG_CACHE_HOME/fish/ (or ~/.cache/fish/)
# Cache invalidated when binary mtime, realpath, or any file-path arg
# changes (e.g. after upgrade or PATH-shadow swap).
#
# Env knobs:
#   EVALCACHE_DISABLE=true  bypass cache read AND write (debug aid)
#   EVALCACHE_TIMING=1      log per-call timing for `dot perf --by-tool`

function _cached_eval_log_timing --description 'Append a timing event for dot perf --by-tool'
    set -l label $argv[1]
    set -l t0 $argv[2]
    set -l t1 $argv[3]
    set -l rc $argv[4]
    set -l shell fish
    if test (count $argv) -ge 5
        set shell $argv[5]
    end
    set -l log_dir (set -q XDG_STATE_HOME; and echo $XDG_STATE_HOME; or echo "$HOME/.local/state")/dotfiles
    mkdir -p "$log_dir" 2>/dev/null; or return 0
    set -l logfile "$log_dir/eval-timings.jsonl"
    test -f "$logfile"; or touch "$logfile" 2>/dev/null; or return 0
    # nanoseconds -> milliseconds
    set -l ms 0
    if test -n "$t0"; and test -n "$t1"
        set ms (math --scale=0 "($t1 - $t0) / 1000000") 2>/dev/null; or set ms 0
    end
    set -l ts (date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '{"ts":"%s","shell":"%s","label":"%s","ms":%s,"rc":%s}\n' \
        "$ts" "$shell" "$label" "$ms" "$rc" \
        >>"$logfile" 2>/dev/null; or true
end

function _cached_eval_impl
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

function _cached_eval --description 'Cache and source tool init output'
    if test "$EVALCACHE_TIMING" != 1
        _cached_eval_impl $argv
        return $status
    end
    set -l _ce_t0 (date +%s%N 2>/dev/null; or echo 0)
    _cached_eval_impl $argv
    set -l _ce_rc $status
    set -l _ce_t1 (date +%s%N 2>/dev/null; or echo 0)
    set -l label unknown
    if test (count $argv) -ge 1
        set label $argv[1]
    end
    _cached_eval_log_timing "$label" "$_ce_t0" "$_ce_t1" "$_ce_rc" fish
    return $_ce_rc
end
