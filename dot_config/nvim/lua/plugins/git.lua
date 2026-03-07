-- Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
return {
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("git-worktree").setup({})
    end,
  },
}
