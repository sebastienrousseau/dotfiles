return {
  {
    "mrcjkb/rustaceanvim",
    version = "^4", -- Recommended
    ft = { "rust" },
    config = function()
      vim.g.rustaceanvim = {
        -- Plugin configuration
        tools = {},
        -- LSP configuration
        server = {
          on_attach = function(_client, _bufnr)
            -- You can Set keybindings here.
            -- rustaceanvim defaults are pretty good though.
          end,
          default_settings = {
            -- rust-analyzer language server configuration
            ["rust-analyzer"] = {},
          },
        },
        -- DAP configuration
        dap = {},
      }
    end,
  },
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup()
    end,
  },
}
