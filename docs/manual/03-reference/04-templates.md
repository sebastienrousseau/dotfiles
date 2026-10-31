---
render_with_liquid: false
---
{% raw %}

# Reference: Template Variables

The variables and helpers available to chezmoi templates (`.tmpl` files) under `defaults/`.

## From `.chezmoidata.toml`

Flat top-level keys (values as shipped, before any `chezmoi.toml` override):

| Variable | Type | Example |
|:---|:---|:---|
| `.dotfiles_version` | string | `"0.2.540"` |
| `.theme` | string | `"maui-dark"` |
| `.theme_family` | string | `"maui"` |
| `.theme_mode` | string | `"auto"` |
| `.machine` | string | `""` (or a preset such as `"macbook-t2"`) |
| `.profile` | string | `"laptop"` |
| `.default_shell` | string | `"fish"` |
| `.terminal_font_family` | string | `"JetBrainsMono Nerd Font"` |
| `.terminal_font_size` | int | `20` |
| `.name` | string | `""` |
| `.email` | string | `""` |
| `.features` | table | see [Feature Flags](05-feature-flags.md) |

`chezmoi init` also writes `.git_name`, `.git_email`, `.git_signingkey`, `.git_signingformat`, `.age_identity` and `.age_recipient` into `~/.config/chezmoi/chezmoi.toml`.

## From `.theme-manifest/themes.toml`

The theme manifest is not chezmoi data (it is too large to hand to every template), so a template loads it and resolves the active theme through the `theme-name` partial, which falls back to `fallback-dark` when `.theme` is missing:

```go
{{- $themes := (include ".theme-manifest/themes.toml" | fromToml).themes -}}
{{- $themeName := includeTemplate "theme-name" (dict "theme" .theme "themes" $themes) -}}
{{- $t := index $themes $themeName -}}
{{ $t.mode }}              // "dark" or "light"
{{ $t.family }}            // "maui"
{{ $t.macos_accent }}      // 4 (integer)
{{ $t.term.bg }}           // "#0f1f21"
{{ $t.term.fg }}           // "#f1f6f7"
{{ $t.term.c0 }} .. {{ $t.term.c15 }}   // ANSI 0-15
{{ $t.ui.accent }}         // "#00d2e0"
{{ $t.ui.accent_text }}    // "#000000"
{{ $t.ui.panel }}
{{ $t.ui.border }}
{{ $t.app.nvim }}          // "tokyonight"
{{ $t.app.starship_palette }}
```

The example values are those of `maui-dark`.

## From `.chezmoidata/hardware.toml`

`.hardware` holds the defaults and `.machines` the presets; a template picks the preset named by `.machine`, as `defaults/dot_config/niri/config.kdl.tmpl` does:

```go
{{ $hw := .hardware -}}
{{- if and .machine (ne .machine "") -}}
  {{- $m := index .machines .machine -}}
  {{- if $m -}}{{- $hw = $m -}}{{- end -}}
{{- end -}}
{{ $hw.scale }}            // 2.0 on macbook-t2
{{ $hw.hidpi }}            // bool
{{ $hw.max_refresh }}      // 60
{{ $hw.keyboard_layout }}  // "us"
{{ $hw.output_name }}      // "eDP-1"
{{ $hw.profile }}          // "laptop" | "desktop"
```

## From Feature Flags

Flags are read straight from `.features`; presets carry no flags of their own:

```go
{{ if .features.niri }}
# Niri WM config
{{ end }}

{{- $linuxDesktop := or .features.linux_desktop .features.niri -}}
```

## Built-in Chezmoi Variables

```go
{{ .chezmoi.os }}                // "darwin" | "linux" | "windows"
{{ .chezmoi.arch }}              // "amd64" | "arm64"
{{ .chezmoi.kernel.ostype }}     // "Linux" (Linux only)
{{ .chezmoi.kernel.osrelease }}  // kernel release; contains "microsoft" on WSL (Linux only)
{{ .chezmoi.hostname }}          // host machine hostname
{{ .chezmoi.username }}          // current user
{{ .chezmoi.homeDir }}           // $HOME
{{ .chezmoi.sourceDir }}         // ~/.dotfiles/defaults (the .chezmoiroot)
{{ .chezmoi.workingTree }}       // git working tree root (~/.dotfiles)
{{ .chezmoi.executable }}        // chezmoi binary path
{{ .chezmoi.osRelease }}         // Linux /etc/os-release data
```

