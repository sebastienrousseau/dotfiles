# 🅳🅾🆃🅵🅸🅻🅴🆂 — Nushell _cached_eval equivalent
# <https://dotfiles.io>
#
# Minimum-viable port of the zsh/fish `_cached_eval` primitive. Caches
# the output of tool-init commands (e.g. `starship init nu`, `mise
# activate nu`) so subsequent shells source the cached file instead of
# spawning a subprocess. Cache invalidates on binary mtime change.
#
# Closes the Nushell-parity AC of #880. Tier-3 by design: not as
# feature-rich as the zsh implementation (no malware-pattern screening,
# no per-tool timing telemetry, no atomic write under concurrent
# shells) — those layers are not yet worth Nushell's parse-time
# constraints. See ADR-011.

# Path resolution helpers — Nushell's parse-time evaluator means we
# can't compute these at import time as cleanly as fish/zsh do.
export def --env _cached_eval_cache_dir [] {
    let xdg = ($env | get -i XDG_CACHE_HOME)
    if $xdg != null and ($xdg | str length) > 0 {
        $"($xdg)/nushell"
    } else {
        $"($env.HOME)/.cache/nushell"
    }
}

# _cached_eval — cache the output of `<tool> <args...>` to disk and
# print the cached path. The caller is responsible for `source`-ing
# the result (Nushell `source` is parse-time, so this can't be
# wrapped further without losing the parse-time semantics).
#
# Returns: the path to the cached file (string), or empty string when
# the tool is unavailable / the eval failed.
export def _cached_eval [tool: string, ...args: string] {
    let cache_dir = (_cached_eval_cache_dir)
    mkdir $cache_dir
    let label = ($tool + "-" + ($args | str join "-") | str replace --all "/" "_" | str replace --all " " "-")
    let cache_file = $"($cache_dir)/($label).nu"

    # Check binary mtime against cache mtime for invalidation.
    let tool_path = (which $tool | get -i 0.path)
    if $tool_path == null {
        return ""
    }

    let fresh = if ($cache_file | path exists) {
        let tool_mtime = (ls $tool_path | get -i 0.modified)
        let cache_mtime = (ls $cache_file | get -i 0.modified)
        if $tool_mtime != null and $cache_mtime != null {
            $cache_mtime > $tool_mtime
        } else {
            false
        }
    } else {
        false
    }

    if not $fresh {
        let output = (try { run-external $tool ...$args | complete } catch { { stdout: "", exit_code: 1 } })
        if $output.exit_code == 0 and ($output.stdout | str length) > 0 {
            $output.stdout | save -f $cache_file
        } else {
            return ""
        }
    }

    $cache_file
}

# Convenience wrapper for the common case: caller wants the source
# path, falls back to silent no-op if the tool is absent.
export def _cached_eval_path_or_skip [tool: string, ...args: string] {
    let p = (_cached_eval $tool ...$args)
    if ($p | str length) == 0 {
        ""
    } else if ($p | path exists) {
        $p
    } else {
        ""
    }
}
