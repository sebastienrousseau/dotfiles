-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
return {
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    -- Upstream's installer fetches the prebuilt preview server. The previous
    -- `cd app && npm install` rewrote app/yarn.lock on every build (npm
    -- resolves against registry.npmjs.org, the lockfile against yarnpkg.com),
    -- which left the checkout dirty and made Lazy refuse every later update.
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_command_for_global = 0
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" },
    },
  },
}
