# Neovim

## Modern Core
- **Requirement**: Neovim >= 0.11.2. The config checks this at startup.
- **Configuration**: Modular, lazy-loaded configuration based on `lazy.nvim`.
- **Completion**: `blink.cmp` for fast, keystroke-level completion with LSP, snippets, and path sources.
- **UI**: Snacks.nvim dashboard, notifications, status line, buffer line, and file explorer.
- **LSP**: Full LSP support for diagnostics, code actions, and more, managed by `mason.nvim`.

## Language Support
- **Rust**: Out-of-the-box support with `rustaceanvim`.
- **Python**: Full support with `basedpyright`, `ruff`, and `venv-selector`.
- **Web**: Support for web development with `prettier` and `eslint`.

## AI Integration
- **Copilot**: `copilot.lua` for code completion. Run `:Copilot auth` to sign in.
- **Copilot Chat**: AI sidebar for asking questions and getting help (`<leader>cc`).

## VS Code Parity
- **Problem Panel**: `trouble.nvim` for a VS Code-like problems panel (`<leader>xx`).
- **Search & Replace**: `nvim-spectre` for project-wide search and replace (`<leader>S`).
- **Auto-Pairs**: Automatically closes brackets and pairs (via `blink.cmp` auto-brackets).
- **TODOs**: Highlights `TODO` and `FIXME` comments.
- **Session**: Auto-restores your last session.
- **Snippets**: Native `vim.snippet` engine (Neovim 0.11+).

## Keybindings
| Key | Action |
| --- | --- |
| `<Space>ff` | Find Files |
| `<Space>fg` | Grep (Search) text |
| `<Space>fb` | File browser |
| `<Space>fp` | Projects |
| `<Space>e` | Toggle File Explorer |
| `<Space>a` | Add file to Harpoon |
| `<Ctrl>e` | Open Harpoon menu |
| `gd` | Go to Definition |
| `gr` | Go to References |
| `<leader>ca` | Code actions |
| `<leader>cf` | Format code |
| `<leader>cr` | Rename symbol |
| `<leader>tt` | Toggle terminal |
| `<leader>tn` | Test nearest |
| `<leader>tf` | Test file |
| `<leader>ts` | Test suite |
| `<F5>` | Continue (Debug) |
| `<F10>` | Step over (Debug) |
| `<F11>` | Step into (Debug) |
| `<F12>` | Step out (Debug) |
| `<leader>cc` | Toggle Copilot Chat |
| `<leader>xx` | Toggle Diagnostics (Trouble) |
| `<leader>S` | Toggle Spectre (Search/Replace) |
