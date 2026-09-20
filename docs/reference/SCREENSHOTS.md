---
render_with_liquid: false
---

# Screenshots Gallery

Here's how the dotfiles look across different themes and configurations.

## Theme Gallery

### Catppuccin Mocha (default)

The default theme. Catppuccin Mocha gives you a dark palette with warm, muted colors.

```text
Terminal: Ghostty / WezTerm / Alacritty
Font:     JetBrains Mono Nerd Font
Theme:    Catppuccin Mocha
```

Key colors:

- Background: `#1e1e2e`
- Foreground: `#cdd6f4`
- Accent Blue: `#89b4fa`
- Accent Red: `#f38ba8`

### Catppuccin Latte (light)

A light theme option for daytime use.

```text
Terminal: Ghostty / WezTerm / Alacritty
Font:     JetBrains Mono Nerd Font
Theme:    Catppuccin Latte
```

Key colors:

- Background: `#eff1f5`
- Foreground: `#4c4f69`
- Accent Blue: `#1e66f5`
- Accent Red: `#d20f39`

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
- Simple YAML config
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

- Catppuccin theme
- Treesitter syntax highlighting
- LSP integration
- Telescope fuzzy finder
- File tree (`nvim-tree`)

## tmux

The tmux status bar displays:

- A prominent rounded session-name pill with a stable per-session palette color
- A red keyboard state while the tmux prefix is active and dimmed blocks when the client loses focus
- Distinct wallpaper-derived primary, secondary, and tertiary color segments
- Compact window tabs with current, zoom, last, bell, and activity icons
- The active workload (including AI CLIs such as Claude and Codex) and time
- Responsive CWD and other-session context on wider terminals
- Copy, synchronized-pane, and SSH indicators only when relevant

Press `prefix + A` to open the AI CLI launcher in the current workspace.
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
