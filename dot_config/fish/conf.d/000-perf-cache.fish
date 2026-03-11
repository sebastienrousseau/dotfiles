# Startup performance cache
# Loaded before vendor conf.d — intercepts slow commands with cached results.

# Fast fish_add_path replacement — builtins only, no argparse overhead.
# Shadows the standard fish_add_path function (autoloaded from /usr/share/fish/).
# Handles the common calling conventions used by vendor conf.d scripts.
function fish_add_path
    set -l append false
    set -l paths
    for arg in $argv
        switch $arg
            case --append -a
                set append true
            case --global --path -g -p -P -U
                # Accepted and ignored — we always use global scope + PATH
            case '--*' '-*'
                # Ignore unknown flags
            case '*'
                set -a paths $arg
        end
    end
    for p in $paths
        if not contains -- $p $PATH
            if $append
                set -g --append PATH $p
            else
                set -g --prepend PATH $p
            end
        end
    end
end

# Cache flatpak --installations (saves ~11ms per startup).
# The vendor /usr/share/fish/vendor_conf.d/flatpak.fish calls this on every
# shell start. We wrap it so only the first call after cache expiry is slow.
# Cache is refreshed by `dot prewarm` or manually:
#   command flatpak --installations > ~/.cache/fish/flatpak-installations
if type -q flatpak
    function flatpak --wraps flatpak
        if test (count $argv) -eq 1; and test "$argv[1]" = --installations
            set -l cache "$HOME/.cache/fish/flatpak-installations"
            if test -f "$cache"
                while read -l line
                    echo $line
                end <"$cache"
                return 0
            end
            mkdir -p "$HOME/.cache/fish"
            command flatpak --installations 2>/dev/null | tee "$cache"
            return 0
        end
        command flatpak $argv
    end
end
