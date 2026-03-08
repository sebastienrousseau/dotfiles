-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.

-- Require Neovim >= 0.11.2 for native LSP improvements and vim.snippet
if vim.fn.has("nvim-0.11.2") ~= 1 then
  vim.api.nvim_echo({
    { "Dotfiles Neovim config requires Neovim >= 0.11.2\n", "ErrorMsg" },
    { "Current: " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch .. "\n", "WarningMsg" },
  }, true, {})
  return
end

require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
