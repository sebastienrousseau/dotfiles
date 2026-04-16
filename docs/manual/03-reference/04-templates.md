# Reference: Template Variables

Every variable available to chezmoi templates (`.tmpl` files).

## From `.chezmoidata.toml`

Flat top-level keys:

| Variable | Type | Example |
|:---|:---|:---|
| `.dotfiles_version` | string | `"0.2.500"` |
| `.theme` | string | `"tahoe-dark"` |
| `.machine` | string | `"macbook-t2"` |
| `.profile` | string | `"laptop"` |
| `.default_shell` | string | `"fish"` |
| `.terminal_font_family` | string | `"JetBrainsMono Nerd Font"` |
| `.terminal_font_size` | int | `12` |
| `.name` | string | `"Your Name"` |
| `.email` | string | `"you@example.com"` |

## From `.chezmoidata/themes.toml`

```go
{{- $t := index .themes .theme }}
{{ $t.mode }}              // "dark" or "light"
{{ $t.family }}            // "tahoe"
{{ $t.macos_accent }}      // 4 (integer)
{{ $t.term.bg }}           // "#121430"
{{ $t.term.fg }}           // "#d4d8ec"
{{ $t.term.c0 }} .. {{ $t.term.c15 }}   // ANSI 0-15
{{ $t.ui.accent }}         // "#3951b1"
{{ $t.ui.accent_text }}    // "#ffffff"
{{ $t.ui.panel }}
{{ $t.ui.border }}
{{ $t.app.nvim }}          // "catppuccin"
{{ $t.app.starship_palette }}
```

## From `.chezmoidata/hardware.toml`

```go
{{- $hw := index .hardware .machine }}
{{ $hw.display_scale }}    // 2.0
{{ $hw.kbd_layout }}       // "qwerty"
{{ $hw.modifier_mode }}    // "left-cmd-control"
{{ $hw.perf_profile }}     // "laptop"
{{ $hw.wm }}               // "aerospace"
{{ $hw.features.touchid }} // bool
```

## From Feature Flags

```go
{{- $f := mergeOverwrite .features $hw.features }}
{{ if $f.dms }}
# Dank Material Shell-specific config
{{ end }}

{{ if $f.niri }}
# Niri WM config
{{ end }}
```

## Built-in Chezmoi Variables

```go
{{ .chezmoi.os }}                // "darwin" | "linux" | "windows"
{{ .chezmoi.arch }}              // "amd64" | "arm64"
{{ .chezmoi.kernel }}            // "Darwin" | "Linux"
{{ .chezmoi.kernel.ostype }}     // "darwin24" etc
{{ .chezmoi.hostname }}          // host machine hostname
{{ .chezmoi.username }}          // current user
{{ .chezmoi.homeDir }}           // $HOME
{{ .chezmoi.sourceDir }}         // ~/.dotfiles
{{ .chezmoi.workingTree }}       // git working tree root
{{ .chezmoi.executable }}        // chezmoi binary path
{{ .chezmoi.osRelease }}         // Linux /etc/os-release data
```

## Built-in Chezmoi Functions

```go
{{ exec "command" | trim }}
{{ output "hostname" }}
{{ include "path/to/file" }}
{{ decrypt "path/to/file.age" }}
{{ sopsDecrypt "path/to/file.sops.yaml" | fromYaml }}
{{ joinPath "a" "b" }}
{{ stat "/path" }}
{{ ioreg ".." ".." }}             // macOS only
{{ lookPath "command" }}           // returns path or empty
```

## Helper Templates (in `.chezmoitemplates/`)

Reusable partials included via:

```go
{{ template "paths/00-default.paths.sh" . }}
{{ template "aliases/cd.aliases.sh" . }}
{{ template "functions/cdls.sh" . }}
```

Available partials:

- `paths/00-default.paths.sh` — canonical PATH construction
- `paths/05-pipx.paths.sh` — pipx + ~/.local/bin
- `paths/99-custom.paths.sh` — user-appended paths
- `aliases/*.aliases.sh` — per-domain alias sets
- `functions/*.sh` — reusable shell functions

## Example: Using Theme in Ghostty Config

```go
{{- /* dot_config/ghostty/config.tmpl */ -}}
{{- $t := index .themes .theme -}}

font-family = "{{ .terminal_font_family }}"
font-size = {{ .terminal_font_size }}

background = {{ $t.term.bg }}
foreground = {{ $t.term.fg }}
cursor-color = {{ $t.term.cursor }}

palette = 0={{ $t.term.c0 }}
palette = 1={{ $t.term.c1 }}
palette = 2={{ $t.term.c2 }}
# ... through 15

{{- if eq .chezmoi.os "darwin" }}
macos-titlebar-style = transparent
{{- end }}
```

## Example: Platform × Preset

```go
{{- $hw := index .hardware .machine -}}

{{- if and (eq .chezmoi.os "darwin") (eq $hw.wm "aerospace") }}
# macOS AeroSpace config
include = ["aerospace-macos.toml"]
{{- else if and (eq .chezmoi.os "linux") (eq $hw.wm "niri") }}
# Linux Niri config
include = ["niri.kdl"]
{{- end }}

# DPI-aware sizing
font-size = {{ mul 8 $hw.display_scale | int }}
```

## Template Testing

Render a template without applying:

```sh
chezmoi execute-template < dot_config/ghostty/config.tmpl
```

Or test an expression:

```sh
chezmoi execute-template '{{ .chezmoi.os }}'
# darwin

chezmoi execute-template '{{- $t := index .themes .theme -}}{{ $t.term.bg }}'
# #121430
```

## Validation in CI

Every push to master runs:

```sh
chezmoi apply --dry-run
```

If any template fails to render, the build breaks before merge.

## See Also

- [Chezmoi template reference](https://www.chezmoi.io/reference/templates/)
- [Configuration Files](02-config-files.md)
- [Create a Profile tutorial](../02-tutorials/03-create-profile.md)
