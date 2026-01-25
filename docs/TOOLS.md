# Tools

This page lists the main tools and CLI conveniences provided by this repo.

## Core

- Zsh (shell)
- Starship (prompt)
- tmux (terminal multiplexer)
- Neovim (editor)

## Search

- fzf
- zoxide
- ripgrep
- fd
- bat
- lsd
- duf
- ncdu
- htop

## Terminal

- WezTerm / Alacritty / Kitty / Ghostty configs
- btop
- fastfetch
- figlet
- lolcat
- cowsay
- cmatrix
- pipes
- atuin
- yazi
- zsh bell sound/visual toggles

## Developer tools

- Git helpers and sane defaults
- Project templates (`dot new`)
- Sandbox preview (`dot sandbox`)
- Benchmarking (`dot benchmark`)
- Lua tooling (`luacheck`, `stylua`, `luarocks`, `lua/luajit`)

## Security

- Firewall hardening
- Telemetry disable
- DNS‑over‑HTTPS (Linux)
- Lock‑screen enforcement
- Encryption checks

## Aliases

Aliases are organized by category under:

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
