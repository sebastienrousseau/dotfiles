# Profiles and Machine Setup

## Profile System

You can set up each machine differently using profiles and hardware presets.

### Setting Your Profile

Edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
profile = "laptop"        # laptop | minimal | server
machine = "macbook-m3"    # optional: machine identifier
```

### Available Profiles

| Profile | Description | What's Included |
|---------|-------------|-----------------|
| `laptop` | Full desktop setup (default) | All tools, AI CLIs, themes, completions |
| `minimal` | Fast, lightweight | Core shell, git, basic aliases only |
| `server` | Headless server | Shell, git, monitoring tools, no desktop |

### Per-Machine Overrides

Create a `~/.config/chezmoi/chezmoi.toml` file on each machine to override defaults:

```toml
[data]
profile = "laptop"
machine = "work-macbook"
default_shell = "zsh"

[data.features]
linux_desktop = false
zellij = true
```

### Hardware Presets

The `templates/chezmoi-data/` folder has ready-made configs for common hardware:

- `mac-m1.toml.example` — Apple Silicon MacBook
- `geekom-a9.toml.example` — AMD mini PC (Linux)
- `surface-pro-7p.toml.example` — Microsoft Surface (Linux)
- `mac-t2-linux.toml.example` — Intel Mac running Linux

Copy the one that matches your hardware:

```bash
cp templates/chezmoi-data/mac-m1.toml.example ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

### Environment Variables

You can change behavior for a single session without editing any files:

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTFILES_FAST=1` | 0 | Skip heavy layers (zinit, completions) |
| `DOTFILES_ULTRA_FAST=1` | 0 | Bare minimum shell (aliases + prompt) |
| `DOTFILES_AI=1` | 0 | Enable AI helper scripts |
| `DOTFILES_PROFILE=custom` | laptop | Override profile for session |
