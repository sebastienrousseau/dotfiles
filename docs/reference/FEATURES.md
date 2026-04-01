# Feature Flags Reference

All feature flags live in `.chezmoidata.toml` under `[features]`.

## Shell and Terminal

| Flag | Default | Description |
|------|---------|-------------|
| `alias_wrapper` | `false` | Enable alias governance wrapper (confirms destructive aliases) |
| `dms` | `true` | Dank Material Shell theming for GNOME |
| `zellij` | `false` | Enable Zellij terminal multiplexer config |

## Linux Desktop

| Flag | Default | Description |
|------|---------|-------------|
| `linux_desktop` | `false` | Enable full Linux desktop environment configs |
| `niri` | `false` | Niri Wayland compositor config |
| `waybar` | `false` | Waybar status bar config |
| `fuzzel` | `false` | Fuzzel application launcher config |
| `mako` | `false` | Mako notification daemon config |
| `foot` | `false` | Foot terminal emulator config |
| `kanshi` | `false` | Kanshi display manager config |

## Hardware

| Flag | Default | Description |
|------|---------|-------------|
| `touch` | `false` | Enable touchscreen support (gestures, on-screen keyboard) |
| `t2` | `false` | Apple T2 security chip handling |
| `surface` | `false` | Microsoft Surface hardware support |

## Tool Selection

| Setting | Default | Options |
|---------|---------|---------|
| `node_manager` | `mise` | `mise`, `fnm`, `nvm` |

## Alias Policy

| Setting | Default | Description |
|---------|---------|-------------|
| `aliases.buckets.system` | `true` | Enable system utility aliases |
| `aliases.buckets.svn` | `true` | Enable SVN aliases |
| `aliases.policy.strict_mode` | `false` | Require confirmation for destructive aliases (rm, mv) |

## How to Toggle Features

Edit `.chezmoidata.toml` in the repo, or override on a single machine in `~/.config/chezmoi/chezmoi.toml`:

```bash
# In ~/.config/chezmoi/chezmoi.toml
[data.features]
zellij = true
linux_desktop = true
```

Then apply: `dot apply`
