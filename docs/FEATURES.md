# Feature Flags

This page documents the feature flags available in the dotfiles configuration.

## Overview

Feature flags are controlled via the `.chezmoidata.toml` file and template conditions. They allow you to enable or disable specific functionality based on your needs.

## Configuration File

Feature flags are set in `~/.dotfiles/.chezmoidata.toml`:

```toml
[features]
docker = true
kubernetes = false
nix = false
```

## Available Features

### Core Features

| Flag | Default | Description |
|------|---------|-------------|
| `shell.zsh` | `true` | Enable Zsh configuration |
| `shell.bash_fallback` | `true` | Enable Bash fallback configuration |
| `shell.starship` | `true` | Enable Starship prompt |

### Editor Features

| Flag | Default | Description |
|------|---------|-------------|
| `editor.neovim` | `true` | Enable Neovim configuration |
| `editor.vim_fallback` | `true` | Enable Vim fallback configuration |
| `editor.vscode` | `false` | Enable VS Code settings sync |

### Terminal Features

| Flag | Default | Description |
|------|---------|-------------|
| `terminal.ghostty` | `true` | Enable Ghostty configuration |
| `terminal.wezterm` | `false` | Enable WezTerm configuration |
| `terminal.alacritty` | `false` | Enable Alacritty configuration |
| `terminal.kitty` | `false` | Enable Kitty configuration |
| `terminal.tmux` | `true` | Enable tmux configuration |

### Tool Features

| Flag | Default | Description |
|------|---------|-------------|
| `tools.docker` | `true` | Enable Docker aliases and config |
| `tools.kubernetes` | `false` | Enable Kubernetes tools and aliases |
| `tools.git` | `true` | Enable Git configuration |
| `tools.lazygit` | `true` | Enable Lazygit configuration |

### Security Features

| Flag | Default | Description |
|------|---------|-------------|
| `security.gnupg` | `false` | Enable GnuPG configuration |
| `security.age` | `true` | Enable Age encryption |
| `security.ssh` | `true` | Enable SSH configuration |

### Optional Toolchains

| Flag | Default | Description |
|------|---------|-------------|
| `toolchain.nix` | `false` | Enable Nix flake integration |
| `toolchain.homebrew` | `true` | Enable Homebrew on macOS |

## Enabling Features

### Via chezmoidata.toml

Edit `~/.dotfiles/.chezmoidata.toml`:

```toml
[features]
kubernetes = true
```

Then apply:

```bash
chezmoi apply
```

### Via chezmoi.toml

For machine-specific overrides, edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
kubernetes = true
```

## Creating Feature-Gated Configs

In template files, use conditionals:

```
{{- if .features.kubernetes }}
# Kubernetes configuration here
{{- end }}
```

## Checking Active Features

Run `dot doctor` to see which features are currently enabled.
