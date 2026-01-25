# Keybindings Catalog

This is the single source of truth for navigation and muscle-memory shortcuts
across the dotfiles stack. Keep this concise and consistent.

## Zsh
- Ctrl+R: History search (fzf/atuin if enabled)
- Ctrl+P / Ctrl+N: History prefix search (up/down)

## Tmux (prefix = `Ctrl-a`)
- Prefix + r: Reload config
- Prefix + N: New window
- Prefix + a / Tab: Last window
- Prefix + %: Split vertical (current path)
- Prefix + ": Split horizontal (current path)
- Prefix + \\: Split vertical (alt)
- Prefix + |: Split horizontal (alt)
- Prefix + h/j/k/l: Move between panes (vim-style)
- Prefix + z: Toggle zoom pane
- Prefix + H/J/K/L: Resize pane (left/down/up/right)

## Neovim (leader = `Space`)
- Ctrl-h/j/k/l: Move between splits
- Ctrl-s: Save file
- Leader + ff: Find files (Telescope)
- Leader + fg: Live grep (Telescope)
- Leader + q: Quit

## Shell Tools
- z <dir>: Jump to a directory (zoxide)
- lg: Open lazygit

## Terminal
- Ctrl+Shift+C: Copy
- Ctrl+Shift+V: Paste

---

Update this file when bindings change. If you add a new tool, add its shortcuts
here and keep them aligned with the global conventions.
