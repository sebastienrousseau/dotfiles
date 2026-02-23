<p align="right">
  <img src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg" alt="Dotfiles logo" width="64" />
</p>

# Dotfiles — A Fast, Idempotent Shell Environment

[![Build](https://img.shields.io/github/actions/workflow/status/sebastienrousseau/dotfiles/ci.yml?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/actions)
[![Version](https://img.shields.io/badge/Version-v0.2.489-blue?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/releases/tag/v0.2.489)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)
[![Release Downloads](https://img.shields.io/github/downloads/sebastienrousseau/dotfiles/total?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/releases)
[![Last Commit](https://img.shields.io/github/last-commit/sebastienrousseau/dotfiles?style=for-the-badge)](https://github.com/sebastienrousseau/dotfiles/commits)

---

## Overview

Configure your development environment once, deploy it everywhere. Dotfiles is a cross‑platform shell distribution managed by [Chezmoi](https://github.com/twpayne/chezmoi) — the dotfiles manager that tracks source state in Git. Works on macOS, Linux, and WSL. **Idempotent** by design: run it once or a hundred times, the result stays the same.

Git + templates + guarded scripts = a reproducible shell.

---

## Table of contents

- [Why dotfiles](#why-dotfiles)
- [Safety](#safety)
- [Get started](#get-started)
- [Discover](#discover)
- [Install details](#install-details)
- [Make it yours](#make-it-yours)
- [Reference](#reference)
- [How it works](#how-it-works)
- [Roadmap](#roadmap)
- [Contribute](#contribute)
- [Changelog](#changelog)
- [License](#license)

---

## Why dotfiles

Dotfiles treats your shell as infrastructure. Built for developers who work across multiple machines and demand **usability, reproducibility, and auditability.**

- **The Stack.** Zsh, Neovim, tmux, and AI CLI tools with production-ready defaults.
- **Unified Control.** The `dot` CLI handles syncing, upgrades, and secrets in one place.
- **Safety First.** System and security changes require explicit opt‑in.
- **Clean Slate.** Source files, generated configs, and system state remain separated.


## Safety

This is **infrastructure**, not an ad‑hoc script.

- **No destructive actions** without explicit opt‑in.
- **No background daemons** install automatically.
- **No system settings** change by default.
- System‑level behavior requires opt‑in via environment variables.
- All privileged actions log to `~/.local/share/dotfiles.log`.

---

## Verification (CI Seal)

Every change is verified across macOS and Linux CI with security scanners, lint, and unit tests. Locally, you can validate your machine in one pass:

```bash
dot scorecard
dot verify
```

---

## Get started

> [!IMPORTANT]
> The installer automatically backs up any existing dotfiles that chezmoi will overwrite (to `~/.dotfiles.bak.<timestamp>/`). It bootstraps `chezmoi` and applies this repo. OS packages install through Chezmoi hooks during the first apply.

```bash
# Works on macOS, Linux, and WSL
sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.489/install.sh)"
exec zsh
```

For non‑interactive installs (servers and CI):
```bash
DOTFILES_NONINTERACTIVE=1 sh -c "$(curl -fsSL https://raw.githubusercontent.com/sebastienrousseau/dotfiles/v0.2.489/install.sh)"
```

### 60-second onboarding

```bash
dot doctor     # health + platform parity checks
dot apply      # apply managed config
dot scorecard  # UX + security + performance snapshot
```

What “done” looks like:
- `dot` resolves to `~/.local/bin/dot`
- doctor summary reports no critical errors
- shell startup remains responsive after `exec zsh`

---

## Discover

- [Installation Guide](docs/INSTALL.md) — Prerequisites and supported platforms.
- [Operations Guide](docs/OPERATIONS.md) — Common workflows and platform notes.
- [Security Guide](docs/SECURITY.md) — Hardening matrix and logging.
- [Secrets Guide](docs/SECRETS.md) — Age setup and encrypted files.
- [Tools Catalog](docs/TOOLS.md) — Core tools and optional utilities.
- [Dot Utils](docs/UTILS.md) — Aliases and dot CLI helpers.
- [Troubleshooting](docs/TROUBLESHOOTING.md) — Fixes for common issues.

---

## Install details

**Prerequisites**
- Required: `git`, `curl`
- Optional: Homebrew (macOS), `apt-get` (Linux/WSL), Nix (toolchain)

**Update**
```bash
dot update
```

**Non‑interactive apply**
```bash
DOTFILES_NONINTERACTIVE=1 dot apply
```

### Upgrade-safe apply flow

When pulling a new release, use this sequence:

```bash
git pull
DOTFILES_NONINTERACTIVE=1 dot apply --force
dot doctor
```

`dot apply` now runs post-apply validation automatically to:
- remove stale read-only zsh cache files (`*.zwc`)
- verify `dot` resolves to `~/.local/bin/dot` in a fresh login shell

After apply, reload your current session:

```bash
exec zsh
```

Or restart the terminal to pick up alias/function updates.

## Make it yours

- [Operations](docs/OPERATIONS.md)
- [Secrets](docs/SECRETS.md)
- [Security](docs/SECURITY.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## Reference

Run `dot --help` or `dot <command> --help` for inline documentation.

| Command | Description | Category |
|---|---|---|
| `dot apply` | Apply dotfiles (chezmoi apply) | Core |
| `dot sync` | Alias of apply | Core |
| `dot update` | Pull latest changes and apply | Core |
| `dot add` | Add a file to chezmoi source | Core |
| `dot diff` | Show chezmoi diff (excludes scripts) | Core |
| `dot status` | Show configuration drift | Core |
| `dot remove` | Safely remove a managed file | Core |
| `dot cd` | Print source directory path | Core |
| `dot upgrade` | Update flake, plugins, and dotfiles | Core |
| `dot edit` | Open chezmoi source in your editor | Core |
| `dot docs` | Show repo README | Core |
| `dot --version` | Show version information | Core |
| `dot help` | Show help | Core |
| `dot drift` | Drift dashboard (chezmoi status) | Diagnostics |
| `dot history` | Shell history analysis | Diagnostics |
| `dot doctor` | Check system health and configuration | Diagnostics |
| `dot verify` | Post-merge verification (`dot doctor`, `dot status`, `chezmoi diff`) | Diagnostics |
| `dot health` | Comprehensive health dashboard (37 checks) | Diagnostics |
| `dot security-score` | Security assessment with grading | Diagnostics |
| `dot scorecard` | Unified health/security/performance scorecard | Diagnostics |
| `dot perf` | Predictable startup profiling (3-run average) | Diagnostics |
| `dot conflicts` | Report alias/command conflicts | Diagnostics |
| `dot locks` | Show version locks for key tools | Diagnostics |
| `dot snapshot` | Capture baseline system snapshot | Diagnostics |
| `dot benchmark` | Shell startup benchmark (`--detailed`, `--profile`) | Diagnostics |
| `dot restore` | Restore from backup or git ref | Diagnostics |
| `dot theme` | Switch terminal theme (dark/light) | UX |
| `dot wallpaper` | Apply a wallpaper from your library | UX |
| `dot keys` | Show keybindings catalog | UX |
| `dot mcp` | Inspect MCP server security and configuration | UX |
| `dot learn` | Interactive tour of tools (requires `gum`) | UX |
| `dot fonts` | Install Nerd Fonts | UX |
| `dot sandbox` | Launch a safe sandbox preview | Tools |
| `dot tools` | Show tools or install through Nix | Tools |
| `dot aliases` | List/search/explain alias definitions | Tools |
| `dot tools install` | Enter Nix development shell | Tools |
| `dot new` | Create a new project from a template | Tools |
| `dot log-rotate` | Rotate `~/.local/share/dotfiles.log` | Tools |
| `dot setup` | Interactive setup (profile, features, secrets) | Tools |
| `dot secrets-init` | Initialise age key for secrets | Secrets |
| `dot secrets` | Manage secrets (`edit|set|get|list|load|provider`) | Secrets |
| `dot env load <bucket>` | Emit shell exports for a secrets bucket | Secrets |
| `dot secrets-create` | Create an encrypted secrets file | Secrets |
| `dot ssh-key` | Encrypt an SSH key locally with age | Secrets |
| `dot backup` | Create a compressed backup of your home directory | Security |
| `dot firewall` | Apply firewall hardening (opt‑in) | Security |
| `dot telemetry` | Disable OS telemetry (opt‑in) | Security |
| `dot dns-doh` | Enable DNS‑over‑HTTPS (opt‑in) | Security |
| `dot encrypt-check` | Check disk encryption status | Security |
| `dot lock-screen` | Enforce lock‑screen idle settings (opt‑in) | Security |
| `dot usb-safety` | Disable automount for removable media | Security |

### Alias Modes (2026)

- `DOTFILES_ALIAS_PROFILE=standard` (default): balanced alias set.
- `DOTFILES_ALIAS_PROFILE=minimal`: trims heavy cloud/security/AI packs.
- `DOTFILES_ALIAS_PROFILE=full`: loads all alias packs.
- `DOTFILES_ALIAS_ECOSYSTEMS=all` (default): load all ecosystem alias families.
- `DOTFILES_ALIAS_ECOSYSTEMS=python,node`: only load selected ecosystems (valid tags: `python,node,rust,network,legacy`).
- `DOTFILES_ENABLE_CD_ALIAS=1`: opt-in override for `cd` -> `cd_with_history`.
- `DOTFILES_SECURITY_MODE=strict`: enables high-impact security aliases (for example UFW mutation aliases).
- `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`: opt-in destructive aliases (`git reset --hard`, trash purge, force-push helpers).
- `DOTFILES_ALIAS_POLICY=strict`: fail alias governance on duplicate names and expired deprecated aliases (enabled by default in CI).

### Developer CLI Tools

These utilities are installed to `~/.local/bin/`:

| Tool | Description |
|------|-------------|
| `jsonv` | JSON validator and formatter |
| `yamlv` | YAML validator |
| `epoch` | Unix timestamp converter |
| `b64` | Base64 encoder/decoder |
| `jwt` | JWT token decoder |
| `hex` | Hex viewer/converter |
| `regex` | Regex tester |
| `lorem` | Lorem ipsum generator |
| `uuid` | UUID generator |
| `hash` | MD5/SHA hash calculator |
| `myip` | Show public/local IP addresses |
| `kill-port` | Kill process by port |
| `extract` | Universal archive extraction |
| `update` | Update all system packages |

**Examples**

```bash
# Initialise secrets (prints a public key)
DOTFILES_NONINTERACTIVE=1 dot secrets-init
# Output: Age key created at ~/.config/chezmoi/key.txt

# Store and retrieve a secret via the configured provider
dot secrets set GEMINI_API_KEY
dot secrets get GEMINI_API_KEY --raw

# Load the AI bucket into your current shell
eval "$(dot env load ai)"
```

### Security changes

These scripts are **opt‑in** and run only when you set the matching environment variable.
All security changes are logged to `~/.local/share/dotfiles.log`.

| Script | macOS | Linux |
|---|---|---|
| `dot firewall` | Enables macOS firewall and stealth mode via `socketfilterfw` | Configures UFW defaults and OpenSSH allow |
| `dot telemetry` | Writes `DiagnosticMessagesHistory.plist` flags | Disables `whoopsie`, `apport`, `popularity-contest` |
| `dot dns-doh` | No system change (browser‑level only) | Enables DoH via `resolvectl` with Cloudflare DNS |
| `dot lock-screen` | `com.apple.screensaver` defaults and idleTime | GNOME `gsettings` lock and idle timeout |
| `dot usb-safety` | No system change (manual UI) | GNOME `gsettings` automount off |
| `dot encrypt-check` | Reads FileVault status via `fdesetup` | Detects LUKS via `lsblk` |

### Nix

Nix is **optional**. The repo does **not** install the Nix daemon.

- Use `nix develop` to enter a reproducible shell environment.
- Use `dot tools` to see the curated utilities overview.
- No toggle replaces Homebrew or Apt with Nix automatically.

---

### Install guide

See [docs/INSTALL.md](docs/INSTALL.md) for prerequisites, supported platforms, and the full install flow.

<p align="right"><a href="#dotfiles--your-shell-everywhere">↑ Back to Top</a></p>

## How it works

If Mermaid does not render, the flow is: `install.sh` → `Chezmoi` → `~/.dotfiles` → `~/.config + ~/.local`.

```mermaid
flowchart LR
  A["install.sh"] --> B["Chezmoi"]
  B --> C["~/.dotfiles (source)"]
  B --> D["~/.config + ~/.local (targets)"]
  E["dot CLI"] --> B
  E --> F["scripts/*"]
```

### Shell startup flow

```
.zshenv ─▶ .zshrc ─▶ rc.d/{10..50} ─▶ shell/{00,05,40,50,90} ─▶ [precmd: 91-lazy] ─▶ tool init
   │          │            │                    │                        │                   │
   │          │            │                    │                        │                   ├─ atuin
  XDG      zinit      options,            paths, safety,          tool-specific          ├─ starship
  PATH     plugins    lazy fnm/nvm        functions,              aliases (deferred)     ├─ zoxide
                                          core aliases (eager)                           └─ fzf
```

Core aliases (~40KB) load at startup. Tool-specific aliases (~137KB) load after the first prompt via a `precmd` hook — keeping shell startup fast while still providing full alias coverage. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full startup sequence and ordering conventions.

**Repository Layout**

```text
~/.dotfiles/
├── dot_config/                 # Maps to ~/.config/ (app configs)
│   ├── nvim/                    # Neovim config (Lua)
│   ├── zsh/                     # Zsh config (modular)
│   ├── tmux/                    # Tmux config
│   ├── shell/                   # Shell logic (aliases, functions, paths)
│   ├── wezterm/ alacritty/ kitty/ ghostty/
│   ├── btop/ fastfetch/ atuin/ yazi/ ...
│   └── docker/ containers/ ...
├── dot_local/                  # Maps to ~/.local/ (CLI tools)
│   └── bin/                     # dot CLI and helpers
├── dot_etc/                    # System configs (sudoers, sysctl, Chrome policies; may require sudo)
├── dot_ssh/                    # SSH config templates
├── templates/                  # Project scaffolds used by `dot new`
├── scripts/                    # Install, security, theme, diagnostics
├── install/                    # Chezmoi run_onchange and run_before hooks
├── nix/                        # Optional Nix shell environment
├── docs/                       # Guides, keys, roadmap, architecture
└── install.sh                  # Bootstrap installer
```

---

## Roadmap

Track progress on [GitHub Issues](https://github.com/sebastienrousseau/dotfiles/issues) and [Milestones](https://github.com/sebastienrousseau/dotfiles/milestones).

---

## Contribute

Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) before opening a pull request.

For security issues, see [SECURITY.md](.github/SECURITY.md).

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE).

Some bundled third‑party dependencies are licensed under GPL‑3.0; the LICENSE file lists them explicitly.

---

<div align="center">

🎨 Designed by **[](https://sebastienrousseau.com/)**
🚀 Engineered with **[Euxis](https://euxis.co/)** — Enterprise Unified eXecution Intelligence System

</div>
