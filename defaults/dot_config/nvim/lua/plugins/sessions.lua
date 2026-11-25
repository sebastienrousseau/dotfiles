-- SPDX-License-Identifier: Apache-2.0 OR MIT
-- Copyright (c) 2015-2026 Sebastien Rousseau
return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
      options = vim.opt.sessionoptions:get(),
    },
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Stop session saving",
      },
    },
  },
}
