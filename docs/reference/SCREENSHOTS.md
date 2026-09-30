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

Each tmux session gets its own Apple system color, so sessions are told apart at
a glance; the rest of the frame is fixed. Every badge has a white label and
meets WCAG AAA, and both bars show the same elements at any window width:

- Top bar: the current window (bold, `*`, zoom flag) in white on black from the left edge, then the CPU, memory, and battery indicators on Apple cyan
- Bottom bar, transparent between its badges: a mode badge on the session's color (terminal icon and session name; a keyboard and `PREFIX` while the tmux prefix is armed; `COPY` in copy mode), the other windows with their native last, bell, and activity flags, `SYNC` and `SSH` when relevant, the directory, and the time on Apple cyan

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
