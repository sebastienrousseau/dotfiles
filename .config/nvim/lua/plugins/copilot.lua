return {
  -- Main Copilot Plugin
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false },
        panel = { enabled = false },
        -- Keeping the Node path fix just in case, as the shell is still v18
        copilot_node_command = "/home/seb/.local/share/fnm/node-versions/v22.22.0/installation/bin/node",
      })
    end,
  },

  -- Copilot Chat (VS Code style chat in sidebar)
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" }, -- or github/copilot.vim
      { "nvim-lua/plenary.nvim" }, -- for curl, log wrapper
    },
    opts = {
      debug = false, -- Disable debugging for cleaner logs
    },
    keys = {
      { "<leader>cc", ":CopilotChatToggle<CR>", desc = "Toggle Copilot Chat" },
      { "<leader>cq", ":CopilotChatQuick<CR>", desc = "Copilot Chat Quick" },
    },
  },
}
