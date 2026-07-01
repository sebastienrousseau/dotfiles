# 10-secrets.fish — optional secret bucket auto-loader (fish parity with
# ~/.config/shell/10-secrets.sh). No-op unless DOTFILES_SECRETS_AUTO_LOAD=1.
# Uses `dot secrets load --shell fish` so the emitted `set -gx` lines are
# fish-native (the POSIX `export` form the sh layer emits is not valid fish).

if test "$DOTFILES_SECRETS_AUTO_LOAD" = 1
    if type -q dot; and set -q DOTFILES_SECRETS_BUCKET_NAMES
        for bucket in (string split ',' -- "$DOTFILES_SECRETS_BUCKET_NAMES")
            set -l bucket (string trim -- "$bucket")
            test -n "$bucket"; and dot secrets load "$bucket" --shell fish 2>/dev/null | source
        end
    end
end
