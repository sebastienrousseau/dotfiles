# Support Matrix

Tested platform and tool combinations for the dotfiles distribution.

## Operating Systems

| OS | Version | Architecture | Status | Notes |
|----|---------|-------------|--------|-------|
| macOS | 14+ (Sonoma) | aarch64 (Apple Silicon) | Supported | Primary dev platform |
| macOS | 14+ (Sonoma) | x86_64 | Supported | CI tested |
| Ubuntu | 22.04+ | x86_64 | Supported | CI tested |
| Ubuntu | 22.04+ | aarch64 | Supported | Tested manually |
| Debian | 12+ | x86_64 | Supported | Compatible with Ubuntu |
| Fedora | 39+ | x86_64 | Community | Not CI tested |
| Arch Linux | Rolling | x86_64 | Community | Not CI tested |
| WSL2 | Ubuntu 22.04+ | x86_64 | Supported | Clipboard bridge included |
| NixOS | 23.11+ | x86_64/aarch64 | Supported | Via Nix Flake |

## Shells

| Shell | Min Version | Status | Parity Tier | Notes |
|-------|-------------|--------|-------------|-------|
| Zsh | 5.8+ | Supported | Tier 1 (Full) | Default shell, all features |
| Bash | 5.0+ | Supported | Tier 1 (Full) | Shared logic core |
| Fish | 4.0+ | Supported | Tier 1 (Core CLI) | Native `dot`, `dm`, `da`, `dmc`, `datt`, and cached alias bridge |
| Nushell | 0.98+ | Supported | Tier 1 (Core CLI) | Native `d`, `dm`, `da`, `dmc`, `datt` aliases for core workflows |
| PowerShell | 7.5+ | Supported | Tier 1 (Core CLI) | Managed profile, `dot` wrapper, modern listing helpers, and attestation aliases |

## Terminal Emulators

| Terminal | Status | Notes |
|----------|--------|-------|
| Ghostty | Supported | Primary, custom config in `dot_config/ghostty/` |
| iTerm2 | Supported | macOS, profile config included |
| Alacritty | Supported | Config in `dot_config/alacritty/` |
| Kitty | Supported | Config in `dot_config/kitty/` |
| WezTerm | Supported | Config in `dot_config/wezterm/` |
| Windows Terminal | Supported | WSL2 profile |
| tmux | Supported | Config in `dot_config/tmux/` |

## Key Tools

| Tool | Min Version | Required | Notes |
|------|-------------|----------|-------|
| chezmoi | 2.40+ | Yes | Core dotfiles manager |
| git | 2.35+ | Yes | Version control |
| curl | 7.0+ | Yes | Bootstrap installer |
| Neovim | 0.11.2+ | No | IDE config, lazy.nvim plugins |
| Starship | 1.17+ | No | Cross-shell prompt |
| mise | 2024.1+ | No | Tool version manager |
| Nix | 2.18+ | No | Reproducible environments |
| fzf | 0.48+ | No | Fuzzy finder |
| zoxide | 0.9+ | No | Smart directory jumper |
| atuin | 18.0+ | No | Shell history sync |
| pueue | 3.0+ | No | Background task manager |

## CI Environments

| Environment | Workflow | Platform | Status |
|------------|----------|----------|--------|
| GitHub Actions (Linux) | `ci.yml` | ubuntu-latest | Tested on every PR |
| GitHub Actions (macOS) | `ci.yml` | macos-latest | Tested on every PR |
| GitHub Actions (Enforced) | `ci-enforced.yml` | ubuntu-latest | Stricter checks |
| Devcontainer | `devcontainer-prebuild.yml` | ubuntu-latest | Pre-built images |

## Known Limitations

| Platform | Limitation | Workaround |
|----------|-----------|------------|
| WSL2 | No native clipboard | `clip.exe`/`powershell.exe` bridge aliases |
| NixOS | System packages conflict | Use Nix Flake exclusively |
| Fish < 4.0 | No keyboard protocol | Upgrade to Fish 4.x |
| Nushell | Complex aliases skipped | Core `dot` workflow remains first-class |
| macOS Intel | Homebrew path differs | Template handles `/usr/local` vs `/opt/homebrew` |
