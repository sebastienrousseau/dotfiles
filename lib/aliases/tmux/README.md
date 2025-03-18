<!-- markdownlint-disable MD033 MD041 MD043 -->

<img
  src="https://kura.pro/dotfiles/v2/images/logos/dotfiles.svg"
  alt="dotfiles logo"
  width="66"
  align="right"
/>

<!-- markdownlint-enable MD033 MD041 -->

# Dotfiles (v0.2.470)

Simply designed to fit your shell life 🐚

![Dotfiles banner][banner]

## 🆃🅼🆄🆇 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽

A comprehensive tmux configuration designed for productivity and ease of use. The configuration is organized in modular files for better maintainability:

- **default**: Core settings and plugin configuration
- **display**: Visual and behaviour settings
- **linux**: Platform-specific functionality
- **navigation**: Comprehensive key bindings
- **panes**: Pane-specific settings
- **theme**: Status bar and visual styling

### Key Features

- Modern color scheme with OS-specific status bar styling
- Intuitive key bindings with Ctrl+a as the prefix key
- Comprehensive window and pane management controls
- Session persistence with tmux-resurrect and tmux-continuum
- Scrollable help menu (press `Ctrl+a ?` to access)
- Mouse support for easy navigation

### Navigation & Key Bindings

Press `Ctrl+a ?` to see all available key bindings. Major features include:

- **Window Management**: Split, create, navigate, and rename windows with ease
- **Pane Navigation**: Move between panes with vim-style h/j/k/l keys
- **Session Management**: Create, rename, and switch between sessions
- **Copy Mode**: Vim-style selection, searching, and clipboard integration

## 🆃🅼🆄🆇 🅰🅻🅸🅰🆂🅴🆂

Convenient aliases for tmux operations:

| Alias | Description |
|-------|-------------|
| `tm`  | Start tmux |
| `tma` | Attach to last session |
| `tmat` | Attach to specific session |
| `tmks` | Kill all sessions except current |
| `tmka` | Kill all sessions (server) |
| `tml` | List all sessions |
| `tmn` | New unnamed session |
| `tms` | New named session |
| `tmr` | Reload tmux configuration |
| `tmls` | List windows |
| `tmlp` | List panes |
| `tmi` | Show tmux info |

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/sebastienrousseau/dotfiles.git ~/.dotfiles
   ```

2. Run the installation script:

   ```bash
   cd ~/.dotfiles && ./install.sh
   ```

3. Install tmux plugin manager (if not already installed):

   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

4. Open tmux and press `Ctrl+a I` to install plugins

## Usage

Start a new tmux session with:

```bash
tmux
```

Or use any of the provided aliases for common operations.

## License

MIT

[banner]: https://kura.pro/dotfiles/v2/images/titles/title-dotfiles.svg
