# Feature flags

Feature flags let you enable or disable specific parts of the dotfiles configuration. They use the `.chezmoidata.toml` file and template conditions.

## Overview

You can toggle features based on your needs. For example, you might enable Docker aliases but leave Kubernetes tools off until you need them.

## Configuration file

Set feature flags in `~/.dotfiles/.chezmoidata.toml`:

```toml
[features]
docker = true
kubernetes = false
nix = false
```

## Available features

### Core features

| Flag | Default | Description |
|------|---------|-------------|
| `shell.zsh` | `true` | Enable Zsh configuration |
| `shell.bash_fallback` | `true` | Enable Bash fallback configuration |
| `shell.starship` | `true` | Enable Starship prompt |

### Editor features

| Flag | Default | Description |
|------|---------|-------------|
| `editor.neovim` | `true` | Enable Neovim configuration |
| `editor.vim_fallback` | `true` | Enable Vim fallback configuration |
| `editor.vscode` | `false` | Enable VS Code settings sync |

### Terminal features

| Flag | Default | Description |
|------|---------|-------------|
| `terminal.ghostty` | `true` | Enable Ghostty configuration |
| `terminal.wezterm` | `false` | Enable WezTerm configuration |
| `terminal.alacritty` | `false` | Enable Alacritty configuration |
| `terminal.kitty` | `false` | Enable Kitty configuration |
| `terminal.tmux` | `true` | Enable tmux configuration |

### Tool features

| Flag | Default | Description |
|------|---------|-------------|
| `tools.docker` | `true` | Enable Docker aliases and config |
| `tools.kubernetes` | `false` | Enable Kubernetes tools and aliases |
| `tools.git` | `true` | Enable Git configuration |
| `tools.lazygit` | `true` | Enable Lazygit configuration |

### Security features

| Flag | Default | Description |
|------|---------|-------------|
| `security.gnupg` | `false` | Enable GnuPG configuration |
| `security.age` | `true` | Enable Age encryption |
| `security.ssh` | `true` | Enable SSH configuration |

### Optional toolchains

| Flag | Default | Description |
|------|---------|-------------|
| `toolchain.nix` | `false` | Enable Nix flake integration |
| `toolchain.homebrew` | `true` | Enable Homebrew on macOS |

## Enabling features

### Via chezmoidata.toml

Edit `~/.dotfiles/.chezmoidata.toml`:

```toml
[features]
kubernetes = true
```

Then apply your changes:

```bash
chezmoi apply
```

### Via chezmoi.toml

For machine-specific overrides, edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
kubernetes = true
```

## Creating feature-gated configs

In your template files, use conditionals:

```
{{- if .features.kubernetes }}
# Kubernetes configuration here
{{- end }}
```

## Checking active features

Run `dot doctor` to see which features are currently enabled.
