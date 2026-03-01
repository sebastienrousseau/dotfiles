# Auto-completion for all commands using carapace
if command -v carapace >/dev/null 2>&1
    mkdir -p ~/.config/fish/completions
    carapace --complete fish | source
end
