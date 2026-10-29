---
render_with_liquid: false
---
{% raw %}

# Tutorial: Create a Machine Profile

Machine presets tell chezmoi how to render templates differently on each host: display scale, refresh rate, touchpad, GPU, the main output. Feature flags and the `profile` value cover the rest.

## When to Use a Preset

- You have more than one host (laptop + desktop, work + personal)
- Your hardware differs materially (HiDPI laptop vs 1080p external, touchscreen vs none)
- Certain features only apply to specific setups (Niri on Wayland, a touch screen)

## Step 1: Choose or Create a Preset

The defaults and the presets live in `defaults/.chezmoidata/hardware.toml` in the source (`~/.dotfiles`). `[hardware]` holds the defaults; each `[machines.<name>]` table is a complete preset with the same keys:

```toml
[hardware]
profile = "laptop"
scale = 1.0
hidpi = false
touchscreen = false
touchpad = true
max_refresh = 60
gpu = "integrated"
keyboard_layout = "us"
touchpad_accel = 0.0
touchpad_accel_profile = "adaptive"
output_name = ""
output_mode = ""

[machines.surface-pro]
profile = "laptop"
scale = 1.5
hidpi = true
touchscreen = true
touchpad = true
max_refresh = 60
gpu = "integrated"
keyboard_layout = "us"
touchpad_accel = 0.2
touchpad_accel_profile = "adaptive"
output_name = "eDP-1"
output_mode = "2736x1824@60"
```

The shipped presets are `macbook-t2`, `surface-pro` and `geekom-a9`. If one fits, use its name. Otherwise, add a new one (Step 4).

## Step 2: Select the Preset for This Host

Edit `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
machine = "surface-pro"      # a [machines.*] name from defaults/.chezmoidata/hardware.toml
theme = "monterey-dark"
default_shell = "fish"
terminal_font_family = "JetBrainsMono Nerd Font"
terminal_font_size = 11       # larger for HiDPI, smaller for dense screens
```

`chezmoi.toml` is **not** in the repository: each host has its own. The installer creates it with `sourceDir` and your git identity; `dot config init` (`chezmoi init`) prompts for the profile, theme and git settings.

For a one-off host you can skip the preset and override single keys instead:

```toml
[data.hardware]
scale = 2.0
hidpi = true
max_refresh = 120
```

## Step 3: Reference the Preset in Templates

A preset replaces `.hardware` as a whole; it is not merged key by key. Templates resolve it like this (from `defaults/dot_config/niri/config.kdl.tmpl`):

```go
{{ $hw := .hardware -}}
{{- $machine := .machine -}}
{{- if and $machine (ne $machine "") -}}
  {{- $m := index .machines $machine -}}
  {{- if $m -}}
    {{- $hw = $m -}}
  {{- end -}}
{{- end -}}

{{- if and $hw.output_name $hw.output_mode }}
output "{{ $hw.output_name }}" {
    mode "{{ $hw.output_mode }}"
    scale {{ $hw.scale }}
}
{{- end }}
```

An unknown `machine` name falls back to `[hardware]`. Today the Niri config is the template that reads the preset this way; `defaults/dot_config/kanshi/config.tmpl` matches on `.machine` names directly.

After editing a template, run `dot apply`.

## Step 4: Add a New Preset

Suppose you have a new mini PC. Add a table to `defaults/.chezmoidata/hardware.toml`, with every key that `[hardware]` has:

```toml
[machines.my-nuc]
profile = "desktop"
scale = 1.0                   # external 1440p
hidpi = false
touchscreen = false
touchpad = false
max_refresh = 144
gpu = "discrete"
keyboard_layout = "us"
touchpad_accel = 0.0
touchpad_accel_profile = "flat"
output_name = "DP-1"
output_mode = "2560x1440@144"
```

Then on that host:

```toml
# ~/.config/chezmoi/chezmoi.toml
[data]
machine = "my-nuc"
```

Apply:

```sh
dot apply
```

Templates that resolve the preset pick up the new data.

## Step 5: Per-Host Feature Flags

Feature flags are not part of a preset. Their defaults live in `defaults/.chezmoidata.toml`:

```toml
[features]
dms = true
linux_desktop = false
waybar = false
```

Override them for one host in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data.features]
linux_desktop = true
niri = true
waybar = true
touch = true
```

In templates:

```go
{{ if .features.waybar }}
# ... waybar-specific config ...
{{ end }}
```

## Example: Font Size by Preset

A template can size things from the resolved preset:

```go
{{- $hw := .hardware -}}
{{- with .machine }}{{ with index $.machines . }}{{ $hw = . }}{{ end }}{{ end -}}

font-family = "{{ .terminal_font_family }}"

{{ if eq $hw.scale 2.0 }}
font-size = 12               # Retina MacBook
{{ else if eq $hw.scale 1.5 }}
font-size = 11               # Surface Pro
{{ else }}
font-size = 14               # External 1440p/4K
{{ end }}
```

On the MacBook: 12pt. On the Surface: 11pt. On the NUC: 14pt. One template.

## Example: Platform × Preset

Combine `.chezmoi.os` with the preset:

```go
{{ if and (eq .chezmoi.os "linux") (eq $hw.profile "desktop") }}
# Linux desktop specifics
{{ else if eq .chezmoi.os "darwin" }}
# macOS specifics
{{ end }}
```

## Listing Known Presets

```sh
chezmoi execute-template '{{- range $name, $_ := .machines }}{{ $name }}{{ "\n" }}{{ end }}'
# geekom-a9
# macbook-t2
# surface-pro
```

## Changing Presets on an Existing Host

If you reassign a host to a different preset:

```sh
# Edit ~/.config/chezmoi/chezmoi.toml
# machine = "my-nuc" (was "surface-pro")

dot diff              # preview changes
dot apply             # apply
```

Chezmoi re-renders every template with the new preset data. No reboot needed.

## Troubleshooting

### Templates Silently Use Defaults

The `machine` value in `~/.config/chezmoi/chezmoi.toml` doesn't match any `[machines.*]` key in `defaults/.chezmoidata/hardware.toml`, so templates fall back to `[hardware]`. Nothing warns about it: check the spelling against the preset list above.

### Feature Flag Not Taking Effect

Print the flags chezmoi sees for this host:

```sh
chezmoi execute-template '{{ .features | toToml }}'
```

A value in `[data.features]` in `~/.config/chezmoi/chezmoi.toml` overrides the default in `defaults/.chezmoidata.toml`. If the output doesn't reflect your override, check the table name and the TOML syntax.

## Summary

Presets let one source tree produce correctly configured output on every host you own. The machinery:

1. `defaults/.chezmoidata/hardware.toml` defines `[hardware]` defaults and `[machines.*]` presets (declarative)
2. `~/.config/chezmoi/chezmoi.toml` selects a preset per host with `machine`, and can override `[data.hardware]` and `[data.features]`
3. `.tmpl` files read `.hardware`, `.machines` and `.machine` (template-time)

## Next

- [Concept: Fleet Architecture](../01-concepts/04-fleet.md)
- [Reference: Templates](../03-reference/04-templates.md)
- [Reference: Feature Flags](../03-reference/05-feature-flags.md)
{% endraw %}
