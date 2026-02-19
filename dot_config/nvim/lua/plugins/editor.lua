return {
  "akinsho/toggleterm.nvim",
  version = "*",
  config = function()
    require("toggleterm").setup({
      -- Automatically close the terminal when the process exits.
      close_on_exit = true,

      -- Terminal window open mode (options: "vertical", "horizontal", "tab", "float").
      direction = "float",

      -- Options for the floating terminal window.
      float_opts = {
        -- Border style for the floating window.
        border = "curved",
        -- Set the floating window width to 80% of the current Neovim window width.
        width = math.floor(vim.o.columns * 0.8),
        -- Set the floating window height to 80% of the current Neovim window height.
        height = math.floor(vim.o.lines * 0.8),
      },

      -- Hide line numbers in the terminal buffer.
      hide_numbers = true,

      -- Default key mapping to toggle the terminal.
      open_mapping = [[<C-\>]],

      -- Persist the terminal size across sessions.
      persist_size = true,

      -- List of filetypes where shading is disabled (empty table means no exclusions).
      shade_filetypes = {},

      -- Enable shading for the terminal window.
      shade_terminals = true,

      -- Shading factor for the terminal (the higher the value, the darker it becomes).
      shading_factor = 2,

      -- Start the terminal in insert mode.
      start_in_insert = true,

      -- Use the default shell as defined by Neovim.
      shell = vim.o.shell,

      -- Set the terminal size (this can also be a function returning a size).
      size = 20,
    })

    -- Custom keybindings for toggling a floating terminal:
    -- <leader>ft toggles the floating terminal.
    vim.api.nvim_set_keymap(
      "n", -- Mode: normal
      "<leader>ft", -- Key combination
      "<Cmd>ToggleTerm direction=float<CR>", -- Command to execute
      { noremap = true, silent = true } -- Options: no recursive mapping, silent execution
    )
  end,
}
