function bg-upgrade --description 'Background upgrade of all package managers'
    echo "🚀 Starting background upgrades (Homebrew, Nix, Chezmoi)..."
    if command -v brew >/dev/null; silent-run "brew upgrade"; end
    if command -v nix >/dev/null; silent-run "nix flake update"; end
    silent-run "chezmoi update"
    echo "Check status with 'pueue status'"
end