## Built-in Chezmoi Functions

Functions the templates here use:

```go
{{ output "hostname" }}
{{ include ".theme-manifest/themes.toml" | fromToml }}
{{ includeTemplate "theme-name" (dict "theme" .theme "themes" $themes) }}
{{ glob (joinPath .chezmoi.sourceDir ".chezmoitemplates/aliases/**/*.aliases.sh") }}
{{ decrypt "path/to/file.age" }}
{{ stat "/path" }}
{{ lookPath "command" }}           // returns path or empty
```

See the [chezmoi template reference](https://www.chezmoi.io/reference/templates/) for the rest.

## Helper Templates (in `.chezmoitemplates/`)

Named partials, included with `template` or `includeTemplate`:

```go
{{ template "go-build-command" . }}
{{- $name := includeTemplate "theme-name" (dict "theme" .theme "themes" $themes) -}}
```

Available partials:

- `theme-name`: resolve the active theme name, with the `fallback-dark` fallback
- `go-build-command`: the build step shared by the `run_onchange_24/25/26-build-*` scripts (dot-ui, dot-ai-tui, dot-mcp)
- `desktop/shell-theme.dconf.tmpl`: GNOME Shell theme settings

The same directory holds the alias and function sources: `aliases/<group>/*.aliases.sh` are gathered by `dot_config/shell/91-ux-aliases-lazy.sh.tmpl` with `glob`, and `functions/<group>/*.sh` are listed in `functions/groups.json` for the fish and nushell function files.

## Example: Using Theme in Ghostty Config

An excerpt of `defaults/dot_config/ghostty/config.tmpl`:

```go
{{ $fontFamily := default "JetBrains Mono" .terminal_font_family -}}
{{- $fontSize := default 20 .terminal_font_size -}}
{{- $linuxDesktop := or .features.linux_desktop .features.niri -}}

{{ $themes := (include ".theme-manifest/themes.toml" | fromToml).themes -}}
{{- $themeName := includeTemplate "theme-name" (dict "theme" .theme "themes" $themes) -}}
{{- $t := index $themes $themeName -}}
background = {{ $t.term.bg }}
foreground = {{ $t.term.fg }}
cursor-color = {{ $t.term.cursor }}
palette = 0={{ $t.term.c0 }}
palette = 1={{ $t.term.c1 }}
# ... through 15

{{- if $linuxDesktop }}
gtk-tabs-location = top
copy-on-select = clipboard
{{- end }}
```

## Example: Platform × Preset

An excerpt of the Niri template's output block:

```go
{{- if and $hw.output_name $hw.output_mode }}
output "{{ $hw.output_name }}" {
    mode "{{ $hw.output_mode }}"
    scale {{ $hw.scale }}
{{- if gt (int $hw.max_refresh) 60 }}
    variable-refresh-rate
{{- end }}
}
{{- end }}
```

## Template Testing

Render a template without applying (from `~/.dotfiles`):

```sh
chezmoi execute-template < defaults/dot_config/ghostty/config.tmpl
```

Or test an expression:

```sh
chezmoi execute-template '{{ .chezmoi.os }}'
# linux

chezmoi execute-template '{{- $themes := (include ".theme-manifest/themes.toml" | fromToml).themes -}}{{- $n := includeTemplate "theme-name" (dict "theme" .theme "themes" $themes) -}}{{ (index $themes $n).term.bg }}'
# #0f1f21
```

## Validation in CI

Every pull request to `main`, and every push to `main`, that touches shell scripts, templates or `dot_*` sources runs, on Linux and macOS (`ci.yml`):

```sh
chezmoi init
chezmoi apply --verbose --dry-run
```

If any template fails to render, the build breaks before merge.

## See Also

- [Chezmoi template reference](https://www.chezmoi.io/reference/templates/)
- [Configuration Files](02-config-files.md)
- [Create a Profile tutorial](../02-tutorials/03-create-profile.md)
{% endraw %}
