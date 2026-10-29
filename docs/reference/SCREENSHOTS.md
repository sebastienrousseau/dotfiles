---
render_with_liquid: false
---

# Screenshots Gallery

Here's how the dotfiles look across different themes and configurations.

## Theme Gallery

Colors come from the wallpaper-derived themes in `defaults/.theme-manifest/themes.toml` (see the [Theming Guide](../guides/THEMING.md)). Each family has a dark and a light variant.

### Maui Dark (default)

The default theme family is `maui`, in `auto` mode: it follows the system appearance.

```text
Terminal: Ghostty / WezTerm / Alacritty / Kitty
Font:     JetBrainsMono Nerd Font
Theme:    maui-dark
```

Key colors:

- Background: `#0f1f21`
- Foreground: `#f1f6f7`
- Accent: `#00d2e0`
- Red: `#ff8282`

### Maui Light

The light variant, used when the system appearance is light.

```text
Terminal: Ghostty / WezTerm / Alacritty / Kitty
Font:     JetBrainsMono Nerd Font
Theme:    maui-light
```

Key colors:

- Background: `#e9f4fa`
- Foreground: `#1c1d1e`
- Cursor: `#005e8b`
- Red: `#a80000`

## Terminal Configurations

### Ghostty

Modern, native terminal with GPU acceleration.

- Native macOS integration
- Fast rendering
- Ligature support
- Custom key bindings

### WezTerm

Cross-platform terminal with Lua configuration.

- GPU acceleration
- Multiple windows/tabs
- Hyperlinks
- Image protocol support

### Alacritty

Minimal, fast terminal.

- Fast rendering
- Simple TOML config
- Vi mode
- Cross-platform

### Kitty

Feature-rich terminal.

- GPU rendering
- Ligatures
- Image support
- Keyboard protocol

## Prompt (Starship)

The Starship prompt displays:

- Current directory
- Git branch and status
- Language versions (when relevant)
- Command duration
- Exit status

## Neovim

The Neovim configuration includes:

- A `dotfiles` colorscheme generated from the active theme
- Treesitter syntax highlighting
- LSP integration
- Telescope fuzzy finder
- File tree (`nvim-tree`)

## tmux

Each tmux session gets its own Apple system color, so sessions are told apart at
a glance; the rest of the frame is fixed. Every badge has a white label and
meets WCAG AAA, and both bars show the same elements at any window width:

- Top bar: the current window (bold, `*`, zoom flag) in white on black from the left edge, then the CPU, memory, and battery indicators on Apple cyan
- Bottom bar, transparent between its badges: a mode badge on the session's color (terminal icon and session name; a keyboard and `PREFIX` while the tmux prefix is armed; `COPY` in copy mode), the other windows with their native last, bell, and activity flags, `SYNC` and `SSH` when relevant, the directory, and the time on Apple cyan

Press `prefix + A` to open the AI CLI launcher in the current workspace.
Press `prefix + T` to pick a theme in a popup, or `prefix + C-t` for a random
wallpaper theme; both reload tmux in place. Keys and options you put in
`~/.config/tmux/local.conf` load last, so they survive every theme change.
AI provider sessions started after a theme switch inherit the same light/dark
mode and wallpaper palette; restart existing TUIs because providers cache their
appearance independently from tmux.

## Adding Screenshots

To contribute screenshots:

1. Take a screenshot of your terminal.
2. Save it as a PNG in `docs/themes/`.
3. Add a reference in this file.
4. Submit a PR.

Recommended screenshot size: 1920x1080 or 2560x1440.
