---
render_with_liquid: false
---

# Keybindings

This is the single source of truth for navigation and muscle-memory shortcuts
across the dotfiles stack. Keep it concise and consistent.

(This page is about keyboard shortcuts, not cryptographic keys. It stays at
this path because other pages and tools link to it. For signing and
encryption keys see [KEY_ROTATION.md](KEY_ROTATION.md) and the repository's
`KEYS.asc`.)

## Zsh

- `Ctrl+R`: History search with `atuin` when it is installed. Without
  `atuin`, fzf's history widget when fzf's key bindings are loaded, and
  zsh's incremental history search otherwise.
- `Ctrl+P` / `Ctrl+N`: History prefix search (up/down)

## Tmux (prefix = `Ctrl-a`)

- `Prefix + r`: Reload config
- `Prefix + N`: New window
- `Prefix + a` / `Tab`: Last window
- `Prefix + %`: Split vertical, panes side by side (current path)
- `Prefix + "`: Split horizontal, panes stacked (current path)
- `Prefix + |`: Split vertical (alt)
- `Prefix + \`: Split horizontal (alt)
- `Prefix + h/j/k/l`: Move between panes (vim-style)
- `Prefix + z`: Toggle zoom pane
- `Prefix + H/J/K/L`: Resize pane (left/down/up/right)
- `Prefix + Q`: Kill the tmux server, all sessions (asks for confirmation)

## Neovim (leader = `Space`)

- `Ctrl-h/j/k/l`: Move between splits
- `Ctrl-s`: Save file
- `Leader + ff`: Find files (Telescope)
- `Leader + fg`: Live grep (Telescope)
- `Leader + q`: Quit

## Shell Tools

- `z <dir>`: Jump to a directory (`zoxide`)
- `lg`: `git log --graph --oneline --decorate --all`
- `lgui`: Open `lazygit`

## Terminal

- `Ctrl+Shift+C`: Copy
- `Ctrl+Shift+V`: Paste

---

Update this file when bindings change. If you add a new tool, add its shortcuts
here and keep them aligned with the global conventions.
