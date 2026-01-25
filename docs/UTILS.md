# Discover

Curated utilities surfaced through aliases, functions, and the `dot` CLI.
This is intentionally small and practical.

## Git
- `g`, `ga`, `gco`, `gst`, `gl`, `gll` and related aliases
- `lg` shows a graph log; `lgui` opens `lazygit` (if installed)
- `gh` aliases in `~/.config/gh/config.yml`

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

## System
- `dot doctor` for health checks
- `dot apply` to apply dotfiles
- `dot update` to pull and apply changes
- `dot diff` to show local changes (excludes scripts/install/tests)
- `dot drift` to summarize config drift
- `dot history` to analyze shell history
- `dot theme` to switch terminal themes
- `dot new` to scaffold a project (python/go/node)
- `dot log-rotate` to rotate `~/.local/share/dotfiles.log`

- `dot backup` to create a compressed backup
- `dot encrypt-check` to check disk encryption status
- `dot firewall` to apply firewall hardening (opt-in)
- `dot telemetry` to disable telemetry (opt-in)
- `dot dns-doh` to enable DNS-over-HTTPS (opt-in)
- `dot lock-screen` to enforce lock screen idle settings
- `dot usb-safety` to disable automount for removable media
- `dot fonts` to install Nerd Fonts
- `dot wallpaper` to apply a wallpaper

## Fonts
- `~/.dotfiles/scripts/fonts/patch-fonts.sh` to patch a font with Nerd Fonts
