return {
  -----------------------------------------------------------------------------
  -- 1. Problems Panel (Trouble)
  -----------------------------------------------------------------------------
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
      modes = {
        lsp = {
          win = { position = "bottom" },
        },
      },
    },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
      { "<leader>cs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols (Trouble)" },
      { "<leader>cl", "<cmd>Trouble lsp toggle<cr>", desc = "LSP Definitions / references / ... (Trouble)" },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
    },
  },

  -----------------------------------------------------------------------------
  -- 2. Search & Replace (Spectre)
  -----------------------------------------------------------------------------
  {
    "nvim-pack/nvim-spectre",
    build = false,
    cmd = "Spectre",
    opts = { open_cmd = "noswapfile vnew" },
    keys = {
      { "<leader>S", function() require("spectre").toggle() end, desc = "Spectre" },
      { "<leader>sw", function() require("spectre").open_visual({select_word=true}) end, desc = "Search current word" },
      { "<leader>sw", function() require("spectre").open_visual() end, mode = "v", desc = "Search current word" },
    },
  },

  -----------------------------------------------------------------------------
  -- 3. Auto-Closing Brackets (Autopairs)
  -----------------------------------------------------------------------------
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
        check_ts = true, -- Enable Treesitter integration
        ts_config = {
            lua = { "string", "source" },
            javascript = { "string", "template_string" },
        },
        disable_filetype = { "TelescopePrompt", "spectre_panel" },
    },
    config = function(_, opts)
        local np = require("nvim-autopairs")
        np.setup(opts)
        -- Identify cmp to add bracket completion
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        local cmp = require("cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  -----------------------------------------------------------------------------
  -- 4. TODO Highlighting (Todo Comments)
  -----------------------------------------------------------------------------
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    opts = { signs = false }, -- Use highlighting only (less clutter)
    keys = {
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo (Trouble)" },
      { "<leader>xT", "<cmd>TodoTelescope<cr>", desc = "Todo (Telescope)" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous Todo" },
    },
  },

  -----------------------------------------------------------------------------
  -- 5. Session Restore (Persistence)
  -----------------------------------------------------------------------------
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = { options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp" } },
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },
}
