---
render_with_liquid: false
---

# Neovim

The config lives in `defaults/dot_config/nvim/` (deployed to `~/.config/nvim/`). Plugin specs are in `lua/plugins/*.lua`, keymaps in `lua/config/keymaps.lua`. Add your own specs in `~/.config/nvim/lua/plugins.local/`: `lua/config/lazy.lua` imports that directory when it exists.

## Modern Core

- **Requirement**: Neovim >= 0.11.2. `init.lua` checks this at startup.
- **Configuration**: Modular configuration on `lazy.nvim`, with the update checker on.
- **Completion**: `blink.cmp` with LSP, snippet (`friendly-snippets`) and path sources, and auto-brackets on accept.
- **UI**: `snacks.nvim` (dashboard and notifications), `noice.nvim`, `lualine.nvim` status line, `bufferline.nvim`, `nvim-tree.lua` file explorer, `which-key.nvim`, `gitsigns.nvim`, `indent-blankline.nvim`, `nvim-scrollbar`, `vim-illuminate` and `outline.nvim`.
- **LSP**: `nvim-lspconfig` with `mason.nvim` and `mason-lspconfig.nvim`. Servers: `bashls`, `lua_ls`, `basedpyright`, `ruff`, `ts_ls`.
- **Formatting and linting**: `conform.nvim` (format on demand) and `nvim-lint`.
- **Syntax**: `nvim-treesitter`.
- **Search**: `telescope.nvim` with `telescope-fzf-native.nvim`.

## Language Support

- **Rust**: `rustaceanvim` and `crates.nvim`.
- **Python**: `basedpyright`, `ruff`, `venv-selector.nvim`, `nvim-dap-python` and `neotest-python`.
- **Go**: debugging through `nvim-dap-go`.
- **Web**: `ts_ls`, with `prettierd` or `prettier` through `conform.nvim`.
- **Markdown**: `markdown-preview.nvim`.

## AI Integration

- **Copilot**: `copilot.lua` for inline suggestions (accept with `<M-l>`). Run `:Copilot auth` to sign in.
- **Copilot Chat**: `CopilotChat.nvim`, under the `<leader>a` group.

## Editing Tools

- **Testing**: `neotest` with Python and plenary adapters.
- **Debugging**: `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text` and `mason-nvim-dap.nvim`.
- **Terminal**: `toggleterm.nvim`.
- **Docstrings**: `neogen`.
- **Git worktrees**: `git-worktree.nvim`.
- **Sessions**: `persistence.nvim` saves sessions; restore one with `<leader>qs` or `<leader>ql`.
- **Snippets**: Native `vim.snippet` engine (Neovim 0.11+).

## Keybindings

`<leader>` is `<Space>`. LSP navigation uses Neovim's built-in defaults (`grr` references, `gri` implementation, `grn` rename, `gra` code action, `K` hover, `<C-]>` definition).

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Find text (live grep) |
| `<leader>fb` | Buffers |
| `<leader>fp` | Recent files |
| `<leader>e` | Toggle file explorer |
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<leader>ca` | Code actions |
| `<leader>cf` | Format buffer |
| `<leader>cr` | Rename symbol |
| `<leader>cs` | Symbols outline |
| `<leader>tt` | Toggle terminal |
| `<leader>tn` | Run nearest test |
| `<leader>tf` | Run test file |
| `<leader>ts` | Toggle test summary |
| `<F5>` / `<leader>dc` | Continue (Debug) |
| `<F10>` / `<leader>do` | Step over (Debug) |
| `<F11>` / `<leader>di` | Step into (Debug) |
| `<F12>` / `<leader>dO` | Step out (Debug) |
| `<leader>db` | Toggle breakpoint |
| `<leader>aa` | AI chat (Copilot Chat) |
| `<leader>ae` / `<leader>ar` / `<leader>af` | AI explain / review / fix |
| `<leader>gw` / `<leader>gW` | Git worktrees / create worktree |
| `<leader>qs` / `<leader>ql` | Restore session / last session |
| `<leader>mp` | Markdown preview |
| `<leader>l` | Lazy |
