return {
  -- Treesitter (Syntax Highlighting)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- Use correct module path (configs)
      local ok, ts_config = pcall(require, "nvim-treesitter.configs")
      if not ok then
        -- Treesitter not installed yet, skip configuration
        return
      end
      
      ts_config.setup({
        ensure_installed = { "python", "go", "markdown", "json", "toml", "yaml", "bash", "vim", "regex", "lua", "rust", "dockerfile" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Neotest (Testing)
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-plenary",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            dap = { justMyCode = false },
            runner = "pytest",
            args = { "--cov", "--cov-report=term-missing", "-v" },
          }),
          require("neotest-plenary"),
        },
      })
      -- Keymaps
      vim.keymap.set("n", "<leader>tn", function() require("neotest").run.run() end, { desc = "Run nearest test" })
      vim.keymap.set("n", "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, { desc = "Run test file" })
      vim.keymap.set("n", "<leader>ts", function() require("neotest").summary.toggle() end, { desc = "Toggle test summary" })
      vim.keymap.set("n", "<leader>to", function() require("neotest").output.open({ enter = true }) end, { desc = "Show test output" })
    end,
  },

  -- Debugging (DAP + Python)
  {
    "mfussenegger/nvim-dap",
    dependencies = { 
      "rcarriga/nvim-dap-ui", 
      "mfussenegger/nvim-dap-python", 
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "jbyuki/one-small-step-for-vimkind"
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local dap_python = require("dap-python")
      local osv = require("osv")

      -- Enhanced UI setup
      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      -- Python path resolution (Robust for Venv/System)
      -- 1. Check for VIRTUAL_ENV env var
      -- 2. Check for .venv directory
      -- 3. Fallback to specific masonry path (if installed) or system python
      local venv_path = os.getenv("VIRTUAL_ENV")
      local python_path
      if venv_path then
         python_path = venv_path .. "/bin/python"
      else
         python_path = vim.fn.exepath("python3") or vim.fn.exepath("python")
      end
      
      dap_python.setup(python_path)
      dap_python.test_runner = "pytest"

      -- Auto-open UI
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Local Lua debugger (OSV)
      osv.setup({ port = 8086 })
      dap.adapters.nlua = function(callback, config)
        callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
      end
      dap.configurations.lua = {
        {
          type = "nlua",
          request = "attach",
          name = "Attach to running Neovim instance",
        },
      }

      -- Signs
      vim.fn.sign_define('DapBreakpoint', {text='🔴', texthl='DapBreakpoint', linehl='', numhl=''})
      vim.fn.sign_define('DapStopped', {text='🟢', texthl='DapStopped', linehl='DapStopped', numhl='DapStopped'})
    end,
  },

  -- Debugging (DAP + Go)
  {
    "leoluz/nvim-dap-go",
    ft = { "go" },
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-go").setup()
    end,
  },

  -- Linting (Nvim-Lint)
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "mypy", "codespell" }, 
        markdown = { "codespell" },
        dockerfile = { "hadolint" },
      }
      
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("lint", { clear = true }),
        callback = function() lint.try_lint() end,
      })
    end,
  },

  -- Neogen (Docstrings)
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    cmd = "Neogen",
    keys = {
      { "<leader>nd", ":Neogen<CR>", desc = "Generate Docstring" },
    },
    config = function()
      require("neogen").setup({ snippet_engine = "luasnip" })
    end,
  },

  -- Telescope (Fuzzy Finder)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-telescope/telescope-fzf-native.nvim", "ThePrimeagen/git-worktree.nvim" },
    cmd = "Telescope",
    config = function()
       local telescope = require("telescope")
       telescope.setup({
         defaults = {
           file_ignore_patterns = { ".git/", "node_modules", ".venv" },
           layout_strategy = "horizontal",
           layout_config = { prompt_position = "top" },
           sorting_strategy = "ascending",
           winblend = 0,
         },
         pickers = {
           find_files = { hidden = true },
         },
       })
       pcall(telescope.load_extension, "fzf")
       pcall(telescope.load_extension, "git_worktree")
    end
  },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  {
    "ThePrimeagen/git-worktree.nvim",
    config = function()
      require("git-worktree").setup()
    end,
  },

  -- Venv Selector (Python Env Management)
  {
    "linux-cultist/venv-selector.nvim",
    branch = "main", -- Explicitly switch back to main
    dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim", "mfussenegger/nvim-dap-python" },
    cmd = "VenvSelect",
    keys = { { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" } },
    opts = {
        name = { "venv", ".venv", "env", ".env" }, 
        auto_refresh = false, -- Disable auto-scan to prevent home dir timeouts
        dap_enabled = true,
    },
  },
}
