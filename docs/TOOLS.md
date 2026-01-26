# Tools

These are the main tools and CLI conveniences included with Dotfiles.

## Core

| Tool | Description |
|------|-------------|
| Zsh | Shell |
| Starship | Cross-shell prompt |
| tmux | Terminal multiplexer |
| Neovim | Modern Vim-based editor |

## Search and navigation

| Tool | Description |
|------|-------------|
| fzf | Fuzzy finder |
| zoxide | Smart directory jumping |
| ripgrep | Fast text search |
| fd | Developer-friendly find |
| bat | Cat with syntax highlighting |
| eza | Modern ls replacement |
| lsd | LSDeluxe file listing |
| duf | Disk usage utility |
| ncdu | NCurses disk usage |
| htop | Process viewer |
| btop | Resource monitor |

## Terminal

| Tool | Description |
|------|-------------|
| WezTerm | GPU-accelerated terminal |
| Alacritty | Fast terminal |
| Kitty | Feature-rich terminal |
| Ghostty | Native terminal |
| fastfetch | System info |
| figlet | ASCII banners |
| lolcat | Rainbow output |
| cowsay | ASCII cow messages |
| cmatrix | Matrix screensaver |
| pipes | Pipe screensaver |
| atuin | Shell history sync |
| yazi | Terminal file manager |

## Git

| Tool | Description |
|------|-------------|
| git | Version control |
| lazygit | Terminal UI for Git |
| delta | Syntax-highlighted diffs |
| gh | GitHub CLI |
| glab | GitLab CLI |

## Data processing

| Tool | Description |
|------|-------------|
| jq | JSON processor |
| yq | YAML processor |
| hexyl | Hex viewer |

## Kubernetes

| Tool | Description |
|------|-------------|
| kubectl | Kubernetes CLI |
| kubectx | Context switcher |
| kubens | Namespace switcher |
| k9s | Kubernetes TUI |
| stern | Multi-pod log tailer |
| kube-linter | Manifest linter |
| kubesec | Security scanner |
| minikube | Local Kubernetes |
| helm | Package manager |

## Database CLIs

| Tool | Description |
|------|-------------|
| psql | PostgreSQL CLI |
| mycli | MySQL CLI with autocomplete |
| sqlite3 | SQLite CLI |
| redis-cli | Redis CLI |
| mongosh | MongoDB Shell |

## Security

| Tool | Description |
|------|-------------|
| age | Modern encryption |
| gnupg | OpenPGP implementation |

## Developer tools

- Git helpers and sane defaults
- Project templates (`dot new`)
- Sandbox preview (`dot sandbox`)
- Benchmarking (`dot benchmark`)
- Lua tooling (`luacheck`, `stylua`, `luarocks`, `lua/luajit`)

## Security features

- Firewall hardening
- Telemetry disable
- DNS-over-HTTPS (Linux)
- Lock-screen enforcement
- Encryption checks

## Aliases

Aliases live in category directories under:

```
~/.dotfiles/.chezmoitemplates/aliases/<category>/<name>.aliases.sh
```

Apply changes with:

```bash
chezmoi apply
```

## Make it yours

- Wallpaper sync/rotate scripts
- Cursor and icon theming helpers (Linux)
- Lock screen icon helper (Linux)
- GRUB theme / boot logo helpers (Linux)
