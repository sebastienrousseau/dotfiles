---
render_with_liquid: false
---

# Feature Flags Reference

Feature flags let you turn parts of the dotfiles on or off. The defaults live in `defaults/.chezmoidata.toml` under `[features]`. Set a flag to `true` to enable it, or `false` to disable it. Changes take effect after you run `dot apply`.

## Shell and Terminal

These flags control shell behavior and terminal tools.

| Flag | Default | Description |
|------|---------|-------------|
| `alias_wrapper` | `false` | Exports `DOTFILES_ALIAS_WRAPPER=1` in zsh. Nothing reads that variable today, so the flag has no effect yet. |
| `dms` | `true` | Dank Material Shell accent colors. Not read by any template today: `dot-theme-sync` drives DMS whenever the `dms` command is installed. |
| `zellij` | `false` | Deploy the Zellij multiplexer config (`~/.config/zellij`) |
| `ai_theme_sync` | `true` | Let `dot-theme-sync` update AI CLI appearance settings to match the theme |

Each AI CLI can be opted out on its own under `[features.ai_theme_providers]`: `codex`, `claude`, `gemini`, `agy`, `qwen`, `opencode` (all `true` by default).

## Linux Desktop

These flags gate Wayland desktop configs. Turn them on if you run a Linux desktop with Niri or another tiling compositor.

| Flag | Default | Description |
|------|---------|-------------|
| `linux_desktop` | `false` | Deploy `~/.config/environment.d`, `~/.config/mako` and the systemd user units |
| `niri` | `false` | Deploy the Niri compositor config, `start-niri` and the Wayland session file |
| `fuzzel` | `false` | Deploy the Fuzzel launcher config |
| `foot` | `false` | Deploy the Foot terminal config |
| `kanshi` | `false` | Deploy the Kanshi display profiles |
| `waybar` | `false` | Reserved: the Waybar config is deployed regardless today |
| `mako` | `false` | Reserved: the Mako config follows `linux_desktop` today |

## Hardware

These flags are set by the starter files in `templates/chezmoi-data/` but no template reads them yet. Hardware tuning comes from the `machine` preset instead (see [PROFILES.md](PROFILES.md)).

| Flag | Default | Description |
|------|---------|-------------|
| `touch` | `false` | Touchscreen hardware (reserved) |
| `t2` | `false` | Apple T2 Mac running Linux (reserved) |
| `surface` | `false` | Microsoft Surface hardware (reserved) |

## Per-host Services

| Flag | Default | Description |
|------|---------|-------------|
| `corral_gitea_mirror` | `false` | Linux only: deploy the nightly GitHub to Gitea mirror timer (`corralctl.timer`) and its scripts. Enable it on one machine. |

## Tool Selection

| Setting | Default | Options |
|---------|---------|---------|
| `tools.node_manager` | `mise` | `mise`, `fnm`, `nvm` (read by zsh) |

## Alias Policy

| Setting | Default | Description |
|---------|---------|-------------|
| `aliases.buckets.system` | `true` | Enable system utility aliases |
| `aliases.buckets.svn` | `true` | Enable SVN aliases |
| `aliases.policy.strict_mode` | `false` | Intended to require confirmation for destructive aliases. zsh reads a top-level `strict_mode` key instead, so set `DOTFILES_ALIAS_STRICT_MODE=1` in your environment to turn the confirmation on. |

## How to Toggle Features

You can edit flags in two places. Change `defaults/.chezmoidata.toml` in the repo to set defaults for all machines. Or override on a single machine in `~/.config/chezmoi/chezmoi.toml`:

```toml
# In ~/.config/chezmoi/chezmoi.toml
[data.features]
zellij = true
linux_desktop = true
```

Then apply:

```bash
dot apply
```
