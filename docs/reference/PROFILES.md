---
render_with_liquid: false
---

# Profiles and Machine Setup

## Profile System

You can set up each machine differently using a profile name, a hardware preset and feature flags.

### Setting Your Profile

`chezmoi init` prompts for `profile` (default `laptop`) and writes it to the `[data]` section of `~/.config/chezmoi/chezmoi.toml`. Add `machine` there by hand to pick a hardware preset:

```toml
[data]
profile = "laptop"
machine = "macbook-t2"    # optional: a key under [machines.*] in defaults/.chezmoidata/hardware.toml
```

`chezmoi init` regenerates `chezmoi.toml` from `defaults/.chezmoi.toml.tmpl`. It carries over `profile`, `theme`, the git identity, `theme_family`, `theme_mode` and the age settings, but not keys you added by hand such as `machine` or `[data.features]`: re-add them after a re-init.

### What the Profile Changes

The profile is a free-form name, not a bundle of features. Features are switched by the `[features]` flags (see [FEATURES.md](FEATURES.md)). Today the profile name is read in these places:

| Where | Effect |
|-------|--------|
| `~/.zshrc` | Exported as `DOTFILES_PROFILE`. `laptop` and `desktop` turn on `compinit` by default; any other value leaves it off (override with `DOTFILES_ENABLE_COMPINIT`). |
| `scripts/tuning/linux.sh`, `scripts/tuning/macos.sh` | Accept `laptop`, `desktop` or `server` from `DOTFILES_PROFILE`. |
| niri config header | Printed as a comment. |

`dot config profile show` prints the profile (from `~/.config/chezmoi/chezmoi.toml`, else the source `.chezmoidata.toml`) and the `[features]` block from the source. `dot config profile set <name>` writes `profile` under `[data]` in `~/.config/chezmoi/chezmoi.toml`, which takes precedence over the source file (`chezmoi init` always writes one).

### Per-Machine Overrides

Add keys to the `[data]` section of `~/.config/chezmoi/chezmoi.toml` on each machine to override the defaults in `defaults/.chezmoidata.toml`:

```toml
[data]
profile = "laptop"
machine = "macbook-t2"
default_shell = "zsh"

[data.features]
linux_desktop = false
zellij = true
```

### Hardware Presets

`defaults/.chezmoidata/hardware.toml` holds the default `[hardware]` table (scale, HiDPI, touch, refresh rate, GPU, keyboard and touchpad settings, display output) and one `[machines.<name>]` table per preset:

- `macbook-t2`: Intel MacBook with T2 chip running Linux
- `surface-pro`: Microsoft Surface Pro (Linux)
- `geekom-a9`: AMD mini PC (Linux desktop)

When `machine` names one of these, the niri config uses that preset in place of `[hardware]`. You can also override single values with `[data.hardware]` in `chezmoi.toml`.

The kanshi config matches `machine` against its own names (`surface-pro-7p`, `mac-t2-linux`, `geekom-a9`), so only `geekom-a9` is understood by both templates today.

### Starter Feature Sets

`templates/chezmoi-data/` has example values for common hardware:

- `mac-m1.toml.example`: Apple Silicon MacBook
- `geekom-a9.toml.example`: AMD mini PC (Linux)
- `surface-pro-7p.toml.example`: Microsoft Surface (Linux)
- `mac-t2-linux.toml.example`: Intel Mac running Linux

Each holds a `profile` line and a `[features]` table. They are not complete config files: do not copy one over `~/.config/chezmoi/chezmoi.toml`, which would discard your age identity, git identity and theme settings. Copy the values into your existing config instead, `profile` under `[data]` and the `[features]` entries under `[data.features]`, then preview and apply:

```bash
chezmoi diff
chezmoi apply
```

### Environment Variables

You can change zsh startup for a single session without editing any files:

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTFILES_FAST=1` | 0 | Skip heavy startup work (plugins, completions, prompt tooling, AI helpers) |
| `DOTFILES_ULTRA_FAST=1` | 0 | Minimal init: no `rc.d`, plugins, completions or prompt tooling |
| `DOTFILES_AI=1` | 0 | Source the opt-in AI shell helpers (context suggestions, error analysis) |
| `DOTFILES_STARTUP_MODE=fast` or `ultra` | full | Same as setting `DOTFILES_FAST=1` or `DOTFILES_ULTRA_FAST=1` |

`DOTFILES_PROFILE` is exported by `~/.zshrc` from the chezmoi data, so setting it before starting a shell does not change the profile.
