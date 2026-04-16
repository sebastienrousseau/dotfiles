# Reference: Feature Flags

Feature flags toggle optional subsystems. Set in `.chezmoidata.toml`, override per-preset in `.chezmoidata/hardware.toml`.

## Global Flags (`.chezmoidata.toml`)

```toml
[features]
dms = false                # Dank Material Shell (Niri desktop)
linux_desktop = false      # Linux-specific desktop configs
niri = false               # Niri window manager
waybar = false             # Waybar status bar
```

## Per-Preset Overrides (`.chezmoidata/hardware.toml`)

```toml
[hardware.surface-pro.features]
niri = true
waybar = true
dms = true                 # overrides .chezmoidata.toml default
```

The effective value is `mergeOverwrite` of global + preset features.

## Flag Catalogue

### `dms` — Dank Material Shell

When `true`:
- Configures DMS IPC for theme sync
- Enables Quickshell templates
- Sets up per-monitor wallpaper via `dms ipc wallpaper`

Requires: Niri + Quickshell + DMS installed.

### `linux_desktop` — Linux Desktop Configs

When `true`:
- Enables GTK 3/4 theme generation from `themes.toml`
- Configures `gsettings color-scheme` behaviour
- Generates desktop file entries for installed tools

No effect on macOS.

### `niri` — Niri Window Manager

When `true`:
- Generates `~/.config/niri/config.kdl`
- Enables Niri keybindings from `keybinds.toml`
- Configures workspace rules per preset

Requires: Niri installed.

### `waybar` — Waybar Status Bar

When `true`:
- Generates `~/.config/waybar/config.jsonc` + `style.css`
- Hooks into theme switching via `dot-theme-sync`

Requires: Waybar installed.

## Using a Flag in a Template

```go
{{- $hw := index .hardware .machine }}
{{- $f := mergeOverwrite .features $hw.features }}

{{ if $f.niri }}
# Niri-specific config
{{ end }}
```

## Checking Active Flags

```sh
chezmoi execute-template '{{- $hw := index .hardware .machine -}}{{- $f := mergeOverwrite .features $hw.features -}}{{ $f | toToml }}'
```

## Adding a New Flag

1. Add to `.chezmoidata.toml`:

   ```toml
   [features]
   my_new_flag = false
   ```

2. (Optional) Set per preset:

   ```toml
   [hardware.macbook-t2.features]
   my_new_flag = true
   ```

3. Use in templates:

   ```go
   {{ if $f.my_new_flag }}
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
