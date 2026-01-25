return {
  -----------------------------------------------------------------------------
  -- 1. Dashboard (Snacks.nvim)
  -----------------------------------------------------------------------------
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
        preset = {
          header = [[
██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝

Simply design to fit your shell life
          ]],
          keys = {
            { icon = "📂", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "📝", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = "🔎", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "🕒", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "🐍", key = "p", desc = "Select Env", action = ":VenvSelect" }, -- Fixed: Specific VS Code-like task
            { icon = "⚙️", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "📦", key = "m", desc = "Manage Packages", action = ":Lazy" },
            { icon = "❌", key = "q", desc = "Quit", action = ":qa" },
          }
        }
      }
    }
  },

  -----------------------------------------------------------------------------
  -- 2. Command Line & Notifications (Noice.nvim) - VS Code feel
  -----------------------------------------------------------------------------
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
        hover = { enabled = true },
        signature = { enabled = true },
      },
      presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = true, -- add a border to hover docs and signature help
      },
      notify = { enabled = false }, -- Fix: Allow nvim-notify to handle notifications directly
    }
  },

  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 3000,
      render = "wrapped-compact",
      background_colour = "#000000",
    },
  },

  -----------------------------------------------------------------------------
  -- 3. File Explorer (Nvim-Tree)
  -----------------------------------------------------------------------------
  {
    "nvim-tree/nvim-tree.lua",
    cmd = "NvimTreeToggle",
    keys = { { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle Explorer" } },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = { enable = true, update_root = true },
        view = { width = 35, side = "left" },
        renderer = { 
            indent_markers = { enable = true },
            icons = { 
                git_placement = "before",
                show = { git = true, folder = true, file = true, folder_arrow = true } 
            } 
        },
        actions = { open_file = { quit_on_open = false } },
        git = { enable = true, ignore = false },
      })
    end,
  },

  -----------------------------------------------------------------------------
  -- 4. Status Line (Lualine)
  -----------------------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        component_separators = "|",
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
        lualine_b = { "filename", "branch" },
        lualine_c = { "diagnostics" },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { { "location", separator = { right = "" }, left_padding = 2 } },
      },
    },
  },

  -----------------------------------------------------------------------------
  -- 5. Tabs (Bufferline)
  -----------------------------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        mode = "buffers",
        show_buffer_close_icons = false,
        show_close_icon = false,
        separator_style = "slant",
        always_show_bufferline = false,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
            local icons = { Error = " ", Warn = " ", Info = " " }
            local ret = (diag.error and icons.Error .. diag.error .. " " or "")
            .. (diag.warning and icons.Warn .. diag.warning or "")
            return vim.trim(ret)
        end,
      },
    },
  },

  -----------------------------------------------------------------------------
  -- 6. Git Integration (Gitsigns)
  -----------------------------------------------------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = true, -- VS Code style blame ghost text
    },
  },

  -----------------------------------------------------------------------------
  -- 7. Indentation Guides (Indent Blankline)
  -----------------------------------------------------------------------------
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = {
        indent = { char = "│" },
        scope = { enabled = true, show_start = false, show_end = false },
    },
  },

  -----------------------------------------------------------------------------
  -- 8. Scrollbar (VS Code Style)
  -----------------------------------------------------------------------------
  {
    "petertriho/nvim-scrollbar",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
       require("scrollbar").setup({
           handle = { color = "#504945" },
           excluded_filetypes = { "cmp_menu", "cmp_docs", "notify", "noice", "prompt", "TelescopePrompt" },
       })
    end,
  },

  -----------------------------------------------------------------------------
  -- 9. Key Helper (WhichKey)
  -----------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {
       spec = {
         { "<leader>c", group = "Code" },
         { "<leader>f", group = "Find/File" },
         { "<leader>p", group = "Python/Project" },
         { "<leader>t", group = "Test/Terminal" },
         { "<leader>b", group = "Debug/Buffer" },
       },
    },
  },

  -----------------------------------------------------------------------------
  -- 10. Word Highlighting (Illuminate)
  -----------------------------------------------------------------------------
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts = { delay = 200, large_file_cutoff = 2000, large_file_overrides = { providers = { "lsp" } } },
    config = function(_, opts) require("illuminate").configure(opts) end,
  },
  
  -- Symbols Outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } },
    config = true,
  },
  
  -- LSP Kind icons
  { "onsails/lspkind.nvim", event = "VeryLazy" },

  -- Theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      local theme = vim.env.DOTFILES_THEME or "catppuccin-mocha"
      local flavour = "mocha"
      if theme == "catppuccin-latte" then
        flavour = "latte"
      end

      require("catppuccin").setup({
          flavour = flavour,
          integrations = {
              nvimtree = true,
              notify = true,
              symbols_outline = true,
              mason = true,
              neotest = true,
              noice = true,
              gitsigns = true,
              illuminate = true,
              which_key = true,
              scrollbar = true,
          }
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
