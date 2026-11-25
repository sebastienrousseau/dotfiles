-- SPDX-License-Identifier: Apache-2.0 OR MIT
-- Copyright (c) 2015-2026 Sebastien Rousseau
return {
  {
    "ThePrimeagen/git-worktree.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("git-worktree").setup({})
    end,
  },
}
