return {
  -- Mason (Manage External Tools)
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup()
    end,
  },
  
  -- Mason LSP Config + Manual Server Setup
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      -- 1. Setup capabilities for LSP
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- 2. Setup mason-lspconfig with handlers (prevents automatic_enable errors)
      require("mason-lspconfig").setup({
        ensure_installed = { "bashls", "lua_ls", "basedpyright", "ruff" },
        automatic_installation = true,
        automatic_setup = false, -- Disable automatic_enable feature that causes errors
        handlers = {
          -- Default handler for all servers
          function(server_name)
            require("lspconfig")[server_name].setup({
              capabilities = capabilities,
            })
          end,
          
          -- Custom handler for lua_ls
          ["lua_ls"] = function()
            require("lspconfig").lua_ls.setup({
              capabilities = capabilities,
              settings = {
                Lua = {
                  diagnostics = { globals = { "vim" } },
                  workspace = { checkThirdParty = false },
                  telemetry = { enable = false },
                  hint = { enable = true },
                },
              },
            })
          end,
          
          -- Custom handler for basedpyright
          ["basedpyright"] = function()
            require("lspconfig").basedpyright.setup({
              capabilities = capabilities,
              settings = {
                basedpyright = {
                  analysis = {
                    typeCheckingMode = "basic",
                    autoSearchPaths = true,
                    useLibraryCodeForTypes = true,
                    diagnosticMode = "openFilesOnly",
                    inlayHints = {
                      variableTypes = true,
                      functionReturnTypes = true,
                    },
                  }
                }
              }
            })
          end,
        },
      })

      -- Diagnostic Configuration
      vim.diagnostic.config({
         underline = true,
         update_in_insert = false,
         virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = "●",
         },
         severity_sort = true,
      })
    end,
  },

  -- Formatting: Conform
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_fallback = true }) end,
        mode = "",
        desc = "Format Buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        rust = { "rustfmt" },
        javascript = { { "prettierd", "prettier" } },
        bash = { "shfmt" },
      },
      format_on_save = { timeout_ms = 500, lsp_fallback = true },
    },
  },

  -- Autocompletion: CMP (Optimized)
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local lspkind = require("lspkind")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
           completion = cmp.config.window.bordered(),
           documentation = cmp.config.window.bordered(),
        },
        formatting = {
           format = lspkind.cmp_format({
             mode = "symbol_text",
             maxwidth = 50,
             ellipsis_char = "...",
           }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
             if cmp.visible() then
               cmp.select_next_item()
             elseif luasnip.expand_or_jumpable() then
               luasnip.expand_or_jump()
             else
               fallback()
             end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
             if cmp.visible() then
               cmp.select_prev_item()
             elseif luasnip.jumpable(-1) then
               luasnip.jump(-1)
             else
               fallback()
             end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
}
