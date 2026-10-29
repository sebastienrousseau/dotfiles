---
render_with_liquid: false
---
{% raw %}

# Reference: Feature Flags

Feature flags toggle optional subsystems. Defaults live in `defaults/.chezmoidata.toml`; override them per host under `[data.features]` in `~/.config/chezmoi/chezmoi.toml`. Hardware presets in `.chezmoidata/hardware.toml` carry no flags.

## Global Flags (`.chezmoidata.toml`)

```toml
[features]
alias_wrapper = false
dms = true
zellij = false
ai_theme_sync = true
linux_desktop = false
niri = false
waybar = false
fuzzel = false
mako = false
foot = false
kanshi = false
touch = false
t2 = false
surface = false
corral_gitea_mirror = false

[features.ai_theme_providers]
codex = true
claude = true
gemini = true
agy = true
qwen = true
opencode = true
```

## Per-Host Overrides (`~/.config/chezmoi/chezmoi.toml`)

```toml
[data.features]
niri = true
linux_desktop = true
corral_gitea_mirror = true
```

Values here replace the defaults for that host at render time.

## Flag Catalogue

### `linux_desktop` — Linux Desktop Configs

When `true`:

- Deploys `~/.config/environment.d`, the systemd user units in `~/.config/systemd` and `~/.config/mako` (left out by `.chezmoiignore.tmpl` when `false`)
- Ghostty uses top GTK tabs and copy-on-select; Kitty sets `linux_display_server wayland`
- fontconfig turns off subpixel (rgb) rendering

The Ghostty, Kitty and fontconfig changes also follow `niri`. On macOS the Linux desktop paths stay ignored whatever the flag says.

### `niri` — Niri Window Manager

When `true`:

- Deploys `~/.config/niri/config.kdl`, `~/.local/bin/start-niri` and the Wayland session files
- The Niri config reads the hardware defaults or the `.machine` preset (output, scale, refresh rate)
- Turns on the same Ghostty, Kitty and fontconfig changes as `linux_desktop`

Requires: Niri installed.

### `zellij` — Zellij Terminal Multiplexer

When `true`:

- Deploys `~/.config/zellij/config.kdl` (its theme is set in that file, not derived from the active palette)
- Adds Zellij to the Linux package provisioning

Requires: Zellij installed (or the Linux provisioning step).

### `fuzzel`, `foot`, `kanshi`: Wayland Tools

When `true`, deploys `~/.config/fuzzel/`, `~/.config/foot/` or `~/.config/kanshi/` respectively. The Fuzzel and Foot configs take their colours from the active theme. No effect on macOS.

### `corral_gitea_mirror`: GitHub to Gitea Mirror

Linux only. When `true`, deploys `corralctl.service`, `corralctl.timer` and the `corralctl-*` scripts in `~/.local/bin`, and enables the timer with `systemctl --user enable --now corralctl.timer`. Meant for one machine; enable it per host.

### `ai_theme_sync` and `ai_theme_providers`: AI CLI Appearance

When `ai_theme_sync` is `true`, a theme switch (`dot-theme-sync`) also aligns the installed AI CLIs' themes with the active palette, for each provider set to `true` under `ai_theme_providers` (`codex`, `claude`, `gemini`, `agy`, `qwen`, `opencode`). Provider configs stay user-owned: malformed or concurrently changed files are never overwritten.

### `alias_wrapper`

When `true`, `.zshrc` exports `DOTFILES_ALIAS_WRAPPER=1`. Nothing reads that variable today, so the flag has no effect. The `alias` pretty-printer in `rc.d/99-alias-wrapper.zsh` is loaded whatever the flag says.

### `dms`, `waybar`, `mako`, `touch`, `t2`, `surface`: Not Read

No template, ignore rule or script reads these flags today; setting them changes nothing. `dot-theme-sync` updates Dank Material Shell whenever the `dms` command is installed on Linux, the Waybar config is deployed regardless of `waybar`, and the Mako config follows `linux_desktop`.

## Using a Flag in a Template

```go
{{ if .features.niri }}
# Niri-specific config
{{ end }}
```

## Checking Active Flags

```sh
chezmoi execute-template '{{ .features | toToml }}'
```

On a host with no overrides this prints the defaults:

```
ai_theme_sync = true
alias_wrapper = false
corral_gitea_mirror = false
dms = true
foot = false
fuzzel = false
kanshi = false
linux_desktop = false
mako = false
niri = false
surface = false
t2 = false
touch = false
waybar = false
zellij = false

[ai_theme_providers]
  agy = true
  claude = true
  codex = true
  gemini = true
  opencode = true
  qwen = true
```

`dot config profile show` lists the `[features]` defaults from the source, without per-host overrides.

## Adding a New Flag

1. Add to `defaults/.chezmoidata.toml`:

   ```toml
   [features]
   my_new_flag = false
   ```

2. (Optional) Turn it on for one host in `~/.config/chezmoi/chezmoi.toml`:

   ```toml
   [data.features]
   my_new_flag = true
   ```

3. Use in templates:

   ```go
   {{ if .features.my_new_flag }}
   # conditional config
   {{ end }}
   ```

4. Document here with the flag's purpose and requirements

## Flag Deprecation

Flags can be deprecated without breaking existing hosts. The deprecation process:

1. Mark the flag as deprecated in this document
2. Leave the flag evaluation in place for one release
3. In the subsequent release, remove the template branches and the flag definition
4. Users who had the flag set will see it ignored — no errors

## See Also

- [Configuration Files](02-config-files.md)
- [Create a Profile](../02-tutorials/03-create-profile.md)
{% endraw %}
