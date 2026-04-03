-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim
    .system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    })
    :wait()
end
vim.opt.rtp:prepend(lazypath)

-- User-local plugin specs (not managed by chezmoi)
local _lazy_spec = {
  { import = "plugins" },
}
local _user_plugins = vim.fn.stdpath("config") .. "/lua/plugins.local"
if vim.uv.fs_stat(_user_plugins) then
  table.insert(_lazy_spec, { import = "plugins.local" })
end

require("lazy").setup({
  spec = _lazy_spec,
  defaults = {
    lazy = false,
    version = false,
  },
  checker = { enabled = true },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
