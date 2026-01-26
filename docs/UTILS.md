# Discover Utilities

Curated utilities surfaced through aliases, functions, and the `dot` CLI.
This is intentionally small and practical.

## Dot CLI

The `dot` command is your primary interface for managing dotfiles. Use `dot --version` to check the installed version.

### Core Commands

| Command | Description |
|---------|-------------|
| `dot apply` | Apply dotfiles (chezmoi apply) |
| `dot sync` | Alias of apply |
| `dot update` | Pull latest changes and apply |
| `dot add <file>` | Add a file to chezmoi source |
| `dot diff` | Show local changes (excludes scripts) |
| `dot status` | Show configuration drift |
| `dot cd` | Print source directory path |
| `dot edit` | Open source in your editor |

### Diagnostics

| Command | Description |
|---------|-------------|
| `dot doctor` | Run system health checks |
| `dot drift` | Detailed configuration drift dashboard |
| `dot history` | Analyse shell history |
| `dot benchmark` | Measure shell startup time |

### Tools

| Command | Description |
|---------|-------------|
| `dot tools` | Show tools documentation |
| `dot tools install` | Enter Nix development shell |
| `dot new <lang> <name>` | Scaffold a project (python/go/node) |
| `dot sandbox` | Launch Docker sandbox preview |
| `dot log-rotate` | Rotate `~/.local/share/dotfiles.log` |

## Git

- `g`, `ga`, `gco`, `gst`, `gl`, `gll` and related aliases
- `lg` shows a graph log; `lgui` opens `lazygit` (if installed)
- `gh` aliases in `~/.config/gh/config.yml`

## Docker

- `dco` for `docker compose`
- `dps`, `dpsa` for container listing
- `dexec`, `denter` for container shells
- `dlogsf`, `dl` for following logs
- `dprune`, `dprunea` for system cleanup
- `dbx`, `dbxbuild` for buildx operations
- `lzd` for lazydocker TUI

## Search

- `rg` (ripgrep), `fd` (find)
- `z <dir>` (zoxide jump)

## Text

- `jq` for JSON
- `bat` for quick file previews

## Terminal

- `banner` for quick figlet-style banners
- `rainbow` for lolcat-style output
- `emoji` for an emoji picker (copies to clipboard)
- `pipes` for a terminal screensaver
- `cmatrix` wrapper with defaults

## Network

- `curlheader`, `curlstatus`, `curltime`, `httpdebug`

## Appearance

- `dot theme` to switch terminal themes (dark/light)
- `dot wallpaper` to apply a wallpaper
- `dot fonts` to install Nerd Fonts

## Security (opt-in)

- `dot backup` to create a compressed backup
- `dot encrypt-check` to check disk encryption status
- `dot firewall` to apply firewall hardening
- `dot telemetry` to disable telemetry
- `dot dns-doh` to enable DNS-over-HTTPS
- `dot lock-screen` to enforce lock screen idle settings
- `dot usb-safety` to disable automount for removable media

## Fonts

- `~/.dotfiles/scripts/fonts/patch-fonts.sh` to patch a font with Nerd Fonts
