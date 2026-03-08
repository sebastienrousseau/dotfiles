-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- AI-assisted coding plugins
-- Loaded when ai_tools feature is enabled in .chezmoidata.toml

return {
  -- GitHub Copilot: AI code completion
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<M-l>",
            accept_word = "<M-k>",
            accept_line = "<M-j>",
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = {
          enabled = true,
          auto_refresh = true,
          keymap = {
            open = "<M-CR>",
          },
        },
        filetypes = {
          yaml = true,
          markdown = true,
          gitcommit = true,
          ["."] = false,
        },
      })
    end,
  },

  -- Copilot Chat: interactive AI chat in a split
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "zbirenbaum/copilot.lua",
      "nvim-lua/plenary.nvim",
    },
    cmd = {
      "CopilotChat",
      "CopilotChatExplain",
      "CopilotChatReview",
      "CopilotChatFix",
      "CopilotChatOptimize",
      "CopilotChatTests",
      "CopilotChatDocs",
    },
    keys = {
      { "<leader>aa", "<cmd>CopilotChat<CR>", desc = "AI Chat" },
      { "<leader>ae", "<cmd>CopilotChatExplain<CR>", desc = "AI Explain", mode = { "n", "v" } },
      { "<leader>ar", "<cmd>CopilotChatReview<CR>", desc = "AI Review", mode = { "n", "v" } },
      { "<leader>af", "<cmd>CopilotChatFix<CR>", desc = "AI Fix", mode = { "n", "v" } },
      { "<leader>ao", "<cmd>CopilotChatOptimize<CR>", desc = "AI Optimize", mode = { "n", "v" } },
      { "<leader>at", "<cmd>CopilotChatTests<CR>", desc = "AI Tests", mode = { "n", "v" } },
      { "<leader>ad", "<cmd>CopilotChatDocs<CR>", desc = "AI Docs", mode = { "n", "v" } },
    },
    opts = {
      model = "gpt-4o",
      window = {
        layout = "vertical",
        width = 0.3,
      },
    },
  },
}
