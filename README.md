<p align="right">
  <img src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg" alt="Dotfiles logo" width="64" />
</p>

# Dotfiles — a fast, idempotent dev shell in minutes

<!-- Build / Status -->
[![Build](https://img.shields.io/github/actions/workflow/status/sebastienrousseau/dotfiles/ci.yml?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/actions)

<!-- Version / License -->
[![Version](https://img.shields.io/badge/Version-v0.2.473-blue?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/releases/tag/v0.2.473)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<!-- Activity / Downloads -->
[![Release Downloads](https://img.shields.io/github/downloads/sebastienrousseau/dotfiles/total?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/releases)
[![Last Commit](https://img.shields.io/github/last-commit/sebastienrousseau/dotfiles?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/commits)

---

## Elevator Pitch

Dotfiles is a cross‑platform, Chezmoi‑managed shell distribution that installs in minutes and keeps your environment consistent across macOS, Linux, and WSL. It’s **idempotent** by design, so running it twice is safe, and it stays fast, predictable, and easy to maintain.

## The Hook

You get a tuned Zsh + Neovim + tmux stack with sane defaults, a single command to apply updates, and optional hardening tools when you want them. It’s designed for daily use first, with reproducibility and auditability baked in.

---

## Table of Contents

- [Key Features](#key-features)
- [Quick Start (60 seconds)](#quick-start-60-seconds)
- [Installation Details](#installation-details)
- [Reference](#reference)
  - [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [The dot CLI](#the-dot-cli)
  - [Security Auditing (What Changes)](#security-auditing-what-changes)
  - [Nix Integration](#nix-integration)
- [How‑to Guides](#how-to-guides)
  - [Add a new alias](#add-a-new-alias)
  - [Commit changes safely](#commit-changes-safely)
- [Architecture (How it Works)](#architecture-how-it-works)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

---

## Key Features

- **One‑command install** with a pinned release tag and checksum‑verified Chezmoi bootstrap.
- **Chezmoi as source of truth** for all configuration, with XDG‑first paths.
- **Fast shell UX**: Zsh + Starship + fzf + zoxide out of the box.
- **Modern editor stack**: Neovim with LSP, formatters, linters, DAP, and testing.
- **Opinionated terminal workflow**: tmux bindings + terminal configs (WezTerm, Alacritty, Kitty, Ghostty).
- **Optional security hardening**: firewall, DoH, telemetry disable, lock‑screen enforcement, encryption checks.
- **Developer utilities**: `dot` CLI for sync, upgrade, secrets, themes, templates, and more.
- **Nix optional toolchain** for reproducible binaries without changing your Chezmoi workflow.

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Quick Start (60 seconds)

> [!IMPORTANT]
> The installer **only** bootstraps `chezmoi` and applies this repo. OS package installs happen via Chezmoi hooks on first apply.

```bash
# 1) Install from the pinned release tag
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.473/install.sh)"

# 2) Restart your shell
exec zsh
```

> [!TIP]
> Use `DOTFILES_NONINTERACTIVE=1` if you want a fully non‑interactive install.

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Installation Details

### Supported Platforms

- **macOS** (Homebrew)
- **Ubuntu/Debian** (apt)
- **WSL2** (Ubuntu/Debian)

> [!WARNING]
> If you already have custom dotfiles, back them up first. Chezmoi is safe, but overwriting configs can still be disruptive.

### Dependencies

| Type | Required | Optional (feature‑dependent) |
|---|---|---|
| Core | `git`, `curl` | — |
| macOS | — | Homebrew (for Brewfile installs) |
| Linux | — | `apt-get` (for package installs) |
| Sandbox | — | Docker or Podman |
| Nix toolchain | — | Nix (optional) |

### What the installer does vs what Chezmoi does

- **Installer**: installs Chezmoi (pinned + checksum verified) and applies this repo.
- **Chezmoi hooks**: install OS packages, fonts, and optional apps defined in this repo.

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Reference

### Configuration

**Chezmoi config (local, not committed)**

```toml
# ~/.config/chezmoi/chezmoi.toml
sourceDir = "~/.dotfiles"

encryption = "age" # optional

[age]
identity = "~/.config/chezmoi/key.txt"
recipient = "age1..."
```

**Data file (template inputs)**

```toml
# ~/.dotfiles/.chezmoidata.toml
profile = "laptop"               # laptop | server
theme = "tokyonight-night"
terminal_font_family = "JetBrains Mono"
terminal_font_size = 12

git_name = "Your Name"
git_email = "you@example.com"
git_signingkey = "~/.ssh/id_ed25519"
git_signingformat = "ssh"

[features]
zsh = true
nvim = true
tmux = true
gui = true
secrets = true
```

### Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `DOTFILES_NONINTERACTIVE` | Non‑interactive install | `0` |
| `DOTFILES_FONTS` | Install fonts during `dot upgrade` | `0` |
| `DOTFILES_WALLPAPER_DIR` | Wallpaper directory | `~/Pictures/Wallpapers` |
| `DOTFILES_FIREWALL` | Enable firewall hardening | unset |
| `DOTFILES_TELEMETRY` | Disable telemetry | unset |
| `DOTFILES_DOH` | Enable DNS‑over‑HTTPS | unset |
| `DOTFILES_LOCK` | Enforce lock screen idle settings | unset |
| `DOTFILES_USB_SAFETY` | Disable automount for removable media | unset |

### The `dot` CLI

> [!TIP]
> Run `dot help` to see available commands.

| Command | Description | Category |
|---|---|---|
| `dot sync` | Apply dotfiles (chezmoi apply) | Core |
| `dot update` | Pull latest changes and apply them | Core |
| `dot upgrade` | Update flake, plugins, and dotfiles | Core |
| `dot tools` | Show dot utils overview | Tooling |
| `dot keys` | Show keybindings catalog | Tooling |
| `dot docs` | Show repo README | Tooling |
| `dot new` | Scaffold a project template (python/go/node) | Tooling |
| `dot benchmark` | Run shell startup benchmark | Tooling |
| `dot sandbox` | Launch a sandbox preview (Docker/Podman) | Tooling |
| `dot log-rotate` | Rotate ~/.local/share/dotfiles.log | Tooling |
| `dot theme` | Switch terminal theme | Visuals |
| `dot wallpaper` | Apply a wallpaper | Visuals |
| `dot fonts` | Install Nerd Fonts | Visuals |
| `dot secrets-init` | Initialize age key for secrets | Security |
| `dot secrets-create` | Create encrypted secrets file | Security |
| `dot secrets` | Edit encrypted secrets (age) | Security |
| `dot ssh-key` | Encrypt an SSH key locally with age | Security |
| `dot firewall` | Apply firewall hardening (opt‑in) | Security |
| `dot telemetry` | Disable OS telemetry (opt‑in) | Security |
| `dot dns-doh` | Enable DNS‑over‑HTTPS (opt‑in) | Security |
| `dot encrypt-check` | Check disk encryption status | Security |
| `dot backup` | Create a compressed backup | Security |
| `dot lock-screen` | Enforce lock screen idle settings (opt‑in) | Security |
| `dot usb-safety` | Disable automount for removable media | Security |

**Examples**

```bash
# Initialize secrets (prints a public key)
DOTFILES_NONINTERACTIVE=1 dot secrets-init
# Output: Age key created at ~/.config/chezmoi/key.txt
```

### Security Auditing (What Changes)

These scripts are **opt‑in** and only run when the matching env var is set.
All security changes are logged to `~/.local/share/dotfiles.log`.

| Script | macOS changes | Linux changes |
|---|---|---|
| `dot firewall` | Enables macOS firewall + stealth mode via `socketfilterfw` | Configures UFW defaults + OpenSSH allow |
| `dot telemetry` | Writes `DiagnosticMessagesHistory.plist` flags | Disables `whoopsie`, `apport`, `popularity-contest` |
| `dot dns-doh` | No system change (browser‑level only) | Enables DoH via `resolvectl` and sets Cloudflare DNS |
| `dot lock-screen` | `com.apple.screensaver` defaults + idleTime | GNOME `gsettings` lock + idle timeout |
| `dot usb-safety` | No system change (manual UI) | GNOME `gsettings` automount off |
| `dot encrypt-check` | Reads FileVault status via `fdesetup` | Detects LUKS via `lsblk` |

### Nix Integration

Nix is **optional**. The repo does **not** install the Nix daemon.

- Use `nix develop` for a reproducible dev shell.
- `dot tools` assumes Nix is already installed.
- There is no toggle that replaces Brew/Apt with Nix automatically.

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## How‑to Guides

### Add a new alias

1. Add a new alias file under:

```
~/.dotfiles/.chezmoitemplates/aliases/<category>/<name>.aliases.sh
```

2. Apply:

```bash
chezmoi apply
```

### Commit changes safely

```bash
# Edit source files in ~/.dotfiles
chezmoi apply

# Review + commit
cd ~/.dotfiles

git status
git add -A
git commit -S -m "Describe your change"
git push
```

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Architecture (How it Works)

```mermaid
flowchart LR
  A[install.sh] --> B[Chezmoi]
  B --> C[~/.dotfiles (source)]
  B --> D[~/.config + ~/.local (targets)]
  E[dot CLI] --> B
  E --> F[scripts/*]
```

If Mermaid does not render, the flow is: `install.sh → Chezmoi → ~/.dotfiles → ~/.config + ~/.local`.

**Repository layout**

```text
~/.dotfiles/
├── dot_config/                 # Maps to ~/.config/ (app configs)
│   ├── nvim/                    # Neovim config (Lua)
│   ├── zsh/                     # Zsh config (modular)
│   ├── tmux/                    # Tmux config
│   ├── shell/                   # Shell logic (aliases/functions/paths)
│   ├── wezterm/ alacritty/ kitty/ ghostty/
│   ├── btop/ fastfetch/ atuin/ yazi/ ...
│   └── docker/ containers/ ...
├── dot_local/                  # Maps to ~/.local/ (CLI tools)
│   └── bin/                     # dot CLI + helpers
├── dot_etc/                    # System configs (sudoers, sysctl, chrome policies; may require sudo)
├── dot_ssh/                    # SSH config templates
├── templates/                  # Project scaffolds used by `dot new`
├── scripts/                    # Install, security, theme, diagnostics
├── install/                    # Chezmoi run_onchange/run_before hooks
├── nix/                        # Optional Nix dev shell
├── docs/                       # Guides, keys, roadmap, architecture
└── install.sh                  # Bootstrap installer
```

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Roadmap

- **Roadmap doc**: `docs/ROADMAP.md`
- **Master plan**: `~/Roadmaps/dotfiles/roadmap.md` (local, not tracked)

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Contributing

Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) before opening a PR.

Security issues: see [SECURITY.md](.github/SECURITY.md).

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>

---

## License

This repo is licensed under the **MIT License**. See [LICENSE](LICENSE).

Third‑party dependencies may carry different licenses (e.g., GPL). See LICENSE for details.

<p align="right"><a href="#dotfiles--a-fast-idempotent-dev-shell-in-minutes">↑ Back to Top</a></p>
